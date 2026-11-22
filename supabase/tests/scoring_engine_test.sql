-- Tests for B7: Scoring engine and ledger writes
-- Run with: supabase test db

BEGIN;

SELECT plan(13);

-- ============================================================
-- Helper: Create test user Ian and activate habits
-- ============================================================

INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token)
VALUES
    ('a9999999-9999-9999-9999-999999999999', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'ian@test.com', crypt('password', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now(), '');

-- Set Ian's city to Bengaluru
UPDATE public.profiles
SET city_id = (SELECT id FROM public.cities WHERE name = 'Bengaluru')
WHERE id = 'a9999999-9999-9999-9999-999999999999';

-- Activate all habits for Ian
INSERT INTO public.user_habits (user_id, habit_id, active)
SELECT 'a9999999-9999-9999-9999-999999999999', id, true
FROM public.habits;

SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims = '{"sub": "a9999999-9999-9999-9999-999999999999", "role": "authenticated"}';

-- ============================================================
-- TEST 1: Steps formula: 8,000 verified steps = 80 KP
-- ============================================================

SELECT is(
    (SELECT (public.submit_activities(jsonb_build_array(
        jsonb_build_object(
            'habit_key', 'steps',
            'quantity', 8000,
            'started_at', '2026-11-20 08:00:00+05:30',
            'ended_at', '2026-11-20 09:00:00+05:30',
            'source', 'healthkit',
            'source_sample_id', 'ian-steps-1',
            'was_user_entered', false
        )
    ))->0->>'earned_kp')::integer),
    80,
    '8,000 verified steps earns exactly 80 KP'
);

-- ============================================================
-- TEST 2: Manual multiplier 0.5x: 500 ml manual water = 5 KP (floor(500/250)*5*0.5)
-- ============================================================

SELECT is(
    (SELECT (public.submit_activities(jsonb_build_array(
        jsonb_build_object(
            'habit_key', 'hydration',
            'quantity', 500,
            'started_at', '2026-11-20 10:00:00+05:30',
            'ended_at', '2026-11-20 10:05:00+05:30',
            'source', 'manual',
            'source_sample_id', 'ian-water-1',
            'was_user_entered', true
        )
    ))->0->>'earned_kp')::integer),
    5,
    '500 ml manual hydration earns 5 KP (raw 10 KP * 0.5 manual multiplier)'
);

-- ============================================================
-- TEST 3: Sleep quality curve: 8.0 hours = 50 KP (optimal window)
-- ============================================================

SELECT is(
    (SELECT (public.submit_activities(jsonb_build_array(
        jsonb_build_object(
            'habit_key', 'sleep',
            'quantity', 8.0,
            'started_at', '2026-11-19 23:00:00+05:30',
            'ended_at', '2026-11-20 07:00:00+05:30',
            'source', 'healthkit',
            'source_sample_id', 'ian-sleep-1',
            'was_user_entered', false
        )
    ))->0->>'earned_kp')::integer),
    50,
    '8.0 hours optimal sleep earns 50 KP'
);

-- ============================================================
-- TEST 4: Sleep quality curve: 4.5 hours = 10 KP (penalized)
-- ============================================================

SELECT is(
    (SELECT (public.submit_activities(jsonb_build_array(
        jsonb_build_object(
            'habit_key', 'sleep',
            'quantity', 4.5,
            'started_at', '2026-11-18 23:00:00+05:30',
            'ended_at', '2026-11-19 03:30:00+05:30',
            'source', 'healthkit',
            'source_sample_id', 'ian-sleep-2',
            'was_user_entered', false
        )
    ))->0->>'earned_kp')::integer),
    10,
    '4.5 hours sleep earns 10 KP'
);

-- ============================================================
-- TEST 5: Per-habit daily cap: Steps capped at 150 KP
-- ============================================================

-- Ian already earned 80 KP from steps on 2026-11-20.
-- Submitting 10,000 steps would earn 100 KP, but cap is 150, so remaining room is 70 KP.
SELECT is(
    (SELECT (public.submit_activities(jsonb_build_array(
        jsonb_build_object(
            'habit_key', 'steps',
            'quantity', 10000,
            'started_at', '2026-11-20 17:00:00+05:30',
            'ended_at', '2026-11-20 18:30:00+05:30',
            'source', 'healthkit',
            'source_sample_id', 'ian-steps-2',
            'was_user_entered', false
        )
    ))->0->>'earned_kp')::integer),
    70,
    'Second steps activity is capped to 70 KP (80 + 70 = 150 KP daily cap)'
);

-- ============================================================
-- TEST 6: Zero-score invariant: Reaching cap earns 0 KP and does NOT insert <= 0 into kp_ledger
-- ============================================================

-- Submitting third steps activity when cap is reached earns 0 KP
SELECT is(
    (SELECT (public.submit_activities(jsonb_build_array(
        jsonb_build_object(
            'habit_key', 'steps',
            'quantity', 5000,
            'started_at', '2026-11-20 19:00:00+05:30',
            'ended_at', '2026-11-20 20:00:00+05:30',
            'source', 'healthkit',
            'source_sample_id', 'ian-steps-3',
            'was_user_entered', false
        )
    ))->0->>'earned_kp')::integer),
    0,
    'Third steps activity on same day earns 0 KP'
);

-- Verify no EARN row with amount <= 0 exists in kp_ledger
-- (Note: revoke rows from anti-cheat legitimately have negative amounts)
SELECT is(
    (SELECT count(*)::integer FROM public.kp_ledger WHERE type = 'earn' AND amount <= 0),
    0,
    'Ledger never contains an earn row with amount <= 0'
);

-- ============================================================
-- TEST 7: Manual cap enforcement: Manual workout caps at 40 KP
-- ============================================================

-- 60 min workout = 120 raw KP * 0.5 = 60 KP, but manual_kp_cap is 40 KP
SELECT is(
    (SELECT (public.submit_activities(jsonb_build_array(
        jsonb_build_object(
            'habit_key', 'workout',
            'quantity', 60,
            'started_at', '2026-11-20 11:00:00+05:30',
            'ended_at', '2026-11-20 12:00:00+05:30',
            'source', 'manual',
            'source_sample_id', 'ian-workout-1',
            'was_user_entered', true
        )
    ))->0->>'earned_kp')::integer),
    40,
    '60 min manual workout caps at 40 KP (manual_kp_cap enforced)'
);

-- ============================================================
-- TEST 8: Global daily cap (500 KP): Multi-habit submissions cap at 500 KP
-- ============================================================

-- Current KP on 2026-11-20:
-- Steps: 80 + 70 = 150
-- Water: 5
-- Sleep: 50
-- Workout: 40
-- Total so far = 245 KP. Remaining to 500 = 255 KP.
-- Submit 10 km run on 2026-11-20: 10 * 20 = 200 KP (under running cap 200).
-- Total becomes 445 KP. Remaining = 55 KP.
-- Then submit 10 km walk on 2026-11-20: 10 * 12 = 120 KP.
-- Walking cap is 120, but global cap leaves only 55 KP! Should earn exactly 55 KP.

-- Use 09:00-10:00 so the run does NOT overlap with sleep (23:00 Nov 19 - 07:00 Nov 20)
-- which would trigger anti-cheat OV-R2 (activity during sleep)
SELECT is(
    (SELECT (public.submit_activities(jsonb_build_array(
        jsonb_build_object(
            'habit_key', 'running',
            'quantity', 10.0,
            'started_at', '2026-11-20 09:00:00+05:30',
            'ended_at', '2026-11-20 10:00:00+05:30',
            'source', 'healthkit',
            'source_sample_id', 'ian-run-1',
            'was_user_entered', false
        )
    ))->0->>'earned_kp')::integer),
    200,
    '10 km run earns 200 KP'
);

SELECT is(
    (SELECT (public.submit_activities(jsonb_build_array(
        jsonb_build_object(
            'habit_key', 'walking_distance',
            'quantity', 10.0,
            'started_at', '2026-11-20 14:00:00+05:30',
            'ended_at', '2026-11-20 15:30:00+05:30',
            'source', 'healthkit',
            'source_sample_id', 'ian-walk-1',
            'was_user_entered', false
        )
    ))->0->>'earned_kp')::integer),
    105,
    '10 km walk capped to 105 KP by the 500 KP global daily cap'
);

-- ============================================================
-- TEST 9: user_kp_total() derives accurate sum from ledger
-- ============================================================

-- Total on 2026-11-20 = 500 KP. Total on 2026-11-19 = 60 KP (50 KP sleep + 10 KP sleep).
-- Plus 50 KP from "First Steps" achievement unlocked on first activity. Total = 610 KP.
SELECT is(
    public.user_kp_total('a9999999-9999-9999-9999-999999999999'::uuid),
    610,
    'user_kp_total() returns 610 KP matching ledger sum (including 50 KP first_steps achievement)'
);

-- ============================================================
-- TEST 10: user_daily_kp view aggregates correctly
-- ============================================================

SELECT is(
    (SELECT daily_kp FROM public.user_daily_kp WHERE day_local = '2026-11-20'),
    500,
    'user_daily_kp view reflects 500 KP for 2026-11-20'
);

-- ============================================================
-- TEST 11: Clients cannot execute score_activity directly
-- ============================================================

SELECT throws_ok(
    $$SELECT public.score_activity(1)$$,
    '42501',
    NULL,
    'Authenticated client cannot execute score_activity directly'
);

SELECT * FROM finish();

ROLLBACK;
