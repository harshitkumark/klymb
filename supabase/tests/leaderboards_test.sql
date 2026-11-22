-- Test: leaderboards_test.sql
-- B10: Leaderboards [REVIEW]
-- Tests for materialized views, refresh_leaderboards(), get_leaderboard(), and get_my_rank()

BEGIN;

SELECT plan(16);

-- ============================================================
-- SETUP TEST USERS & SCORES
-- ============================================================

-- Create 3 test users in different cities
-- User 1: Bengaluru (Top scorer)
INSERT INTO auth.users (id, email, role, aud, instance_id)
VALUES (
    'b1000001-0000-0000-0000-000000000001'::uuid,
    'lb_user1@klymb.app',
    'authenticated',
    'authenticated',
    '00000000-0000-0000-0000-000000000000'::uuid
);

-- User 2: Bengaluru (Second scorer)
INSERT INTO auth.users (id, email, role, aud, instance_id)
VALUES (
    'b1000002-0000-0000-0000-000000000002'::uuid,
    'lb_user2@klymb.app',
    'authenticated',
    'authenticated',
    '00000000-0000-0000-0000-000000000000'::uuid
);

-- User 3: Mumbai (City leader in Mumbai)
INSERT INTO auth.users (id, email, role, aud, instance_id)
VALUES (
    'b1000003-0000-0000-0000-000000000003'::uuid,
    'lb_user3@klymb.app',
    'authenticated',
    'authenticated',
    '00000000-0000-0000-0000-000000000000'::uuid
);

-- User 4: Cheater user (with active HIGH flag)
INSERT INTO auth.users (id, email, role, aud, instance_id)
VALUES (
    'b1000004-0000-0000-0000-000000000004'::uuid,
    'lb_cheater@klymb.app',
    'authenticated',
    'authenticated',
    '00000000-0000-0000-0000-000000000000'::uuid
);

-- Update cities
UPDATE public.profiles SET city_id = (SELECT id FROM public.cities WHERE name = 'Bengaluru' LIMIT 1), username = 'lb_top_bengaluru'
WHERE id = 'b1000001-0000-0000-0000-000000000001'::uuid;

UPDATE public.profiles SET city_id = (SELECT id FROM public.cities WHERE name = 'Bengaluru' LIMIT 1), username = 'lb_second_bengaluru'
WHERE id = 'b1000002-0000-0000-0000-000000000002'::uuid;

UPDATE public.profiles SET city_id = (SELECT id FROM public.cities WHERE name = 'Mumbai' LIMIT 1), username = 'lb_top_mumbai'
WHERE id = 'b1000003-0000-0000-0000-000000000003'::uuid;

UPDATE public.profiles SET city_id = (SELECT id FROM public.cities WHERE name = 'Mumbai' LIMIT 1), username = 'lb_cheater'
WHERE id = 'b1000004-0000-0000-0000-000000000004'::uuid;

-- Insert ledger rows for today (CURRENT_DATE)
-- User 1: 300 KP today
INSERT INTO public.kp_ledger (user_id, amount, type, source_type, idempotency_key, day_local)
VALUES ('b1000001-0000-0000-0000-000000000001'::uuid, 300, 'earn', 'activity', 'lb-test-u1-today', CURRENT_DATE);

-- User 2: 150 KP today
INSERT INTO public.kp_ledger (user_id, amount, type, source_type, idempotency_key, day_local)
VALUES ('b1000002-0000-0000-0000-000000000002'::uuid, 150, 'earn', 'activity', 'lb-test-u2-today', CURRENT_DATE);

-- User 3: 200 KP today
INSERT INTO public.kp_ledger (user_id, amount, type, source_type, idempotency_key, day_local)
VALUES ('b1000003-0000-0000-0000-000000000003'::uuid, 200, 'earn', 'activity', 'lb-test-u3-today', CURRENT_DATE);

-- User 4: 500 KP today (highest, but flagged)
INSERT INTO public.kp_ledger (user_id, amount, type, source_type, idempotency_key, day_local)
VALUES ('b1000004-0000-0000-0000-000000000004'::uuid, 500, 'earn', 'activity', 'lb-test-u4-today', CURRENT_DATE);

-- Create dummy activity and active HIGH flag for User 4
INSERT INTO public.activities (user_id, habit_id, quantity, started_at, ended_at, source, verification_status)
VALUES ('b1000004-0000-0000-0000-000000000004'::uuid, (SELECT id FROM public.habits LIMIT 1), 100, now() - interval '1 hour', now(), 'healthkit', 'verified');

INSERT INTO public.activity_flags (activity_id, user_id, rule, severity, status)
SELECT a.id, a.user_id, 'T1-R3', 'HIGH', 'open'
FROM public.activities a
WHERE a.user_id = 'b1000004-0000-0000-0000-000000000004'::uuid
ORDER BY a.id DESC LIMIT 1;

