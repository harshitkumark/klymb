# Klymb — Product Requirements Document

> **Version:** 0.1 (MVP)
> **Last updated:** 2026-11-21
> **Status:** Draft — awaiting founder approval

---

## 1. Vision

Klymb is a **competitive lifestyle gaming platform** that turns real-world healthy habits into a city-level, team, and global competition. Users earn **Klymb Points (KP)** for verified activities — steps, runs, workouts, hydration, sleep, mindfulness — and climb leaderboards to prove they live the most active lifestyle in their city.

It is **not a health app**. It is a **game powered by health data**. The aesthetic is premium dark gaming, the tone is competitive and rewarding, and the core emotion is "I need to beat that person above me."

---

## 2. Target Users

| Attribute | Detail |
|---|---|
| **Age** | 18–35 |
| **Geography** | India-first launch (30 major Indian cities + select global cities) |
| **Psychographic** | Fitness-curious, competitive, social, motivated by status and streaks |
| **Device** | iPhone (iOS 17+), iPhone-only for MVP |
| **Health tools** | Already use Apple Health / workout apps, or want a reason to start |

**Primary persona — "Competitive Ravi":** 24, works in tech in Bangalore, does 8k steps most days, runs 3×/week, wants to prove he's the fittest in his office and his city. Loves leaderboards and streaks.

**Secondary persona — "Social Priya":** 22, college student in Delhi, tracks water and sleep, joins challenges with friends, motivated by group accountability more than raw competition.

---

## 3. Core Loop

```
┌─────────────────────────────────────────────────────┐
│                                                     │
│   DO HABITS ──▶ EARN KP ──▶ CLIMB RANKS ──▶        │
│        ▲                                    │       │
│        │        ◀── COMPETE ◀── COMPARE ◀───┘       │
│        │                                            │
│        └──── STREAKS & CHALLENGES keep you back ────┘
│                                                     │
└─────────────────────────────────────────────────────┘
```

1. **Do habits** — walk, run, work out, drink water, sleep, meditate. Tracked via HealthKit (auto) or manual entry.
2. **Earn KP** — Server scores activities using published formulas. Verified (HealthKit) activities earn more than manual entries.
3. **Climb ranks** — Daily, weekly, all-time leaderboards scoped to city, friends, team, and global.
4. **Compare & compete** — See who's above you, get "X KP to overtake" nudges, join daily/weekly challenges.
5. **Come back** — Streaks, streak freezes, achievements, and push notifications ("You just got overtaken!") drive daily retention.

---

## 4. MVP Scope

### 4.1 MVP Features

| # | Feature | Category |
|---|---------|----------|
| F1 | **Authentication** — Email/password + Sign in with Apple. Email verification. Password reset. | Auth |
| F2 | **Profile creation** — Auto-generated username on signup, editable. Display name, preset avatar selection. | Profile |
| F3 | **City assignment** — Pick from seeded cities during onboarding. One change allowed per 30 days. | Profile |
| F4 | **Habit selection** — Choose which habits to track (steps, running, walking distance, workout, hydration, sleep, mindfulness). | Core |
| F5 | **HealthKit integration** — Anchored queries for new samples. Background delivery. Source and device metadata captured. `HKWasUserEntered` flag captured. | Core |
| F6 | **Manual entry** — Quick-log for water, workout, mindfulness. Clearly labeled as "unverified." Lower KP rate. | Core |
| F7 | **Activity sync service** — Local queue, batch submission (up to 500), retry with backoff, idempotent, background refresh. | Core |
| F8 | **KP scoring engine** — Server-side only. Per-habit formulas, per-habit daily caps, global daily cap, manual multiplier, verified multiplier. Append-only ledger. | Core |
| F9 | **Streaks** — Daily streak for qualifying days. Streak bonuses at milestones (7, 30, 100 days). Streak freeze (1 free per week, MVP). | Engagement |
| F10 | **Leaderboards** — Daily, weekly, all-time. Scoped: city, friends, team, global. Paginated. Pinned "my row." Rank change indicators. | Competition |
| F11 | **Teams** — Create or join a team (max 20 members MVP). Team leaderboard (sum of member KP). Team name, avatar. Invite by share link/username. Team chat is post-MVP. | Competition |
| F12 | **Daily & weekly challenges** — Auto-generated. Join/leave. Progress tracking. Reward KP on completion. Results screen with standings. | Engagement |
| F13 | **Achievements** — Catalog of unlockable badges (first activity, streak milestones, KP thresholds, first top-10 city rank, challenge winner). Grid display with locked/unlocked states. | Engagement |
| F14 | **Friends** — Search by username, send/accept/decline requests, friends list, remove, block. Friend profile sheet (limited public fields). | Social |
| F15 | **Push notifications** — Overtaken on leaderboard, challenge ending soon, streak at risk, achievement unlocked, friend request. Per-type preferences. Quiet hours. | Engagement |
| F16 | **Anti-cheat (server)** — Impossible value detection, duplicate submission prevention, rate limiting, manual-entry caps, activity flagging, trust score. | Integrity |
| F17 | **Account deletion & data export** — Full GDPR/Indian data protection compliance. JSON export with 24h signed URL. Cascading delete with ledger anonymization. | Privacy |
| F18 | **Settings** — Account, notification preferences, connected sources, HealthKit permission status, privacy (export/delete), legal links, app version, logout. | Utility |
| F19 | **Offline resilience** — Offline banner, cached last-known data, retry policies, error mapping, session-expiry handling, force-update gate. | Reliability |
| F20 | **Home screen** — Today's KP (animated count-up), streak display, daily goal ring, per-habit progress cards, city rank with overtake nudge, active challenge card. | UI |
| F21 | **Onboarding flow** — Username → display name → avatar → city → habits → HealthKit permission → notification permission. Progress indicator, resumable. | UX |

