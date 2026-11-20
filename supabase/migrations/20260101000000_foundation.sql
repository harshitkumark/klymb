-- Foundation migration: core tables for Klymb
-- This migration establishes the base schema that all other migrations build upon.
-- DO NOT EDIT after merging to main. Create new migrations instead.

-- ============================================================
-- EXTENSIONS
-- ============================================================
CREATE EXTENSION IF NOT EXISTS "pgcrypto";   -- gen_random_uuid()
CREATE EXTENSION IF NOT EXISTS "pgtap";      -- testing framework

-- ============================================================
-- CITIES
-- ============================================================
CREATE TABLE public.cities (
    id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name        text NOT NULL,
    country     text NOT NULL DEFAULT 'India',
    iana_timezone text NOT NULL DEFAULT 'Asia/Kolkata',
    latitude    double precision,
    longitude   double precision,
    created_at  timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.cities ENABLE ROW LEVEL SECURITY;

-- All authenticated users can read cities
CREATE POLICY "cities_select_authenticated"
    ON public.cities FOR SELECT
    TO authenticated
    USING (true);

-- ============================================================
-- PROFILES
-- ============================================================
CREATE TABLE public.profiles (
    id              uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    username        text NOT NULL UNIQUE,
    display_name    text,
    avatar_preset   text DEFAULT 'default',
    city_id         bigint REFERENCES public.cities(id),
    city_changed_at timestamptz,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT username_format CHECK (
        username ~ '^[a-z0-9][a-z0-9_]{1,18}[a-z0-9]$'
        AND username !~ '__'
    ),
    CONSTRAINT display_name_length CHECK (
        display_name IS NULL OR (char_length(trim(display_name)) BETWEEN 1 AND 30)
    )
);

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

-- Users can read all profiles (public info)
CREATE POLICY "profiles_select_authenticated"
    ON public.profiles FOR SELECT
    TO authenticated
    USING (true);

-- Users can update only their own profile (but NOT id)
CREATE POLICY "profiles_update_own"
    ON public.profiles FOR UPDATE
    TO authenticated
    USING (auth.uid() = id)
    WITH CHECK (auth.uid() = id);

-- ============================================================
-- HABITS (catalog — seeded, read-only for clients)
-- ============================================================
CREATE TABLE public.habits (
    id              bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    key             text NOT NULL UNIQUE,
    display_name    text NOT NULL,
    unit            text NOT NULL,
    formula_type    text NOT NULL DEFAULT 'linear',  -- 'linear', 'curve'
    formula_params  jsonb NOT NULL DEFAULT '{}',      -- e.g. {"per_unit": 10, "unit_size": 1000}
    daily_kp_cap    integer NOT NULL,
    manual_kp_cap   integer,                          -- NULL if manual not allowed
    manual_allowed  boolean NOT NULL DEFAULT false,
    created_at      timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.habits ENABLE ROW LEVEL SECURITY;

CREATE POLICY "habits_select_authenticated"
    ON public.habits FOR SELECT
    TO authenticated
    USING (true);

-- ============================================================
-- USER_HABITS
-- ============================================================
CREATE TABLE public.user_habits (
    id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    habit_id    bigint NOT NULL REFERENCES public.habits(id),
    active      boolean NOT NULL DEFAULT true,
    created_at  timestamptz NOT NULL DEFAULT now(),

    UNIQUE (user_id, habit_id)
);

ALTER TABLE public.user_habits ENABLE ROW LEVEL SECURITY;

CREATE POLICY "user_habits_select_own"
    ON public.user_habits FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

CREATE POLICY "user_habits_insert_own"
    ON public.user_habits FOR INSERT
    TO authenticated
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "user_habits_update_own"
    ON public.user_habits FOR UPDATE
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

CREATE POLICY "user_habits_delete_own"
    ON public.user_habits FOR DELETE
    TO authenticated
    USING (auth.uid() = user_id);

-- ============================================================
-- ACTIVITIES
-- ============================================================
CREATE TABLE public.activities (
    id                  bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id             uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    habit_id            bigint NOT NULL REFERENCES public.habits(id),
    quantity            double precision NOT NULL CHECK (quantity > 0),
    started_at          timestamptz NOT NULL,
    ended_at            timestamptz NOT NULL,
    source              text NOT NULL DEFAULT 'healthkit',   -- 'healthkit', 'manual'
    source_sample_id    text,                                 -- HealthKit sample UUID
    was_user_entered    boolean NOT NULL DEFAULT false,
    device_info         jsonb,
    verification_status text NOT NULL DEFAULT 'pending',      -- 'verified', 'unverified', 'pending'
    created_at          timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT valid_time_range CHECK (started_at < ended_at),
    CONSTRAINT valid_source CHECK (source IN ('healthkit', 'manual'))
);

-- Deduplication index
CREATE UNIQUE INDEX activities_dedup_idx
    ON public.activities (user_id, source_sample_id)
    WHERE source_sample_id IS NOT NULL;

-- Daily cap lookups
CREATE INDEX activities_user_habit_day_idx
    ON public.activities (user_id, habit_id, started_at);

ALTER TABLE public.activities ENABLE ROW LEVEL SECURITY;

-- Users can read their own activities
CREATE POLICY "activities_select_own"
    ON public.activities FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

-- No direct INSERT/UPDATE/DELETE — only via submit_activities RPC
-- (No insert/update/delete policies for authenticated role)

-- ============================================================
-- KP_LEDGER (append-only)
-- ============================================================
CREATE TABLE public.kp_ledger (
    id              bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id         uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    amount          integer NOT NULL,
    type            text NOT NULL,          -- 'earn', 'streak_bonus', 'challenge_reward',
                                            -- 'achievement_reward', 'revoke', 'reinstate', 'admin_adjust'
    source_type     text,                   -- 'activity', 'streak', 'challenge', 'achievement', 'admin', 'anticheat'
    source_id       text,
    idempotency_key text NOT NULL UNIQUE,
    day_local       date NOT NULL,
    metadata        jsonb,
    created_at      timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT valid_type CHECK (type IN (
        'earn', 'streak_bonus', 'challenge_reward',
        'achievement_reward', 'revoke', 'reinstate', 'admin_adjust'
    ))
);

-- Index for daily KP sums
CREATE INDEX kp_ledger_user_day_idx
    ON public.kp_ledger (user_id, day_local);

-- Index for type filtering
CREATE INDEX kp_ledger_user_type_idx
    ON public.kp_ledger (user_id, type);

ALTER TABLE public.kp_ledger ENABLE ROW LEVEL SECURITY;

-- Users can read their own ledger entries
CREATE POLICY "kp_ledger_select_own"
    ON public.kp_ledger FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

-- No direct INSERT/UPDATE/DELETE — only via server functions
-- (No insert/update/delete policies for authenticated role)

-- ============================================================
-- VIEWS
-- ============================================================

-- Total KP per user (derived from ledger)
CREATE OR REPLACE VIEW public.user_kp_total AS
SELECT
    user_id,
    COALESCE(SUM(amount), 0)::integer AS total_kp
FROM public.kp_ledger
GROUP BY user_id;

-- Daily KP breakdown
CREATE OR REPLACE VIEW public.user_daily_kp AS
SELECT
    user_id,
    day_local,
    COALESCE(SUM(amount), 0)::integer AS daily_kp,
    COALESCE(SUM(amount) FILTER (WHERE type = 'earn'), 0)::integer AS earned_kp,
    COALESCE(SUM(amount) FILTER (WHERE type = 'streak_bonus'), 0)::integer AS streak_kp,
    COALESCE(SUM(amount) FILTER (WHERE type = 'challenge_reward'), 0)::integer AS challenge_kp,
    COALESCE(SUM(amount) FILTER (WHERE type = 'achievement_reward'), 0)::integer AS achievement_kp
FROM public.kp_ledger
GROUP BY user_id, day_local;

-- ============================================================
-- GRANTS
-- ============================================================
-- Authenticated users can call RPCs and read permitted tables via RLS.
-- No broad grants on mutation-sensitive tables.

GRANT SELECT ON public.cities TO authenticated;
GRANT SELECT ON public.habits TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.user_habits TO authenticated;
GRANT SELECT ON public.profiles TO authenticated;
GRANT UPDATE ON public.profiles TO authenticated;
GRANT SELECT ON public.activities TO authenticated;
GRANT SELECT ON public.kp_ledger TO authenticated;
GRANT SELECT ON public.user_kp_total TO authenticated;
GRANT SELECT ON public.user_daily_kp TO authenticated;

-- Anon gets nothing
-- (No grants to anon role)
