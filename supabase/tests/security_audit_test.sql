-- pgTAP tests for B18: Security Audit & Hardening [REVIEW]
-- Verifies RLS, privileges, and function configurations across the entire database.

BEGIN;
SELECT plan(12);

-- ============================================================
-- Test 1: 100% of tables in public schema have RLS enabled
-- ============================================================
SELECT is_empty(
    $$SELECT tablename FROM pg_tables WHERE schemaname = 'public' AND rowsecurity = false$$,
    'Test 1: Every table in public schema has RLS enabled'
);

-- ============================================================
-- Test 2: Anon role has NO mutating privileges on any application table
-- ============================================================
SELECT is_empty(
    $$SELECT table_name, privilege_type
      FROM information_schema.role_table_grants
      WHERE grantee = 'anon'
        AND table_schema = 'public'
        AND table_name NOT IN ('tap_funky', 'pg_all_foreign_keys')
        AND privilege_type IN ('INSERT', 'UPDATE', 'DELETE', 'TRUNCATE')$$,
    'Test 2: Anon role has zero mutating privileges on application tables'
);

-- ============================================================
-- Test 3: Authenticated role has NO TRUNCATE on any application table
-- ============================================================
SELECT is_empty(
    $$SELECT table_name
      FROM information_schema.role_table_grants
      WHERE grantee = 'authenticated'
        AND table_schema = 'public'
        AND table_name NOT IN ('tap_funky', 'pg_all_foreign_keys')
        AND privilege_type = 'TRUNCATE'$$,
    'Test 3: Authenticated role has zero TRUNCATE grants on application tables'
);

-- ============================================================
-- Test 4: Authenticated role cannot directly INSERT into kp_ledger (Rule 1)
-- ============================================================
SELECT is_empty(
    $$SELECT privilege_type
      FROM information_schema.role_table_grants
      WHERE grantee = 'authenticated'
        AND table_schema = 'public'
        AND table_name = 'kp_ledger'
        AND privilege_type = 'INSERT'$$,
    'Test 4: Authenticated role cannot directly INSERT into kp_ledger'
);

-- ============================================================
-- Test 5: Authenticated role cannot directly mutate audit_log
-- ============================================================
SELECT is_empty(
    $$SELECT privilege_type
      FROM information_schema.role_table_grants
      WHERE grantee = 'authenticated'
        AND table_schema = 'public'
        AND table_name = 'audit_log'
        AND privilege_type IN ('INSERT', 'UPDATE', 'DELETE')$$,
    'Test 5: Authenticated role cannot directly INSERT/UPDATE/DELETE audit_log'
);

-- ============================================================
-- Test 6: Authenticated role cannot directly mutate activity_flags
-- ============================================================
SELECT is_empty(
    $$SELECT privilege_type
      FROM information_schema.role_table_grants
      WHERE grantee = 'authenticated'
        AND table_schema = 'public'
        AND table_name = 'activity_flags'
        AND privilege_type IN ('INSERT', 'UPDATE', 'DELETE')$$,
    'Test 6: Authenticated role cannot directly INSERT/UPDATE/DELETE activity_flags'
);

-- ============================================================
-- Test 7: Authenticated role cannot directly INSERT into activities
-- ============================================================
SELECT is_empty(
    $$SELECT privilege_type
      FROM information_schema.role_table_grants
      WHERE grantee = 'authenticated'
        AND table_schema = 'public'
        AND table_name = 'activities'
        AND privilege_type = 'INSERT'$$,
    'Test 7: Authenticated role cannot directly INSERT activities'
);

-- ============================================================
-- Test 8: Authenticated role cannot directly mutate account_deletion_requests
-- ============================================================
SELECT is_empty(
    $$SELECT privilege_type
      FROM information_schema.role_table_grants
      WHERE grantee = 'authenticated'
        AND table_schema = 'public'
        AND table_name = 'account_deletion_requests'
        AND privilege_type IN ('INSERT', 'UPDATE', 'DELETE')$$,
    'Test 8: Authenticated role cannot directly INSERT/UPDATE/DELETE account_deletion_requests'
);

-- ============================================================
-- Test 9: Authenticated role cannot directly mutate challenges or achievements
-- ============================================================
SELECT is_empty(
    $$SELECT table_name, privilege_type
      FROM information_schema.role_table_grants
      WHERE grantee = 'authenticated'
        AND table_schema = 'public'
        AND table_name IN ('challenges', 'achievements')
        AND privilege_type IN ('INSERT', 'UPDATE', 'DELETE')$$,
    'Test 9: Authenticated role cannot directly INSERT/UPDATE/DELETE challenges or achievements'
);

-- ============================================================
-- Test 10: Every SECURITY DEFINER function has search_path set (Rule 9)
-- ============================================================
SELECT is_empty(
    $$SELECT proname
      FROM pg_proc p
      JOIN pg_namespace n ON n.oid = p.pronamespace
      WHERE n.nspname = 'public'
        AND p.prosecdef = true
        AND (p.proconfig IS NULL OR NOT array_to_string(p.proconfig, ',') LIKE '%search_path%')$$,
    'Test 10: All SECURITY DEFINER functions have explicit search_path'
);

-- ============================================================
-- Test 11: Anon cannot select internal-only tables (audit_log, outbox, etc.)
-- ============================================================
SELECT is_empty(
    $$SELECT table_name
      FROM information_schema.role_table_grants
      WHERE grantee = 'anon'
        AND table_schema = 'public'
        AND table_name IN ('audit_log', 'notification_outbox', 'admin_roles', 'rate_limits')
        AND privilege_type = 'SELECT'$$,
    'Test 11: Anon role has no SELECT grants on internal tables'
);

-- ============================================================
-- Test 12: Ledger integrity: no rows in kp_ledger without idempotency_key (Rule 7)
-- ============================================================
SELECT is_empty(
    $$SELECT id FROM public.kp_ledger WHERE idempotency_key IS NULL OR trim(idempotency_key) = ''$$,
    'Test 12: No kp_ledger rows without idempotency_key'
);

-- ============================================================
-- Done
-- ============================================================
SELECT * FROM finish();
ROLLBACK;
