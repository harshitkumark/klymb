-- Test: challenges_test.sql
-- B12: Challenges tests
-- Tests for: join_challenge, leave_challenge, update_challenge_progress, get_challenge_standings, finalize_challenge

BEGIN;

SELECT plan(18);

-- ============================================================
-- SETUP TEST USERS
-- ============================================================

-- User 1: Maya
INSERT INTO auth.users (id, email, role, aud, instance_id)
VALUES (
    'd1000001-0000-0000-0000-000000000001'::uuid,
    'maya@klymb.app',
    'authenticated',
    'authenticated',
    '00000000-0000-0000-0000-000000000000'::uuid
);

-- User 2: Liam
INSERT INTO auth.users (id, email, role, aud, instance_id)
VALUES (
    'd1000002-0000-0000-0000-000000000002'::uuid,
    'liam@klymb.app',
    'authenticated',
    'authenticated',
    '00000000-0000-0000-0000-000000000000'::uuid
);

-- User 3: Noah
INSERT INTO auth.users (id, email, role, aud, instance_id)
VALUES (
    'd1000003-0000-0000-0000-000000000003'::uuid,
    'noah@klymb.app',
    'authenticated',
    'authenticated',
    '00000000-0000-0000-0000-000000000000'::uuid
);

UPDATE public.profiles SET username = 'maya_fast', display_name = 'Maya Fast', city_id = (SELECT id FROM public.cities WHERE name = 'Bengaluru' LIMIT 1)
WHERE id = 'd1000001-0000-0000-0000-000000000001'::uuid;

UPDATE public.profiles SET username = 'liam_steady', display_name = 'Liam Steady', city_id = (SELECT id FROM public.cities WHERE name = 'Bengaluru' LIMIT 1)
WHERE id = 'd1000002-0000-0000-0000-000000000002'::uuid;

UPDATE public.profiles SET username = 'noah_late', display_name = 'Noah Late', city_id = (SELECT id FROM public.cities WHERE name = 'Bengaluru' LIMIT 1)
WHERE id = 'd1000003-0000-0000-0000-000000000003'::uuid;

-- Activate running habit for users
INSERT INTO public.user_habits (user_id, habit_id)
SELECT 'd1000001-0000-0000-0000-000000000001'::uuid, id FROM public.habits WHERE key = 'running'
ON CONFLICT DO NOTHING;

INSERT INTO public.user_habits (user_id, habit_id)
SELECT 'd1000002-0000-0000-0000-000000000002'::uuid, id FROM public.habits WHERE key = 'running'
ON CONFLICT DO NOTHING;

INSERT INTO public.user_habits (user_id, habit_id)
SELECT 'd1000003-0000-0000-0000-000000000003'::uuid, id FROM public.habits WHERE key = 'running'
ON CONFLICT DO NOTHING;

-- Create an active daily challenge: "5 km Run" (target = 5.0 km)
INSERT INTO public.challenges (id, type, title, description, habit_key, target, reward_kp, start_at, end_at, status)
OVERRIDING SYSTEM VALUE
VALUES (
    101,
    'daily',
    'Daily 5K Dash',
    'Run 5 km today to earn 50 KP plus podium bonuses!',
    'running',
    5.0,
    50,
    now() - interval '2 hours',
    now() + interval '4 hours',
    'active'
);

-- ============================================================
-- TEST 1: Maya joins challenge
-- ============================================================
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"sub":"d1000001-0000-0000-0000-000000000001","role":"authenticated"}', true);

SELECT is(
    (SELECT public.join_challenge(101)->>'status'),
    'joined',
    'Maya joins challenge 101'
);

SELECT is(
    (SELECT current_value FROM public.challenge_progress WHERE challenge_id = 101 AND user_id = 'd1000001-0000-0000-0000-000000000001'::uuid),
    0.0::double precision,
    'Maya progress initialized to 0'
);

-- ============================================================
-- TEST 2: Liam joins then leaves challenge
-- ============================================================
SELECT set_config('request.jwt.claims', '{"sub":"d1000002-0000-0000-0000-000000000002","role":"authenticated"}', true);

SELECT is(
    (SELECT public.join_challenge(101)->>'status'),
    'joined',
    'Liam joins challenge 101'
);

SELECT is(
    (SELECT public.leave_challenge(101)->>'status'),
    'left',
    'Liam leaves challenge 101'
);

SELECT is(
    (SELECT COUNT(*)::integer FROM public.challenge_participants WHERE challenge_id = 101 AND user_id = 'd1000002-0000-0000-0000-000000000002'::uuid),
    0,
    'Liam is removed from participants'
);

-- Liam re-joins
SELECT public.join_challenge(101);

-- Noah joins too
SELECT set_config('request.jwt.claims', '{"sub":"d1000003-0000-0000-0000-000000000003","role":"authenticated"}', true);
SELECT public.join_challenge(101);

-- ============================================================
-- TEST 3: Activity submission updates challenge progress
-- ============================================================
-- Maya submits 5 km run at (now - 1 hour) -> Completes target!
SELECT set_config('request.jwt.claims', '{"sub":"d1000001-0000-0000-0000-000000000001","role":"authenticated"}', true);

