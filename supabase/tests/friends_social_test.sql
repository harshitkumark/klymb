-- Test: friends_social_test.sql
-- B11: Friends and social tests
-- Tests for: send_friend_request, accept, decline, remove, block, unblock, get_friends, search_users, friends leaderboard scope

BEGIN;

SELECT plan(16);

-- ============================================================
-- SETUP TEST USERS
-- ============================================================

-- User A: Alice
INSERT INTO auth.users (id, email, role, aud, instance_id)
VALUES (
    'c1000001-0000-0000-0000-000000000001'::uuid,
    'alice@klymb.app',
    'authenticated',
    'authenticated',
    '00000000-0000-0000-0000-000000000000'::uuid
);

-- User B: Bob
INSERT INTO auth.users (id, email, role, aud, instance_id)
VALUES (
    'c1000002-0000-0000-0000-000000000002'::uuid,
    'bob@klymb.app',
    'authenticated',
    'authenticated',
    '00000000-0000-0000-0000-000000000000'::uuid
);

-- User C: Charlie
INSERT INTO auth.users (id, email, role, aud, instance_id)
VALUES (
    'c1000003-0000-0000-0000-000000000003'::uuid,
    'charlie@klymb.app',
    'authenticated',
    'authenticated',
    '00000000-0000-0000-0000-000000000000'::uuid
);

-- Update profiles
UPDATE public.profiles SET username = 'alice_runner', display_name = 'Alice Runner', city_id = (SELECT id FROM public.cities WHERE name = 'Bengaluru' LIMIT 1)
WHERE id = 'c1000001-0000-0000-0000-000000000001'::uuid;

UPDATE public.profiles SET username = 'bob_cyclist', display_name = 'Bob Cyclist', city_id = (SELECT id FROM public.cities WHERE name = 'Bengaluru' LIMIT 1)
WHERE id = 'c1000002-0000-0000-0000-000000000002'::uuid;

UPDATE public.profiles SET username = 'charlie_gym', display_name = 'Charlie Gym', city_id = (SELECT id FROM public.cities WHERE name = 'Bengaluru' LIMIT 1)
WHERE id = 'c1000003-0000-0000-0000-000000000003'::uuid;

-- Add ledger points today for leaderboard test:
-- Alice: 100 KP
INSERT INTO public.kp_ledger (user_id, amount, type, source_type, idempotency_key, day_local)
VALUES ('c1000001-0000-0000-0000-000000000001'::uuid, 100, 'earn', 'activity', 'friend-test-alice-today', CURRENT_DATE);

-- Bob: 250 KP
INSERT INTO public.kp_ledger (user_id, amount, type, source_type, idempotency_key, day_local)
VALUES ('c1000002-0000-0000-0000-000000000002'::uuid, 250, 'earn', 'activity', 'friend-test-bob-today', CURRENT_DATE);

-- Charlie: 400 KP (not a friend of Alice)
INSERT INTO public.kp_ledger (user_id, amount, type, source_type, idempotency_key, day_local)
VALUES ('c1000003-0000-0000-0000-000000000003'::uuid, 400, 'earn', 'activity', 'friend-test-charlie-today', CURRENT_DATE);

-- ============================================================
-- TEST 1: Alice sends friend request to Bob
-- ============================================================
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"sub":"c1000001-0000-0000-0000-000000000001","role":"authenticated"}', true);

SELECT is(
    (SELECT public.send_friend_request('c1000002-0000-0000-0000-000000000002'::uuid)->>'status'),
    'request_sent',
    'Alice successfully sends friend request to Bob'
);

SELECT is(
    (SELECT status FROM public.friendships WHERE requester_id = 'c1000001-0000-0000-0000-000000000001'::uuid AND addressee_id = 'c1000002-0000-0000-0000-000000000002'::uuid),
    'pending',
    'Friendship row is in pending status'
);

-- ============================================================
-- TEST 2: Cannot send duplicate request
-- ============================================================
SELECT is(
    (SELECT public.send_friend_request('c1000002-0000-0000-0000-000000000002'::uuid)->>'status'),
    'already_requested',
    'Duplicate friend request returns already_requested'
);

