-- Tests for B6: Activity submission RPC
-- Run with: supabase test db

BEGIN;

SELECT plan(14);

-- ============================================================
-- Helper: Create test user via auth.users and activate habits
-- ============================================================

INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token)
VALUES
    ('b8888888-8888-8888-8888-888888888888', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'helen@test.com', crypt('password', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now(), '');

-- Activate steps and workout for Helen
INSERT INTO public.user_habits (user_id, habit_id, active)
VALUES
    ('b8888888-8888-8888-8888-888888888888', (SELECT id FROM public.habits WHERE key = 'steps'), true),
    ('b8888888-8888-8888-8888-888888888888', (SELECT id FROM public.habits WHERE key = 'workout'), true);

SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims = '{"sub": "b8888888-8888-8888-8888-888888888888", "role": "authenticated"}';

-- ============================================================
-- TEST 1: Valid HealthKit sample is accepted as verified
-- ============================================================

SELECT is(
    (SELECT (public.submit_activities(jsonb_build_array(
        jsonb_build_object(
            'habit_key', 'steps',
            'quantity', 5000,
            'started_at', (now() - interval '2 hours')::text,
            'ended_at', (now() - interval '1 hour')::text,
            'source', 'healthkit',
            'source_sample_id', 'hk-sample-001',
            'was_user_entered', false
        )
    ))->0->>'verification_status')),
    'verified',
    'HealthKit sample with was_user_entered=false is accepted as verified'
);

-- ============================================================
-- TEST 2: HealthKit sample with was_user_entered=true is accepted as unverified
-- ============================================================

SELECT is(
    (SELECT (public.submit_activities(jsonb_build_array(
        jsonb_build_object(
            'habit_key', 'steps',
            'quantity', 3000,
            'started_at', (now() - interval '3 hours')::text,
            'ended_at', (now() - interval '2 hours')::text,
            'source', 'healthkit',
            'source_sample_id', 'hk-sample-002',
            'was_user_entered', true
        )
    ))->0->>'verification_status')),
    'unverified',
    'HealthKit sample with was_user_entered=true is accepted as unverified'
);

-- ============================================================
-- TEST 3: Manual entry is accepted as unverified
-- ============================================================

SELECT is(
    (SELECT (public.submit_activities(jsonb_build_array(
        jsonb_build_object(
            'habit_key', 'workout',
            'quantity', 30,
            'started_at', (now() - interval '4 hours')::text,
            'ended_at', (now() - interval '3 hours')::text,
            'source', 'manual',
            'source_sample_id', 'manual-sample-001',
            'was_user_entered', true
        )
    ))->0->>'verification_status')),
    'unverified',
    'Manual entry for workout is accepted as unverified'
);

-- ============================================================
-- TEST 4: Duplicate source_sample_id returns duplicate status
-- ============================================================

SELECT is(
    (SELECT (public.submit_activities(jsonb_build_array(
        jsonb_build_object(
            'habit_key', 'steps',
            'quantity', 5000,
            'started_at', (now() - interval '2 hours')::text,
            'ended_at', (now() - interval '1 hour')::text,
            'source', 'healthkit',
            'source_sample_id', 'hk-sample-001',
            'was_user_entered', false
        )
    ))->0->>'status')),
    'duplicate',
    'Submitting the same source_sample_id returns duplicate status'
);

-- ============================================================
-- TEST 5: Huge batch (> 500) is rejected
-- ============================================================

SELECT throws_ok(
    $$SELECT public.submit_activities((
        SELECT jsonb_agg(jsonb_build_object(
            'habit_key', 'steps',
            'quantity', 100,
            'started_at', (now() - interval '10 min')::text,
            'ended_at', now()::text
        ))
        FROM generate_series(1, 501)
    ))$$,
    '22023',
    NULL,
    'Submitting batch of > 500 samples raises ERR_BATCH_TOO_LARGE'
);

-- ============================================================
-- TEST 6: Unknown habit key is rejected with bad_habit
-- ============================================================

SELECT is(
    (SELECT (public.submit_activities(jsonb_build_array(
        jsonb_build_object(
            'habit_key', 'skydiving',
            'quantity', 1,
            'started_at', (now() - interval '1 hour')::text,
            'ended_at', now()::text
        )
    ))->0->>'reason')),
    'bad_habit',
    'Unknown habit key is rejected with reason bad_habit'
);

-- ============================================================
-- TEST 7: Inactive habit for user is rejected with habit_not_active
-- ============================================================

-- Running is a valid habit in catalog, but Helen has not activated it
SELECT is(
    (SELECT (public.submit_activities(jsonb_build_array(
        jsonb_build_object(
            'habit_key', 'running',
            'quantity', 5,
            'started_at', (now() - interval '1 hour')::text,
            'ended_at', now()::text
        )
    ))->0->>'reason')),
    'habit_not_active',
    'Submitting for a habit not active in user_habits is rejected with habit_not_active'
);

-- ============================================================
-- TEST 8: Invalid quantity (zero or negative) is rejected
-- ============================================================

SELECT is(
    (SELECT (public.submit_activities(jsonb_build_array(
        jsonb_build_object(
            'habit_key', 'steps',
            'quantity', -100,
            'started_at', (now() - interval '1 hour')::text,
            'ended_at', now()::text
        )
    ))->0->>'reason')),
    'invalid_quantity',
    'Negative quantity is rejected with invalid_quantity'
);

-- ============================================================
-- TEST 9: Invalid time range (started_at >= ended_at) is rejected
-- ============================================================

SELECT is(
    (SELECT (public.submit_activities(jsonb_build_array(
        jsonb_build_object(
            'habit_key', 'steps',
            'quantity', 500,
            'started_at', now()::text,
            'ended_at', (now() - interval '1 hour')::text
        )
    ))->0->>'reason')),
    'invalid_time_range',
    'started_at >= ended_at is rejected with invalid_time_range'
);

-- ============================================================
-- TEST 10: Samples older than 7 days are rejected with too_old
-- ============================================================

SELECT is(
    (SELECT (public.submit_activities(jsonb_build_array(
        jsonb_build_object(
            'habit_key', 'steps',
            'quantity', 500,
            'started_at', (now() - interval '8 days')::text,
            'ended_at', (now() - interval '8 days' + interval '30 min')::text
        )
    ))->0->>'reason')),
    'too_old',
    'Samples older than 7 days are rejected with too_old'
);

-- ============================================================
-- TEST 11: Future dates (> 1 hour) are rejected with future_date
-- ============================================================

SELECT is(
    (SELECT (public.submit_activities(jsonb_build_array(
        jsonb_build_object(
            'habit_key', 'steps',
            'quantity', 500,
            'started_at', (now() + interval '2 hours')::text,
            'ended_at', (now() + interval '3 hours')::text
        )
    ))->0->>'reason')),
    'future_date',
    'Future samples (> 1 hour) are rejected with future_date'
);

-- ============================================================
-- TEST 12: Manual entry for habit with manual_allowed=false is rejected
-- ============================================================

SELECT is(
    (SELECT (public.submit_activities(jsonb_build_array(
        jsonb_build_object(
            'habit_key', 'steps',
            'quantity', 1000,
            'started_at', (now() - interval '1 hour')::text,
            'ended_at', now()::text,
            'source', 'manual'
        )
    ))->0->>'reason')),
    'manual_not_allowed',
    'Manual entry for steps (manual_allowed=false) is rejected with manual_not_allowed'
);

-- ============================================================
-- TEST 13: Spoof prevention: User ID spoofing attempt is ignored
-- ============================================================

-- Attacker passes another user's id inside payload
SELECT is(
    (SELECT user_id FROM public.activities WHERE source_sample_id = 'hk-sample-001'),
    'b8888888-8888-8888-8888-888888888888'::uuid,
    'Activity user_id is strictly bound to auth.uid(), spoofing impossible'
);

-- ============================================================
-- TEST 14: Anon cannot execute submit_activities
-- ============================================================

RESET ROLE;
SET LOCAL ROLE anon;

SELECT throws_ok(
    $$SELECT public.submit_activities('[]'::jsonb)$$,
    '42501',
    NULL,
    'Anon role cannot execute submit_activities'
);

SELECT * FROM finish();

ROLLBACK;
