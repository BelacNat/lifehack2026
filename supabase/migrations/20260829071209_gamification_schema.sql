-- Gamification schema: profiles, points ledger, quests, quest progress,
-- friend requests. Owner: Person 3 (Gamification). Does not modify any
-- existing table.

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null,
  avatar_emoji text not null default '🙂',
  township text,
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "profiles are viewable by authenticated users"
  on public.profiles for select
  to authenticated
  using (true);

create policy "users can insert their own profile"
  on public.profiles for insert
  to authenticated
  with check ((select auth.uid()) = id);

create policy "users can update their own profile"
  on public.profiles for update
  to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

-- Append-only. Weekly/monthly/lifetime totals are computed by summing this
-- table (see views below), never stored, so they can't drift out of sync.
create table public.points_ledger (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  source text not null check (source in ('food_rescue', 'quest_claim')),
  source_id text,
  points integer not null check (points > 0),
  earned_at timestamptz not null default now()
);

create index points_ledger_user_id_idx on public.points_ledger (user_id);
create index points_ledger_earned_at_idx on public.points_ledger (earned_at);

alter table public.points_ledger enable row level security;

create policy "points are viewable by authenticated users"
  on public.points_ledger for select
  to authenticated
  using (true);

-- Deliberately no INSERT policy for regular users — rows are only written
-- by claim_quest_reward() below, so points can't be fabricated via the
-- REST API. 'food_rescue' is defined for future use; nothing writes it yet.

create table public.quests (
  id text primary key,
  title text not null,
  emoji text not null,
  points_reward integer not null check (points_reward > 0),
  ends_at timestamptz,
  active boolean not null default true
);

alter table public.quests enable row level security;

create policy "quests are viewable by authenticated users"
  on public.quests for select
  to authenticated
  using (true);

create table public.quest_progress (
  id bigint generated always as identity primary key,
  user_id uuid not null references public.profiles(id) on delete cascade,
  quest_id text not null references public.quests(id) on delete cascade,
  progress numeric not null default 0 check (progress >= 0 and progress <= 1),
  claimed_at timestamptz check (claimed_at is null or progress >= 1),
  unique (user_id, quest_id)
);

create index quest_progress_user_id_idx on public.quest_progress (user_id);
create index quest_progress_quest_id_idx on public.quest_progress (quest_id);

alter table public.quest_progress enable row level security;

create policy "users see their own quest progress"
  on public.quest_progress for select
  to authenticated
  using ((select auth.uid()) = user_id);

create policy "users can create their own quest progress rows"
  on public.quest_progress for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

create policy "users can update their own quest progress"
  on public.quest_progress for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

-- "Friends" is derived as any pair with status = 'accepted', rather than a
-- separate friendships table, so the two representations can't disagree.
create table public.friend_requests (
  id bigint generated always as identity primary key,
  requester_id uuid not null references public.profiles(id) on delete cascade,
  recipient_id uuid not null references public.profiles(id) on delete cascade,
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'rejected')),
  created_at timestamptz not null default now(),
  responded_at timestamptz,
  check (requester_id <> recipient_id),
  unique (requester_id, recipient_id)
);

create index friend_requests_requester_id_idx
  on public.friend_requests (requester_id);
create index friend_requests_recipient_id_idx
  on public.friend_requests (recipient_id);

alter table public.friend_requests enable row level security;

create policy "users see requests they sent or received"
  on public.friend_requests for select
  to authenticated
  using ((select auth.uid()) in (requester_id, recipient_id));

create policy "users can send friend requests"
  on public.friend_requests for insert
  to authenticated
  with check ((select auth.uid()) = requester_id);

create policy "recipients can respond to requests"
  on public.friend_requests for update
  to authenticated
  using ((select auth.uid()) = recipient_id)
  with check ((select auth.uid()) = recipient_id);

-- Atomically marks a quest claimed and credits points, so a client can only
-- ever earn a quest's reward once, for a quest it actually completed.
create or replace function public.claim_quest_reward(p_quest_id text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user_id uuid := (select auth.uid());
  v_reward integer;
begin
  if v_user_id is null then
    raise exception 'not authenticated';
  end if;

  update public.quest_progress
    set claimed_at = now()
    where user_id = v_user_id
      and quest_id = p_quest_id
      and progress >= 1
      and claimed_at is null;

  if not found then
    raise exception 'quest not claimable';
  end if;

  select points_reward into v_reward
    from public.quests where id = p_quest_id;

  insert into public.points_ledger (user_id, source, source_id, points)
  values (v_user_id, 'quest_claim', p_quest_id, v_reward);
end;
$$;

revoke all on function public.claim_quest_reward(text) from public;
grant execute on function public.claim_quest_reward(text) to authenticated;

-- security_invoker so these respect the querying user's own RLS rather
-- than the view owner's.
create view public.leaderboard_weekly with (security_invoker = true) as
  select user_id, sum(points)::integer as points
  from public.points_ledger
  where earned_at >= date_trunc('week', now())
  group by user_id;

create view public.leaderboard_monthly with (security_invoker = true) as
  select user_id, sum(points)::integer as points
  from public.points_ledger
  where earned_at >= date_trunc('month', now())
  group by user_id;

create view public.leaderboard_lifetime with (security_invoker = true) as
  select user_id, sum(points)::integer as points
  from public.points_ledger
  group by user_id;
