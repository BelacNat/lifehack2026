# Team split & git workflow

4-person split, mapped onto this Flutter skeleton so each person's work
lives in its own folder and rarely touches a file anyone else edits.

| Person | Owns | Folder |
|---|---|---|
| 1 — Inventory & Shopping (🛒 Pause Before Purchase) | Inventory list, shopping-list input/OCR, duplicate-purchase warnings | `lib/features/inventory/` |
| 2 — Food Rescue & AI (🥕 Rescue My Fridge) | Expiry tracking, AI/recipe recommendations, marking items consumed | `lib/features/fridge/` |
| 3 — Gamification (🎯 EcoQuests & Rewards) | Daily quests, EcoPoints, streaks, levels/tree progression | `lib/features/quests/` |
| 4 — Dashboard & Integration (🌍 Impact + Home) | Home dashboard, impact stats, overall navigation, wiring features together | `lib/features/dashboard/`, plus the shared shell below |

Each person also owns writing the README section and demo-video piece listed
in the original plan — that's docs/content work, not code, so it doesn't
create merge conflicts either way.

## Why this avoids conflicts

- **No shared feature files.** Each feature's page only lives in its own
  `lib/features/<feature>/` folder. Two people editing different features
  never touch the same file.
- **Nav is append-only.** To add your tab, add one line to `kNavItems` in
  `lib/core/navigation/nav_items.dart`, and one `StatefulShellBranch` at the
  end of the list in `lib/core/navigation/app_router.dart` — don't reorder
  or edit anyone else's entry. Git merges independent added lines in the
  same file without conflict.
- **Migrations are append-only files.** Each person creates their own
  timestamped SQL file under `supabase/migrations/` (see the README there)
  instead of editing a shared schema file.
- **Dependencies are front-loaded.** The starter already includes
  `go_router`, `supabase_flutter`, and `flutter_dotenv`. If you need
  something hackathon-specific (charts, camera/OCR, etc.), add it to
  `pubspec.yaml` early and push that as its own tiny commit so
  `pubspec.yaml`/`pubspec.lock` conflicts don't pile up later.

## One-time setup (do this first, together)

This skeleton was hand-written without the Flutter SDK available in the
authoring environment, so the platform folders (`android/`, `ios/`, `web/`,
etc.) don't exist yet. Whoever sets up first, on a machine with Flutter
installed, should run:

```bash
flutter create . --project-name ecohabit --org com.ecovolt.ecohabit
flutter pub get
```

`flutter create .` fills in the missing platform folders without touching
`pubspec.yaml`'s dependencies or anything under `lib/`. Commit the result
once, before anyone starts on their feature branch — that's the one
scaffolding step everyone should build on top of rather than each doing
separately (which would generate near-identical but conflicting platform
files).

Then everyone:

```bash
cp .env.example .env   # fill in SUPABASE_ANON_KEY
flutter pub get
flutter run
```

## Git workflow

1. Branch per person: `feature/inventory`, `feature/fridge`, `feature/quests`,
   `feature/dashboard`.
2. Commit and push often — small commits merge easier than one giant diff.
3. Before opening a PR (or merging to `main`), rebase on latest `main`:
   ```
   git fetch origin main
   git rebase origin/main
   ```
4. Person 4 (Dashboard & Integration) merges everyone's branches into `main`
   and resolves any shell/nav conflicts centrally, since they own the
   integration layer.
5. If you touch a shared file (`lib/app.dart`, `lib/main.dart`,
   `lib/core/*`, `pubspec.yaml`), keep the diff additive and give the group
   a heads-up — that's the one place conflicts can still happen.

## Filling in your feature

Each feature folder starts with a placeholder page
(`lib/features/<feature>/presentation/<feature>_page.dart`). Replace its
body — keep the file and class name so the router doesn't need touching.
