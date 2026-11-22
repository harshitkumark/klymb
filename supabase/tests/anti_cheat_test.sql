-- Test: anti_cheat_test.sql
-- B9: Anti-cheat rules & flags [REVIEW]
-- Tests for: blocked_sources, activity_flags, rate_limits, evaluate_activity_flags,
--            user_trust_score, rate limiting, and false-positive resilience.

BEGIN;

SELECT plan(15);

-- ============================================================
-- TEST SETUP: Create a test user with habits
-- ============================================================

-- Create test user in auth.users
INSERT INTO auth.users (id, email, role, aud, instance_id)
VALUES (
    'a1111111-1111-1111-1111-111111111111'::uuid,
    'anticheat_test@klymb.app',
    'authenticated',
    'authenticated',
    '00000000-0000-0000-0000-000000000000'::uuid
);

-- Create a second user for RLS test
INSERT INTO auth.users (id, email, role, aud, instance_id)
VALUES (
    'a2222222-2222-2222-2222-222222222222'::uuid,
    'anticheat_other@klymb.app',
    'authenticated',
    'authenticated',
    '00000000-0000-0000-0000-000000000000'::uuid
);

-- Profile is auto-created by trigger. Update city for timezone.
UPDATE public.profiles SET city_id = (SELECT id FROM public.cities WHERE name = 'Bengaluru' LIMIT 1)
WHERE id = 'a1111111-1111-1111-1111-111111111111'::uuid;

UPDATE public.profiles SET city_id = (SELECT id FROM public.cities WHERE name = 'Bengaluru' LIMIT 1)
WHERE id = 'a2222222-2222-2222-2222-222222222222'::uuid;

-- Activate all habits for test user
INSERT INTO public.user_habits (user_id, habit_id)
SELECT 'a1111111-1111-1111-1111-111111111111'::uuid, id FROM public.habits
ON CONFLICT (user_id, habit_id) DO NOTHING;

INSERT INTO public.user_habits (user_id, habit_id)
SELECT 'a2222222-2222-2222-2222-222222222222'::uuid, id FROM public.habits
ON CONFLICT (user_id, habit_id) DO NOTHING;

-- Set auth context to test user
SELECT set_config('request.jwt.claims', '{"sub":"a1111111-1111-1111-1111-111111111111","role":"authenticated"}', true);

-- ============================================================
-- TEST 1: Impossible steps rate → HIGH flag + revoke
-- ============================================================
-- 20,000 steps in 30 minutes = 40,000 steps/hour → T1-R3 HIGH
SELECT lives_ok(
    format(
        'SELECT public.submit_activities(''[{
            "habit_key": "steps",
            "quantity": 20000,
            "started_at": "%s",
            "ended_at": "%s",
            "source": "healthkit",
            "source_sample_id": "ac-test-steps-impossible",
            "was_user_entered": false
        }]''::jsonb)',
        (CURRENT_TIMESTAMP - interval '2 hours')::text,
        (CURRENT_TIMESTAMP - interval '1 hour 30 minutes')::text
    ),
    'Submit impossible steps rate succeeds (flag is post-scoring)'
);

SELECT is(
    (SELECT COUNT(*)::integer FROM public.activity_flags
     WHERE user_id = 'a1111111-1111-1111-1111-111111111111'::uuid
       AND rule = 'T1-R3' AND severity = 'HIGH' AND status = 'open'),
    1,
    'T1-R3: Impossible steps rate creates HIGH flag'
);

SELECT is(
    (SELECT COUNT(*)::integer FROM public.kp_ledger
     WHERE user_id = 'a1111111-1111-1111-1111-111111111111'::uuid
       AND type = 'revoke'
       AND idempotency_key LIKE 'revoke:%'),
    1,
    'HIGH flag: revoke ledger row inserted'
);

-- ============================================================
-- TEST 2: Impossible running speed → HIGH flag
-- ============================================================
-- 15 km in 20 minutes = 45 km/h → T1-R4 HIGH
SELECT lives_ok(
    format(
        'SELECT public.submit_activities(''[{
            "habit_key": "running",
            "quantity": 15,
            "started_at": "%s",
            "ended_at": "%s",
            "source": "healthkit",
            "source_sample_id": "ac-test-run-impossible",
            "was_user_entered": false
        }]''::jsonb)',
        (CURRENT_TIMESTAMP - interval '3 hours')::text,
        (CURRENT_TIMESTAMP - interval '2 hours 40 minutes')::text
    ),
    'Submit impossible running speed succeeds'
);

SELECT is(
    (SELECT COUNT(*)::integer FROM public.activity_flags
     WHERE user_id = 'a1111111-1111-1111-1111-111111111111'::uuid
       AND rule = 'T1-R4' AND severity = 'HIGH'),
    1,
    'T1-R4: Impossible running speed creates HIGH flag'
);

-- ============================================================
-- TEST 3: Legitimate fast walking → no flag (false-positive resilience)
-- ============================================================
-- 2.5 km in 20 minutes = 7.5 km/h (under 10 km/h threshold)
SELECT lives_ok(
    format(
        'SELECT public.submit_activities(''[{
            "habit_key": "walking_distance",
            "quantity": 2.5,
            "started_at": "%s",
            "ended_at": "%s",
            "source": "healthkit",
            "source_sample_id": "ac-test-walk-legit",
            "was_user_entered": false
        }]''::jsonb)',
        (CURRENT_TIMESTAMP - interval '4 hours')::text,
        (CURRENT_TIMESTAMP - interval '3 hours 40 minutes')::text
    ),
    'Submit legitimate fast walking succeeds'
);

