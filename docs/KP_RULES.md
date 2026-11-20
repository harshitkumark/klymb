# Klymb Points (KP) — Scoring Rules

> **Version:** 0.1 (MVP)
> **Last updated:** 2026-11-21
> **Status:** Draft — awaiting founder approval
> **Depends on:** [PRD.md](./PRD.md)

---

## 1. Philosophy

KP is the single currency of competition in Klymb. Every point must be **earned through real activity**, **scored by the server**, and **recorded as an append-only ledger row**. The client never calculates or awards KP.

**Design goals:**
- Reward consistency over one-off bursts
- Reward verified (HealthKit) data more than manual entries
- Cap daily earning to prevent unhealthy extremes and gaming
- Make every habit feel rewarding but keep the total fair across habit types
- Be transparent — users should understand why they earned what they earned

---

## 2. Earning Formulas

### 2.1 Per-Habit Scoring

Each accepted activity earns KP based on the formula for its habit. All scoring happens inside `score_activity(activity_id)` on the server.

| Habit | Formula | Unit | Verified Multiplier | Manual Multiplier | Per-Habit Daily Cap | Notes |
|---|---|---|---|---|---|---|
| **Steps** | `floor(quantity / 1000) × 10` | count | 1.0× | N/A (no manual) | 150 KP | 15,000 steps = cap. Encourages walking without rewarding obsessive counting |
| **Running** | `floor(quantity × 20)` | km | 1.0× | N/A (no manual) | 200 KP | 10 km = cap. Rewards distance, not time |
| **Walking Distance** | `floor(quantity × 12)` | km | 1.0× | N/A (no manual) | 120 KP | 10 km = cap. Lower rate than running (lower intensity) |
| **Workout** | `floor(quantity × 2)` | minutes | 1.0× | 0.5× | 120 KP (verified) / 40 KP (manual) | 60 min verified = cap. Manual capped much lower |
| **Hydration** | `floor(quantity / 250) × 5` | ml | 1.0× | 0.5× | 40 KP (verified) / 20 KP (manual) | 2000ml = cap. Each glass (250ml) = 5 KP |
| **Sleep** | `quality_score(quantity)` | hours | 1.0× | N/A (no manual) | 50 KP | See §2.2 for quality curve |
| **Mindfulness** | `floor(quantity × 3)` | minutes | 1.0× | 0.5× | 45 KP (verified) / 15 KP (manual) | 15 min verified = cap |

> **⚠️ ASSUMPTION — All multipliers and caps are proposed defaults. Flag for founder approval before implementation.**

### 2.2 Sleep Quality Curve

Sleep uses a bell curve to reward healthy amounts (7–9 hours) and penalize both too little and too much:

| Sleep Duration | KP Awarded |
|---|---|
| < 4 hours | 0 KP |
| 4–5 hours | 10 KP |
| 5–6 hours | 25 KP |
| 6–7 hours | 40 KP |
| **7–8 hours** | **50 KP** (optimal) |
| **8–9 hours** | **50 KP** (optimal) |
| 9–10 hours | 35 KP |
| 10–11 hours | 20 KP |
| > 11 hours | 10 KP |

- Sleep is scored once per calendar day (user-local timezone)
- If multiple sleep sessions exist, the **longest continuous session** crossing the user's night boundary (8 PM – 12 PM next day) is used
- Naps are not scored separately in MVP

> **⚠️ ASSUMPTION — The sleep scoring curve values are proposed. Founder may want to adjust the optimal window or KP values.**

### 2.3 Verified vs Manual Multipliers

| Source | Classification | Multiplier |
|---|---|---|
| HealthKit sample, `wasUserEntered = false` | **Verified** | 1.0× |
| HealthKit sample, `wasUserEntered = true` | **Unverified (manual via Health app)** | 0.5× |
| Submitted via Klymb manual entry | **Unverified (manual)** | 0.5× |

- The 0.5× multiplier applies **before** the per-habit daily cap
- Manual entries also have a **separate, lower daily cap** (see table in §2.1)
- This means manual-only users earn significantly less KP per day, incentivizing HealthKit connection

> **⚠️ ASSUMPTION — 0.5× manual multiplier. Could be 0.6× or 0.4× depending on how much we want to penalize manual entries.**

---

## 3. Daily Caps

### 3.1 Per-Habit Daily Caps

