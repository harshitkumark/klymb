-- Tests for B3: Auth and profile creation
-- Run with: supabase test db

BEGIN;

SELECT plan(19);

-- ============================================================
-- TEST 1: Trigger creates profile on auth.users insert
-- ============================================================

INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token)
VALUES
    ('c3333333-3333-3333-3333-333333333333', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'carol@test.com', crypt('password', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now(), '');

SELECT is(
    (SELECT count(*)::integer FROM public.profiles WHERE id = 'c3333333-3333-3333-3333-333333333333'),
    1,
    'Trigger on_auth_user_created creates a public.profiles row'
);

-- ============================================================
-- TEST 2: Auto-generated username matches pattern
-- ============================================================

SELECT matches(
    (SELECT username FROM public.profiles WHERE id = 'c3333333-3333-3333-3333-333333333333'),
    '^user_[a-z0-9]{6,16}$',
    'Auto-generated username follows user_xxxxxx pattern'
);

-- ============================================================
-- TEST 3: Direct client INSERT into profiles is denied
-- ============================================================

SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims = '{"sub": "c3333333-3333-3333-3333-333333333333", "role": "authenticated"}';

SELECT throws_ok(
    $$INSERT INTO public.profiles (id, username) VALUES ('d4444444-4444-4444-4444-444444444444', 'direct_insert_user')$$,
    '42501',
    NULL,
    'Authenticated user cannot directly INSERT into profiles'
);

-- ============================================================
-- TEST 4: set_username succeeds for authenticated user
-- ============================================================

SELECT lives_ok(
    $$SELECT public.set_username('carol_climbs')$$,
    'Authenticated user can set username'
);

SELECT is(
    (SELECT username FROM public.profiles WHERE id = 'c3333333-3333-3333-3333-333333333333'),
    'carol_climbs',
    'Profile username updated to carol_climbs'
);

-- ============================================================
-- TEST 5: set_username trims whitespace and enforces lowercase
-- ============================================================

SELECT lives_ok(
    $$SELECT public.set_username('  Carol_Pro  ')$$,
    'set_username trims whitespace and lowercases input'
);

SELECT is(
    (SELECT username FROM public.profiles WHERE id = 'c3333333-3333-3333-3333-333333333333'),
    'carol_pro',
    'Profile username stored trimmed and lowercased'
);

-- ============================================================
-- TEST 6: set_username rejects too short (< 3 chars)
-- ============================================================

SELECT throws_ok(
    $$SELECT public.set_username('ab')$$,
    '22023',
    NULL,
    'set_username rejects username shorter than 3 characters'
);

-- ============================================================
-- TEST 7: set_username rejects too long (> 20 chars)
-- ============================================================

SELECT throws_ok(
    $$SELECT public.set_username('this_username_is_way_too_long_for_klymb')$$,
    '22023',
    NULL,
    'set_username rejects username longer than 20 characters'
);

-- ============================================================
-- TEST 8: set_username rejects invalid characters
-- ============================================================

SELECT throws_ok(
    $$SELECT public.set_username('bad-user-name')$$,
    '22023',
    NULL,
    'set_username rejects hyphens and special characters'
);

-- ============================================================
-- TEST 9: set_username rejects consecutive underscores
-- ============================================================

SELECT throws_ok(
    $$SELECT public.set_username('carol__climbs')$$,
    '22023',
    NULL,
    'set_username rejects consecutive underscores'
);

-- ============================================================
-- TEST 10: set_username rejects leading / trailing underscores
-- ============================================================

SELECT throws_ok(
    $$SELECT public.set_username('_carol')$$,
    '22023',
    NULL,
    'set_username rejects leading underscore'
);

-- ============================================================
-- TEST 11: set_username rejects reserved username (admin, klymb, support)
-- ============================================================

SELECT throws_ok(
    $$SELECT public.set_username('admin')$$,
    '23514',
    NULL,
    'set_username rejects reserved username: admin'
);

SELECT throws_ok(
    $$SELECT public.set_username('klymb')$$,
    '23514',
    NULL,
    'set_username rejects reserved username: klymb'
);

SELECT throws_ok(
    $$SELECT public.set_username('support')$$,
    '23514',
    NULL,
    'set_username rejects reserved username: support'
);

-- ============================================================
-- TEST 12: set_username rejects already taken username
-- ============================================================

-- Create a second user
RESET ROLE;
INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token)
VALUES
    ('d4444444-4444-4444-4444-444444444444', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'dave@test.com', crypt('password', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now(), '');

SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims = '{"sub": "d4444444-4444-4444-4444-444444444444", "role": "authenticated"}';

-- Dave tries to take Carol's username 'carol_pro'
SELECT throws_ok(
    $$SELECT public.set_username('carol_pro')$$,
    '23505',
    NULL,
    'set_username rejects already taken username'
);

-- ============================================================
-- TEST 13: Calling set_username with current username is a no-op success
-- ============================================================

SELECT lives_ok(
    $$SELECT public.set_username('dave_runner')$$,
    'Dave can set his own username'
);

SELECT lives_ok(
    $$SELECT public.set_username('dave_runner')$$,
    'Calling set_username with already current username succeeds (no-op)'
);

-- ============================================================
-- TEST 14: Anon cannot execute set_username
-- ============================================================

RESET ROLE;
SET LOCAL ROLE anon;

SELECT throws_ok(
    $$SELECT public.set_username('anon_hacker')$$,
    '42501',
    NULL,
    'Anon role cannot execute set_username'
);

SELECT * FROM finish();

ROLLBACK;
