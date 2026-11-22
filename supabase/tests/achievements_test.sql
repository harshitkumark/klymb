-- Test: achievements_test.sql
-- B13: Achievements tests
-- Tests for: first_steps, week_warrior, step_legend, challenge_champion, get_my_achievements, idempotency

BEGIN;

SELECT plan(16);

-- ============================================================
-- SETUP TEST USER
-- ============================================================

INSERT INTO auth.users (id, email, role, aud, instance_id)
VALUES (
    'e1000001-0000-0000-0000-000000000001'::uuid,
    'zara@klymb.app',
    'authenticated',
    'authenticated',
    '00000000-0000-0000-0000-000000000000'::uuid
);

UPDATE public.profiles
SET username = 'zara_achieve', display_name = 'Zara Achieve', city_id = (SELECT id FROM public.cities WHERE name = 'Bengaluru' LIMIT 1)
WHERE id = 'e1000001-0000-0000-0000-000000000001'::uuid;

-- Activate habits
INSERT INTO public.user_habits (user_id, habit_id)
SELECT 'e1000001-0000-0000-0000-000000000001'::uuid, id FROM public.habits
ON CONFLICT DO NOTHING;

-- Set auth context to Zara
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"sub":"e1000001-0000-0000-0000-000000000001","role":"authenticated"}', true);

-- ============================================================
-- TEST 1: Initial state: No achievements unlocked
-- ============================================================

SELECT is(
    (SELECT COUNT(*)::integer FROM public.get_my_achievements() WHERE unlocked = true),
    0,
    'Zara starts with 0 unlocked achievements'
);

SELECT ok(
    (SELECT COUNT(*)::integer FROM public.get_my_achievements()) >= 8,
    'Catalog returns at least 8 achievements'
);

-- ============================================================
-- TEST 2: First activity submission unlocks "First Steps"
-- ============================================================

SELECT lives_ok(
    format(
        'SELECT public.submit_activities(''[{
            "habit_key": "steps",
            "quantity": 1000,
            "started_at": "%s",
            "ended_at": "%s",
            "source": "healthkit",
            "source_sample_id": "ach-zara-steps-1",
            "was_user_entered": false
        }]''::jsonb)',
        (now() - interval '2 hours')::text,
        (now() - interval '1 hour 45 minutes')::text
    ),
    'Zara submits first activity'
);

SELECT is(
    (SELECT unlocked FROM public.get_my_achievements() WHERE key = 'first_steps'),
    true,
    'Submitting first activity unlocks "First Steps"'
);

-- Verify achievement reward KP (50 KP) written to ledger
SELECT is(
    (SELECT amount FROM public.kp_ledger
     WHERE user_id = 'e1000001-0000-0000-0000-000000000001'::uuid
       AND type = 'achievement_reward'
       AND metadata->>'achievement_key' = 'first_steps'),
    50,
    '"First Steps" awards 50 achievement KP in kp_ledger'
);

-- Verify idempotency: Submitting second activity does NOT re-award "First Steps"
SELECT lives_ok(
    format(
        'SELECT public.submit_activities(''[{
            "habit_key": "steps",
            "quantity": 1000,
            "started_at": "%s",
            "ended_at": "%s",
            "source": "healthkit",
            "source_sample_id": "ach-zara-steps-2",
            "was_user_entered": false
        }]''::jsonb)',
        (now() - interval '1 hour 30 minutes')::text,
        (now() - interval '1 hour 15 minutes')::text
    ),
    'Zara submits second activity'
);

SELECT is(
    (SELECT COUNT(*)::integer FROM public.kp_ledger
     WHERE user_id = 'e1000001-0000-0000-0000-000000000001'::uuid
       AND type = 'achievement_reward'
       AND metadata->>'achievement_key' = 'first_steps'),
    1,
    'Second activity submission does not duplicate achievement reward'
);

-- ============================================================
-- TEST 3: Cumulative steps unlocks "Step Legend" (100k steps)
-- ============================================================