### 4.2 Post-MVP Features

| # | Feature | Notes |
|---|---------|-------|
| P1 | **Photo avatar upload** | Camera/gallery, cropped, stored in Supabase Storage |
| P2 | **Earned cosmetics** | Frames, badges, skins unlocked by achievements or KP milestones |
| P3 | **Team chat** | In-team messaging |
| P4 | **Custom challenges** | User-created challenges shared with friends or team |
| P5 | **Community challenges** | City-wide or global challenges with large participation |
| P6 | **Monetization** | Freemium model — free core, premium for: extra streak freezes, cosmetic shop, advanced analytics, ad-free |
| P7 | **iPad support** | Responsive layouts for iPad |
| P8 | **Android** | Full Android client |
| P9 | **Referral system** | Invite friends for bonus KP (capped, anti-abuse) |
| P10 | **Rank tiers & seasons** | Bronze/Silver/Gold/Diamond ranks, seasonal resets |
| P11 | **Location-verified activities** | GPS-verified runs for higher trust multiplier |
| P12 | **Social feed / activity feed** | See friends' recent achievements and milestones |
| P13 | **Apple Watch companion** | Complication showing today's KP and streak |
| P14 | **Widgets** | iOS home screen widgets for KP, streak, rank |
| P15 | **Multi-language** | Hindi, regional languages |
| P16 | **Advanced analytics** | Personal trends, weekly reports, habit correlations |

---

## 5. Feature Details

### F1 — Authentication

- **Sign in with Apple** (primary — required for App Store if any third-party auth is offered)
- **Email + password** (secondary)
- Email verification required before full access
- Password reset via email link
- Session persisted in Keychain via Supabase Swift SDK
- Auto-refresh of JWT tokens
- Logout clears local data and session
- **No phone/SMS auth in MVP** (cost, complexity)
- **No social logins (Google, Facebook) in MVP**

### F2 — Profiles

| Field | Type | Editable | Visibility |
|---|---|---|---|
| `id` | UUID (= auth.uid) | Never | Internal |
| `username` | text | Yes (validated, unique) | Public |
| `display_name` | text | Yes | Public |
| `avatar_preset` | text | Yes | Public |
| `city_id` | FK → cities | Yes (30-day limit) | Public |
| `created_at` | timestamp | Never | Internal |
| `city_changed_at` | timestamp | Auto | Internal |

- Username: 3–20 chars, lowercase alphanumeric + underscores, no leading/trailing underscores, unique, blocklist (admin, klymb, support, help, official, etc.)
- Auto-generated on signup: `user_` + 6 random alphanumeric chars
- Display name: 1–30 chars, trimmed
- **Never exposed:** email, auth provider, raw activity data, trust score

### F3 — Cities

- Seeded with **30 major Indian cities** (Mumbai, Delhi, Bangalore, Hyderabad, Chennai, Kolkata, Pune, Ahmedabad, Jaipur, Lucknow, Chandigarh, Kochi, Indore, Bhopal, Coimbatore, Nagpur, Surat, Visakhapatnam, Patna, Guwahati, Thiruvananthapuram, Vadodara, Dehradun, Mysore, Mangalore, Noida, Gurugram, Thane, Navi Mumbai, Faridabad) + **select global cities** (Dubai, Singapore, London, New York, San Francisco, Toronto, Sydney, Berlin, Tokyo, Seoul)
- User picks city during onboarding
- One change per 30 days (prevents leaderboard gaming)
- **No precise location stored** — city is self-declared
- City used for scoping leaderboards and future community challenges