-- Refresh leaderboards to incorporate newly inserted test rows
SELECT lives_ok(
    $$SELECT public.refresh_leaderboards('all')$$,
    'refresh_leaderboards() executes without error'
);

-- Set auth context to User 2 (Bengaluru, 150 KP, rank 3 globally, rank 2 city)
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"sub":"b1000002-0000-0000-0000-000000000002","role":"authenticated"}', true);

-- ============================================================
-- TEST 1: Global Daily Leaderboard & Flag Exclusion
-- ============================================================
-- Expected Global order:
-- Rank 1: User 1 (300 KP)
-- Rank 2: User 3 (200 KP)
-- Rank 3: User 2 (150 KP)
-- User 4 is excluded due to active HIGH flag!

SELECT is(
    (SELECT COUNT(*)::integer FROM public.get_leaderboard('global', 'daily', NULL, 10, 0) WHERE username = 'lb_cheater'),
    0,
    'Flagged user with active HIGH severity flag is excluded from leaderboard'
);

SELECT is(
    (SELECT username FROM public.get_leaderboard('global', 'daily', NULL, 1, 0)),
    'lb_top_bengaluru',
    'Rank 1 global is User 1 (300 KP)'
);

SELECT is(
    (SELECT rank FROM public.get_leaderboard('global', 'daily', NULL, 10, 0) WHERE username = 'lb_top_mumbai'),
    2::bigint,
    'Rank 2 global is User 3 (200 KP)'
);

SELECT is(
    (SELECT rank FROM public.get_leaderboard('global', 'daily', NULL, 10, 0) WHERE username = 'lb_second_bengaluru'),
    3::bigint,
    'Rank 3 global is User 2 (150 KP)'
);

-- ============================================================
-- TEST 2: City Leaderboard (Bengaluru & Mumbai Scopes)
-- ============================================================

-- City leaderboard for Bengaluru
SELECT is(
    (SELECT rank FROM public.get_leaderboard('city', 'daily', (SELECT id FROM public.cities WHERE name = 'Bengaluru' LIMIT 1), 10, 0) WHERE username = 'lb_top_bengaluru'),
    1::bigint,
    'Bengaluru City Rank 1 is User 1'
);

SELECT is(
    (SELECT rank FROM public.get_leaderboard('city', 'daily', (SELECT id FROM public.cities WHERE name = 'Bengaluru' LIMIT 1), 10, 0) WHERE username = 'lb_second_bengaluru'),
    2::bigint,
    'Bengaluru City Rank 2 is User 2'
);

-- City leaderboard for Mumbai
SELECT is(
    (SELECT username FROM public.get_leaderboard('city', 'daily', (SELECT id FROM public.cities WHERE name = 'Mumbai' LIMIT 1), 1, 0)),
    'lb_top_mumbai',
    'Mumbai City Rank 1 is User 3'
);

-- ============================================================
-- TEST 3: Pagination (Limit & Offset)
-- ============================================================
SELECT is(
    (SELECT count(*)::integer FROM public.get_leaderboard('global', 'daily', NULL, 2, 0)),
    2,
    'get_leaderboard honors limit = 2'
);

SELECT is(
    (SELECT rank FROM public.get_leaderboard('global', 'daily', NULL, 1, 1)),
    2::bigint,
    'get_leaderboard honors offset = 1 (returns rank 2)'
);

-- ============================================================
-- TEST 4: get_my_rank (Caller = User 2, 150 KP)
-- ============================================================
-- Global: rank 3, next user is User 3 (200 KP), kp_to_overtake = 51
SELECT is(
    (SELECT (public.get_my_rank('global', 'daily', NULL)->>'rank')::integer),
    3,
    'get_my_rank returns rank 3 globally for User 2'
);

SELECT is(
    (SELECT (public.get_my_rank('global', 'daily', NULL)->>'kp')::integer),
    150,
    'get_my_rank returns 150 KP for User 2'
);

SELECT is(
    (SELECT (public.get_my_rank('global', 'daily', NULL)->'next_user'->>'username')),
    'lb_top_mumbai',
    'Next user above User 2 is lb_top_mumbai'
);

SELECT is(
    (SELECT (public.get_my_rank('global', 'daily', NULL)->>'kp_to_overtake')::integer),
    51,
    'KP to overtake User 3 is 51 (200 - 150 + 1)'
);

-- City scope (Bengaluru): User 2 is rank 2, next user is User 1 (300 KP), kp_to_overtake = 151
SELECT is(
    (SELECT (public.get_my_rank('city', 'daily', NULL)->>'rank')::integer),
    2,
    'get_my_rank returns rank 2 in Bengaluru for User 2'
);

SELECT is(
    (SELECT (public.get_my_rank('city', 'daily', NULL)->>'kp_to_overtake')::integer),
    151,
    'KP to overtake in city is 151 (300 - 150 + 1)'
);

-- ============================================================
-- DONE
-- ============================================================

SELECT * FROM finish();
ROLLBACK;
