# EcoHabit — LifeHack 2026

> Small green habits, tracked and gamified.

EcoHabit is a Flutter application that helps households reduce food waste before it happens. It connects grocery planning, fridge inventory, expiry rescue, AI-assisted recipes, and sustainability challenges in one mobile-first experience.

| Project information | Details |
|---|---|
| Team | Ryan Tan, Caleb Tan, Yong See, Kong Qi Yuan |
| GitHub repository | [BelacNat/lifehack2026](https://github.com/BelacNat/lifehack2026) |

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
- [Getting started](#getting-started)
- [Demo guide](#demo-guide)

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
| AI recognition | OpenAI vision through an Edge Function | Identifies visible grocery items from an image |
| AI recipes | OpenAI recipe suggestion service | Produces recipes using active fridge ingredients |

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

---

### 03 — Grocery scanning and OCR

EcoHabit reduces manual entry by supporting one recognition path on Android and iOS.

#### Food-image recognition

A selected camera or gallery image can be sent to the authenticated Supabase Edge Function. OpenAI vision returns structured names for visible foods.

#### Human review

Before saving, users can:

- review every detected item;
- edit an incorrect name;
- deselect an unwanted detection;
- add the selected results to inventory.

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

<p align="center">
  Built for LifeHack 2026 with the belief that the easiest food to rescue is the food we remember in time.
</p>