### F4 — Habits

| Habit Key | Display Name | Unit | HealthKit Type | Manual Allowed | Daily KP Cap |
|---|---|---|---|---|---|
| `steps` | Steps | count | HKQuantityTypeIdentifier.stepCount | No | Defined in KP_RULES |
| `running` | Running | km | HKQuantityTypeIdentifier.distanceWalkingRunning (filtered by workout) | No | Defined in KP_RULES |
| `walking_distance` | Walking | km | HKQuantityTypeIdentifier.distanceWalkingRunning | No | Defined in KP_RULES |
| `workout` | Workout | minutes | HKWorkoutType | Yes | Defined in KP_RULES |
| `hydration` | Water | ml | HKQuantityTypeIdentifier.dietaryWater | Yes | Defined in KP_RULES |
| `sleep` | Sleep | hours | HKCategoryTypeIdentifier.sleepAnalysis | No | Defined in KP_RULES |
| `mindfulness` | Mindfulness | minutes | HKCategoryTypeIdentifier.mindfulSession | Yes | Defined in KP_RULES |

- Users select which habits they want to track during onboarding (can change anytime in settings)
- Minimum 1 habit, no maximum
- Habit selection determines which HealthKit permissions are requested

### F5 — HealthKit Integration

- **Anchored object queries** — fetch only new samples since last anchor
- **Observer queries + background delivery** — wake the app when new data arrives
- Captured per sample:
  - Sample UUID (for dedup via `source_sample_id`)
  - Source bundle identifier
  - Device name/model
  - Start date, end date
  - Quantity (in canonical unit)
  - `HKWasUserEntered` metadata flag
