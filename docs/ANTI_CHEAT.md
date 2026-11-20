# Klymb Anti-Cheat — Threat Model & Enforcement

> **Version:** 0.1 (MVP)
> **Last updated:** 2026-11-21
> **Status:** Draft — awaiting founder approval
> **Depends on:** [PRD.md](./PRD.md), [KP_RULES.md](./KP_RULES.md)

---

## 1. Principles

1. **Assume good faith first.** Most users are honest. The system should never make an honest user feel accused.
2. **Server is the only authority.** The client submits data; the server validates, scores, and enforces.
3. **Defense in depth.** No single check stops all abuse. Layer detection, rate limits, caps, and human review.
4. **Transparent consequences.** Users see "Under review" — never "You cheated." Provide an appeal path.
5. **Err toward false negatives over false positives.** A cheater earning a few extra KP is less damaging than a legitimate user losing trust in the platform.

---

## 2. Threat Catalog

### T1 — Fake HealthKit Writes

**Description:** iOS allows any app (or the user via Apple Health) to write samples to HealthKit. A user can install a third-party app that writes fake steps, runs, or workouts to HealthKit, which Klymb then reads as "verified" data.

**Detection Rules:**

| Rule ID | Check | Threshold | Severity |
|---|---|---|---|
| T1-R1 | Source bundle check | Sample source is a known fake-data app (maintain blocklist) | HIGH |
| T1-R2 | `HKWasUserEntered` flag | Sample marked as user-entered → classify as unverified (0.5× multiplier) | LOW (not a flag, just classification) |
| T1-R3 | Impossible rate — steps | > 15,000 steps in any single hour | HIGH |
| T1-R4 | Impossible rate — running | > 25 km/h average speed for session > 10 min | HIGH |
| T1-R5 | Impossible rate — walking | > 10 km/h average for session > 10 min | MEDIUM |
| T1-R6 | Suspicious source diversity | > 5 different source bundles submitting in one day | MEDIUM |
| T1-R7 | Activity during sleep | Running/workout samples overlapping with sleep session | MEDIUM |

**Server-Side Enforcement:**
- T1-R1: Reject sample at `submit_activities` with reason `'blocked_source'`
- T1-R2: Auto-classify, no flag
- T1-R3 to T1-R7: Accept sample, run `evaluate_activity_flags()`, flag in `activity_flags` table

**KP Consequence:**
- HIGH severity → KP held immediately (revoke ledger row inserted)
- MEDIUM severity → KP awarded but activity marked for batch review

**User-Facing Message:**
- "This activity is under review. KP will be confirmed after verification."
- Activity shown with a neutral ⏳ indicator, never ❌ or accusatory language

**Appeal Path:**
- Contact support via email (Settings → Support)
- Include flag ID and activity details
- Admin reviews in `activity_flags` table, can approve (reinstate KP) or confirm (keep revoked)

---

### T2 — Manual Entry Abuse

**Description:** Users flood manual entries (water, workout, mindfulness) to farm KP at the lower rate but in high volume.

**Detection Rules:**

| Rule ID | Check | Threshold | Severity |
|---|---|---|---|
| T2-R1 | Manual entries per day | > 20 manual entries in one calendar day | MEDIUM |
| T2-R2 | Manual-only user, high KP | User has 0 verified activities but > 100 manual KP in 7 days | LOW (monitoring) |
| T2-R3 | Rapid-fire manual entries | > 5 manual entries within 2 minutes | MEDIUM |
| T2-R4 | Manual workout duration | Single manual workout > 240 minutes | MEDIUM |
| T2-R5 | Manual water volume | Single manual water entry > 2,000 ml | MEDIUM |
| T2-R6 | Manual mindfulness duration | Single manual mindfulness > 120 minutes | MEDIUM |

**Server-Side Enforcement:**
- Per-habit manual daily caps (defined in KP_RULES.md) are the **primary defense**
- T2-R1, T2-R3: Flag for review; do not auto-revoke (caps already limit damage)
- T2-R4 to T2-R6: Reject at `submit_activities` with reason `'exceeds_manual_limit'`

**KP Consequence:**
- Manual caps already limit earning to ~75 KP/day from manual entries alone
- Flagged activities: KP held pending review only if pattern is repeated (3+ flagged days in 7 days)

**User-Facing Message:**
- Rejection: "This entry exceeds the daily limit for manual logging."
- Flag: "Some of your manual entries are being reviewed."

**Appeal Path:** Same as T1.

---