SELECT lives_ok(
    format(
        'SELECT public.submit_activities(''[{
            "habit_key": "running",
            "quantity": 5.0,
            "started_at": "%s",
            "ended_at": "%s",
            "source": "healthkit",
            "source_sample_id": "ch-test-maya-run",
            "was_user_entered": false
        }]''::jsonb)',
        (now() - interval '1 hour')::text,
        (now() - interval '30 minutes')::text
    ),
    'Maya submits 5 km run'
);

SELECT is(
    (SELECT (completed_at IS NOT NULL) FROM public.challenge_progress WHERE challenge_id = 101 AND user_id = 'd1000001-0000-0000-0000-000000000001'::uuid),
    true,
    'Maya completed the challenge target'
);

-- Liam submits 5 km run at (now - 20 minutes) -> Completes target LATER than Maya!
SELECT set_config('request.jwt.claims', '{"sub":"d1000002-0000-0000-0000-000000000002","role":"authenticated"}', true);

SELECT lives_ok(
    format(
        'SELECT public.submit_activities(''[{
            "habit_key": "running",
            "quantity": 5.0,
            "started_at": "%s",
            "ended_at": "%s",
            "source": "healthkit",
            "source_sample_id": "ch-test-liam-run",
            "was_user_entered": false
        }]''::jsonb)',
        (now() - interval '20 minutes')::text,
        (now() - interval '5 minutes')::text
    ),
    'Liam submits 5 km run'
);

-- Noah submits 3 km run (incomplete)
SELECT set_config('request.jwt.claims', '{"sub":"d1000003-0000-0000-0000-000000000003","role":"authenticated"}', true);

SELECT lives_ok(
    format(
        'SELECT public.submit_activities(''[{
            "habit_key": "running",
            "quantity": 3.0,
            "started_at": "%s",
            "ended_at": "%s",
            "source": "healthkit",
            "source_sample_id": "ch-test-noah-run",
            "was_user_entered": false
        }]''::jsonb)',
        (now() - interval '15 minutes')::text,
        (now() - interval '5 minutes')::text
    ),
    'Noah submits 3 km run (incomplete)'
);

-- ============================================================
-- TEST 4: Challenge standings: tie-break by earliest completion
-- ============================================================
-- Maya finished earlier than Liam -> Maya is rank 1, Liam is rank 2, Noah is rank 3
SELECT is(
    (SELECT username FROM public.get_challenge_standings(101, 1, 0)),
    'maya_fast',
    'Maya is rank 1 on standings (finished earlier)'
);

SELECT is(
    (SELECT username FROM public.get_challenge_standings(101, 1, 1)),
    'liam_steady',
    'Liam is rank 2 on standings'
);

-- ============================================================
-- TEST 5: Finalize challenge & reward distribution
-- ============================================================
-- Switch to postgres role to run internal finalize_challenge
SET LOCAL ROLE postgres;

SELECT lives_ok(
    $$SELECT public.finalize_challenge(101)$$,
    'finalize_challenge executes successfully'
);

-- Check challenge status is now 'finalized'
SELECT is(
    (SELECT status FROM public.challenges WHERE id = 101),
    'finalized',
    'Challenge status is finalized'
);

-- Maya rewards:
-- Daily: Completion (50) + Top 3 (100) + 1st place (50) = 200 KP total
SELECT is(
    (SELECT SUM(amount)::integer FROM public.kp_ledger
     WHERE user_id = 'd1000001-0000-0000-0000-000000000001'::uuid
       AND type = 'challenge_reward'
       AND source_id = '101'),
    200,
    'Maya (1st place) earned 200 challenge KP (50 completion + 100 top 3 + 50 1st place)'
);

-- Liam rewards:
-- Daily: Completion (50) + Top 3 (100) = 150 KP total (no 1st place bonus)
SELECT is(
    (SELECT SUM(amount)::integer FROM public.kp_ledger
     WHERE user_id = 'd1000002-0000-0000-0000-000000000002'::uuid
       AND type = 'challenge_reward'
       AND source_id = '101'),
    150,
    'Liam (2nd place) earned 150 challenge KP (50 completion + 100 top 3)'
);

-- Noah rewards:
-- Noah did not complete target -> 0 challenge reward KP
SELECT is(
    (SELECT COALESCE(SUM(amount), 0)::integer FROM public.kp_ledger
     WHERE user_id = 'd1000003-0000-0000-0000-000000000003'::uuid
       AND type = 'challenge_reward'
       AND source_id = '101'),
    0,
    'Noah (incomplete) earned 0 challenge reward KP'
);

-- ============================================================
-- TEST 6: Double finalize idempotency
-- ============================================================
-- Calling finalize_challenge again should do nothing
SELECT lives_ok(
    $$SELECT public.finalize_challenge(101)$$,
    'Second finalize_challenge call succeeds idempotently'
);

SELECT is(
    (SELECT COUNT(*)::integer FROM public.kp_ledger
     WHERE type = 'challenge_reward' AND source_id = '101'),
    5,
    'Double finalize produces zero duplicate ledger rows (3 for Maya + 2 for Liam = 5 rows total)'
);

SELECT * FROM finish();
ROLLBACK;
