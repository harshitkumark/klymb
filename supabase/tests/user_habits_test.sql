-- Tests for B5: User habits
-- Run with: supabase test db

BEGIN;

SELECT plan(11);

-- ============================================================
-- TEST 1: Exactly 7 habits seeded
-- ============================================================

SELECT is(
    (SELECT count(*)::integer FROM public.habits),
    7,
    'Exactly 7 core habits are seeded in public.habits'
);

-- ============================================================
-- TEST 2: Verified-only habits have manual_allowed = false
-- ============================================================

SELECT is(
    (SELECT count(*)::integer FROM public.habits WHERE key IN ('steps', 'running', 'walking_distance', 'sleep') AND manual_allowed = false),
    4,
    'Steps, running, walking_distance, and sleep have manual_allowed = false'
);

-- ============================================================
-- TEST 3: Manual-allowed habits have manual_allowed = true and manual_kp_cap set
-- ============================================================

SELECT is(
    (SELECT count(*)::integer FROM public.habits WHERE key IN ('workout', 'hydration', 'mindfulness') AND manual_allowed = true AND manual_kp_cap IS NOT NULL),
    3,
    'Workout, hydration, and mindfulness allow manual entry with a lower cap'
);

-- ============================================================
-- Helper: Create test user via auth.users
-- ============================================================

INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token)
VALUES
    ('f6666666-6666-6666-6666-666666666666', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'frank@test.com', crypt('password', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now(), '');

-- ============================================================
-- TEST 4: Frank can set his active habits
-- ============================================================

SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims = '{"sub": "f6666666-6666-6666-6666-666666666666", "role": "authenticated"}';

SELECT lives_ok(
    $$SELECT public.set_user_habits(ARRAY[
        (SELECT id FROM public.habits WHERE key = 'steps'),
        (SELECT id FROM public.habits WHERE key = 'hydration'),
        (SELECT id FROM public.habits WHERE key = 'sleep')
    ])$$,
    'Frank can set active habits (steps, hydration, sleep)'
);

SELECT is(
    (SELECT count(*)::integer FROM public.user_habits WHERE user_id = 'f6666666-6666-6666-6666-666666666666' AND active = true),
    3,
    'Frank has exactly 3 active habits'
);

-- ============================================================
-- TEST 5: Atomic replacement deactivates previous habits
-- ============================================================

-- Frank replaces his active set: switches to running and workout (steps, hydration, sleep deactivated)
SELECT lives_ok(
    $$SELECT public.set_user_habits(ARRAY[
        (SELECT id FROM public.habits WHERE key = 'running'),
        (SELECT id FROM public.habits WHERE key = 'workout')
    ])$$,
    'Frank atomically replaces active habits to running and workout'
);

SELECT is(
    (SELECT count(*)::integer FROM public.user_habits WHERE user_id = 'f6666666-6666-6666-6666-666666666666' AND active = true),
    2,
    'Frank now has exactly 2 active habits (running and workout)'
);

-- ============================================================
-- TEST 6: Empty array is rejected
-- ============================================================

SELECT throws_ok(
    $$SELECT public.set_user_habits(ARRAY[]::bigint[])$$,
    '22023',
    NULL,
    'Empty habit array is rejected with ERR_NO_HABITS_SELECTED'
);

-- ============================================================
-- TEST 7: Invalid habit ID in array is rejected
-- ============================================================

SELECT throws_ok(
    $$SELECT public.set_user_habits(ARRAY[(SELECT id FROM public.habits WHERE key = 'steps'), 999999::bigint])$$,
    'P0002',
    NULL,
    'Invalid habit ID in array is rejected with ERR_HABIT_NOT_FOUND'
);

-- ============================================================
-- TEST 8: Anon cannot execute set_user_habits
-- ============================================================

RESET ROLE;
SET LOCAL ROLE anon;

SELECT throws_ok(
    $$SELECT public.set_user_habits(ARRAY[1::bigint])$$,
    '42501',
    NULL,
    'Anon cannot execute set_user_habits'
);

-- ============================================================
-- TEST 9: Cross-user isolation: Another user cannot see Frank's habits
-- ============================================================

-- Create second user Grace
RESET ROLE;
INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token)
VALUES
    ('a7777777-7777-7777-7777-777777777777', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'grace@test.com', crypt('password', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now(), '');

SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims = '{"sub": "a7777777-7777-7777-7777-777777777777", "role": "authenticated"}';

SELECT is(
    (SELECT count(*)::integer FROM public.user_habits),
    0,
    'Grace cannot see any of Frank''s user_habits rows (RLS isolation)'
);

SELECT * FROM finish();

ROLLBACK;