### T3 — Duplicate Submission

**Description:** Client submits the same HealthKit sample multiple times (bug or intentional) to earn KP twice.

**Detection Rules:**

| Rule ID | Check | Threshold | Severity |
|---|---|---|---|
| T3-R1 | Duplicate `source_sample_id` | Same `source_sample_id` for same user | N/A (structural) |
| T3-R2 | Duplicate idempotency key | Same `idempotency_key` in `kp_ledger` | N/A (structural) |
| T3-R3 | Near-identical samples | Same habit, same quantity (±1%), same time range (±60s), different sample ID | MEDIUM |

**Server-Side Enforcement:**
- T3-R1: `ON CONFLICT DO NOTHING` on the activities dedupe index — silently skipped, returned as `'duplicate'` in response
- T3-R2: `ON CONFLICT DO NOTHING` on `kp_ledger.idempotency_key` — scoring is idempotent
- T3-R3: Flag for review (legitimate case: two devices recording same walk)

**KP Consequence:**
- T3-R1/R2: 0 additional KP (structural prevention, no flag needed)
- T3-R3: KP awarded for first, flagged for review on subsequent

**User-Facing Message:**
- Duplicate: shown as "Already synced" with ✓ in sync status
- Near-identical flag: "A similar activity was already recorded. Under review."

**Appeal Path:** Automatic resolution after 48h if no other flags. Manual review otherwise.

---

### T4 — Replayed Requests

**Description:** Attacker captures a valid `submit_activities` API request and replays it to earn KP again.

**Detection Rules:**

| Rule ID | Check | Threshold | Severity |
|---|---|---|---|
| T4-R1 | Structural dedup | Same `source_sample_id` → `ON CONFLICT DO NOTHING` | N/A (structural) |
| T4-R2 | Rate limit | > 60 `submit_activities` calls/hour per user | HIGH |
| T4-R3 | Identical payload hash | Same exact JSON payload submitted within 5 minutes | LOW (likely bug) |

**Server-Side Enforcement:**
- T4-R1: Structural — duplicates silently ignored
- T4-R2: Return HTTP 429 with `Retry-After` header. Log the event.
- T4-R3: Accept (dedup handles it) but log for monitoring

**KP Consequence:** None (structural dedup prevents double-earning)

**User-Facing Message:**
- Rate limit: "You're syncing too fast. Please wait a moment."
- Normal duplicate: silent (handled gracefully)

**Appeal Path:** Rate limit auto-resets after the cooldown period.

---

### T5 — Multiple Accounts

**Description:** User creates multiple accounts to earn KP on each and dominate leaderboards, or to get fresh streak freezes.

**Detection Rules:**

| Rule ID | Check | Threshold | Severity |
|---|---|---|---|
| T5-R1 | Same device submitting for multiple users | Device identifier appears in activities for > 1 user | HIGH |
| T5-R2 | Same HealthKit source samples | Identical `source_sample_id` values across different user accounts | HIGH |
| T5-R3 | Same email domain pattern | Multiple accounts from same `+alias` email pattern | LOW (monitoring) |

**Server-Side Enforcement:**
- T5-R1/R2: Flag both accounts for admin review
- T5-R3: Monitor only (legitimate users may share devices in family)

**KP Consequence:**
- HIGH: Both accounts flagged, KP held on the newer account pending review
- Admin can ban the duplicate account

**User-Facing Message:**
- "Your account is under review. This usually takes 24–48 hours."

**Appeal Path:** Contact support. Admin reviews device/sample overlap evidence.

---

### T6 — Time Manipulation