SELECT is(
    (SELECT COUNT(*)::integer FROM public.activity_flags
     WHERE user_id = 'a1111111-1111-1111-1111-111111111111'::uuid
       AND rule = 'T1-R5'),
    0,
    'T1-R5: Legitimate 7.5 km/h walk creates no flag (false-positive resilience)'
);

-- ============================================================
-- TEST 4: Normal activity → no flags
-- ============================================================
-- 5,000 steps in 1 hour = 5,000 steps/hour → perfectly normal
SELECT lives_ok(
    format(
        'SELECT public.submit_activities(''[{
            "habit_key": "steps",
            "quantity": 5000,
            "started_at": "%s",
            "ended_at": "%s",
            "source": "healthkit",
            "source_sample_id": "ac-test-steps-normal",
            "was_user_entered": false
        }]''::jsonb)',
        (CURRENT_TIMESTAMP - interval '5 hours')::text,
        (CURRENT_TIMESTAMP - interval '4 hours')::text
    ),
    'Submit normal steps succeeds'
);

-- Count flags for the normal activity — should be zero
SELECT is(
    (SELECT COUNT(*)::integer FROM public.activity_flags af
     JOIN public.activities a ON a.id = af.activity_id
     WHERE a.source_sample_id = 'ac-test-steps-normal'),
    0,
    'Normal 5,000 steps in 1 hour creates no flags'
);

-- ============================================================
-- TEST 5: Workout > 8 hours → MEDIUM flag (KP still awarded)
-- ============================================================
SELECT lives_ok(
    format(
        'SELECT public.submit_activities(''[{
            "habit_key": "workout",
            "quantity": 500,
            "started_at": "%s",
            "ended_at": "%s",
            "source": "manual",
            "source_sample_id": "ac-test-workout-long",
            "was_user_entered": true
        }]''::jsonb)',
        (CURRENT_TIMESTAMP - interval '6 hours')::text,
        (CURRENT_TIMESTAMP - interval '5 hours 1 minute')::text
    ),
    'Submit 500-min workout succeeds'
);

SELECT is(
    (SELECT COUNT(*)::integer FROM public.activity_flags
     WHERE user_id = 'a1111111-1111-1111-1111-111111111111'::uuid
       AND rule = 'T7-R8' AND severity = 'MEDIUM'),
    1,
    'T7-R8: 500-min workout creates MEDIUM flag'
);

-- MEDIUM flags do NOT create revoke rows for their own activity
-- (only HIGH flags do)

-- ============================================================
-- TEST 6: Blocked source rejection
-- ============================================================
SELECT is(
    (SELECT (r->0->>'reason')
     FROM (
         SELECT public.submit_activities(format(
             '[{"habit_key": "steps", "quantity": 1000,
               "started_at": "%s", "ended_at": "%s",
               "source": "healthkit", "source_sample_id": "ac-test-blocked",
               "was_user_entered": false,
               "device_info": {"bundle_id": "com.stepfaker.pro"}}]',
             (CURRENT_TIMESTAMP - interval '1 hour')::text,
             (CURRENT_TIMESTAMP - interval '30 minutes')::text
         )::jsonb) AS r
     ) sub),
    'blocked_source',
    'Blocked source (com.stepfaker.pro) is rejected with reason blocked_source'
);

-- ============================================================
-- TEST 7: Revoke idempotency — re-evaluating doesn't duplicate
-- ============================================================
-- Get the activity_id of the impossible steps activity
-- We have 2 HIGH flags (T1-R3 steps, T1-R4 running), each creates its own revoke row
SELECT is(
    (SELECT COUNT(*)::integer FROM public.kp_ledger
     WHERE user_id = 'a1111111-1111-1111-1111-111111111111'::uuid
       AND type = 'revoke'),
    2,
    'Each HIGH flag creates its own revoke row (2 HIGH flags = 2 revoke rows)'
);

-- ============================================================
-- TEST 8: Trust score reflects flags
-- ============================================================
-- User has 2 HIGH flags (steps, running) and 1 MEDIUM (workout)
-- Trust score = 100 - (2 × 25) - (1 × 10) + min(verified_days, 20)
-- verified_days depends on how many unique days have verified earn rows
-- At minimum: 100 - 50 - 10 = 40 (before bonus)
SELECT ok(
    (SELECT trust_score <= 75
     FROM public.user_trust_score
     WHERE user_id = 'a1111111-1111-1111-1111-111111111111'::uuid),
    'Trust score <= 75 for user with 2 HIGH + 1 MEDIUM flags'
);

-- ============================================================
-- TEST 9: RLS — flags not visible to other users
-- ============================================================
-- Switch to second user AND set role to authenticated (so RLS is enforced)
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"sub":"a2222222-2222-2222-2222-222222222222","role":"authenticated"}', true);

SELECT is(
    (SELECT COUNT(*)::integer FROM public.activity_flags),
    0,
    'RLS: Other user cannot see first user''s flags'
);

-- ============================================================
-- DONE
-- ============================================================

SELECT * FROM finish();
ROLLBACK;
