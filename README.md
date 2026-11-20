# Klymb

A competitive lifestyle gaming platform — earn Klymb Points (KP) for real-world healthy habits and climb your city's leaderboard.

**iOS (SwiftUI) + Supabase (Postgres, Auth, Edge Functions)**

---

## Quick Start

### Prerequisites

- **Xcode 16+** (iOS 17+ target)
- **Supabase CLI** — `brew install supabase/tap/supabase`
- **Docker Desktop** — required for local Supabase
- **Node.js 18+** — for SQL linting (optional)

### 1. Clone & Setup

```bash
git clone <repo-url>
cd klymb
```

### 2. Start Local Supabase

```bash
supabase start
```

This starts a local Postgres, Auth, and Storage instance in Docker. First run pulls images (~2 min).

### 3. Apply Migrations & Run Tests

```bash
supabase db reset       # Applies all migrations from scratch
supabase test db        # Runs pgTAP tests
```

### 4. iOS App

1. Open `klymb.xcodeproj` in Xcode
2. Create `Config/Staging.xcconfig` (gitignored) with:
   ```
   SUPABASE_URL = http://127.0.0.1:54321
   SUPABASE_ANON_KEY = <from supabase status>
   ```
3. Build and run on simulator or device

---

## Project Structure

```
klymb/
├── AGENTS.md                   # AI agent rules
├── docs/                       # Specs & design docs
│   ├── PRD.md
│   ├── KP_RULES.md
│   ├── ANTI_CHEAT.md
│   ├── ARCHITECTURE.md
│   └── DESIGN_SYSTEM.md
├── supabase/
│   ├── config.toml             # Supabase local config
│   ├── migrations/             # Ordered SQL migrations
│   └── tests/                  # pgTAP test files
├── klymb/                      # iOS app source
│   ├── App/
│   ├── Core/
│   ├── Features/
│   ├── Services/
│   └── DesignSystem/
└── klymb.xcodeproj/
```

---

## Development Workflow

1. **Branch per task** — `git checkout -b b3-auth-profiles`
2. **Plan first** — describe what you'll change and why
3. **Write migration** — `supabase/migrations/YYYYMMDDHHMMSS_description.sql`
4. **Write tests** — `supabase/tests/<name>_test.sql`
5. **Verify** — `supabase db reset && supabase test db`
6. **PR & review** — one logical change per PR

---

## Key Rules

- **KP is ledger-only** — never write a balance column; derive from `SUM(kp_ledger.amount)`
- **No scoring in the client** — the server is authoritative
- **RLS on every table** — with positive and negative test cases
- **Never edit merged migrations** — always create new ones

See [AGENTS.md](./AGENTS.md) for the full rule set.

---

## Environments

| Env | Supabase | iOS Config |
|---|---|---|
| Local | `supabase start` (Docker) | `Staging.xcconfig` pointing to localhost |
| Staging | Hosted Supabase project | `Staging.xcconfig` |
| Production | Hosted Supabase project | `Prod.xcconfig` |