Each habit has a daily KP cap (see §2.1 table). Once a user reaches the cap for a habit on a given day, additional activities for that habit earn 0 KP for that day. The user is notified: "You've reached today's steps cap. Keep moving — it counts tomorrow!"

### 3.2 Global Daily Cap

| Cap | Value |
|---|---|
| **Global daily cap** | **500 KP** |

- Applies across all habits combined
- If per-habit subtotals sum to more than 500, the last-scored activities are capped to bring the total to 500
- Prevents any single user from running away with the leaderboard through extreme multi-habit gaming
- Does **not** include streak bonuses or achievement rewards (those are separate)

**Maximum theoretical daily KP breakdown (all verified):**

| Source | Max KP |
|---|---|
| Steps (15K) | 150 |
| Running (10 km) | 200 |
| Walking (10 km) | 120 |
| Workout (60 min) | 120 |
| Hydration (2L) | 40 |
| Sleep (7–9h) | 50 |
| Mindfulness (15 min) | 45 |
| **Sum before cap** | **725** |
| **Global cap applied** | **500** |

> **⚠️ ASSUMPTION — Global daily cap of 500 KP. This is a critical balance lever. Too low = frustrating for active users. Too high = leaderboard dominated by extreme athletes. Recommend playtesting with 400–600 range.**

### 3.3 Cap Interaction Rules

1. Per-habit caps are checked **first**
2. Global daily cap is checked **second** (after all per-habit caps are applied)
3. Streak bonuses and achievement rewards are **exempt** from both caps
4. Challenge reward KP is **exempt** from both caps
5. Caps reset at **midnight in the user's local timezone**

---

## 4. Streak Bonuses

### 4.1 Qualifying Day

A day qualifies for a streak if the user earned **≥ 50 KP** from **verified** activities on that calendar day (user-local timezone).

> **⚠️ ASSUMPTION — 50 KP minimum from verified activities. This means roughly 5,000 steps OR 2.5 km run OR 25 min workout. Should be achievable but not trivially easy. Manual-only KP does NOT count toward streak qualification.**

### 4.2 Streak Milestones & Bonuses

| Streak Length | Bonus KP | Idempotency Key |
|---|---|---|
| 3 days | 25 | `streak:<user_id>:3` |
| 7 days | 100 | `streak:<user_id>:7` |
| 14 days | 200 | `streak:<user_id>:14` |
| 30 days | 500 | `streak:<user_id>:30` |
| 60 days | 1,000 | `streak:<user_id>:60` |
| 100 days | 2,500 | `streak:<user_id>:100` |
| 200 days | 5,000 | `streak:<user_id>:200` |
| 365 days | 10,000 | `streak:<user_id>:365` |

- Bonuses are one-time awards (idempotency key prevents re-award)
- If a user breaks their streak and rebuilds it, they re-earn milestones with a new idempotency key cycle: `streak:<user_id>:7:v2` (streak version incremented on break)
- Streak bonuses are **exempt** from daily caps

### 4.3 Streak Freeze

| Rule | Value |
|---|---|
| Free freezes per week | 1 |
| Freeze auto-activation | Automatic at end of day if no qualifying activity |
| Freeze restock | Weekly (Monday 00:00 user-local time) |
| Freeze visibility | Home screen shows "Freeze available" / "Freeze used" |

