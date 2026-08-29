# EcoHabit — LifeHack 2026

> Small green habits, tracked and gamified.

EcoHabit is a Flutter application that helps households reduce food waste before it happens. It connects grocery planning, fridge inventory, expiry rescue, AI-assisted recipes, and sustainability challenges in one mobile-first experience.

| Project information | Details |
|---|---|
| Team | _Add team member names_ |
| Advisor | _Add advisor name, if applicable_ |
| Proposed achievement | _Add level of achievement, if applicable_ |
| GitHub repository | [BelacNat/lifehack2026](https://github.com/BelacNat/lifehack2026) |
| Project log | _Add project log link, if applicable_ |
| Deployment | _Add deployment link, if applicable_ |

## Contents

- [Overview](#overview)
  - [Motivation](#motivation)
  - [Existing solutions and their gaps](#existing-solutions-and-their-gaps)
  - [Aim](#aim)
  - [Target audience](#target-audience)
- [Tech stack](#tech-stack)
- [Architecture](#architecture)
  - [System components](#system-components)
  - [Data flow](#data-flow)
  - [Design rationale](#design-rationale)
- [Project structure](#project-structure)
- [Database and backend](#database-and-backend)
- [Software engineering principles](#software-engineering-principles)
- [Features](#features)
- [Testing](#testing)
- [Getting started](#getting-started)
- [Demo guide](#demo-guide)
- [Known limitations](#known-limitations)
- [Timeline and development plan](#timeline-and-development-plan)
- [Team collaboration](#team-collaboration)

---

## Overview

### Motivation

Food waste often begins with small, disconnected decisions:

- buying an item that is already at home;
- forgetting what is approaching expiry;
- not knowing what to cook with available ingredients;
- lacking a visible sense of progress after preventing waste.

Many existing tools address only one part of this journey. A shopping list may help before purchase, while a recipe application helps after purchase, but neither necessarily closes the loop between planning, inventory, consumption, and measurable environmental impact.

EcoHabit treats food rescue as one connected habit cycle:

> **Check before buying → track what is at home → rescue food before expiry → earn progress → repeat**

### Existing solutions and their gaps

| Existing approach | What it does well | Remaining gap addressed by EcoHabit |
|---|---|---|
| Notes and shopping-list apps | Make grocery planning quick | Do not know what is already in the fridge or warn about likely duplicates |
| Manual fridge trackers | Record stored food and expiry dates | Data entry can be slow, and the information may not lead to an immediate action |
| Recipe applications | Suggest meals from searches or selected ingredients | Often do not prioritise expiring ingredients or update the user's actual stock |
| Sustainability trackers | Show challenges, streaks, or impact metrics | May be disconnected from real household food-rescue actions |
| Loyalty and leaderboard systems | Encourage repeated engagement | Often reward spending rather than avoided waste |

EcoHabit combines these functions into a single application and uses actual inventory events—such as avoiding a duplicate purchase or consuming an expiring item—to drive the user's progress.

### Aim

EcoHabit aims to make low-waste behaviour:

1. **Preventive** — warn users before they purchase food they already own.
2. **Timely** — highlight food that should be consumed soon.
3. **Actionable** — turn at-risk ingredients into practical recipe suggestions.
4. **Rewarding** — connect real actions to EcoPoints, quests, and streaks.
5. **Easy to maintain** — reduce data-entry friction with camera and text recognition.

### Target audience

EcoHabit is designed for:

- students and young adults managing groceries independently;
- families sharing a household fridge;
- budget-conscious shoppers who want to avoid duplicate purchases;
- environmentally conscious users who want practical, measurable habits;
- users in Singapore who want neighbourhood-based community motivation.

---

## Tech stack

| Layer | Technology | Purpose |
|---|---|---|
| Frontend | Flutter and Dart | Cross-platform application interface |
| Design system | Material 3 | Consistent components, colour, and interaction patterns |
| Navigation | go_router | Authentication redirects and persistent bottom navigation |
| Authentication | Supabase Auth | Email/password account creation and sign-in |
| Database | Supabase Postgres | Inventory, avoided-purchase, profile, and gamification data |
| Backend logic | Supabase Edge Functions | Secure server-side AI requests |
| Local persistence | SharedPreferences | Quest progress, claimed rewards, and local preferences |
| On-device recognition | Google ML Kit Text Recognition | Reads handwritten or printed grocery text on Android and iOS |
| AI recognition | OpenAI vision through an Edge Function | Identifies visible grocery items from an image |
| AI recipes | OpenAI recipe suggestion service | Produces recipes using active fridge ingredients |
| Recipe imagery | Wikipedia API | Retrieves a representative image for recipe details |
| Media input | image_picker | Camera and gallery image selection |
| Networking | http | External API communication |

---

## Architecture

### System components

EcoHabit follows a feature-oriented Flutter structure. Each major user journey owns its presentation, domain, and data logic where applicable.

| Component | Responsibility |
|---|---|
| Authentication and profile | Protects application routes and manages user identity and residential area |
| Dashboard | Aggregates impact statistics, category summaries, urgent items, and recipe shortcuts |
| Inventory | Adds, sorts, scans, checks, and removes household food items |
| Fridge rescue | Finds urgent food, records consumption, and awards rescue points |
| Recipe rescue | Generates recipes from available stock and deducts ingredients after cooking |
| Quests and rewards | Tracks sustainability actions, streaks, EcoPoints, and quest claims |
| Supabase | Stores shared application data and exposes authentication, SQL, RPC, and function services |
| Local storage | Preserves selected prototype gamification state and notification preferences |

### Data flow

~~~mermaid
flowchart LR
    U[User] --> UI[Flutter interface]
    UI --> NAV[go_router]
    UI --> CTRL[Feature controllers]
    CTRL --> REPO[Feature repositories]

    REPO --> AUTH[Supabase Auth]
    REPO --> DB[(Supabase Postgres)]
    REPO --> EDGE[Supabase Edge Functions]
    CTRL --> LOCAL[(SharedPreferences)]

    UI --> CAMERA[Camera or gallery]
    CAMERA --> ML[ML Kit text recognition]
    CAMERA --> EDGE
    EDGE --> AI[OpenAI vision and recipes]
    CTRL --> WIKI[Wikipedia recipe images]

    DB --> DASH[Impact dashboard]
    DB --> RESCUE[Expiry rescue]
    RESCUE --> QUEST[EcoPoints and quest progress]
    QUEST --> DASH
~~~

A typical rescue journey is:

1. The user adds food manually or scans a list or grocery image.
2. Inventory items are saved in Supabase with quantity, unit, category, and expiry date.
3. The Fridge view queries unconsumed items that expire today or within three days.
4. The user marks an item as eaten or opens an AI-generated rescue recipe.
5. Recipe completion deducts the quantities used and marks empty items as consumed.
6. Rescue actions contribute to EcoPoints, streaks, quests, and dashboard statistics.

### Design rationale

**Feature-first organisation.** Inventory, fridge rescue, quests, dashboard, authentication, and profile code are separated so team members can work independently.

**Repository boundary.** Supabase queries are kept in repository or service classes instead of being spread throughout widgets.

**Progressive review for AI input.** Recognition results are never written directly to the database. Users can edit, deselect, and confirm detected foods first.

**Graceful fallbacks.** On supported mobile platforms, local text recognition can still extract a grocery list if server-side food recognition is unavailable.

**Best-effort gamification sync.** Prototype quest state remains responsive locally even when a backend reward update is unavailable.

---

## Project structure

~~~text
lifehack2026/
├── lib/
│   ├── main.dart                         # Environment and Supabase initialisation
│   ├── app.dart                          # MaterialApp, theme, and router
│   ├── core/
│   │   ├── navigation/                   # Routes and persistent bottom navigation
│   │   ├── supabase/                     # Shared client and Singapore towns
│   │   └── theme/                        # Application theme
│   └── features/
│       ├── auth/presentation/             # Sign-in and sign-up
│       ├── dashboard/presentation/        # Impact home and category drill-down
│       ├── inventory/
│       │   ├── data/                      # Inventory storage and OCR services
│       │   ├── domain/                    # Inventory, OCR, and shopping-list logic
│       │   └── presentation/              # Inventory and purchase-checking interface
│       ├── fridge/
│       │   ├── data/                      # Rescue, recipe, and notification services
│       │   ├── domain/                    # Fridge and recipe models
│       │   └── presentation/              # Urgent food and recipe interfaces
│       ├── quests/
│       │   ├── data/                      # Points, streaks, friends, and progress stores
│       │   ├── domain/                    # Quest and leaderboard models
│       │   └── presentation/              # Quests, leaderboard, and friends
│       └── profile/presentation/           # User profile
├── supabase/
│   ├── functions/
│   │   └── recognize-inventory-foods/     # OpenAI image-recognition function
│   └── migrations/                        # Timestamped Postgres migrations
├── test/                                  # Parser, checker, and widget tests
├── android/ ios/ web/ macos/ linux/ windows/
├── TEAM_SPLIT.md                          # Team ownership and Git workflow
└── pubspec.yaml                           # Flutter dependencies and assets
~~~

---

## Database and backend

### Main data areas

| Data area | Purpose |
|---|---|
| <code>fridge_items</code> | Stores food name, category, quantity, unit, expiry, and consumption state |
| <code>avoided_purchases</code> | Records occasions where a user chooses not to buy a detected duplicate |
| <code>profiles</code> | Stores user-facing account information and location metadata |
| <code>quests</code> and quest-related records | Describe rewards and completion state in the intended backend model |
| Gamification RPCs | Intended to award rescue or quest points and update daily streaks |

### Data validation

The application normalises inventory quantities and units before storage. It supports:

- countable items;
- weights;
- liquid volumes;
- category selection;
- required expiry dates;
- consumed and unconsumed states.

Shopping-list text is parsed before matching. The checker understands common quantity formats, number words, containers, and plural forms, then compares the normalised item name against existing inventory.

### Edge Function security

The <code>recognize-inventory-foods</code> function keeps the OpenAI API key on the server. The authenticated Flutter client sends a compressed image and receives structured food detections. The key is never embedded in the application bundle.

### Prototype database note

The committed migrations capture part of the backend but do not yet reproduce every service expected by the client. See [Known limitations](#known-limitations) before setting up a new Supabase project.

---

## Software engineering principles

### Separation of concerns

Widgets focus on interaction and rendering. Repositories handle Supabase data access, controllers coordinate feature state, domain models represent application concepts, and services integrate with external APIs.

### Don't repeat yourself

Shared behaviours—such as inventory normalisation, points calculation, recipe image loading, route protection, and Supabase access—are implemented once and reused by the relevant screens.

### Defensive user flows

AI and OCR output is treated as a suggestion. Users remain in control of what is saved. Network-dependent actions surface retryable states, and important local interactions are kept responsive.

### Append-only collaboration

The project uses feature folders and timestamped SQL migrations to reduce merge conflicts. Shared navigation is kept small, while each team member owns a bounded feature area.

### Version control practices

The repository uses feature ownership, small commits, and a documented rebase workflow. At the time of this review, the repository contained 37 commits and 249 tracked files.

---

## Features

### 01 — Authentication and profile

**What users can do**

- Create an account using email and password.
- Provide a display name and residential area during registration.
- Sign in and sign out.
- Update their residential area from the profile screen.

**How it works**

go_router watches Supabase authentication changes. Signed-out users are redirected to the sign-in page, while authenticated users enter the main four-tab application shell.

**Status:** Implemented, subject to the profile-schema limitation described below.

---

### 02 — Pause Before Purchase

The Inventory tab is designed to stop duplicate purchases before checkout.

**What users can do**

- View the household's current food inventory.
- Add an item with name, quantity, unit, category, and expiry date.
- Sort inventory by name, category, or expiry.
- Delete an item.
- Paste or type a shopping list to check against food already at home.
- Skip a likely duplicate and record it as an avoided purchase.
- Ignore a warning when the purchase is still necessary.

**How duplicate detection works**

The parser handles entries such as:

- <code>2 apples</code>
- <code>two cartons of milk</code>
- <code>1.5 kg chicken breast</code>
- plural and partial name variations

Normalised shopping-list names are compared with active inventory. When a match is found, EcoHabit presents a warning and lets the user make the final decision.

**Status:** Implemented with live Supabase inventory data.

---

### 03 — Grocery scanning and OCR

EcoHabit reduces manual entry by supporting two complementary recognition paths on Android and iOS.

#### Text recognition

ML Kit extracts handwritten or printed grocery text locally. The recognised text is converted into editable inventory candidates.

#### Food-image recognition

A selected camera or gallery image can be sent to the authenticated Supabase Edge Function. OpenAI vision returns structured names for visible foods.

#### Human review

Before saving, users can:

- review every detected item;
- edit an incorrect name;
- deselect an unwanted detection;
- add the selected results to inventory.

<table>
  <tr>
    <td align="center"><img src="Codex%20Image%2029%20Aug%202026%2C%2017_49_12.png" alt="Handwritten grocery-list recognition input" width="320"></td>
    <td align="center"><img src="Codex%20Image%2029%20Aug%202026%2C%2017_52_44.png" alt="Visible grocery recognition input" width="320"></td>
  </tr>
  <tr>
    <td align="center"><em>Handwritten grocery-list input</em></td>
    <td align="center"><em>Visible grocery-item input</em></td>
  </tr>
</table>

**Status:** Implemented on Android and iOS. Other platforms use the unsupported-platform fallback.

---

### 04 — Rescue My Fridge

The Fridge tab turns an expiry warning into an immediate action.

**What users can do**

- See unconsumed items expiring today.
- See items expiring within the next three days.
- Pull to refresh the latest inventory.
- Mark an item with **I ate this** after consuming it.

**How rewards are calculated**

Rescued food awards category-weighted points rather than treating every item identically. The event is passed into the gamification layer, which updates relevant progress and attempts to sync points and streaks to Supabase.

**Status:** Core rescue flow implemented.

---

### 05 — AI rescue recipes

When food is available, EcoHabit can generate recipes that prioritise ingredients closest to expiry.

**What users can do**

- Browse recipe suggestions generated from active, non-expired inventory.
- Open recipe details with ingredients and instructions.
- Change the number of servings from 1 to 8.
- See serving limits when the fridge does not contain enough stock.
- Confirm cooking to deduct used ingredient quantities.
- Automatically mark fully used items as consumed.
- View a representative recipe image retrieved from Wikipedia.

**Inventory-aware completion**

Recipe completion is not only a visual confirmation. It updates the underlying stock, creating a closed loop between recipe choice and the next inventory view.

**Status:** Client integration implemented. A corresponding recipe Edge Function is required but is not included in this repository.

---

### 06 — Impact dashboard

The Home tab summarises the user's current sustainability state.

**Dashboard sections**

- user greeting and profile access;
- impact statistics;
- urgent expiry shelf;
- inventory category counts;
- category detail drill-down;
- recipe shortcuts;
- shopping insight.

Dashboard inventory and profile sections are connected to Supabase. The category breakdown lets users move from a high-level count to the individual food items behind it.

**Status:** Partially dynamic. The displayed date and shopping insight are currently static prototype content.

---

### 07 — EcoQuests, EcoPoints, and streaks

EcoHabit turns repeated actions into visible progress.

**Implemented behaviour**

- Six quest definitions are available in the application.
- Progress is driven by in-app actions such as inventory activity and food rescue.
- Claimable rewards are stored locally for responsive prototype behaviour.
- Reward claims attempt a best-effort Supabase sync.
- Rescue points use category-based weighting.
- Daily streak update services are connected from rescue-related flows.

**Why it matters**

The goal is not to reward opening the application. The intended loop connects meaningful actions—avoiding a purchase, logging food, or rescuing an expiring item—to progress that the user can see.

**Status:** Hybrid local/backend prototype. Some progress rules currently trigger more broadly than the intended final behaviour.

---

### 08 — Leaderboard and friends

The Quests area also demonstrates the community layer.

**Leaderboard**

- weekly, monthly, and overall periods;
- neighbourhood and broader ranking filters;
- signed-in user's name and points inserted into the demo ranking.

**Friends**

- seeded friend requests;
- accept and decline interactions;
- an add-friend interface.

**Status:** Prototype. Other leaderboard entries and friend relationships are in-memory mock data and reset when the application restarts.

---

### 09 — Expiry notifications

EcoHabit can ask web users for browser notification permission and send a reminder at their selected time while the application is open.

**Status:** Web prototype only. It polls once per minute and prevents duplicate reminders locally. Background and native mobile scheduling are not yet implemented.

---

## Testing

### Automated tests

| Test file | Coverage |
|---|---|
| <code>inventory_ocr_parser_test.dart</code> | OCR text cleaning and candidate extraction |
| <code>shopping_list_checker_test.dart</code> | Quantities, number words, containers, plurals, and inventory matching |
| <code>inventory_page_test.dart</code> | Inventory interface behaviour |
| <code>widget_test.dart</code> | Application smoke-test scaffold |

Run the test suite with:

~~~bash
flutter test
~~~

### Static analysis

~~~bash
flutter analyze
~~~

### Build verification

~~~bash
flutter build web
~~~

The repository was reviewed with Flutter static analysis and a production web build. Both completed successfully. The test files should still be run in the development machine's native Flutter environment; one smoke-test expectation may require updating to match the current Home label.

### Manual test scenarios

1. Register a new account and verify the authentication redirect.
2. Add an inventory item and confirm it appears after refresh.
3. Enter the same item in the shopping checker and choose **Skip**.
4. Scan a grocery list, edit a detection, deselect another, and save.
5. Add an item expiring today and mark it as eaten.
6. Generate a recipe, change servings, cook it, and confirm stock deduction.
7. Complete a quest action and verify progress and reward behaviour.
8. Switch leaderboard filters and exercise the friend-request interactions.
9. Enable a web reminder and confirm the selected minute does not notify twice.

---

## Getting started

### Prerequisites

- Flutter SDK with Dart <code>>=3.3.0 &lt;4.0.0</code>
- a Supabase project
- Supabase CLI for migrations and Edge Functions
- an OpenAI API key for server-side food recognition
- Android Studio or Xcode for mobile OCR testing

### 1. Clone the repository

~~~bash
git clone https://github.com/BelacNat/lifehack2026.git
cd lifehack2026
~~~

### 2. Create the environment file

Create <code>.env</code> in the project root:

~~~dotenv
SUPABASE_URL=https://your-project.supabase.co
SUPABASE_ANON_KEY=your-anon-key
~~~

Do not commit real credentials.

### 3. Install dependencies

~~~bash
flutter pub get
~~~

### 4. Apply Supabase migrations

With the project linked to Supabase:

~~~bash
supabase link --project-ref your-project-ref
supabase db push
~~~

Review [Database and backend](#database-and-backend) and [Known limitations](#known-limitations), because the committed migrations do not yet contain the complete expected backend.

### 5. Configure food recognition

~~~bash
supabase secrets set OPENAI_API_KEY=your-openai-key
supabase functions deploy recognize-inventory-foods
~~~

### 6. Run the application

~~~bash
flutter run
~~~

Useful alternatives:

~~~bash
flutter run -d chrome
flutter build apk
flutter build ios
flutter build web
~~~

---

## Demo guide

For a short end-to-end demonstration:

1. **Sign in** and open the Inventory tab.
2. **Add or scan groceries**, then review the recognised candidates.
3. **Check a shopping list** containing one of those groceries and skip the duplicate.
4. Add an item with an expiry date of today.
5. Open **Fridge** and choose **I ate this**, or generate a rescue recipe.
6. Open **Quests** to show points, quest progress, ranking filters, and the friends prototype.
7. Return to **Home** to show the aggregated impact and inventory summary.

For the clearest demo, prepare the required Supabase rows and recipe service before presenting.

---

## Known limitations

This repository represents a hackathon prototype. The most important gaps are:

1. **The committed backend is incomplete.** Client code expects <code>profiles.residential_area</code>, a <code>user_stats</code> table, and point/streak RPCs that are not fully defined by the checked-in migrations.
2. **Profile naming differs in SQL.** One migration creates <code>profiles.township</code>, while the application reads and writes <code>residential_area</code>.
3. **Account bootstrap is missing.** No committed database trigger creates all required profile and statistics rows after sign-up.
4. **The recipe function is external.** The client calls an AI recipe service, but the matching <code>openai-recipe-suggestions</code> Edge Function source is not included.
5. **Inventory is shared in the demo schema.** <code>fridge_items</code> and <code>avoided_purchases</code> have no user identifier and use permissive prototype row-level security.
6. **Quest definitions are not fully aligned.** Local quest rewards differ from the seeded SQL catalogue, and two client quests are absent from that seed.
7. **Quest progress is device-wide.** SharedPreferences state is not currently namespaced per signed-in user.
8. **Social data is simulated.** Leaderboard opponents, item totals, and friend relationships are mock or in-memory data.
9. **Undo is not reachable after rescue.** Consumed food leaves the urgent list immediately, so the existing undo action cannot be accessed there.
10. **Some progress triggers are too broad.** Opening the Fridge can advance inventory-related progress and may update a zero-waste streak even when no item expires today.
11. **Notifications are foreground web reminders.** Native scheduled and background delivery are not implemented.
12. **Some dashboard content is static.** The displayed date and AI shopping insight are hard-coded prototype values.
13. **Brand naming is inconsistent.** A few areas still use Eco Quest or Fridgewise wording instead of EcoHabit.
14. **Project setup needs polishing.** The original README referenced a missing <code>.env.example</code>; default app identifiers, debug signing, web manifest metadata, and continuous integration are not production-ready.

---

## Timeline and development plan

| Stage | Outcome | Status |
|---|---|---|
| Foundation | Flutter shell, theme, routing, Supabase initialisation, and team ownership | Complete |
| Authentication | Email/password sign-in, registration, profile, and route protection | Implemented |
| Inventory | CRUD, sorting, shopping-list matching, and avoided-purchase records | Implemented |
| Recognition | Mobile text OCR and server-side visual food recognition | Implemented |
| Rescue | Urgent expiry views, consumption events, and points integration | Implemented |
| Recipes | AI suggestions, serving scaling, images, and inventory deduction | Client complete; backend function required |
| Gamification | Quests, points, streak services, leaderboard, and friends | Hybrid prototype |
| Dashboard | Impact summary, category drill-down, urgent food, and recipe shortcuts | Partially dynamic |
| Backend hardening | Per-user data, complete migrations, secure RLS, account bootstrap, and RPC alignment | Next priority |
| Product polish | Native notifications, real social data, consistent branding, and UI screenshots | Planned |
| Delivery | CI, release identifiers, deployment, accessibility review, and production testing | Planned |

### Recommended next steps

1. Reconcile the database migrations with every table, column, RPC, trigger, and Edge Function used by the client.
2. Add <code>user_id</code> ownership and restrictive row-level security to household records.
3. Replace mock leaderboard and friend data with persisted relationships.
4. Namespace local quest state by authenticated user or move it fully to Supabase.
5. Implement native background expiry notifications.
6. Replace static dashboard values and standardise EcoHabit branding.
7. Add continuous integration for analysis, tests, and web builds.
8. Capture final application screenshots and add team, advisor, project-log, and deployment links to this README.

---

## Team collaboration

The application was split into four low-conflict areas:

| Owner | Area | Primary folder |
|---|---|---|
| Person 1 | Inventory and Pause Before Purchase | <code>lib/features/inventory/</code> |
| Person 2 | Food rescue and AI recipes | <code>lib/features/fridge/</code> |
| Person 3 | EcoQuests and rewards | <code>lib/features/quests/</code> |
| Person 4 | Dashboard and integration | <code>lib/features/dashboard/</code> and shared navigation |

See [TEAM_SPLIT.md](TEAM_SPLIT.md) for the branch, migration, and merge workflow.

---

<p align="center">
  Built for LifeHack 2026 with the belief that the easiest food to rescue is the food we remember in time.
</p>
