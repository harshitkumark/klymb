-- Migration: 20260116000000_security_audit.sql
-- B18: Security Audit & Hardening [REVIEW]
-- Implements AGENTS.md §3 Security, §1 Architecture Boundaries, §2 Database Rules
--
-- 1. Revoke default and explicit mutating privileges from anon across public schema.
-- 2. Revoke TRUNCATE from anon and authenticated on all public tables.
-- 3. Lock down sensitive system and append-only tables from direct authenticated mutation:
--    - kp_ledger (AGENTS.md Rule 1: mutations only via server scoring RPCs)
--    - audit_log (append-only via admin RPCs)
--    - account_deletion_requests (mutations only via privacy RPCs)
--    - activity_flags (mutations only via anti-cheat engine)
--    - notification_outbox (internal delivery queue)
--    - admin_roles (managed only by super_admin RPCs)
--    - blocked_sources, reserved_usernames (read-only catalogs)
--    - challenges, achievements (system catalogs, read-only)
--    - challenge_progress, user_achievements, user_streaks (managed only via scoring RPCs)
-- 4. Alter default privileges to prevent auto-granting mutations to anon/authenticated.

-- ============================================================
-- 1. HARDEN DEFAULT PRIVILEGES
-- ============================================================

ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE ALL ON TABLES FROM anon;
ALTER DEFAULT PRIVILEGES IN SCHEMA public REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON TABLES FROM authenticated;

-- ============================================================
-- 2. LOCK DOWN ANON ROLE
-- ============================================================

-- Revoke all mutating permissions from anon on all existing tables
REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON ALL TABLES IN SCHEMA public FROM anon;

-- Revoke SELECT on internal-only tables from anon
REVOKE SELECT ON TABLE
    public.audit_log,
    public.admin_roles,
    public.notification_outbox,
    public.rate_limits
FROM anon;

-- Allow SELECT on tables where RLS protects user data (returning 0 rows for anon)
GRANT SELECT ON TABLE
    public.profiles,
    public.activities,
    public.kp_ledger,
    public.cities,
    public.habits,
    public.user_habits,
    public.challenges,
    public.achievements,
    public.leaderboard_daily,
    public.leaderboard_weekly,
    public.leaderboard_alltime
TO anon;

-- ============================================================
-- 3. LOCK DOWN AUTHENTICATED ROLE ON SENSITIVE TABLES
-- ============================================================

-- Revoke TRUNCATE on all public tables from authenticated
REVOKE TRUNCATE ON ALL TABLES IN SCHEMA public FROM authenticated;

-- Revoke INSERT, UPDATE, DELETE on system/catalog tables
REVOKE INSERT, UPDATE, DELETE ON TABLE
    public.cities,
    public.habits,
    public.challenges,
    public.achievements,
    public.blocked_sources,
    public.reserved_usernames
FROM authenticated;

-- Revoke INSERT, UPDATE, DELETE on append-only / server-managed tables
REVOKE INSERT, UPDATE, DELETE ON TABLE
    public.audit_log,
    public.account_deletion_requests,
    public.activity_flags,
    public.notification_outbox,
    public.admin_roles,
    public.rate_limits,
    public.challenge_progress,
    public.user_streaks,
    public.user_achievements
FROM authenticated;

-- kp_ledger: INSERT is blocked via permissions; UPDATE/DELETE are blocked via RLS (no policies, 0 rows)
REVOKE INSERT ON TABLE public.kp_ledger FROM authenticated;
GRANT UPDATE, DELETE ON TABLE public.kp_ledger TO authenticated;

-- Direct INSERT on activities is blocked — submissions must go through submit_activities RPC
REVOKE INSERT ON TABLE public.activities FROM authenticated;
-- UPDATE and DELETE rely on RLS (no policies exist, resulting in 0 rows updated/deleted)
GRANT UPDATE, DELETE ON TABLE public.activities TO authenticated;

-- Ensure SELECT permissions are correctly granted where needed
GRANT SELECT ON TABLE
    public.cities,
    public.habits,
    public.challenges,
    public.achievements,
    public.blocked_sources,
    public.reserved_usernames,
    public.leaderboard_daily,
    public.leaderboard_weekly,
    public.leaderboard_alltime,
    public.user_kp_total,
    public.user_daily_kp,
    public.activities,
    public.user_habits,
    public.user_streaks,
    public.user_achievements,
    public.friendships,
    public.challenge_participants,
    public.challenge_progress,
    public.device_tokens,
    public.notification_preferences,
    public.account_deletion_requests,
    public.admin_roles,
    public.audit_log,
    public.activity_flags,
    public.kp_ledger
TO authenticated;

-- ============================================================
-- 4. DOUBLE CHECK RLS ON ALL PUBLIC TABLES
-- ============================================================

DO $$
DECLARE
    r record;
BEGIN
    FOR r IN (
        SELECT tablename
        FROM pg_tables
        WHERE schemaname = 'public'
    ) LOOP
        EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY;', r.tablename);
    END LOOP;
END;
$$;
