-- Test: notifications_test.sql
-- B14: Notifications backend tests
-- Tests for: register_device_token, update_notification_preferences, enqueue_notification, quiet hours delay, preference suppression, RLS

BEGIN;

SELECT plan(16);

-- ============================================================
-- SETUP TEST USERS
-- ============================================================

INSERT INTO auth.users (id, email, role, aud, instance_id)
VALUES (
    'f1000001-0000-0000-0000-000000000001'::uuid,
    'notif_user1@klymb.app',
    'authenticated',
    'authenticated',
    '00000000-0000-0000-0000-000000000000'::uuid
);

INSERT INTO auth.users (id, email, role, aud, instance_id)
VALUES (
    'f1000002-0000-0000-0000-000000000002'::uuid,
    'notif_user2@klymb.app',
    'authenticated',
    'authenticated',
    '00000000-0000-0000-0000-000000000000'::uuid
);

UPDATE public.profiles SET username = 'notif_sam', display_name = 'Sam Notif', city_id = (SELECT id FROM public.cities WHERE name = 'Bengaluru' LIMIT 1)
WHERE id = 'f1000001-0000-0000-0000-000000000001'::uuid;

UPDATE public.profiles SET username = 'notif_alex', display_name = 'Alex Notif', city_id = (SELECT id FROM public.cities WHERE name = 'Bengaluru' LIMIT 1)
WHERE id = 'f1000002-0000-0000-0000-000000000002'::uuid;

-- ============================================================
-- TEST 1: Register device token
-- ============================================================
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"sub":"f1000001-0000-0000-0000-000000000001","role":"authenticated"}', true);

SELECT is(
    (SELECT public.register_device_token('apns-dummy-token-12345', 'sandbox')->>'status'),
    'registered',
    'Sam registers device token'
);

SELECT is(
    (SELECT apns_token FROM public.device_tokens WHERE user_id = 'f1000001-0000-0000-0000-000000000001'::uuid),
    'apns-dummy-token-12345',
    'Device token stored correctly'
);

-- Register duplicate token updates last_seen
SELECT is(
    (SELECT public.register_device_token('apns-dummy-token-12345', 'production')->>'status'),
    'registered',
    'Re-registering same token succeeds idempotently'
);

SELECT is(
    (SELECT environment FROM public.device_tokens WHERE user_id = 'f1000001-0000-0000-0000-000000000001'::uuid),
    'production',
    'Environment updated to production'
);

-- ============================================================
-- TEST 2: Notification preferences
-- ============================================================
SELECT is(
    (SELECT (public.get_my_notification_preferences()->>'overtaken')::boolean),
    true,
    'Default preferences have overtaken = true'
);

-- Sam disables overtaken notifications and configures quiet hours
SELECT is(
    (SELECT public.update_notification_preferences(
        p_overtaken => false,
        p_quiet_start => '22:00:00'::time,
        p_quiet_end => '08:00:00'::time
    )->>'status'),
    'updated',
    'Preferences updated successfully'
);

SELECT is(
    (SELECT (public.get_my_notification_preferences()->>'overtaken')::boolean),
    false,
    'Overtaken preference is now false'
);

-- ============================================================
-- TEST 3: Preference suppression
-- ============================================================
SET LOCAL ROLE postgres;

-- Attempting to enqueue an 'overtaken' notification for Sam should return false (suppressed)
SELECT is(
    public.enqueue_notification(
        'f1000001-0000-0000-0000-000000000001'::uuid,
        'overtaken',
        'Overtaken!',
        'Someone overtook you on the leaderboard'
    ),
    false,
    'Overtaken notification is suppressed when preference is toggled off'
);

SELECT is(
    (SELECT COUNT(*)::integer FROM public.notification_outbox WHERE user_id = 'f1000001-0000-0000-0000-000000000001'::uuid AND type = 'overtaken'),
    0,
    'Outbox contains 0 rows for suppressed notification'
);

-- ============================================================
-- TEST 4: Enqueue allowed notification (friend_request is enabled)
-- ============================================================
SELECT is(
    public.enqueue_notification(
        'f1000001-0000-0000-0000-000000000001'::uuid,
        'friend_request',
        'Friend Request',
        'Alex sent you a friend request'
    ),
    true,
    'Friend request notification enqueued successfully'
);

SELECT is(
    (SELECT COUNT(*)::integer FROM public.notification_outbox WHERE user_id = 'f1000001-0000-0000-0000-000000000001'::uuid AND type = 'friend_request'),
    1,
    'Outbox contains 1 row for friend_request notification'
);

-- ============================================================
-- TEST 5: Quiet hours delay
-- ============================================================
-- Schedule a notification at 23:30 (during quiet hours 22:00 - 08:00)
SELECT lives_ok(
    format(
        'SELECT public.enqueue_notification(
            ''%s''::uuid,
            ''achievement'',
            ''Night Achievement'',
            ''Great job'',
            ''{}''::jsonb,
            ''%s''::timestamptz
        )',
        'f1000001-0000-0000-0000-000000000001',
        ((CURRENT_DATE::text || ' 23:30:00+05:30')::timestamptz)::text
    ),
    'Enqueue during quiet hours succeeds'
);

-- Check scheduled_at was delayed to 08:00 next day
SELECT is(
    (SELECT ((scheduled_at AT TIME ZONE 'Asia/Kolkata')::time without time zone)
     FROM public.notification_outbox
     WHERE user_id = 'f1000001-0000-0000-0000-000000000001'::uuid AND type = 'achievement'),
    '08:00:00'::time,
    'Notification scheduled during quiet hours is rescheduled to 08:00:00'
);

-- ============================================================
-- TEST 6: Trigger wiring — send_friend_request enqueues outbox
-- ============================================================
-- Alex sends friend request to Sam
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"sub":"f1000002-0000-0000-0000-000000000002","role":"authenticated"}', true);

SELECT public.send_friend_request('f1000001-0000-0000-0000-000000000001'::uuid);

-- Check outbox for Sam has a notification for Alex's request
SET LOCAL ROLE postgres;
SELECT is(
    (SELECT COUNT(*)::integer FROM public.notification_outbox
     WHERE user_id = 'f1000001-0000-0000-0000-000000000001'::uuid
       AND payload->>'username' = 'notif_alex'),
    1,
    'send_friend_request automatically enqueues notification in outbox'
);

-- ============================================================
-- TEST 7: RLS — Client cannot access notification_outbox directly
-- ============================================================
SET LOCAL ROLE authenticated;
SELECT set_config('request.jwt.claims', '{"sub":"f1000001-0000-0000-0000-000000000001","role":"authenticated"}', true);

SELECT throws_ok(
    $$SELECT * FROM public.notification_outbox$$,
    '42501',
    NULL,
    'Authenticated client has no permission on notification_outbox'
);

-- Other user cannot see Sam's tokens
SELECT set_config('request.jwt.claims', '{"sub":"f1000002-0000-0000-0000-000000000002","role":"authenticated"}', true);

SELECT is(
    (SELECT COUNT(*)::integer FROM public.device_tokens WHERE user_id = 'f1000001-0000-0000-0000-000000000001'::uuid),
    0,
    'RLS: Alex cannot see Sam''s device tokens'
);

SELECT * FROM finish();
ROLLBACK;