- A freeze preserves the streak count but the frozen day does **not** count as a qualifying day for milestone purposes
- Example: 6-day streak → freeze on day 7 → day 8 qualifies → streak shows 7 (not 8, since the frozen day didn't count toward progress, but the chain is not broken)

> **⚠️ ASSUMPTION — 1 free freeze per week. Post-MVP: purchasable extra freezes via premium. Some competitors offer 1/month — 1/week is more generous and reduces churn.**

---

## 5. Challenge Rewards

### 5.1 Daily Challenges

| Placement | Reward KP |
|---|---|
| Completed target | 50 |
| Top 3 | +100 bonus |
| 1st place | +50 additional (total +150 for 1st who completed) |

### 5.2 Weekly Challenges

| Placement | Reward KP |
|---|---|
| Completed target | 150 |
| Top 3 | +300 bonus |
| 1st place | +150 additional (total +450 for 1st who completed) |

- Rewards are written as ledger rows with idempotency key `challenge:<challenge_id>:<user_id>:<placement>`
- **You must complete the target** to be eligible for placement bonuses
- Ties broken by **earliest completion time**
- Challenge rewards are **exempt** from daily caps

> **⚠️ ASSUMPTION — Challenge reward amounts. These should be meaningful enough to motivate but not so large that challenges overshadow daily habits. Weekly rewards are ~3× daily to match the commitment level.**

---

## 6. Revokes & Adjustments

### 6.1 Anti-Cheat Revokes

When an activity is flagged with high severity by the anti-cheat system:

1. A `revoke` ledger row is inserted with:
   - `amount` = negative of the original earn amount
   - `type` = `'revoke'`
   - `reason` = flag rule that triggered it
   - `idempotency_key` = `'revoke:flag:<flag_id>'`
2. The user's visible KP decreases accordingly
3. The user sees: "An activity has been flagged for review. KP adjusted pending review."
4. If the flag is later dismissed (false positive), a `reinstate` ledger row restores the KP:
   - `idempotency_key` = `'reinstate:flag:<flag_id>'`

### 6.2 Admin Adjustments

Admins can manually adjust KP via ledger rows:

- `type` = `'admin_adjust'`
- `reason` = required text
- `admin_id` = the admin's user ID
- `idempotency_key` = `'admin:<adjustment_id>'`
- Recorded in `audit_log`

### 6.3 Revoke Rules

- Revokes are **never** applied retroactively to streak milestones already awarded (the bonus was earned at the time)
- Revokes **do** affect leaderboard positions (recalculated on next refresh)
- If a revoke drops a user below the streak qualifying threshold for a past day, the streak is **not** retroactively broken (too complex for MVP, revisit post-MVP)

> **⚠️ ASSUMPTION — No retroactive streak breaking on revokes. This is simpler but could be exploited. Revisit if abuse patterns emerge.**

---

## 7. Rounding

| Rule | Detail |
|---|---|
| **Direction** | Always `floor()` (round down) |
| **Precision** | KP values are integers (no fractional KP) |
| **Applied when** | At formula evaluation time, before cap checks |
| **Quantities** | Stored with original precision from HealthKit; rounding only affects KP output |

Examples:
- 7,432 steps → `floor(7432 / 1000) × 10` = `7 × 10` = **70 KP** (not 74.32)
- 2.7 km run → `floor(2.7 × 20)` = `floor(54)` = **54 KP**
- 850 ml water → `floor(850 / 250) × 5` = `3 × 5` = **15 KP** (not 17)

---

## 8. Timezone Handling

### 8.1 User-Local Day

All daily boundaries (caps, streaks, challenge days) use the **user's local timezone**:

| Rule | Detail |
|---|---|
| **Timezone source** | Derived from the city the user selected (each city maps to an IANA timezone) |
| **Day boundary** | Midnight (00:00:00) in user's local timezone |
| **Activity assignment** | An activity belongs to the day of its `started_at` timestamp in the user's timezone |
| **City change** | When a user changes city (and thus timezone), the day boundary shifts immediately. No retroactive re-scoring. |

### 8.2 City → Timezone Mapping (Examples)

| City | IANA Timezone |
|---|---|
| Mumbai | Asia/Kolkata |
| Delhi | Asia/Kolkata |
| Bangalore | Asia/Kolkata |
| Dubai | Asia/Dubai |
| Singapore | Asia/Singapore |
| London | Europe/London |
| New York | America/New_York |
| San Francisco | America/Los_Angeles |
| Tokyo | Asia/Tokyo |

> **Note:** All Indian cities share `Asia/Kolkata` (IST, UTC+5:30). This simplifies the Indian launch but the system must support multiple timezones for global cities.

---

## 9. Late-Sync Rules

HealthKit data can arrive late (e.g., iPhone was offline, user opens app after a trip). Rules for handling:

| Rule | Value |
|---|---|
| **Maximum sample age** | 7 days |
| **Scoring** | Late samples are scored against the **day they occurred** (not the day they were synced) |
| **Cap enforcement** | Caps are checked for the original day. If the day's cap was already hit, late samples earn 0 KP |
| **Streak impact** | Late samples **can** retroactively qualify a past day for streak purposes, but only within the 7-day window |
| **Leaderboard impact** | Leaderboard positions update on next refresh cycle |
| **Rejection** | Samples older than 7 days are rejected with reason `'too_old'` |
| **Future samples** | Samples with `started_at` > now + 1 hour are rejected with reason `'future_date'` |

> **⚠️ ASSUMPTION — 7-day late-sync window. Too short = frustrates travelers. Too long = enables gaming. 7 days balances both. Competitors typically use 7–14 days.**

---

## 10. Ledger Row Structure

Every KP change is a row in `kp_ledger`:

```sql
kp_ledger (
    id              bigint generated always as identity primary key,
    user_id         uuid not null references auth.users(id),
    amount          integer not null,          -- positive for earn, negative for revoke
    type            text not null,             -- 'earn', 'streak_bonus', 'challenge_reward',
                                               -- 'achievement_reward', 'revoke', 'reinstate',
                                               -- 'admin_adjust'
    source_type     text,                      -- 'activity', 'streak', 'challenge', 'achievement',
                                               -- 'admin', 'anticheat'
    source_id       text,                      -- activity_id, challenge_id, achievement_id, etc.
    idempotency_key text not null unique,      -- prevents double-crediting
    day_local       date not null,             -- the user-local day this KP belongs to
    metadata        jsonb,                     -- habit, formula details, reason, etc.
    created_at      timestamptz not null default now()
)
```

**Balance is always derived:** `SELECT SUM(amount) FROM kp_ledger WHERE user_id = $1`

---

## 11. Worked Examples

### Scenario Table

| # | Scenario | Habit | Quantity | Source | Day's Prior KP (habit) | Day's Prior KP (global) | Calculation | KP Earned | Notes |
|---|---|---|---|---|---|---|---|---|---|
| 1 | Morning walk | Steps | 8,200 | HealthKit (verified) | 0 | 0 | `floor(8200/1000)×10` = 80 | **80** | Normal earn |
| 2 | Afternoon walk | Steps | 4,500 | HealthKit (verified) | 80 | 80 | `floor(4500/1000)×10` = 40. Total = 120. Cap = 150. | **40** | Under cap |
| 3 | Evening walk | Steps | 6,000 | HealthKit (verified) | 120 | 120 | `floor(6000/1000)×10` = 60. Total would be 180 > cap 150. | **30** | Capped to 150 |
| 4 | 5K run | Running | 5.2 km | HealthKit (verified) | 0 | 150 | `floor(5.2×20)` = 104 | **104** | Different habit, own cap |
| 5 | Manual water log | Hydration | 500 ml | Manual | 0 | 254 | `floor(500/250)×5×0.5` = 5. Manual cap = 20 | **5** | 0.5× manual multiplier |
| 6 | Manual workout | Workout | 45 min | Manual | 0 | 259 | `floor(45×2×0.5)` = 45. Manual cap = 40 | **40** | Capped to manual limit |
| 7 | Sleep (optimal) | Sleep | 7.5 hours | HealthKit (verified) | 0 | 299 | Quality curve → 50 | **50** | Optimal window |
| 8 | Sleep (too short) | Sleep | 4.5 hours | HealthKit (verified) | 0 | 299 | Quality curve → 10 | **10** | Penalized |
| 9 | Mindfulness | Mindfulness | 10 min | HealthKit (verified) | 0 | 349 | `floor(10×3)` = 30 | **30** | Normal earn |
| 10 | Global cap hit | Steps | 10,000 | HealthKit (verified) | 0 | 480 | Would earn 100. Global cap: 500 − 480 = 20 remaining | **20** | Global cap applied |
| 11 | Duplicate sample | Steps | 8,200 | HealthKit (verified) | 80 | 80 | Same `source_sample_id` as #1 → `ON CONFLICT DO NOTHING` | **0** | Duplicate rejected |
| 12 | Streak bonus (day 7) | — | — | System | — | — | Milestone 7 → 100 KP | **100** | Exempt from caps |
| 13 | Challenge reward | — | — | System | — | — | Completed daily target → 50, plus top 3 → +100 | **150** | Exempt from caps |
| 14 | Late sync (3 days old) | Running | 3.0 km | HealthKit (verified) | — | 200 (that day) | `floor(3.0×20)` = 60. Scored against original day. | **60** | Within 7-day window |
| 15 | Too-old sample | Steps | 5,000 | HealthKit (verified) | — | — | Sample is 10 days old → rejected | **0** | Exceeds 7-day window |
| 16 | Anti-cheat revoke | Steps | 50,000 | HealthKit (user-entered) | 150 | 400 | Flagged: impossible (50K steps in 1 hour). Revoke: −150 | **−150** | KP clawed back |
| 17 | Achievement unlock | — | — | System | — | — | "Week Warrior" (7-day streak) → 100 KP | **100** | Exempt from caps |

### Detailed Walkthrough: "Ravi's Tuesday"

Ravi is in Bangalore (IST, UTC+5:30). His Tuesday:

| Time (IST) | Activity | Raw KP | After Habit Cap | After Global Cap | Running Total |
|---|---|---|---|---|---|
| 06:30 | Sleep: 7.8h (verified) | 50 | 50 (cap: 50) | 50 | **50** |
| 07:00 | Morning run: 4.2 km (verified) | 84 | 84 (cap: 200) | 84 | **134** |
| 09:00 | Walk to office: 1.1 km (verified) | 13 | 13 (cap: 120) | 13 | **147** |
| 12:30 | Steps so far: 6,200 (verified) | 60 | 60 (cap: 150) | 60 | **207** |
| 13:00 | Water: 750ml (manual) | 7 | 7 (cap: 20) | 7 | **214** |
| 17:00 | Steps cumulative: 11,400 (verified) | 50 | 50 (90 remaining of 150) | 50 | **264** |
| 18:30 | Gym workout: 50 min (verified) | 100 | 100 (cap: 120) | 100 | **364** |
| 19:00 | Water: 500ml (manual) | 5 | 5 (12 remaining of 20) | 5 | **369** |
| 20:00 | Meditation: 10 min (verified) | 30 | 30 (cap: 45) | 30 | **399** |
| 21:00 | Evening walk: 2.0 km (verified) | 24 | 24 (cap: 96 remaining) | 24 | **423** |
| 22:00 | Water: 500ml (manual) | 5 | 5 (8 remaining of 20) | 5 | **428** |
| — | 7-day streak bonus | 100 | — | Exempt | **528** |
| — | Daily challenge completed (3rd place) | 150 | — | Exempt | **678** |

**Day total: 428 KP (capped) + 100 (streak) + 150 (challenge) = 678 KP**

Ravi's 428 KP from activities is under the 500 global cap, so no global cap was applied today. Had he done more, the global cap would have kicked in at 500.

---

## 12. Summary of All Assumptions Requiring Approval

| # | Assumption | Proposed Value | Alternatives to Consider |
|---|---|---|---|
| A1 | Steps KP formula | 10 KP per 1,000 steps | 8 or 12 per 1,000 |
| A2 | Steps daily cap | 150 KP (15K steps) | 100 (10K) or 200 (20K) |
| A3 | Running KP formula | 20 KP per km | 15 or 25 per km |
| A4 | Running daily cap | 200 KP (10 km) | 150 or 250 |
| A5 | Walking KP formula | 12 KP per km | 10 or 15 per km |
| A6 | Walking daily cap | 120 KP (10 km) | 100 or 150 |
| A7 | Workout KP formula | 2 KP per minute | 1.5 or 2.5 per minute |
| A8 | Workout daily cap | 120 KP / 40 KP manual | 100/30 or 150/50 |
| A9 | Hydration KP formula | 5 KP per 250ml | 4 or 6 per 250ml |
| A10 | Hydration daily cap | 40 KP / 20 KP manual | 30/15 or 50/25 |
| A11 | Sleep scoring curve | Bell curve, 50 KP max | Flat 40 KP for 6–9h |
| A12 | Mindfulness KP formula | 3 KP per minute | 2 or 4 per minute |
| A13 | Mindfulness daily cap | 45 KP / 15 KP manual | 30/10 or 60/20 |
| A14 | Manual multiplier | 0.5× | 0.4× or 0.6× |
| A15 | Global daily cap | 500 KP | 400 or 600 |
| A16 | Streak qualifying threshold | 50 KP from verified | 30 or 75 |
| A17 | Streak freeze per week | 1 | 0 or 2 |
| A18 | Late-sync window | 7 days | 3 or 14 days |
| A19 | Daily challenge: completion reward | 50 KP | 30 or 75 |
| A20 | Daily challenge: top 3 bonus | 100 KP | 75 or 150 |
| A21 | Weekly challenge: completion reward | 150 KP | 100 or 200 |
| A22 | Weekly challenge: top 3 bonus | 300 KP | 200 or 400 |
| A23 | No retroactive streak break on revoke | Yes (simpler) | Retroactive break (complex) |
| A24 | Frozen day doesn't count toward milestone | Yes | Frozen day counts |
| A25 | Streak bonus re-earn on rebuild | New cycle (v2, v3...) | One-time only ever |