- Anchors persisted locally (UserDefaults or SwiftData)
- Graceful handling of denied/partial permissions (show what's missing, link to Settings)
- **Mock implementation** for simulator/tests

### F6 — Manual Entry

- Available only for habits where `manual_allowed = true` (workout, hydration, mindfulness)
- Quick-log UI with presets:
  - **Water:** 250ml, 500ml, 750ml, custom
  - **Workout:** type picker + duration (minutes)
  - **Mindfulness:** 5, 10, 15, 20, custom minutes
- Clearly labeled as "Manual" / "Unverified" in UI
- Shows estimated KP preview (labeled as estimate, server authoritative)
- Submitted through the same sync queue as `source = 'manual'`
- Subject to lower KP multiplier (defined in KP_RULES)
- Subject to stricter daily caps (defined in KP_RULES)

### F7 — Activity Sync Service

1. HealthKit observer fires → new samples collected
2. Samples stored in **local queue** (SwiftData)
3. Batched (up to 500 per request) → `submit_activities` RPC
4. Server returns per-sample result (accepted / duplicate / rejected + reason)
5. Queue updated based on results
6. **Retry policy:** exponential backoff (1s, 2s, 4s, 8s… max 5 min), max 10 retries
7. **Triggers:** app foreground, background delivery callback, `BGAppRefreshTask`
8. **Idempotent:** safe to resend (server deduplicates by `source_sample_id`)
9. Sync state exposed to UI: idle / syncing / error / last synced timestamp

### F8 — KP Scoring Engine

> Full formulas defined in `docs/KP_RULES.md` (P0.2)

**Key principles:**
- All scoring happens **server-side** in Postgres functions
- KP changes are **append-only ledger rows**, never balance updates
- Every ledger row has an `idempotency_key` preventing double-credit
- Per-habit daily caps prevent gaming any single habit
- Global daily cap prevents unreasonable totals
- Manual entries earn at a **lower multiplier** than verified entries
- Re-scoring the same activity is idempotent (no additional KP)

### F9 — Streaks

- A **qualifying day** = earned ≥ X KP from verified activities (threshold in KP_RULES)
- Current streak = consecutive qualifying days (user-local timezone)
- Streak bonuses: KP awards at milestones (7, 30, 100 days) via ledger rows
- **Streak freeze:** 1 free per week in MVP. Consumes automatically if a day is missed. Resets weekly.
- Streak displayed prominently on Home with flame animation
- Longest streak tracked for profile/achievements

### F10 — Leaderboards

| Dimension | Options |
|---|---|
| **Period** | Daily, Weekly, All-time |
| **Scope** | City, Friends, Team, Global |

- Implemented via materialized views or incremental aggregate table (decided in ARCHITECTURE.md)
- Refreshed on a schedule via `pg_cron` (e.g., every 5 minutes for daily, every 15 for weekly)
- **Excludes** users with active high-severity anti-cheat flags
- RPC: `get_leaderboard(scope, period, city_id, limit, offset)` → rank, username, avatar, KP
- RPC: `get_my_rank(scope, period, city_id)` → user's rank, KP, distance to next rank
- Paginated (20 per page default)
- "My row" always pinned at the bottom of the UI regardless of scroll position
- Rank change indicators (↑3, ↓1, NEW) comparing to previous period snapshot

### F11 — Teams

| Attribute | Detail |
|---|---|
| **Team size** | 2–20 members (MVP) |
| **Creation** | Any user can create one team; a user can be in only one team at a time |
| **Joining** | Via invite link (shareable) or by username search + request |
| **Team leaderboard** | Sum of all member KP for the period |
| **Team profile** | Team name (unique, 3–24 chars), preset avatar, city (majority or creator's), member count |
| **Roles** | Owner (creator), Member. Owner can remove members, disband team |
| **Leaving** | Members can leave anytime. Owner must transfer or disband |

- Team leaderboard is a separate scope in `get_leaderboard`
- Team KP = SUM of member KP (derived, never stored separately)
- **Post-MVP:** team chat, team challenges, team cosmetics

### F12 — Challenges

| Type | Cadence | Example |
|---|---|---|
| **Daily** | Resets every day | "Walk 10,000 steps today" |
| **Weekly** | Monday–Sunday | "Run 20 km this week" |

- Auto-generated by `pg_cron` jobs (create daily challenges at midnight UTC, weekly on Monday)
- Each challenge: type, habit filter, target quantity, start/end, reward KP, status (upcoming/active/completed)
- Users join/leave before challenge starts (or within first 25% of duration)
- Progress tracked from scored activities matching the habit filter
- `finalize_challenge` (server-only, via cron) freezes results and awards KP to top N (1st, 2nd, 3rd + all who hit target)
- Ties broken by earliest completion time
- **Post-MVP:** community challenges, custom user-created challenges

### F13 — Achievements

| Achievement | Condition | KP Reward |
|---|---|---|
| First Steps | Submit first activity | 50 |
| Week Warrior | 7-day streak | 100 |
| Month Master | 30-day streak | 500 |
| Century Club | 100-day streak | 2000 |
| Step Legend | 100,000 lifetime steps | 200 |
| City Star | First top-10 city rank | 300 |
| Challenge Champion | Win a challenge | 150 |
| Social Butterfly | Add 5 friends | 50 |
| Team Player | Join a team | 50 |
| Hydration Hero | 7 days of water logging | 75 |
| Early Bird | Complete a daily challenge before noon | 100 |
| Night Owl | Log mindfulness after 10 PM for 7 days | 75 |

- Server evaluates unlocks after scoring
- KP rewards via idempotent ledger rows (`'achievement:<achievement_id>:<user_id>'`)
- Catalog readable by all authenticated users; user_achievements scoped to own rows
- UI: grid with locked (greyed, silhouette) and unlocked (color, glow animation) states

### F14 — Friends

- **Search** by username (prefix match, rate-limited, excludes blocked users)
- **Request flow:** send → pending → accept/decline
- **States:** none, pending_sent, pending_received, friends, blocked
- **Remove:** unfriend (both sides lose the connection)
- **Block:** removes friendship + prevents future requests + hides from search
- **Friend profile sheet:** username, display name, avatar, city, rank, total KP — never email or raw activity data
- **Friends leaderboard scope** — see only friends' KP
- Request badge on tab bar (count of pending received requests)

### F15 — Push Notifications

| Event | Message Example | Deep Link |
|---|---|---|
| Overtaken | "🔥 @ravi just passed you on the Bangalore leaderboard!" | Compete tab |
| Challenge ending | "⏰ 'Walk 10K' challenge ends in 2 hours. You're in 3rd!" | Challenges tab |
| Streak at risk | "😱 Your 15-day streak is at risk! Log an activity before midnight." | Home tab |
| Achievement unlocked | "🏆 You earned 'Week Warrior'! 100 KP added." | Profile → Achievements |
| Friend request | "👋 @priya wants to be your friend" | Friends tab |
| Team invite | "🤝 You've been invited to join 'Bangalore Beasts'" | Teams |

- **Contextual permission prompt** — asked after user has seen value (e.g., after first KP earn), not on first launch
- Per-type toggle in Settings
- Quiet hours (default 10 PM – 7 AM, user-configurable)
- APNs token-based auth (.p8 key)
- Server-side outbox pattern with retry and invalid-token cleanup

### F16 — Anti-Cheat

> Full threat model and thresholds defined in `docs/ANTI_CHEAT.md` (P0.3)

**Key mechanisms:**
- **Impossible value detection** — max steps/hour, max running speed, etc.
- **Duplicate prevention** — `source_sample_id` dedup index + idempotency keys
- **Rate limiting** — max 60 `submit_activities` calls/hour per user
- **Manual entry caps** — lower KP rate + stricter daily cap
- **Activity flagging** — `activity_flags` table with severity levels
- **Trust score** — derived view, affects leaderboard eligibility
- **Burst detection** — abnormal submission patterns
- **User-facing:** flagged activities shown neutrally ("Under review"), no accusatory language
- **Appeal path:** contact support (email in MVP, in-app post-MVP)

### F17 — Account Deletion & Data Export

- **Export:** `request_data_export` → JSON file (profile, habits, activities, ledger) in private Storage bucket → signed URL valid 24h → emailed or shown in-app
- **Delete:** double confirmation ("Type DELETE to confirm") → `delete_account` → auth user deleted, cascading cleanup, ledger rows anonymized (user_id nulled, KP preserved for leaderboard integrity or removed — per final decision)
- Compliant with Indian data protection requirements and Apple App Store guidelines
- Triggered from Settings → Privacy

### F18 — Settings

```
Settings
├── Account
│   ├── Username
│   ├── Display Name
│   ├── Email (read-only)
│   └── Change Password
├── Notifications
│   ├── Per-type toggles (overtaken, challenges, streaks, achievements, friends, teams)
│   └── Quiet Hours (start/end time)
├── Connected Sources
│   ├── HealthKit status (connected / partial / denied)
│   └── Link to iOS Settings for permissions
├── Privacy
│   ├── Export My Data
│   └── Delete My Account
├── About
│   ├── Terms of Service
│   ├── Privacy Policy
│   └── App Version
├── Support
│   └── Contact (email)
└── Log Out
```

### F19 — Offline & Resilience

- **Offline banner** — shown when no network, auto-dismisses on reconnect
- **Cached data** — last-known Home screen data, leaderboard snapshot persisted locally
- **Retry policies** — exponential backoff for all network calls
- **Error mapping** — Supabase/RPC error codes → user-friendly messages (never raw errors)
- **Session expiry** — detect expired JWT, prompt re-auth, preserve local queue
- **Force-update gate** — remote `min_version` value checked on app launch; if current version < min, block UI with "Please update" and App Store link

### F20 — Home Screen

```
┌──────────────────────────────┐
│  🔥 15-day streak           │
│                              │
│      ╭─────────╮            │
│      │  1,247  │  KP today  │
│      │  ▲ +89  │            │
│      ╰─────────╯            │
│                              │
│  ● Steps      8,432/10,000  │
│  ● Running    3.2 km ✓      │
│  ● Water      1,500 ml      │
│  ● Sleep      7.2h ✓        │
│                              │
│  📊 Bangalore #12 (↑3)      │
│  "142 KP to overtake @ravi" │
│                              │
│  🎯 Daily: Walk 10K [78%]   │
└──────────────────────────────┘
```

### F21 — Onboarding

**Flow (screens):**
1. Welcome / value prop (3 slides max)
2. Sign up / Sign in
3. Set username (live availability check)
4. Display name
5. Choose avatar (preset grid)
6. Select city (searchable list)
7. Select habits (multi-select, min 1)
8. HealthKit permission explainer → request
9. "You're ready!" → Home

- Progress indicator (dots or bar)
- Back navigation at every step
- **Resumable** — if app is killed mid-onboarding, resume from last completed step
- Notification permission requested later (after first KP earn, not during onboarding)

---

## 6. Tech Stack

| Layer | Technology |
|---|---|
| **iOS client** | SwiftUI, MVVM, iOS 17+, iPhone-only |
| **Backend** | Supabase (Postgres, Auth, Edge Functions, Storage, Realtime) |
| **Health data** | Apple HealthKit |
| **Push** | APNs (token-based, .p8 key) |
| **Scheduling** | pg_cron (leaderboard refresh, challenge lifecycle, notifications) |
| **CI/CD** | GitHub Actions (backend: `supabase db reset && supabase test db`; iOS: build + test) |
| **Analytics** | Privacy-respecting event wrapper (no PII, no health data in events) |
| **Crash reporting** | TBD (Firebase Crashlytics or Sentry — post-MVP decision) |

---

## 7. Success Metrics (MVP)

| Metric | Target | Measurement |
|---|---|---|
| **D1 retention** | ≥ 60% | Users who return day after signup |
| **D7 retention** | ≥ 35% | Users active 7 days after signup |
| **D30 retention** | ≥ 20% | Users active 30 days after signup |
| **Daily active / Monthly active** | ≥ 30% | DAU/MAU ratio |
| **Avg. activities synced/day** | ≥ 3 per active user | Server logs |
| **Challenge participation** | ≥ 40% of DAU join ≥ 1 challenge/week | Challenge join events |
| **Streak ≥ 7 days** | ≥ 25% of users who complete onboarding | Streak data |
| **Friends added** | ≥ 2 avg per user in first 14 days | Friend data |
| **Anti-cheat flag rate** | < 5% of submissions | Flag data |
| **Crash-free sessions** | ≥ 99.5% | Crash reporting |
| **App Store rating** | ≥ 4.5 | App Store Connect |

---

## 8. Non-Goals (MVP)

These are explicitly **out of scope** for the MVP:

1. **Android app** — iOS only for MVP
2. **iPad support** — iPhone only
3. **Monetization / payments** — no in-app purchases, subscriptions, or ads
4. **Social feed / activity feed** — no timeline of friends' activities
5. **GPS/location-verified activities** — city is self-declared, no location tracking
6. **Apple Watch app** — no companion app
7. **Home screen widgets** — no widgets
8. **Multi-language / localization** — English only
9. **Admin dashboard UI** — admin actions via SQL/RPC only (no web UI)
10. **Custom challenges** — only system-generated daily/weekly challenges
11. **Chat / messaging** — no DMs, no team chat
12. **Calorie tracking / nutrition** — not a diet app
13. **Workout plans / coaching** — not a training app
14. **Wearable integrations beyond HealthKit** — no Fitbit, Garmin, etc.
15. **Gamified avatars / virtual characters** — preset static avatars only
16. **Referral program** — no invite rewards
17. **Seasonal ranks / rank resets** — continuous all-time leaderboard

---

## 9. Risks & Mitigations

| Risk | Impact | Mitigation |
|---|---|---|
| HealthKit data manipulation | Unfair leaderboards, user trust erosion | Multi-layer anti-cheat (P0.3), trust scores, flagging |
| Low initial user density per city | Empty leaderboards, no competition feel | Seed with beta users per city, friends-first growth, global scope always available |
| HealthKit permission denial | Core features broken | Graceful degradation, clear explainers, manual entry as fallback for some habits |
| App Store rejection (HealthKit) | Launch delay | Pre-submission checklist, usage justification text, compliance review (L3) |
| Data privacy regulations | Legal risk | GDPR-style export/delete from day 1, privacy policy, no PII in analytics |
| Cheating arms race | Ongoing maintenance burden | Server-authoritative design, automated flagging, manual review path |
| Team feature complexity | Scope creep | Minimal MVP (create/join/leave/leaderboard only, no chat) |

---

## 10. Open Decisions

> These require founder input before or during implementation:

1. **KP formula specifics** — exact multipliers and caps per habit → defined in P0.2 (KP_RULES.md)
2. **Anti-cheat thresholds** — exact numeric limits per habit → defined in P0.3 (ANTI_CHEAT.md)
3. **Leaderboard refresh frequency** — 5 min vs 15 min vs realtime → decided in P0.4 (ARCHITECTURE.md)
4. **Streak qualifying threshold** — minimum KP from verified activities to count a day → defined in P0.2
5. **Team size limit** — 20 for MVP, revisit based on usage
6. **Challenge reward distribution** — top 3 only, or all who complete? → defined in P0.2
7. **Ledger anonymization vs deletion** on account delete — anonymize (preserve leaderboard integrity) or hard delete?
8. **Crash reporting vendor** — Firebase Crashlytics vs Sentry vs defer?
9. **Beta launch city list** — start with all 30 Indian cities or focus on 5–10?
10. **Minimum iOS version** — 17.0 (wider reach) vs 18.0 (newer APIs)?
