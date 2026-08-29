update public.fridge_items
set quantity = quantity * 1000,
    unit = 'ml'
where lower(unit) in ('l', 'litre', 'litres');

update public.fridge_items
set quantity = quantity * 1000,
    unit = 'g'
where lower(unit) in ('kg', 'kilogram', 'kilograms');

update public.fridge_items
set unit = 'pcs'
where lower(unit) in (
  'pc', 'piece', 'pieces',
  'loaf', 'loaves',
  'can', 'cans',
  'bottle', 'bottles',
  'container', 'containers'
);
