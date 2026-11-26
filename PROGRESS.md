# Klymb Build Progress

> **Updated:** 2026-11-26  
> **Branches:** `main` & `feat/ui-redesign`  
> **Backend:** Live Supabase Cloud (`ghqoybepcawkvjahjlma`), 17 migrations applied

---

## Phase 0: Specs — Complete
| Task | Status | Description |
|---|---|---|
| P0.1 PRD | Done | Product requirements (`docs/PRD.md`) |
| P0.2 KP Rules | Done | Scoring formulas, caps, worked examples (`docs/KP_RULES.md`) |
| P0.3 Anti-Cheat | Done | Threat model, detection rules, thresholds (`docs/ANTI_CHEAT.md`) |
| P0.4 Architecture | Done | System architecture, data model, iOS architecture (`docs/ARCHITECTURE.md`) |
| P0.5 Design System | Done | Visual tokens, components, accessibility (`docs/DESIGN_SYSTEM.md`) |

---

## Phase 1 & Phase 2: Backend (Supabase Cloud) — Complete
| Area | Status | Details |
|---|---|---|
| Migrations & RLS | Done | All 17 migrations applied; RLS enabled with pgTAP test coverage |
| Auth & Profile | Done | Trigger profile creation, `get_my_profile`, `set_username` |
| Cities & Habits | Done | Seeded 30 cities (`set_city` 30-day cooldown) & habits (`set_user_habits`) |
| Scoring & Ledger | Done | `submit_activities` & `score_activity` server-only scoring + append-only `kp_ledger` |
| Streaks & Anti-Cheat | Done | Streak tracking, freezes, `activity_flags`, trust scoring, rate limits |
| Social, Leaderboards, Quests | Done | City/Global/Friends rankings, friendships, cheering, daily/weekly challenges, achievements |
| Notifications, Privacy, Ops | Done | Device tokens, outbox, APNs Edge Function, GDPR export & deletion, admin audit |

---

## Phase 3: iOS App — Core, Live Wiring & UI Overhaul Complete
| Task | Status | Details |
|---|---|---|
| Xcode Project & Entitlements | Done | `Config/Info.plist`, `Shared.xcconfig`, `klymb.entitlements` (HealthKit, Apple Sign-In, APNs) |
| Live Supabase Integration | Done | `SupabaseClient`, `SupabaseServices`, `AppContainer.live` wired to all RPCs (`fbe69f1`) |
| Email/Password & Apple Auth | Done | Sign-Up / Sign-In UI + `SupabaseErrorPayload` auth error mapping (`9f73b8f`) |
| **Matte Charcoal & Terracotta UI Overhaul** | Done | Branch `feat/ui-redesign`: low-glare obsidian/grey palette (`#111113` / `#18181B`), Velvet Terracotta (`#D9683E`), Mint completion state (`#45C486`), top-lit specular cards, condensed athletic numerals, shared `KlymbPrimitives`, redesigned Auth, 6-step Onboarding, Home open radial gauge, Quick Log console, Compete stage & table, Challenges, Profile Athlete Pass, Friends, Settings, Notifications, and system banners |
| Simulator Build Verification | Verified | `xcodebuild` Debug iPhone 17 Pro Simulator (`** BUILD SUCCEEDED **`) |
| GitHub Feature Gallery | Done | 10 real simulator screenshots in `docs/screenshots/` + CEO-ready `README.md` |
| Full Screen & Real iPhone Pass | Pending `[YOU]` | Visual tap-through of Log/Compete/Challenges/Profile/Settings + physical iPhone USB run & HealthKit test |

---

## Phase 4: Launch & Scale — Pending
| Task | Status | Details |
|---|---|---|
| L1 Load Testing | Pending | 100K-user seeding & RPC latency benchmarks |
| L2 Observability | Pending | Structured production logging & operational runbooks |
| L3 App Store Readiness | Pending | HealthKit justification, App Store screenshots, Privacy Policy & Terms |
| L4 Production Release | Pending | Prod environment rollout, TestFlight & App Store submission |