-- ============================================================
-- TEST 3: Bob accepts Alice's friend request
-- ============================================================
SELECT set_config('request.jwt.claims', '{"sub":"c1000002-0000-0000-0000-000000000002","role":"authenticated"}', true);

SELECT is(
    (SELECT public.accept_friend_request('c1000001-0000-0000-0000-000000000001'::uuid)->>'status'),
    'accepted',
    'Bob successfully accepts Alice''s friend request'
);

SELECT is(
    (SELECT status FROM public.friendships WHERE requester_id = 'c1000001-0000-0000-0000-000000000001'::uuid AND addressee_id = 'c1000002-0000-0000-0000-000000000002'::uuid),
    'accepted',
    'Friendship row is now accepted'
);

-- ============================================================
-- TEST 4: get_friends returns Bob for Alice
-- ============================================================
SELECT set_config('request.jwt.claims', '{"sub":"c1000001-0000-0000-0000-000000000001","role":"authenticated"}', true);

SELECT is(
    (SELECT COUNT(*)::integer FROM public.get_friends()),
    1,
    'Alice has 1 friend'
);

SELECT is(
    (SELECT username FROM public.get_friends() LIMIT 1),
    'bob_cyclist',
    'Alice''s friend is bob_cyclist'
);

-- ============================================================
-- TEST 5: Search users by prefix
-- ============================================================
SELECT is(
    (SELECT username FROM public.search_users('bob', 10) LIMIT 1),
    'bob_cyclist',
    'search_users finds bob_cyclist by prefix "bob"'
);

SELECT is(
    (SELECT username FROM public.search_users('charlie', 10) LIMIT 1),
    'charlie_gym',
    'search_users finds charlie_gym by prefix "charlie"'
);

-- ============================================================
-- TEST 6: Friends Leaderboard Scope
-- ============================================================
-- Refresh leaderboards as superuser
SET LOCAL ROLE postgres;
SELECT public.refresh_leaderboards('all');

-- Back to Alice
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"sub":"c1000001-0000-0000-0000-000000000001","role":"authenticated"}', true);

-- In friends leaderboard, only Alice (100 KP) and Bob (250 KP) appear. Charlie (400 KP) is NOT a friend and should NOT appear!
SELECT is(
    (SELECT COUNT(*)::integer FROM public.get_leaderboard('friends', 'daily', NULL, 10, 0)),
    2,
    'Friends leaderboard contains exactly 2 users (Alice + Bob)'
);

SELECT is(
    (SELECT username FROM public.get_leaderboard('friends', 'daily', NULL, 1, 0)),
    'bob_cyclist',
    'Bob (250 KP) is rank 1 on friends leaderboard'
);

SELECT is(
    (SELECT rank FROM public.get_leaderboard('friends', 'daily', NULL, 10, 0) WHERE username = 'alice_runner'),
    2::bigint,
    'Alice (100 KP) is rank 2 on friends leaderboard'
);

-- get_my_rank for Alice on friends scope
SELECT is(
    (SELECT (public.get_my_rank('friends', 'daily', NULL)->>'rank')::integer),
    2,
    'Alice get_my_rank returns rank 2 on friends scope'
);

SELECT is(
    (SELECT (public.get_my_rank('friends', 'daily', NULL)->>'kp_to_overtake')::integer),
    151,
    'Alice needs 151 KP to overtake Bob (250 - 100 + 1)'
);

-- ============================================================
-- TEST 7: Block user and search exclusion
-- ============================================================
-- Alice blocks Charlie
SELECT is(
    (SELECT public.block_user('c1000003-0000-0000-0000-000000000003'::uuid)->>'status'),
    'blocked',
    'Alice blocks Charlie'
);

-- Charlie should no longer appear in Alice''s search results
SELECT is(
    (SELECT COUNT(*)::integer FROM public.search_users('charlie', 10)),
    0,
    'Blocked user Charlie is excluded from Alice''s search'
);

SELECT * FROM finish();
ROLLBACK;
