-- Tests for B8: Streaks and freeze logic
-- Run with: supabase test db

BEGIN;

SELECT plan(13);

-- ============================================================
-- Helper: Create test user Jack and activate habits
-- ============================================================

INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token)
VALUES
    ('c9999999-9999-9999-9999-999999999999', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'jack@test.com', crypt('password', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now(), '');

UPDATE public.profiles
SET city_id = (SELECT id FROM public.cities WHERE name = 'Bengaluru')
WHERE id = 'c9999999-9999-9999-9999-999999999999';

INSERT INTO public.user_habits (user_id, habit_id, active)
SELECT 'c9999999-9999-9999-9999-999999999999', id, true
FROM public.habits;

SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims = '{"sub": "c9999999-9999-9999-9999-999999999999", "role": "authenticated"}';

-- ============================================================
-- TEST 1: Activity with < 50 verified KP does not create a qualifying streak
-- ============================================================

-- 4,000 steps = 40 KP (< 50 KP) on (CURRENT_DATE - 4)
SELECT (public.submit_activities(jsonb_build_array(
    jsonb_build_object(
        'habit_key', 'steps',
        'quantity', 4000,
        'started_at', ((CURRENT_DATE - 4)::text || ' 08:00:00+05:30'),
        'ended_at', ((CURRENT_DATE - 4)::text || ' 09:00:00+05:30'),
        'source', 'healthkit',
        'source_sample_id', 'jack-steps-day1-low',
        'was_user_entered', false
    )
)));

SELECT is(
    (SELECT count(*)::integer FROM public.user_streaks WHERE user_id = 'c9999999-9999-9999-9999-999999999999'),
    0,
    'Earned 40 KP (< 50 KP) does not qualify for streak'
);

-- ============================================================
-- TEST 2: Reaching >= 50 verified KP qualifies and starts 1-day streak
-- ============================================================

-- Add 2,000 more steps on same day = 20 KP (total verified = 60 KP >= 50 KP)
SELECT (public.submit_activities(jsonb_build_array(
    jsonb_build_object(
        'habit_key', 'steps',
        'quantity', 2000,
        'started_at', ((CURRENT_DATE - 4)::text || ' 11:00:00+05:30'),
        'ended_at', ((CURRENT_DATE - 4)::text || ' 11:30:00+05:30'),
        'source', 'healthkit',
        'source_sample_id', 'jack-steps-day1-qualify',
        'was_user_entered', false
    )
)));

SELECT is(
    (SELECT current_streak FROM public.user_streaks WHERE user_id = 'c9999999-9999-9999-9999-999999999999'),
    1,
    'Reaching 60 verified KP qualifies and starts a 1-day streak'
);

-- ============================================================
-- TEST 3: Submitting another activity on same day does not advance streak
-- ============================================================

SELECT (public.submit_activities(jsonb_build_array(
    jsonb_build_object(
        'habit_key', 'running',
        'quantity', 3.0,
        'started_at', ((CURRENT_DATE - 4)::text || ' 17:00:00+05:30'),
        'ended_at', ((CURRENT_DATE - 4)::text || ' 17:30:00+05:30'),
        'source', 'healthkit',
        'source_sample_id', 'jack-run-day1-extra',
        'was_user_entered', false
    )
)));

SELECT is(
    (SELECT current_streak FROM public.user_streaks WHERE user_id = 'c9999999-9999-9999-9999-999999999999'),
    1,
    'Additional qualifying activity on the same day keeps streak at 1'
);

-- ============================================================
-- TEST 4: Consecutive day (Day 2) advances streak to 2 days
-- ============================================================

-- Day 2: (CURRENT_DATE - 3) (5,000 steps = 50 KP)
SELECT (public.submit_activities(jsonb_build_array(
    jsonb_build_object(
        'habit_key', 'steps',
        'quantity', 5000,
        'started_at', ((CURRENT_DATE - 3)::text || ' 08:00:00+05:30'),
        'ended_at', ((CURRENT_DATE - 3)::text || ' 09:00:00+05:30'),
        'source', 'healthkit',
        'source_sample_id', 'jack-steps-day2',
        'was_user_entered', false
    )
)));

SELECT is(
    (SELECT current_streak FROM public.user_streaks WHERE user_id = 'c9999999-9999-9999-9999-999999999999'),
    2,
    'Qualifying on consecutive day advances current_streak to 2'
);

-- ============================================================
-- TEST 5: Day 3 advances streak to 3 days and awards 3-day milestone (25 KP)
-- ============================================================

-- Day 3: (CURRENT_DATE - 2) (5,000 steps = 50 KP)
SELECT (public.submit_activities(jsonb_build_array(
    jsonb_build_object(
        'habit_key', 'steps',
        'quantity', 5000,
        'started_at', ((CURRENT_DATE - 2)::text || ' 08:00:00+05:30'),
        'ended_at', ((CURRENT_DATE - 2)::text || ' 09:00:00+05:30'),
        'source', 'healthkit',
        'source_sample_id', 'jack-steps-day3',
        'was_user_entered', false
    )
)));

SELECT is(
    (SELECT current_streak FROM public.user_streaks WHERE user_id = 'c9999999-9999-9999-9999-999999999999'),
    3,
    'Qualifying on day 3 advances current_streak to 3'
);

-- ============================================================
-- TEST 6: Milestone bonus in kp_ledger is 25 KP with streak:*:3:v1
-- ============================================================

SELECT is(
    (SELECT amount FROM public.kp_ledger WHERE user_id = 'c9999999-9999-9999-9999-999999999999' AND type = 'streak_bonus'),
    25,
    '3-day milestone bonus of 25 KP awarded to kp_ledger'
);

SELECT is(
    (SELECT idempotency_key FROM public.kp_ledger WHERE user_id = 'c9999999-9999-9999-9999-999999999999' AND type = 'streak_bonus'),
    'streak:c9999999-9999-9999-9999-999999999999:3:v1',
    'Streak bonus has correct idempotency_key format streak:<user>:3:v1'
);

-- ============================================================
-- TEST 7: 1 missed day (gap = 2) auto-applies freeze and preserves streak
-- ============================================================

-- Last qualified was (CURRENT_DATE - 2). Missed (CURRENT_DATE - 1). Submits on CURRENT_DATE (5,000 steps).
SELECT (public.submit_activities(jsonb_build_array(
    jsonb_build_object(
        'habit_key', 'steps',
        'quantity', 5000,
        'started_at', (CURRENT_DATE::text || ' 08:00:00+05:30'),
        'ended_at', (CURRENT_DATE::text || ' 09:00:00+05:30'),
        'source', 'healthkit',
        'source_sample_id', 'jack-steps-day5-freeze',
        'was_user_entered', false
    )
)));

SELECT is(
    (SELECT current_streak FROM public.user_streaks WHERE user_id = 'c9999999-9999-9999-9999-999999999999'),
    4,
    '1 missed day with freeze available auto-applies freeze and advances streak to 4'
);

SELECT is(
    (SELECT freezes_available FROM public.user_streaks WHERE user_id = 'c9999999-9999-9999-9999-999999999999'),
    0,
    'Streak freeze was consumed (freezes_available = 0)'
);

-- ============================================================
-- TEST 8: 2+ day gap without freeze breaks streak and increments streak_version
-- ============================================================

-- Simulate gap: reset last_qualified_date to 5 days ago (no freeze available since freezes_available=0)
RESET ROLE;
UPDATE public.user_streaks
SET last_qualified_date = CURRENT_DATE - 4
WHERE user_id = 'c9999999-9999-9999-9999-999999999999';

SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims = '{"sub": "c9999999-9999-9999-9999-999999999999", "role": "authenticated"}';

SELECT (public.submit_activities(jsonb_build_array(
    jsonb_build_object(
        'habit_key', 'running',
        'quantity', 3.0,
        'started_at', (CURRENT_DATE::text || ' 10:00:00+05:30'),
        'ended_at', (CURRENT_DATE::text || ' 10:30:00+05:30'),
        'source', 'healthkit',
        'source_sample_id', 'jack-steps-broken-gap',
        'was_user_entered', false
    )
)));

SELECT is(
    (SELECT current_streak FROM public.user_streaks WHERE user_id = 'c9999999-9999-9999-9999-999999999999'),
    1,
    'Streak resets to 1 after unbroken gap exceeds freeze allowance'
);

SELECT is(
    (SELECT streak_version FROM public.user_streaks WHERE user_id = 'c9999999-9999-9999-9999-999999999999'),
    2,
    'streak_version increments to 2 to allow re-earning milestone bonuses'
);

-- ============================================================
-- TEST 9: Manual activity alone does not qualify for streak
-- ============================================================

-- Create user Liam
RESET ROLE;
INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token)
VALUES
    ('c8888888-8888-8888-8888-888888888888', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'liam@test.com', crypt('password', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now(), '');

INSERT INTO public.user_habits (user_id, habit_id, active)
SELECT 'c8888888-8888-8888-8888-888888888888', id, true FROM public.habits;

SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims = '{"sub": "c8888888-8888-8888-8888-888888888888", "role": "authenticated"}';

-- Liam logs 40 KP manual workout (manual_allowed=true)
SELECT (public.submit_activities(jsonb_build_array(
    jsonb_build_object(
        'habit_key', 'workout',
        'quantity', 60,
        'started_at', (CURRENT_DATE::text || ' 10:00:00+05:30'),
        'ended_at', (CURRENT_DATE::text || ' 11:00:00+05:30'),
        'source', 'manual',
        'source_sample_id', 'liam-manual-workout',
        'was_user_entered', true
    )
)));

SELECT is(
    (SELECT count(*)::integer FROM public.user_streaks WHERE user_id = 'c8888888-8888-8888-8888-888888888888'),
    0,
    'Manual entry KP does not count toward streak qualification'
);

-- ============================================================
-- TEST 10: Client cannot directly insert into user_streaks
-- ============================================================

SELECT throws_ok(
    $$INSERT INTO public.user_streaks (user_id, current_streak) VALUES ('c8888888-8888-8888-8888-888888888888', 99)$$,
    '42501',
    NULL,
    'Authenticated client cannot directly INSERT into user_streaks'
);

SELECT * FROM finish();

ROLLBACK;
