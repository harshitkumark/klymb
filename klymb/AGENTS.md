# AGENTS.md — Klymb Development Rules

Every AI agent working on this project MUST read and follow these rules before writing any code or migration.

---

## 1. Architecture Boundaries

1. **Ledger-only KP accounting.** Never write or update a KP balance column. All KP changes are append-only rows in `kp_ledger`. Balances are derived (SUM over ledger).
2. **No scoring logic in the client.** The iOS app displays KP; it never calculates or awards it. All scoring happens server-side in Postgres functions.
3. **Server is authoritative.** The client may preview estimated KP for UX, but must label it as an estimate and never persist it.

## 2. Database Rules

4. **RLS on every table.** Every new table must have Row-Level Security enabled with explicit policies. No table may rely on "public access."
5. **Tests for every table.** Every migration must be accompanied by pgTAP tests proving RLS works (positive and negative cases).
6. **Migrations only.** Schema changes are always new migration files (`supabase/migrations/YYYYMMDDHHMMSS_description.sql`). Never edit a migration that has been merged to `main`.
7. **Idempotency keys on ledger rows.** Every ledger insert must include an `idempotency_key` to prevent double-crediting. Format: `'<type>:<entity_id>'` (e.g., `'earn:<activity_id>'`, `'streak:<user_id>:<milestone>'`).

## 3. Security

8. **Least privilege.** Grant only the minimum permissions needed. Prefer RPC functions over direct table access for mutations.
9. **SECURITY DEFINER functions must:**
   - Set `search_path = public, pg_temp` (or the specific schemas needed).
   - Validate `auth.uid()` is not null (unless intentionally anon-accessible).
   - Validate and sanitize all input parameters.
   - Never leak internal error details to the caller.
   - Be documented with a comment explaining why DEFINER is needed.
10. **No secrets in code.** Supabase URL, anon key, and all secrets come from environment config (xcconfig for iOS, Supabase secrets/env for backend). Never commit them.

## 4. Code Quality

11. **Plan before code.** On every task, produce a short plan (what you'll create/change, why, risks) and wait for approval before writing code.
12. **Small, reviewable diffs.** One logical change per PR. If a task is large, break it into sub-tasks.
13. **Naming conventions:**
    - SQL: `snake_case` for tables, columns, functions.
    - Swift: standard Swift conventions (`camelCase` properties, `PascalCase` types).
    - Files: match the primary type they contain.
14. **Error handling.** Every RPC returns structured errors. The iOS app maps error codes to user-friendly copy. No raw error strings shown to users.

## 5. iOS Specific

15. **SwiftUI + MVVM.** Views are declarative and thin. Business logic lives in ViewModels. Data access lives in Services behind protocols.
16. **Dependency injection via protocols.** Every service has a protocol. ViewModels take protocol-typed dependencies for testability.
17. **No health data leaves the device except through `submit_activities`.** HealthKit samples are read, batched, and submitted via the sync service. Raw health data is never logged, sent to analytics, or stored in plaintext beyond the sync queue.
18. **Accessibility is not optional.** Every screen supports Dynamic Type, VoiceOver, and Reduce Motion from the start.

## 6. Process

19. **Branch per task.** Each prompt/task = one git branch = one PR.
20. **Test before merge.** Backend: `supabase db reset && supabase test db`. iOS: build and run on a real device or simulator.
21. **[REVIEW] tags mean line-by-line review.** These prompts touch security or KP logic. Read every line of the diff.
22. **[YOU] tags mean manual action.** These require Xcode, Apple portal, or Supabase dashboard — not automatable by agents.
