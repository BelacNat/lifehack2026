-- Fridge Items: base table + seed data for the "Rescue My Fridge" feature
-- (Person 2 — Food Rescue & AI). Shared demo table for now: the app has no
-- auth flow yet, so this isn't scoped per-user. Once auth lands, add a
-- `user_id uuid references auth.users(id)` column and swap the policies
-- below for the standard `to authenticated using (user_id = auth.uid())`
-- pattern (see security-rls-basics in the supabase-postgres-best-practices
-- skill) instead of the open ones here.

create table if not exists public.fridge_items (
  id bigint generated always as identity primary key,
  name text not null,
  category text not null check (
    category in ('dairy', 'produce', 'meat', 'seafood', 'bakery', 'pantry', 'beverage', 'condiment', 'frozen', 'other')
  ),
  quantity numeric not null default 1 check (quantity >= 0),
  unit text not null default 'pcs',
  expiry_date date,
  added_at timestamptz not null default now(),
  consumed_at timestamptz,
  notes text
);

comment on table public.fridge_items is 'Shared demo fridge inventory for Rescue My Fridge. Not yet user-scoped — no auth flow exists in the app.';

alter table public.fridge_items enable row level security;

-- Permissive demo policies: anyone with the anon/authenticated key can
-- read and manage fridge items. Fine for a hackathon prototype with no
-- login; tighten once auth exists.
drop policy if exists "fridge_items_select_all" on public.fridge_items;
create policy "fridge_items_select_all" on public.fridge_items
  for select
  to anon, authenticated
  using (true);

drop policy if exists "fridge_items_insert_all" on public.fridge_items;
create policy "fridge_items_insert_all" on public.fridge_items
  for insert
  to anon, authenticated
  with check (true);

drop policy if exists "fridge_items_update_all" on public.fridge_items;
create policy "fridge_items_update_all" on public.fridge_items
  for update
  to anon, authenticated
  using (true)
  with check (true);

drop policy if exists "fridge_items_delete_all" on public.fridge_items;
create policy "fridge_items_delete_all" on public.fridge_items
  for delete
  to anon, authenticated
  using (true);

-- Belt-and-suspenders in case this project's Data API settings don't
-- auto-expose new tables to anon/authenticated.
grant select, insert, update, delete on public.fridge_items to anon, authenticated;
grant usage, select on sequence public.fridge_items_id_seq to anon, authenticated;

-- Seed data: expiry dates are relative to whenever this migration actually
-- runs, so they stay meaningful (some already expired, some urgent, some
-- fresh) no matter which day the team applies it.
insert into public.fridge_items (name, category, quantity, unit, expiry_date, notes)
values
  ('Whole milk', 'dairy', 1, 'L', (current_date - 1), 'Already past expiry — good test case for the "expired" state'),
  ('Greek yogurt', 'dairy', 4, 'pcs', current_date, 'Expires today'),
  ('Cheddar cheese', 'dairy', 200, 'g', (current_date + 5), null),
  ('Butter', 'dairy', 250, 'g', (current_date + 21), null),
  ('Spinach', 'produce', 1, 'bag', (current_date + 1), 'Wilting — use soon'),
  ('Carrots', 'produce', 6, 'pcs', (current_date + 10), null),
  ('Tomatoes', 'produce', 4, 'pcs', (current_date + 2), null),
  ('Bananas', 'produce', 3, 'pcs', (current_date + 2), null),
  ('Bell peppers', 'produce', 3, 'pcs', (current_date + 6), null),
  ('Chicken breast', 'meat', 500, 'g', (current_date + 1), 'Freeze if not using today'),
  ('Ground beef', 'meat', 400, 'g', (current_date + 2), null),
  ('Salmon fillet', 'seafood', 300, 'g', (current_date), 'Expires today'),
  ('Sourdough bread', 'bakery', 1, 'loaf', (current_date + 3), null),
  ('Eggs', 'dairy', 8, 'pcs', (current_date + 14), null),
  ('Rice', 'pantry', 2, 'kg', (current_date + 180), null),
  ('Pasta', 'pantry', 1, 'kg', (current_date + 200), null),
  ('Canned chickpeas', 'pantry', 2, 'cans', (current_date + 365), null),
  ('Orange juice', 'beverage', 1, 'L', (current_date + 4), null),
  ('Soy sauce', 'condiment', 1, 'bottle', (current_date + 300), null),
  ('Frozen peas', 'frozen', 500, 'g', (current_date + 90), null),
  ('Leftover stir fry', 'other', 1, 'container', (current_date + 1), 'Finish tomorrow')
on conflict do nothing;

-- A couple of already-consumed items, so "mark as consumed" has example
-- history to render from day one.
insert into public.fridge_items (name, category, quantity, unit, expiry_date, added_at, consumed_at)
values
  ('Strawberries', 'produce', 1, 'punnet', (current_date - 3), (now() - interval '5 days'), (now() - interval '2 days')),
  ('Leftover rice', 'other', 1, 'container', (current_date - 2), (now() - interval '4 days'), (now() - interval '1 day'))
on conflict do nothing;
