-- Tests for B4: Cities and city assignment
-- Run with: supabase test db

BEGIN;

SELECT plan(13);

-- ============================================================
-- TEST 1: Exactly 30 cities are seeded
-- ============================================================

SELECT is(
    (SELECT count(*)::integer FROM public.cities),
    30,
    'Exactly 30 cities are seeded'
);

-- ============================================================
-- TEST 2: Indian and global cities exist with timezones
-- ============================================================

SELECT is(
    (SELECT iana_timezone FROM public.cities WHERE name = 'Bengaluru'),
    'Asia/Kolkata',
    'Bengaluru exists with Asia/Kolkata timezone'
);

SELECT is(
    (SELECT iana_timezone FROM public.cities WHERE name = 'London'),
    'Europe/London',
    'London exists with Europe/London timezone'
);

-- ============================================================
-- TEST 3: Privacy check: No precise coordinates stored
-- ============================================================

SELECT is(
    (SELECT count(*)::integer FROM public.cities WHERE latitude IS NOT NULL OR longitude IS NOT NULL),
    0,
    'No precise coordinates stored (latitude and longitude are NULL for privacy)'
);

-- ============================================================
-- Helper: Create a test user via auth.users (trigger creates profile)
-- ============================================================

INSERT INTO auth.users (id, instance_id, aud, role, email, encrypted_password, email_confirmed_at, raw_app_meta_data, raw_user_meta_data, created_at, updated_at, confirmation_token)
VALUES
    ('e5555555-5555-5555-5555-555555555555', '00000000-0000-0000-0000-000000000000', 'authenticated', 'authenticated', 'elena@test.com', crypt('password', gen_salt('bf')), now(), '{"provider":"email","providers":["email"]}', '{}', now(), now(), '');

-- Get city IDs for testing
DO $$
DECLARE
    v_bengaluru_id bigint;
    v_mumbai_id    bigint;
    v_london_id    bigint;
BEGIN
    SELECT id INTO v_bengaluru_id FROM public.cities WHERE name = 'Bengaluru';
    SELECT id INTO v_mumbai_id FROM public.cities WHERE name = 'Mumbai';
    SELECT id INTO v_london_id FROM public.cities WHERE name = 'London';
END;
$$;

-- ============================================================
-- TEST 4: First-time city assignment succeeds without cooldown
-- ============================================================

SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims = '{"sub": "e5555555-5555-5555-5555-555555555555", "role": "authenticated"}';

SELECT lives_ok(
    format('SELECT public.set_city(%s)', (SELECT id FROM public.cities WHERE name = 'Bengaluru')),
    'Elena can set city for the first time during onboarding'
);

SELECT is(
    (SELECT city_id FROM public.profiles WHERE id = 'e5555555-5555-5555-5555-555555555555'),
    (SELECT id FROM public.cities WHERE name = 'Bengaluru'),
    'Profile city_id updated to Bengaluru'
);

-- ============================================================
-- TEST 5: Setting to same city is a no-op success
-- ============================================================

SELECT lives_ok(
    format('SELECT public.set_city(%s)', (SELECT id FROM public.cities WHERE name = 'Bengaluru')),
    'Setting to the same city succeeds without error (no-op)'
);

-- ============================================================
-- TEST 6: Changing city within 30 days is rejected
-- ============================================================

SELECT throws_ok(
    format('SELECT public.set_city(%s)', (SELECT id FROM public.cities WHERE name = 'Mumbai')),
    '22023',
    NULL,
    'Cannot change city within 30-day cooldown period'
);

-- ============================================================
-- TEST 7: Changing city after 30 days succeeds
-- ============================================================

-- Simulate 31 days elapsed
RESET ROLE;
UPDATE public.profiles
SET city_changed_at = now() - interval '31 days'
WHERE id = 'e5555555-5555-5555-5555-555555555555';

SET LOCAL ROLE authenticated;
SET LOCAL request.jwt.claims = '{"sub": "e5555555-5555-5555-5555-555555555555", "role": "authenticated"}';

SELECT lives_ok(
    format('SELECT public.set_city(%s)', (SELECT id FROM public.cities WHERE name = 'Mumbai')),
    'Elena can change city after 30 days have elapsed'
);

SELECT is(
    (SELECT city_id FROM public.profiles WHERE id = 'e5555555-5555-5555-5555-555555555555'),
    (SELECT id FROM public.cities WHERE name = 'Mumbai'),
    'Profile city_id updated to Mumbai'
);

-- ============================================================
-- TEST 8: Non-existent city ID is rejected
-- ============================================================

SELECT throws_ok(
    $$SELECT public.set_city(999999)$$,
    'P0002',
    NULL,
    'Non-existent city ID is rejected with ERR_CITY_NOT_FOUND'
);

-- ============================================================
-- TEST 9: NULL city ID is rejected
-- ============================================================

SELECT throws_ok(
    $$SELECT public.set_city(NULL)$$,
    '22023',
    NULL,
    'NULL city ID is rejected with ERR_INVALID_CITY'
);

-- ============================================================
-- TEST 10: Anon cannot execute set_city
-- ============================================================

RESET ROLE;
SET LOCAL ROLE anon;

SELECT throws_ok(
    $$SELECT public.set_city(1)$$,
    '42501',
    NULL,
    'Anon role cannot execute set_city'
);

SELECT * FROM finish();

ROLLBACK;
