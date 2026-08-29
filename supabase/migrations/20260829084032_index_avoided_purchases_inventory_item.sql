create index avoided_purchases_inventory_item_id_idx
  on public.avoided_purchases using btree (inventory_item_id);
