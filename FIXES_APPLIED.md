# FridgeWise fixes applied

This project copy contains the requested fixes for the dashboard streak, per-user fridge data, and avatar consistency.

## What changed

- **Waste streak no longer increases just by opening/refreshing the Fridge page.**
  - The streak RPC is only called after a real rescue action such as consuming an unexpired item or completing a rescue recipe.
  - The Supabase RPC now stores `last_streak_date` and no-ops after the first credited action of the Singapore calendar day.
- **Fridge and Inventory are now per-user.**
  - Reads/writes include the authenticated user's `user_id`.
  - Supabase RLS only allows users to access their own fridge rows.
  - Existing shared demo/seed rows remain `user_id = null`, so they disappear from normal signed-in accounts instead of appearing as inherited ingredients.
  - The shared Dashboard/recipe caches are also cleared and reloaded when the signed-in account changes.
- **Avoided-purchase events are now per-user** as well.
- **Gamification local state is scoped per signed-in user** so quest/bonus state on the same device does not leak between accounts.
- **Dashboard and Profile avatar now use the same profile avatar as the current user's leaderboard entry.**

## Required Supabase step

The Dart code expects the included migration to be applied:

`supabase/migrations/20260829234500_scope_fridge_and_guard_streak.sql`

If your local project is linked to your Supabase project, run:

```bash
supabase db push
```

Alternatively, paste that migration into the Supabase SQL Editor and run it once.

## After replacing your local project

Keep your existing `.env` file (it is intentionally not included in this package), then run:

```bash
flutter pub get
cd ios
pod install
cd ..
flutter run
```

## Quick behaviour check

1. Sign in with User A: inventory should only show items User A added.
2. Sign in with a fresh User B account: inventory should start empty.
3. Open Dashboard/Fridge repeatedly without doing anything: streak should not change.
4. Consume a non-expired item: the streak may increment once for that day if the zero-waste condition is satisfied.
5. Repeat valid actions on the same day: the streak should not increment again.
6. Dashboard/Profile avatar should match the signed-in user's avatar shown in the leaderboard.
