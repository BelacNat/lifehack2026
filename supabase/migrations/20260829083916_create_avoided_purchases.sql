create table public.avoided_purchases (
  id bigint generated always as identity primary key,
  inventory_item_id bigint references public.fridge_items (id)
    on delete set null,
  item_name text not null constraint avoided_purchases_item_name_not_blank
    check (btrim(item_name) <> ''),
  shopping_quantity numeric not null
    constraint avoided_purchases_quantity_positive
    check (shopping_quantity > 0),
  shopping_unit text not null
    constraint avoided_purchases_unit_valid
    check (shopping_unit in ('pcs', 'g', 'ml')),
  estimated_savings numeric,
  avoided_at timestamptz not null default now(),
  constraint avoided_purchases_savings_nonnegative
    check (estimated_savings is null or estimated_savings >= 0)
);

create index avoided_purchases_avoided_at_idx
  on public.avoided_purchases using btree (avoided_at desc);

alter table public.avoided_purchases enable row level security;

revoke all on table public.avoided_purchases from anon, authenticated;
grant select, insert on table public.avoided_purchases to anon, authenticated;
grant usage, select on sequence public.avoided_purchases_id_seq
  to anon, authenticated;

create policy "Demo users can view avoided purchases"
  on public.avoided_purchases for select
  to anon, authenticated
  using (true);

create policy "Demo users can record avoided purchases"
  on public.avoided_purchases for insert
  to anon, authenticated
  with check (true);

comment on table public.avoided_purchases is
  'Shared demo events for skipped duplicate purchases; ready for impact and quest aggregation.';
