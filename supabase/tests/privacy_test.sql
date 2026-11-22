-- pgTAP tests for B16: Privacy — Export & Deletion
-- Tests export_my_data, request_account_deletion, cancel_account_deletion, RLS

BEGIN;
SELECT plan(12);

-- ============================================================
-- Setup: create test users
-- ============================================================

-- User A (the one who exports/deletes)
INSERT INTO auth.users (id, email, raw_app_meta_data, raw_user_meta_data, aud, role, created_at, updated_at)
VALUES (
    'a1111111-1111-1111-1111-111111111111',
    'privacy_a@test.com',
    '{"provider":"apple","providers":["apple"]}',
    '{"full_name":"Privacy User A"}',
    'authenticated', 'authenticated', now(), now()
);

-- User B (should not appear in A's export)
INSERT INTO auth.users (id, email, raw_app_meta_data, raw_user_meta_data, aud, role, created_at, updated_at)
VALUES (
    'b2222222-2222-2222-2222-222222222222',
    'privacy_b@test.com',
    '{"provider":"apple","providers":["apple"]}',
    '{"full_name":"Privacy User B"}',
    'authenticated', 'authenticated', now(), now()
);

-- Wait for profile triggers
SELECT pg_sleep(0.1);

-- Set usernames
SELECT set_config('request.jwt.claims', '{"sub":"a1111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;
SELECT public.set_username('privacyusera');

SELECT set_config('request.jwt.claims', '{"sub":"b2222222-2222-2222-2222-222222222222","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;
SELECT public.set_username('privacyuserb');

-- Add a habit for user A
SELECT set_config('request.jwt.claims', '{"sub":"a1111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;
SELECT public.set_user_habits(ARRAY(SELECT id FROM public.habits LIMIT 2));

-- Register a device token for user A
SELECT public.register_device_token('fake-apns-token-aaa', 'sandbox');

-- Make A and B friends
SELECT public.send_friend_request('b2222222-2222-2222-2222-222222222222');

SELECT set_config('request.jwt.claims', '{"sub":"b2222222-2222-2222-2222-222222222222","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;
SELECT public.accept_friend_request('a1111111-1111-1111-1111-111111111111');

RESET ROLE;

-- ============================================================
-- Test 1: export_my_data returns valid structure for user A
-- ============================================================
SELECT set_config('request.jwt.claims', '{"sub":"a1111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;

SELECT ok(
    (SELECT public.export_my_data()) ? 'profile'
    AND (SELECT public.export_my_data()) ? 'habits'
    AND (SELECT public.export_my_data()) ? 'activities'
    AND (SELECT public.export_my_data()) ? 'kp_ledger'
    AND (SELECT public.export_my_data()) ? 'achievements'
    AND (SELECT public.export_my_data()) ? 'friends',
    'Test 1: export_my_data returns expected top-level keys'
);

-- ============================================================
-- Test 2: export contains user A's profile data
-- ============================================================
SELECT ok(
    (SELECT (public.export_my_data()->'profile'->>'username') = 'privacyusera'),
    'Test 2: export contains correct username'
);

-- ============================================================
-- Test 3: export contains user A's habits (should have 2)
-- ============================================================
SELECT ok(
    (SELECT jsonb_array_length(public.export_my_data()->'habits') = 2),
    'Test 3: export contains 2 habits'
);

-- ============================================================
-- Test 4: export friends list contains B's username
-- ============================================================
SELECT ok(
    (SELECT public.export_my_data()->'friends'->0->>'friend_username' = 'privacyuserb'),
    'Test 4: export friends contains privacyuserb'
);

-- ============================================================
-- Test 5: export does NOT contain user B's data
-- ============================================================
SELECT ok(
    (SELECT (public.export_my_data()->>'user_id') = 'a1111111-1111-1111-1111-111111111111'),
    'Test 5: export is scoped to requesting user only'
);

-- ============================================================
-- Test 6: request_account_deletion creates pending request
-- ============================================================
SELECT ok(
    (SELECT (public.request_account_deletion()->>'status') = 'deletion_scheduled'),
    'Test 6: request_account_deletion returns deletion_scheduled'
);

RESET ROLE;

-- ============================================================
-- Test 7: deletion request exists in table
-- ============================================================
SELECT ok(
    (SELECT EXISTS(
        SELECT 1 FROM public.account_deletion_requests
        WHERE user_id = 'a1111111-1111-1111-1111-111111111111'
          AND status = 'pending'
    )),
    'Test 7: pending deletion request exists in table'
);

-- ============================================================
-- Test 8: device tokens removed after deletion request
-- ============================================================
SELECT ok(
    (SELECT NOT EXISTS(
        SELECT 1 FROM public.device_tokens
        WHERE user_id = 'a1111111-1111-1111-1111-111111111111'
    )),
    'Test 8: device tokens removed after deletion request'
);

-- ============================================================
-- Test 9: profile display_name anonymized
-- ============================================================
SELECT ok(
    (SELECT display_name = 'Deleted User'
     FROM public.profiles
     WHERE id = 'a1111111-1111-1111-1111-111111111111'),
    'Test 9: display_name anonymized to Deleted User'
);

-- ============================================================
-- Test 10: duplicate deletion request returns already_requested
-- ============================================================
SELECT set_config('request.jwt.claims', '{"sub":"a1111111-1111-1111-1111-111111111111","role":"authenticated"}', true);
SET LOCAL ROLE authenticated;

SELECT ok(
    (SELECT (public.request_account_deletion()->>'status') = 'already_requested'),
    'Test 10: duplicate deletion request returns already_requested'
);

-- ============================================================
-- Test 11: cancel_account_deletion cancels the request
-- ============================================================
SELECT ok(
    (SELECT (public.cancel_account_deletion()->>'status') = 'deletion_cancelled'),
    'Test 11: cancel_account_deletion returns deletion_cancelled'
);

RESET ROLE;

SELECT ok(
    (SELECT status = 'cancelled'
     FROM public.account_deletion_requests
     WHERE user_id = 'a1111111-1111-1111-1111-111111111111'
     ORDER BY requested_at DESC LIMIT 1),
    'Test 12: deletion request status is cancelled in table'
);

-- ============================================================
-- Done
-- ============================================================
SELECT * FROM finish();
ROLLBACK;
