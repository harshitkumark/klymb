-- Migration: 20260114000000_privacy.sql
-- B16: Privacy — Export & Deletion
-- Implements docs/PRD.md §F14 & GDPR/App Store data portability & right to erasure.
--
-- 1. Table: account_deletion_requests
-- 2. RPCs:
--    - export_my_data()       → JSON blob of all user PII & activity
--    - request_account_deletion() → Soft-delete with 30-day grace period
--    - cancel_account_deletion()  → Cancel pending deletion
--    - execute_account_deletion(p_user_id) → Hard delete (service-role only, pg_cron)

-- ============================================================
-- 1. TABLE: account_deletion_requests
-- ============================================================

CREATE TABLE public.account_deletion_requests (
    id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id      uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    status       text NOT NULL DEFAULT 'pending',
    requested_at timestamptz NOT NULL DEFAULT now(),
    scheduled_for timestamptz NOT NULL DEFAULT (now() + interval '30 days'),
    cancelled_at timestamptz,
    completed_at timestamptz,

    CONSTRAINT valid_deletion_status CHECK (status IN ('pending', 'cancelled', 'completed'))
);

CREATE INDEX account_deletion_requests_user_idx
    ON public.account_deletion_requests (user_id);
CREATE INDEX account_deletion_requests_pending_idx
    ON public.account_deletion_requests (status, scheduled_for)
    WHERE status = 'pending';

ALTER TABLE public.account_deletion_requests ENABLE ROW LEVEL SECURITY;

-- Users can see their own deletion requests
CREATE POLICY "deletion_requests_select_own"
    ON public.account_deletion_requests FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

-- No direct insert/update/delete — only through RPCs
GRANT SELECT ON public.account_deletion_requests TO authenticated;

-- ============================================================
-- 2. RPC: export_my_data
-- ============================================================
-- Why SECURITY DEFINER: Needs to read across multiple tables that the user
-- may not have direct SELECT on (e.g. kp_ledger, notification_outbox).
-- Returns ONLY the requesting user's data — never other users'.

