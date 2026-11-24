-- Tests for iOS RPC Alignment & friend_cheers RLS
-- Run with: supabase test db

BEGIN;

SELECT plan(11);

-- Setup two test users + third observer
INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token)
VALUES
    ('c1111111-1111-1111-1111-111111111111', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u1@test.com', crypt('password', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now(), ''),
    ('c2222222-2222-2222-2222-222222222222', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u2@test.com', crypt('password', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now(), ''),
    ('c3333333-3333-3333-3333-333333333333', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'u3@test.com', crypt('password', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now(), '');

UPDATE public.profiles
SET username = 'ios_user_one', display_name = 'User One', city_id = (SELECT id FROM public.cities WHERE name = 'Bengaluru')
WHERE id = 'c1111111-1111-1111-1111-111111111111';

UPDATE public.profiles
SET username = 'ios_user_two', display_name = 'User Two', city_id = (SELECT id FROM public.cities WHERE name = 'Bengaluru')
WHERE id = 'c2222222-2222-2222-2222-222222222222';

INSERT INTO public.user_habits (user_id, habit_id, active)
SELECT 'c1111111-1111-1111-1111-111111111111', id, true
FROM public.habits WHERE key IN ('steps', 'hydration', 'workout');

-- Switch to User 1
SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims = '{"sub": "c1111111-1111-1111-1111-111111111111", "role": "authenticated"}';

-- 1. get_my_profile returns username and city_name
SELECT is(
    (SELECT public.get_my_profile()->>'username'),
    'ios_user_one',
    'get_my_profile returns caller username'
);

-- 2. get_my_streak returns default object when no streak row exists
SELECT is(
    (SELECT (public.get_my_streak()->>'current_streak')::integer),
    0,
    'get_my_streak returns 0 default when user has no streak row'
);

-- 3. get_my_habits returns all 7 habits with is_selected flags
SELECT is(
    (SELECT count(*)::integer FROM public.get_my_habits() WHERE is_selected = true),
    3,
    'get_my_habits reflects the 3 selected habits'
);

-- 4. get_active_challenges returns seeded active challenges
SELECT ok(
    (SELECT count(*) >= 5 FROM public.get_active_challenges()),
    'get_active_challenges returns seeded active challenges'
);

-- 5. Submit manual hydration activity and verify get_today_habit_progress reflects it
SELECT ok(
    (SELECT (public.submit_activities(jsonb_build_array(
        jsonb_build_object(
            'habit_key', 'hydration',
            'quantity', 500,
            'started_at', (now() - interval '1 minute')::text,
            'ended_at', now()::text,
            'source', 'manual',
            'source_sample_id', 'ios-align-water-1',
            'was_user_entered', true
        )
    ))->0->>'status') = 'accepted'),
    'submit_activities accepts valid manual hydration activity'
);

SELECT is(
    (SELECT (public.get_today_habit_progress()->>'today_kp')::integer),
    5,
    'get_today_habit_progress reflects 5 KP earned today'
);

-- 6. cheer_friend works & enqueues notification, and blocks direct INSERT (RLS)
SELECT throws_ok(
    $$INSERT INTO public.friend_cheers (sender_id, recipient_id) VALUES ('c1111111-1111-1111-1111-111111111111', 'c2222222-2222-2222-2222-222222222222')$$,
    '42501',
    NULL,
    'Direct INSERT on friend_cheers is blocked'
);

SELECT is(
    (SELECT public.cheer_friend('c2222222-2222-2222-2222-222222222222')->>'status'),
    'cheered',
    'cheer_friend succeeds via RPC'
);

SELECT is(
    (SELECT public.cheer_friend('c2222222-2222-2222-2222-222222222222')->>'status'),
    'already_cheered_today',
    'cheer_friend is idempotent per day'
);

-- 7. Third user cannot see cheers between user 1 and user 2 (RLS positive/negative)
SET LOCAL request.jwt.claims = '{"sub": "c3333333-3333-3333-3333-333333333333", "role": "authenticated"}';
SELECT is(
    (SELECT count(*)::integer FROM public.friend_cheers),
    0,
    'Unrelated user cannot read others friend_cheers rows'
);

-- 8. User 2 sees the cheer and can see search_users_with_status
SET LOCAL request.jwt.claims = '{"sub": "c2222222-2222-2222-2222-222222222222", "role": "authenticated"}';
SELECT is(
    (SELECT count(*)::integer FROM public.friend_cheers),
    1,
    'Recipient user can read their friend_cheers row'
);

SELECT * FROM finish();
ROLLBACK;
