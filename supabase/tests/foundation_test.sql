-- Foundation tests: RLS enforcement on core tables
-- Run with: supabase test db

BEGIN;

SELECT plan(14);

-- ============================================================
-- Helper: create test users
-- ============================================================

-- Create two test users in auth.users
INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token)
VALUES
    ('a1111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'alice@test.com', crypt('password', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now(), ''),
    ('b2222222-2222-2222-2222-222222222222', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'bob@test.com', crypt('password', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now(), '');

-- Create profiles for the test users
INSERT INTO public.profiles (id, username) VALUES
    ('a1111111-1111-1111-1111-111111111111', 'alice_test01'),
    ('b2222222-2222-2222-2222-222222222222', 'bob_test0001');

-- Seed a habit for testing
INSERT INTO public.habits (key, display_name, unit, daily_kp_cap, manual_allowed)
VALUES ('steps', 'Steps', 'count', 150, false);

-- Seed an activity for alice (inserted directly for testing — normally via RPC)
INSERT INTO public.activities (user_id, habit_id, quantity, started_at, ended_at, source, verification_status)
VALUES (
    'a1111111-1111-1111-1111-111111111111',
    (SELECT id FROM public.habits WHERE key = 'steps'),
    8000,
    now() - interval '1 hour',
    now(),
    'healthkit',
    'verified'
);

-- Seed a ledger row for alice
INSERT INTO public.kp_ledger (user_id, amount, type, source_type, idempotency_key, day_local)
VALUES (
    'a1111111-1111-1111-1111-111111111111',
    80,
    'earn',
    'activity',
    'earn:test_activity_1',
    CURRENT_DATE
);

-- ============================================================
-- TEST: Authenticated user CANNOT insert into activities
-- ============================================================

SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims = '{"sub": "a1111111-1111-1111-1111-111111111111", "role": "authenticated"}';

SELECT throws_ok(
    $$INSERT INTO public.activities (user_id, habit_id, quantity, started_at, ended_at, source, verification_status)
      VALUES ('a1111111-1111-1111-1111-111111111111', 1, 5000, now() - interval '30 min', now(), 'healthkit', 'verified')$$,
    '42501',
    NULL,
    'Authenticated user cannot INSERT into activities'
);

-- ============================================================
-- TEST: Authenticated user CANNOT update activities
-- ============================================================

SELECT throws_ok(
    $$UPDATE public.activities SET quantity = 99999 WHERE user_id = 'a1111111-1111-1111-1111-111111111111'$$,
    '42501',
    NULL,
    'Authenticated user cannot UPDATE activities'
);

-- ============================================================
-- TEST: Authenticated user CANNOT delete activities
-- ============================================================

SELECT throws_ok(
    $$DELETE FROM public.activities WHERE user_id = 'a1111111-1111-1111-1111-111111111111'$$,
    '42501',
    NULL,
    'Authenticated user cannot DELETE from activities'
);

-- ============================================================
-- TEST: Authenticated user CANNOT insert into kp_ledger
-- ============================================================

SELECT throws_ok(
    $$INSERT INTO public.kp_ledger (user_id, amount, type, source_type, idempotency_key, day_local)
      VALUES ('a1111111-1111-1111-1111-111111111111', 9999, 'earn', 'activity', 'hack:1', CURRENT_DATE)$$,
    '42501',
    NULL,
    'Authenticated user cannot INSERT into kp_ledger'
);

-- ============================================================
-- TEST: Authenticated user CANNOT update kp_ledger
-- ============================================================

SELECT throws_ok(
    $$UPDATE public.kp_ledger SET amount = 99999 WHERE user_id = 'a1111111-1111-1111-1111-111111111111'$$,
    '42501',
    NULL,
    'Authenticated user cannot UPDATE kp_ledger'
);

-- ============================================================
-- TEST: Authenticated user CANNOT delete from kp_ledger
-- ============================================================

SELECT throws_ok(
    $$DELETE FROM public.kp_ledger WHERE user_id = 'a1111111-1111-1111-1111-111111111111'$$,
    '42501',
    NULL,
    'Authenticated user cannot DELETE from kp_ledger'
);

-- ============================================================
-- TEST: Alice CAN read her own activities
-- ============================================================

SELECT is(
    (SELECT count(*)::integer FROM public.activities),
    1,
    'Alice can read her own activities'
);

-- ============================================================
-- TEST: Alice CAN read her own ledger
-- ============================================================

SELECT is(
    (SELECT count(*)::integer FROM public.kp_ledger),
    1,
    'Alice can read her own ledger entries'
);

-- ============================================================
-- TEST: Bob CANNOT see Alice's activities
-- ============================================================

SET LOCAL request.jwt.claims = '{"sub": "b2222222-2222-2222-2222-222222222222", "role": "authenticated"}';

SELECT is(
    (SELECT count(*)::integer FROM public.activities),
    0,
    'Bob cannot see Alice''s activities'
);

-- ============================================================
-- TEST: Bob CANNOT see Alice's ledger
-- ============================================================

SELECT is(
    (SELECT count(*)::integer FROM public.kp_ledger),
    0,
    'Bob cannot see Alice''s ledger entries'
);

-- ============================================================
-- TEST: Bob CANNOT update Alice's profile
-- ============================================================

SELECT is(
    (SELECT count(*)::integer FROM (
        UPDATE public.profiles SET display_name = 'HACKED' WHERE id = 'a1111111-1111-1111-1111-111111111111' RETURNING 1
    ) AS updated),
    0,
    'Bob cannot update Alice''s profile'
);

-- ============================================================
-- TEST: Alice CANNOT change her own profile ID
-- ============================================================

SET LOCAL request.jwt.claims = '{"sub": "a1111111-1111-1111-1111-111111111111", "role": "authenticated"}';

SELECT throws_ok(
    $$UPDATE public.profiles SET id = 'b2222222-2222-2222-2222-222222222222' WHERE id = 'a1111111-1111-1111-1111-111111111111'$$,
    NULL,
    NULL,
    'Alice cannot change her own profile ID'
);

-- ============================================================
-- TEST: Anon CANNOT read profiles
-- ============================================================

RESET ROLE;
SET LOCAL ROLE anon;

SELECT is(
    (SELECT count(*)::integer FROM public.profiles),
    0,
    'Anon cannot read profiles'
);

-- ============================================================
-- TEST: Anon CANNOT read activities
-- ============================================================

SELECT is(
    (SELECT count(*)::integer FROM public.activities),
    0,
    'Anon cannot read activities'
);

SELECT * FROM finish();

ROLLBACK;