CREATE OR REPLACE FUNCTION public.export_my_data()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_uid uuid;
    v_profile jsonb;
    v_habits jsonb;
    v_activities jsonb;
    v_kp_ledger jsonb;
    v_achievements jsonb;
    v_streaks jsonb;
    v_friends jsonb;
    v_challenges jsonb;
    v_notification_prefs jsonb;
    v_deletion_requests jsonb;
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'ERR_UNAUTHORIZED' USING ERRCODE = '42501';
    END IF;

    -- Profile
    SELECT to_jsonb(p.*) - 'id' INTO v_profile
    FROM public.profiles p
    WHERE p.id = v_uid;

    -- User habits
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'habit_key', h.key,
            'habit_name', h.display_name,
            'selected_at', uh.created_at
        )
    ), '[]'::jsonb) INTO v_habits
    FROM public.user_habits uh
    JOIN public.habits h ON h.id = uh.habit_id
    WHERE uh.user_id = v_uid;

    -- Activities (last 365 days for export size management)
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'habit', h.key,
            'quantity', a.quantity,
            'unit', h.unit,
            'source', a.source,
            'started_at', a.started_at,
            'ended_at', a.ended_at,
            'submitted_at', a.created_at
        ) ORDER BY a.created_at DESC
    ), '[]'::jsonb) INTO v_activities
    FROM public.activities a
    JOIN public.habits h ON h.id = a.habit_id
    WHERE a.user_id = v_uid
      AND a.created_at >= now() - interval '365 days';

    -- KP Ledger (last 365 days)
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'amount', kl.amount,
            'type', kl.type,
            'source_type', kl.source_type,
            'day', kl.day_local,
            'created_at', kl.created_at
        ) ORDER BY kl.created_at DESC
    ), '[]'::jsonb) INTO v_kp_ledger
    FROM public.kp_ledger kl
    WHERE kl.user_id = v_uid
      AND kl.created_at >= now() - interval '365 days';

    -- Achievements
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'achievement', a.key,
            'name', a.display_name,
            'unlocked_at', ua.unlocked_at
        ) ORDER BY ua.unlocked_at
    ), '[]'::jsonb) INTO v_achievements
    FROM public.user_achievements ua
    JOIN public.achievements a ON a.id = ua.achievement_id
    WHERE ua.user_id = v_uid;

    -- Streaks
    SELECT to_jsonb(us.*) - 'id' - 'user_id' INTO v_streaks
    FROM public.user_streaks us
    WHERE us.user_id = v_uid;

    -- Friends (accepted only — don't export other users' IDs, just usernames)
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'friend_username', p.username,
            'since', f.updated_at
        )
    ), '[]'::jsonb) INTO v_friends
    FROM public.friendships f
    JOIN public.profiles p ON p.id = CASE
        WHEN f.requester_id = v_uid THEN f.addressee_id
        ELSE f.requester_id
    END
    WHERE f.status = 'accepted'
      AND (f.requester_id = v_uid OR f.addressee_id = v_uid);

    -- Challenge participations
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'challenge_title', c.title,
            'challenge_type', c.type,
            'joined_at', cp.joined_at,
            'progress', cprog.current_value,
            'finish_rank', cprog.rank
        ) ORDER BY cp.joined_at DESC
    ), '[]'::jsonb) INTO v_challenges
    FROM public.challenge_participants cp
    JOIN public.challenges c ON c.id = cp.challenge_id
    LEFT JOIN public.challenge_progress cprog ON cprog.challenge_id = cp.challenge_id AND cprog.user_id = v_uid
    WHERE cp.user_id = v_uid;

    -- Notification preferences
    SELECT to_jsonb(np.*) - 'user_id' INTO v_notification_prefs
    FROM public.notification_preferences np
    WHERE np.user_id = v_uid;

    -- Deletion requests
    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'status', dr.status,
            'requested_at', dr.requested_at,
            'scheduled_for', dr.scheduled_for
        )
    ), '[]'::jsonb) INTO v_deletion_requests
    FROM public.account_deletion_requests dr
    WHERE dr.user_id = v_uid;

    RETURN jsonb_build_object(
        'exported_at', now(),
        'user_id', v_uid,
        'profile', COALESCE(v_profile, '{}'::jsonb),
        'habits', v_habits,
        'activities', v_activities,
        'kp_ledger', v_kp_ledger,
        'achievements', v_achievements,
        'streaks', COALESCE(v_streaks, '{}'::jsonb),
        'friends', v_friends,
        'challenges', v_challenges,
        'notification_preferences', COALESCE(v_notification_prefs, '{}'::jsonb),
        'deletion_requests', v_deletion_requests
    );
END;
$$;

REVOKE ALL ON FUNCTION public.export_my_data() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.export_my_data() TO authenticated;

-- ============================================================
-- 3. RPC: request_account_deletion
-- ============================================================
-- Why SECURITY DEFINER: Needs to insert into account_deletion_requests,
-- update profile, and clean up device tokens — tables the user may not
-- have direct write access to.

CREATE OR REPLACE FUNCTION public.request_account_deletion()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_uid uuid;
    v_existing record;
    v_scheduled timestamptz;
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'ERR_UNAUTHORIZED' USING ERRCODE = '42501';
    END IF;

    -- Check for existing pending deletion
    SELECT * INTO v_existing
    FROM public.account_deletion_requests
    WHERE user_id = v_uid AND status = 'pending';

    IF FOUND THEN
        RETURN jsonb_build_object(
            'status', 'already_requested',
            'scheduled_for', v_existing.scheduled_for
        );
    END IF;

    v_scheduled := now() + interval '30 days';

    -- Create deletion request
    INSERT INTO public.account_deletion_requests (user_id, status, scheduled_for)
    VALUES (v_uid, 'pending', v_scheduled);

    -- Immediately: anonymize display name, mark profile
    UPDATE public.profiles
    SET display_name = 'Deleted User',
        avatar_preset = 'default',
        updated_at = now()
    WHERE id = v_uid;

    -- Remove device tokens (stop receiving pushes)
    DELETE FROM public.device_tokens WHERE user_id = v_uid;

    -- Clear pending notifications
    DELETE FROM public.notification_outbox
    WHERE user_id = v_uid AND status = 'pending';

    RETURN jsonb_build_object(
        'status', 'deletion_scheduled',
        'scheduled_for', v_scheduled,
        'message', 'Your account will be permanently deleted in 30 days. You can cancel before then.'
    );
