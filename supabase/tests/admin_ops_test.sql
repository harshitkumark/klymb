-- pgTAP tests for B17: Admin & Ops
-- Tests admin roles, audit logging, flag review, authorization checks

BEGIN;
SELECT plan(13);

-- ============================================================
-- Setup: create test users
-- ============================================================

-- Admin User (will be super_admin)
INSERT INTO auth.users (id, email, raw_app_meta_data, raw_user_meta_data, aud, role, created_at, updated_at)
VALUES (
    'aa111111-1111-1111-1111-111111111111',
    'admin_super@test.com',
    '{"provider":"apple","providers":["apple"]}',
    '{"full_name":"Super Admin"}',
    'authenticated', 'authenticated', now(), now()
);

-- Moderator User
INSERT INTO auth.users (id, email, raw_app_meta_data, raw_user_meta_data, aud, role, created_at, updated_at)
VALUES (
    'bb222222-2222-2222-2222-222222222222',
    'admin_mod@test.com',
    '{"provider":"apple","providers":["apple"]}',
    '{"full_name":"Moderator User"}',
    'authenticated', 'authenticated', now(), now()
);

-- Regular User
INSERT INTO auth.users (id, email, raw_app_meta_data, raw_user_meta_data, aud, role, created_at, updated_at)
VALUES (
    'cc333333-3333-3333-3333-333333333333',
    'regular_user@test.com',
    '{"provider":"apple","providers":["apple"]}',
    '{"full_name":"Regular User"}',
    'authenticated', 'authenticated', now(), now()
);

SELECT pg_sleep(0.1);