-- Submit 100,000 steps sample
SELECT lives_ok(
    format(
        'SELECT public.submit_activities(''[{
            "habit_key": "steps",
            "quantity": 100000,
            "started_at": "%s",
            "ended_at": "%s",
            "source": "healthkit",
            "source_sample_id": "ach-zara-steps-legend",
            "was_user_entered": false
        }]''::jsonb)',
        (now() - interval '1 hour')::text,
        (now() - interval '30 minutes')::text
    ),
    'Zara submits 100,000 steps'
);

SELECT is(
    (SELECT unlocked FROM public.get_my_achievements() WHERE key = 'step_legend'),
    true,
    '100,000 cumulative steps unlocks "Step Legend"'
);

SELECT is(
    (SELECT amount FROM public.kp_ledger
     WHERE user_id = 'e1000001-0000-0000-0000-000000000001'::uuid
       AND type = 'achievement_reward'
       AND metadata->>'achievement_key' = 'step_legend'),
    200,
    '"Step Legend" awards 200 achievement KP'
);

-- ============================================================
-- TEST 4: Streak update unlocks "Week Warrior" (7-day streak)
-- ============================================================
-- Switch to postgres role to simulate a 7-day streak
SET LOCAL ROLE postgres;

UPDATE public.user_streaks
SET current_streak = 7, longest_streak = 7
WHERE user_id = 'e1000001-0000-0000-0000-000000000001'::uuid;

-- Trigger streak evaluation
SELECT public.evaluate_achievements('e1000001-0000-0000-0000-000000000001'::uuid, 'streak_updated', '{"current_streak": 7}'::jsonb);

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"sub":"e1000001-0000-0000-0000-000000000001","role":"authenticated"}', true);

SELECT is(
    (SELECT unlocked FROM public.get_my_achievements() WHERE key = 'week_warrior'),
    true,
    '7-day streak unlocks "Week Warrior"'
);

SELECT is(
    (SELECT amount FROM public.kp_ledger
     WHERE user_id = 'e1000001-0000-0000-0000-000000000001'::uuid
       AND type = 'achievement_reward'
       AND metadata->>'achievement_key' = 'week_warrior'),
    100,
    '"Week Warrior" awards 100 achievement KP'
);

-- ============================================================
-- TEST 5: Challenge win unlocks "Challenge Champion"
-- ============================================================
SET LOCAL ROLE postgres;

-- Create challenge 201 and finalize with Zara as rank 1
INSERT INTO public.challenges (id, type, title, habit_key, target, reward_kp, start_at, end_at, status)
OVERRIDING SYSTEM VALUE
VALUES (201, 'daily', 'Sprint Test', 'running', 1.0, 50, now() - interval '2 hours', now() - interval '1 hour', 'active');

INSERT INTO public.challenge_participants (challenge_id, user_id)
VALUES (201, 'e1000001-0000-0000-0000-000000000001'::uuid);

INSERT INTO public.challenge_progress (challenge_id, user_id, current_value, completed_at)
VALUES (201, 'e1000001-0000-0000-0000-000000000001'::uuid, 1.0, now() - interval '90 minutes');

SELECT public.finalize_challenge(201);

SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"sub":"e1000001-0000-0000-0000-000000000001","role":"authenticated"}', true);

SELECT is(
    (SELECT unlocked FROM public.get_my_achievements() WHERE key = 'challenge_champion'),
    true,
    'Winning challenge unlocks "Challenge Champion"'
);

SELECT is(
    (SELECT amount FROM public.kp_ledger
     WHERE user_id = 'e1000001-0000-0000-0000-000000000001'::uuid
       AND type = 'achievement_reward'
       AND metadata->>'achievement_key' = 'challenge_champion'),
    150,
    '"Challenge Champion" awards 150 achievement KP'
);

-- ============================================================
-- TEST 6: Security — Direct client manipulation rejected
-- ============================================================

SELECT throws_ok(
    $$INSERT INTO public.achievements (key, display_name, description, condition_type) VALUES ('hack', 'Hack', 'Hack', 'custom')$$,
    '42501',
    NULL,
    'Client cannot insert into achievements'
);

SELECT throws_ok(
    format($$INSERT INTO public.user_achievements (user_id, achievement_id) VALUES ('%s', 1)$$, 'e1000001-0000-0000-0000-000000000001'),
    '42501',
    NULL,
    'Client cannot manually insert into user_achievements'
);

SELECT * FROM finish();
ROLLBACK;