END;
$$;

REVOKE ALL ON FUNCTION public.request_account_deletion() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.request_account_deletion() TO authenticated;

-- ============================================================
-- 4. RPC: cancel_account_deletion
-- ============================================================
-- Why SECURITY DEFINER: Needs to update account_deletion_requests.

CREATE OR REPLACE FUNCTION public.cancel_account_deletion()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_uid uuid;
    v_request record;
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'ERR_UNAUTHORIZED' USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_request
    FROM public.account_deletion_requests
    WHERE user_id = v_uid AND status = 'pending';

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'status', 'no_pending_request'
        );
    END IF;

    -- Cancel the deletion
    UPDATE public.account_deletion_requests
    SET status = 'cancelled',
        cancelled_at = now()
    WHERE id = v_request.id;

    RETURN jsonb_build_object(
        'status', 'deletion_cancelled',
        'message', 'Your account deletion has been cancelled.'
    );
END;
$$;

REVOKE ALL ON FUNCTION public.cancel_account_deletion() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cancel_account_deletion() TO authenticated;

-- ============================================================
-- 5. RPC: execute_account_deletion (service-role / pg_cron only)
-- ============================================================
-- Why SECURITY DEFINER: Hard-deletes user data across all tables.
-- This is NOT client-callable. Called by pg_cron after 30-day grace.
-- The auth.users row deletion cascades to profiles and all FK-linked tables.

CREATE OR REPLACE FUNCTION public.execute_account_deletion(p_user_id uuid)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_request record;
BEGIN
    -- This function is NOT client-callable (no GRANT to authenticated)
    -- Validate the deletion request exists and is due
    SELECT * INTO v_request
    FROM public.account_deletion_requests
    WHERE user_id = p_user_id
      AND status = 'pending'
      AND scheduled_for <= now();

    IF NOT FOUND THEN
        RETURN false;
    END IF;

    -- Mark as completed before cascade
    UPDATE public.account_deletion_requests
    SET status = 'completed',
        completed_at = now()
    WHERE id = v_request.id;

    -- Hard-delete: remove the auth.users row.
    -- All tables with ON DELETE CASCADE will be cleaned automatically:
    --   profiles, activities, kp_ledger, user_habits, user_streaks,
    --   user_achievements, friendships, challenge_participants,
    --   device_tokens, notification_preferences, notification_outbox,
    --   account_deletion_requests, activity_flags
    DELETE FROM auth.users WHERE id = p_user_id;

    RETURN true;
END;
$$;

-- Only service_role can call this (for pg_cron)
REVOKE ALL ON FUNCTION public.execute_account_deletion(uuid) FROM PUBLIC, anon, authenticated;

-- ============================================================
-- 6. COMMENT documentation
-- ============================================================

COMMENT ON FUNCTION public.export_my_data() IS
    'Returns a JSON export of all personal data for the authenticated user. '
    'SECURITY DEFINER needed to read across kp_ledger, outbox, and other tables '
    'that may not have direct user SELECT policies.';

COMMENT ON FUNCTION public.request_account_deletion() IS
    'Initiates a 30-day soft-delete: anonymizes display name, removes device tokens, '
    'clears pending notifications. Can be cancelled within the grace period. '
    'SECURITY DEFINER needed to write to deletion_requests and clean up tokens/outbox.';

COMMENT ON FUNCTION public.cancel_account_deletion() IS
    'Cancels a pending account deletion request. '
    'SECURITY DEFINER needed to update account_deletion_requests.';

COMMENT ON FUNCTION public.execute_account_deletion(uuid) IS
    'Hard-deletes a user account after the 30-day grace period. '
    'NOT client-callable — invoked by pg_cron only. '
    'SECURITY DEFINER needed to delete from auth.users which cascades to all tables.';