-- Set usernames
SELECT set_config('request.jwt.claims', '{"sub":"aa111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;
SELECT public.set_username('chiefadmin');

SELECT set_config('request.jwt.claims', '{"sub":"bb222222-2222-2222-2222-222222222222","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;
SELECT public.set_username('modguy');

SELECT set_config('request.jwt.claims', '{"sub":"cc333333-3333-3333-3333-333333333333","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;
SELECT public.set_username('regularguy');

-- Seed super_admin role for User A (direct system insert)
RESET ROLE;
INSERT INTO public.admin_roles (user_id, role)
VALUES ('aa111111-1111-1111-1111-111111111111', 'super_admin');

-- Create an activity and a flag for the regular user
INSERT INTO public.activities (
    user_id, habit_id, quantity, started_at, ended_at, source, was_user_entered
) VALUES (
    'cc333333-3333-3333-3333-333333333333',
    (SELECT id FROM public.habits WHERE key = 'running'),
    10.0,
    now() - interval '2 hours',
    now() - interval '1 hour',
    'healthkit',
    false
);

-- Earned KP entry
INSERT INTO public.kp_ledger (
    user_id, amount, type, source_type, source_id, idempotency_key, day_local, created_at
) VALUES (
    'cc333333-3333-3333-3333-333333333333',
    200,
    'earn',
    'activity',
    (SELECT currval(pg_get_serial_sequence('public.activities', 'id'))::text),
    'earn:test_flagged_act',
    CURRENT_DATE,
    now()
);

-- Flag the activity
INSERT INTO public.activity_flags (
    activity_id, user_id, rule, severity, status, detail
) VALUES (
    (SELECT currval(pg_get_serial_sequence('public.activities', 'id'))),
    'cc333333-3333-3333-3333-333333333333',
    'OV-R1',
    'HIGH',
    'open',
    '{"speed_kmh": 45.0}'::jsonb
);

-- ============================================================
-- Test 1: Regular user is not an admin
-- ============================================================
SELECT set_config('request.jwt.claims', '{"sub":"cc333333-3333-3333-3333-333333333333","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;

SELECT is(
    public.is_admin(),
    false,
    'Test 1: Regular user is_admin() returns false'
);

-- ============================================================
-- Test 2: Regular user cannot call admin_list_flags
-- ============================================================
SELECT throws_ok(
    'SELECT public.admin_list_flags()',
    '42501',
    'ERR_UNAUTHORIZED',
    'Test 2: Regular user cannot call admin_list_flags'
);

-- ============================================================
-- Test 3: Regular user cannot see admin_roles table via RLS
-- ============================================================
SELECT is_empty(
    'SELECT * FROM public.admin_roles',
    'Test 3: Regular user sees empty admin_roles due to RLS'
);

-- ============================================================
-- Test 4: Super admin is_admin() returns true and can see roles
-- ============================================================
SELECT set_config('request.jwt.claims', '{"sub":"aa111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;

SELECT is(
    public.is_admin(),
    true,
    'Test 4: Super admin is_admin() returns true'
);

-- ============================================================
-- Test 5: Super admin has all role levels
-- ============================================================
SELECT ok(
    public.has_admin_role('super_admin')
    AND public.has_admin_role('moderator')
    AND public.has_admin_role('support'),
    'Test 5: Super admin satisfies all role checks'
);

-- ============================================================
-- Test 6: Super admin grants moderator role to User B
-- ============================================================
SELECT ok(
    (SELECT (public.admin_grant_role('bb222222-2222-2222-2222-222222222222', 'moderator')->>'status') = 'role_granted'),
    'Test 6: Super admin grants moderator role to User B'
);

-- ============================================================
-- Test 7: Audit log records the role grant
-- ============================================================
SELECT ok(
    (SELECT EXISTS(
        SELECT 1 FROM public.audit_log
        WHERE admin_id = 'aa111111-1111-1111-1111-111111111111'
          AND action = 'grant_role'
          AND target_id = 'bb222222-2222-2222-2222-222222222222'
    )),
    'Test 7: Role grant recorded in audit_log'
);

-- ============================================================
-- Test 8: Moderator can list flags
-- ============================================================
SELECT set_config('request.jwt.claims', '{"sub":"bb222222-2222-2222-2222-222222222222","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;

SELECT ok(
    (SELECT (public.admin_list_flags()->>'total')::int >= 1),
    'Test 8: Moderator can list flags and see at least 1 flag'
);

-- ============================================================
-- Test 9: Moderator reviews flag -> confirmed cheating
-- ============================================================
SELECT ok(
    (SELECT (public.admin_review_flag(
        (SELECT id FROM public.activity_flags LIMIT 1),
        'resolved_confirmed',
        'Speed is impossible'
    )->>'status') = 'flag_reviewed'),
    'Test 9: Moderator reviews and confirms flag'
);

-- ============================================================
-- Test 10: Confirming flag revokes KP in kp_ledger
-- ============================================================
SELECT ok(
    (SELECT EXISTS(
        SELECT 1 FROM public.kp_ledger
        WHERE user_id = 'cc333333-3333-3333-3333-333333333333'
          AND type = 'revoke'
          AND amount < 0
    )),
    'Test 10: KP revoked in kp_ledger after flag confirmation'
);

-- ============================================================
-- Test 11: Moderator cannot grant roles (requires super_admin)
-- ============================================================
SELECT throws_ok(
    'SELECT public.admin_grant_role(''cc333333-3333-3333-3333-333333333333'', ''support'')',
    '42501',
    'ERR_UNAUTHORIZED',
    'Test 11: Moderator cannot grant roles'
);

-- ============================================================
-- Test 12: admin_get_user_summary returns user stats
-- ============================================================
SELECT ok(
    (SELECT (public.admin_get_user_summary('cc333333-3333-3333-3333-333333333333')->>'username') = 'regularguy'),
    'Test 12: admin_get_user_summary returns correct username'
);

-- ============================================================
-- Test 13: Super admin revokes role from User B
-- ============================================================
SELECT set_config('request.jwt.claims', '{"sub":"aa111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;

SELECT ok(
    (SELECT (public.admin_revoke_role('bb222222-2222-2222-2222-222222222222', 'moderator')->>'status') = 'role_revoked'),
    'Test 13: Super admin revokes moderator role'
);

-- ============================================================
-- Done
-- ============================================================
SELECT * FROM finish();
ROLLBACK;
