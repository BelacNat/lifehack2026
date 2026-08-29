# Migrations

Each person owns their own tables — never add columns to someone else's
table without asking them first.

To avoid two people editing the same migration file:

1. Run `supabase migration new <your_feature>_<what>` to create your own
   timestamped file (e.g. `20260829101500_inventory_init.sql`).
2. Only add new files here — never edit a migration someone else already
   committed. If you need to change a shipped table, add a new migration
   that alters it.
3. Suggested table ownership (rename to match your actual schema):
   - Person 1 (Inventory & Shopping): `inventory_items`, `shopping_list_items`
   - Person 2 (Food Rescue & AI): `fridge_items`, `recipe_suggestions`
   - Person 3 (Gamification): `quests`, `quest_completions`, `eco_points`
   - Person 4 (Dashboard & Integration): any cross-cutting views/aggregates

Since filenames are timestamped, everyone's migrations apply cleanly in
parallel — there's nothing to merge.
