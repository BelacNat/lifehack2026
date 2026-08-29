# EcoHabit — LifeHack 2026

Sustainability habit app: track your fridge inventory, rescue food before it
expires, and build streaks through eco quests. See `TEAM_SPLIT.md` for how
the 4-person team divides the work.

## Stack

- Flutter + Dart
- `go_router` (bottom-nav shell navigation)
- Supabase (Postgres, Auth) via `supabase_flutter`

## Getting started

```bash
cp .env.example .env   # fill in SUPABASE_ANON_KEY
flutter pub get
flutter run
```

## Project layout

```
lib/
  main.dart                          Loads env, initializes Supabase, runs app
  app.dart                           MaterialApp.router + theme
  core/
    navigation/
      app_router.dart                go_router config (append-only branches)
      nav_items.dart                 Bottom nav tabs (append-only list)
      root_shell.dart                Bottom-nav scaffold
    supabase/
      supabase_client.dart           Shared Supabase client accessor
    theme/
      app_theme.dart
  features/
    dashboard/    presentation/      Person 4 — Impact + Home
    inventory/    presentation/      Person 1 — Pause Before Purchase
    fridge/       presentation/      Person 2 — Rescue My Fridge
    quests/       presentation/      Person 3 — EcoQuests & Rewards
supabase/
  migrations/     One timestamped SQL file per feature, see its README
```

## Useful commands

- `flutter run` — run on a connected device/emulator
- `flutter analyze` — static analysis / lints
- `flutter test` — run tests
- `flutter build apk` / `flutter build ios` / `flutter build web` — release builds