**Description:** User changes their device clock to submit activities in the future (pre-earning tomorrow's KP) or far past (outside late-sync window to bypass caps on a different day).

**Detection Rules:**

| Rule ID | Check | Threshold | Severity |
|---|---|---|---|
| T6-R1 | Future samples | `started_at` > server `now()` + 1 hour | HIGH |
| T6-R2 | Excessive age | `started_at` < server `now()` − 7 days | N/A (rejection) |
| T6-R3 | Clock skew pattern | > 50% of samples in a batch have `started_at` within 1 minute of each other but span > 1 hour of real time | MEDIUM |
| T6-R4 | Timezone abuse | User changes city multiple times in 24 hours (not possible due to 30-day limit, but check API bypass) | HIGH |

**Server-Side Enforcement:**
- T6-R1: Reject sample with reason `'future_date'`
- T6-R2: Reject sample with reason `'too_old'`
- T6-R3: Flag for review
- T6-R4: `set_city` RPC enforces 30-day limit server-side

**KP Consequence:**
- Rejections: 0 KP
- Flags: KP held pending review

**User-Facing Message:**
- Future: "This activity has a future timestamp and cannot be recorded."
- Too old: "This activity is older than 7 days and cannot be synced."

**Appeal Path:** Contact support (legitimate case: device clock was wrong after travel).

---

### T7 — Impossible Values

**Description:** Submitted quantities that are physiologically impossible for a human.

**Detection Rules:**

| Habit | Rule ID | Metric | Impossible Threshold | Severity |
|---|---|---|---|---|
| **Steps** | T7-R1 | Steps per hour | > 15,000 steps/hour | HIGH |
| **Steps** | T7-R2 | Steps per day (single sample) | > 80,000 steps in one sample | HIGH |
| **Running** | T7-R3 | Speed (km/h) | > 25 km/h avg for session > 10 min | HIGH |
| **Running** | T7-R4 | Distance per session | > 100 km in one session | HIGH |
| **Running** | T7-R5 | Speed (km/h) — suspect | > 18 km/h avg for session > 30 min | MEDIUM |
| **Walking** | T7-R6 | Speed (km/h) | > 10 km/h avg for session > 10 min | HIGH |
| **Walking** | T7-R7 | Distance per session | > 50 km in one session | MEDIUM |
| **Workout** | T7-R8 | Duration per session | > 480 minutes (8 hours) | MEDIUM |
| **Workout** | T7-R9 | Sessions per day | > 10 separate workout sessions in one day | MEDIUM |
| **Hydration** | T7-R10 | Volume per entry | > 2,000 ml in one entry | MEDIUM |
| **Hydration** | T7-R11 | Volume per day | > 10,000 ml total in one day | MEDIUM |
| **Sleep** | T7-R12 | Duration per session | > 16 hours in one sleep session | MEDIUM |
| **Mindfulness** | T7-R13 | Duration per session | > 180 minutes in one session | MEDIUM |
| **Mindfulness** | T7-R14 | Sessions per day | > 10 sessions in one day | MEDIUM |

**Reference: Human Performance Limits**

| Metric | Elite Athlete | Casual Fit Person | Klymb Threshold |
|---|---|---|---|
| Steps per hour | ~10,000 (running) | ~5,000 (brisk walk) | 15,000 |
| Running speed (sustained) | 20 km/h (marathon pace) | 10 km/h | 25 km/h |
| Walking speed | 7 km/h (race walking) | 5 km/h | 10 km/h |
| Marathon distance | 42.2 km | 5–10 km | 100 km (ultra buffer) |
| Water intake/day | 8–10 L (extreme) | 2–3 L | 10 L |

> **⚠️ ASSUMPTION — Thresholds are set generously to avoid flagging elite athletes. The system is designed to catch egregious fakes, not edge cases. We can tighten these post-launch based on data.**

**Server-Side Enforcement:**
- HIGH severity: KP held immediately
- MEDIUM severity: KP awarded, flagged for batch review

**KP Consequence:**
- HIGH: Revoke ledger row inserted immediately
- MEDIUM: Held only if 3+ medium flags in 7 days

**User-Facing Message:**
- "This activity was flagged as unusual. Our team will review it within 48 hours."

**Appeal Path:** Contact support with explanation (e.g., "I'm a competitive runner").

---

### T8 — API Abuse

**Description:** Attacker bypasses the iOS app to call Supabase RPCs directly (using the anon key + stolen JWT) to submit fabricated data or probe the API.

**Detection Rules:**

| Rule ID | Check | Threshold | Severity |
|---|---|---|---|
| T8-R1 | Rate limit — submit_activities | > 60 calls/hour per user | HIGH |
| T8-R2 | Rate limit — global per user | > 300 RPC calls/hour per user (across all RPCs) | HIGH |
| T8-R3 | Batch size | > 500 samples per `submit_activities` call | N/A (rejection) |
| T8-R4 | Missing required fields | Samples missing habit_key, quantity, started_at, ended_at | N/A (validation) |
| T8-R5 | Invalid habit key | habit_key not in user's active habits | N/A (rejection) |
| T8-R6 | Negative quantity | quantity ≤ 0 | N/A (rejection) |
| T8-R7 | Burst pattern | > 10 submit_activities calls within 1 minute | HIGH |

**Server-Side Enforcement:**
- Rate limits tracked in `rate_limits` table (user_id, endpoint, window_start, count)
- Rejections return structured error codes, never internal details
- T8-R7: Temporary 15-minute cooldown + flag

**KP Consequence:**
- Rate limited calls: 0 KP (request rejected)
- Burst pattern: all KP from that burst held for review

**User-Facing Message:**
- Rate limit: "You've reached the sync limit. Please try again later."
- Validation: "Some activities could not be processed. Please update your app."

**Appeal Path:** Rate limits auto-reset. Persistent abuse → admin ban.

---

## 3. Severity Levels & Automated Actions

| Severity | Automated Action | KP Impact | Review Timeline |
|---|---|---|---|
| **HIGH** | Flag created, revoke ledger row inserted immediately | KP held (negative ledger entry) | Admin reviews within 48h |
| **MEDIUM** | Flag created, KP awarded normally | KP at risk (held only if 3+ medium flags in 7 days) | Batch review weekly |
| **LOW** | Logged for monitoring, no flag | No impact | Monthly pattern review |

---

## 4. Trust Score

A derived view `user_trust_score` that quantifies a user's trustworthiness:

```
trust_score = 100
  − (high_severity_flags × 25)
  − (medium_severity_flags × 10)
  − (low_severity_flags × 2)
  + (verified_activity_days × 1, max +20 bonus)
```

| Score Range | Status | Effect |
|---|---|---|
| 80–100 | **Trusted** | Normal operation |
| 50–79 | **Watch** | Increased monitoring, all activities run full flag evaluation |
| 20–49 | **Restricted** | Manual entries disabled, all KP from new activities held for 24h |
| 0–19 | **Suspended** | Account flagged for admin review, excluded from leaderboards |

- Trust score is **never shown to the user** (internal metric only)
- Score recovers over time as flags are resolved or age out (flags > 90 days old contribute 50% weight)
- Leaderboards exclude users with trust_score < 20

> **⚠️ ASSUMPTION — Trust score formula and thresholds. These are starting points and should be tuned with real data post-launch.**

---

## 5. Overlapping Sample Detection

A special cross-cutting rule that applies to all activity types:

| Rule ID | Check | Description | Severity |
|---|---|---|---|
| OV-R1 | Time overlap — same habit | Two samples for the same habit where time ranges overlap by > 50% | MEDIUM |
| OV-R2 | Time overlap — conflicting habits | Running + sleep at the same time | HIGH |
| OV-R3 | Total active hours | > 20 hours of non-sleep activity in a single day | HIGH |

**Implementation:**
- Checked in `evaluate_activity_flags()` after insertion
- OV-R1: Flag the later sample
- OV-R2: Flag the less-likely sample (e.g., running during sleep → flag the running sample)
- OV-R3: Flag all activities for that day

---

## 6. Source Bundle Blocklist

Maintained as a table `blocked_sources` (bundle_id, reason, added_at):

**Initial blocklist (known fake-data apps):**

| Bundle ID Pattern | App Name | Reason |
|---|---|---|
| `com.healthdata.fake*` | Various | Known fake data generators |
| `com.stepfaker.*` | Step Faker | Fake step counter |
| `*fakesteps*` | Various | Pattern match |
| `*healthhack*` | Various | Pattern match |

- Blocklist is updated via admin action (new migration or admin RPC)
- Matching is case-insensitive and supports wildcards
- Blocked source samples are rejected at `submit_activities` before insertion
- **Legitimate apps** (Apple Health, popular fitness trackers) are on an allowlist — not blocked even if user-entered

> **⚠️ ASSUMPTION — Blocklist will need ongoing maintenance. Consider a crowd-sourced or automated approach post-MVP.**

---

## 7. Rate Limit Implementation

```sql
rate_limits (
    id          bigint generated always as identity primary key,
    user_id     uuid not null references auth.users(id),
    endpoint    text not null,       -- 'submit_activities', 'global'
    window_start timestamptz not null,
    call_count  integer not null default 1,
    unique(user_id, endpoint, window_start)
)
```

| Endpoint | Window | Max Calls | Cooldown on Exceed |
|---|---|---|---|
| `submit_activities` | 1 hour (rolling) | 60 | Reject until window resets |
| Global (all RPCs) | 1 hour (rolling) | 300 | Reject until window resets |
| `submit_activities` burst | 1 minute | 10 | 15-minute cooldown + flag |

- Window is truncated to the hour for simplicity (not true sliding window in MVP)
- Rate limit check happens **before** any processing in the RPC

---

## 8. Flag Lifecycle

```
┌──────────┐    evaluate_    ┌──────────┐    admin     ┌───────────┐
│          │   activity_     │          │   reviews    │           │
│  (none)  │──────flags()──▶│  OPEN    │────────────▶│  RESOLVED │
│          │                 │          │              │           │
└──────────┘                 └────┬─────┘              └───────────┘
                                  │                         │
                                  │ auto-resolve            │
                                  │ (48h, no other flags)   │
                                  ▼                         │
                             ┌──────────┐                   │
                             │  AUTO_   │                   │
                             │ RESOLVED │◀──────────────────┘
                             └──────────┘
```

**Flag statuses:**
- `open` — newly created, awaiting review
- `auto_resolved` — automatically closed after 48h with no corroborating flags
- `resolved_approved` — admin confirmed as false positive, KP reinstated
- `resolved_confirmed` — admin confirmed as genuine flag, KP remains revoked

**Auto-resolution rules:**
- MEDIUM flags with no other flags in 7 days → auto-resolve after 48h
- HIGH flags → never auto-resolve, require admin action
- On resolution: if KP was held, insert `reinstate` ledger row

---

## 9. User-Facing Communication

### Language Guidelines

| ❌ Never say | ✅ Say instead |
|---|---|
| "You cheated" | "This activity is under review" |
| "Suspicious activity detected" | "We noticed something unusual" |
| "Your account is flagged" | "Your account is being verified" |
| "Penalty applied" | "KP adjusted pending review" |
| "Fake data" | "Unusual activity pattern" |

### UI Treatment

- Flagged activities show a neutral ⏳ clock icon
- Held KP shown as "Pending: X KP" in a muted color (not red)
- Reinstated KP shown with ✓ and brief celebration
- Confirmed revokes shown as "Adjusted" with no further detail
- **Never show the flag rule or threshold** that triggered it (prevents gaming)

---

## 10. Appeal Process (MVP)

1. User sees flagged activity in their activity history
2. Taps it → sees "This activity is under review. If you believe this is an error, contact support."
3. Settings → Support → email link with pre-filled subject: "Activity Review Request — [flag_id]"
4. Admin reviews in `activity_flags` table
5. Admin actions:
   - **Approve** → flag status = `resolved_approved`, reinstate KP via ledger row
   - **Confirm** → flag status = `resolved_confirmed`, KP stays revoked
   - **Ban** → user account suspended, excluded from all leaderboards
6. User receives email notification of resolution (post-MVP: in-app notification)

> **Post-MVP:** In-app appeal form, automated appeal for first-time flags, appeal SLA tracking.

---

## 11. Monitoring & Alerting

| Metric | Alert Threshold | Action |
|---|---|---|
| Flag rate (% of submissions) | > 5% over 24h | Investigate — possible app bug or new exploit |
| High-severity flags per day | > 50 | Manual triage — possible coordinated abuse |
| False positive rate | > 20% of reviewed flags | Loosen thresholds |
| Average flag resolution time | > 72h | Staff more reviewers |
| Rate-limited users per day | > 100 | Investigate — possible bot attack |

---

## 12. Summary of Assumptions Requiring Approval

| # | Assumption | Proposed Value | Risk if Wrong |
|---|---|---|---|
| AC1 | Steps impossible threshold | 15,000/hour | Too tight → flags marathon runners on treadmill |
| AC2 | Running speed threshold | 25 km/h | Too tight → flags sprinters; too loose → misses fakes |
| AC3 | Walking speed threshold | 10 km/h | Race walkers can exceed 7 km/h |
| AC4 | Manual entries/day limit | 20 entries | Too tight → frustrates legitimate manual loggers |
| AC5 | Rate limit: submit_activities | 60/hour | Too tight → breaks legitimate background sync |
| AC6 | Trust score formula | See §4 | Needs real-world calibration |
| AC7 | Auto-resolve window | 48h for MEDIUM, never for HIGH | 48h too fast? Too slow? |
| AC8 | Flag contribution to trust score | HIGH=−25, MEDIUM=−10, LOW=−2 | Arbitrary, needs tuning |
| AC9 | Leaderboard exclusion threshold | trust_score < 20 | Too aggressive? |
| AC10 | Late-sync window | 7 days (from KP_RULES) | Interacts with time manipulation detection |
| AC11 | Overlapping sample threshold | 50% time overlap | Legitimate: two apps recording simultaneously |
| AC12 | Burst detection threshold | 10 calls/minute | Background sync could legitimately burst |
