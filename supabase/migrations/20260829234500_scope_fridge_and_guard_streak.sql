-- Fixes for the authenticated app:
--   1. fridge/inventory rows belong to one signed-in user;
--   2. avoided-purchase events belong to one signed-in user;
--   3. a zero-waste streak can increment at most once per Singapore calendar day.
--
-- Existing shared demo rows are intentionally left with user_id = null. Once
-- these RLS policies are active they are no longer visible to normal users,
-- which gives a newly signed-in account an empty fridge instead of inherited
-- seed/demo ingredients.

-- ---------------------------------------------------------------------------
-- Profile compatibility for the shared avatar / residential-area UI
-- ---------------------------------------------------------------------------
alter table public.profiles
  add column if not exists avatar_emoji text not null default '🙂';

alter table public.profiles
  add column if not exists residential_area text;

-- An earlier migration called this field `township`. Preserve that data when
-- upgrading an environment that still has the old column name.
do $$
begin
  if exists (
    select 1
      from information_schema.columns
      where table_schema = 'public'
        and table_name = 'profiles'
        and column_name = 'township'
  ) then
    execute 'update public.profiles set residential_area = township where residential_area is null';
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- Per-user fridge / inventory
-- ---------------------------------------------------------------------------
alter table public.fridge_items
  add column if not exists user_id uuid references auth.users(id) on delete cascade;

create index if not exists fridge_items_user_id_idx
  on public.fridge_items (user_id);

comment on table public.fridge_items is
  'Per-user fridge inventory. Rows are visible and writable only by their owner.';

drop policy if exists "fridge_items_select_all" on public.fridge_items;
drop policy if exists "fridge_items_insert_all" on public.fridge_items;
drop policy if exists "fridge_items_update_all" on public.fridge_items;
drop policy if exists "fridge_items_delete_all" on public.fridge_items;
drop policy if exists "users select their own fridge items" on public.fridge_items;
drop policy if exists "users insert their own fridge items" on public.fridge_items;
drop policy if exists "users update their own fridge items" on public.fridge_items;
drop policy if exists "users delete their own fridge items" on public.fridge_items;

create policy "users select their own fridge items"
  on public.fridge_items for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "users insert their own fridge items"
  on public.fridge_items for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

create policy "users update their own fridge items"
  on public.fridge_items for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create policy "users delete their own fridge items"
  on public.fridge_items for delete
  to authenticated
  using ((select auth.uid()) = user_id);

revoke all on table public.fridge_items from anon;
grant select, insert, update, delete on table public.fridge_items to authenticated;
grant usage, select on sequence public.fridge_items_id_seq to authenticated;

-- ---------------------------------------------------------------------------
-- Per-user duplicate-purchase / sustainability events
-- ---------------------------------------------------------------------------
alter table public.avoided_purchases
  add column if not exists user_id uuid references auth.users(id) on delete cascade;

create index if not exists avoided_purchases_user_id_idx
  on public.avoided_purchases (user_id);

comment on table public.avoided_purchases is
  'Per-user events for skipped duplicate purchases and sustainability impact.';

drop policy if exists "Demo users can view avoided purchases" on public.avoided_purchases;
drop policy if exists "Demo users can record avoided purchases" on public.avoided_purchases;
drop policy if exists "users view their own avoided purchases" on public.avoided_purchases;
drop policy if exists "users record their own avoided purchases" on public.avoided_purchases;

create policy "users view their own avoided purchases"
  on public.avoided_purchases for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "users record their own avoided purchases"
  on public.avoided_purchases for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

revoke all on table public.avoided_purchases from anon;
grant select, insert on table public.avoided_purchases to authenticated;
grant usage, select on sequence public.avoided_purchases_id_seq to authenticated;

-- ---------------------------------------------------------------------------
-- Once-per-day waste streak
-- ---------------------------------------------------------------------------
-- The app already uses public.user_stats(user_id, streak_days, best_streak,
-- points). Store the last credited local date on the same row so widget reloads
-- and repeated RPC calls cannot create extra streak days.
alter table public.user_stats
  add column if not exists last_streak_date date;

create or replace function public.bump_daily_streak()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_today date := (now() at time zone 'Asia/Singapore')::date;
  v_last_date date;
  v_current_streak integer;
  v_new_streak integer;
begin
  if v_user_id is null then
    raise exception 'not authenticated';
  end if;

  select last_streak_date, streak_days
    into v_last_date, v_current_streak
    from public.user_stats
    where user_id = v_user_id
    for update;

  if not found then
    raise exception 'missing user_stats row for %', v_user_id;
  end if;

  -- Already earned today's streak. Reopening pages or repeating a valid
  -- action on the same day is intentionally a no-op.
  if v_last_date = v_today then
    return;
  end if;

  v_new_streak := case
    when v_last_date = v_today - 1 then coalesce(v_current_streak, 0) + 1
    else 1
  end;

  update public.user_stats
    set streak_days = v_new_streak,
        best_streak = greatest(coalesce(best_streak, 0), v_new_streak),
        last_streak_date = v_today
    where user_id = v_user_id;
end;
$$;

revoke all on function public.bump_daily_streak() from public;
grant execute on function public.bump_daily_streak() to authenticated;
