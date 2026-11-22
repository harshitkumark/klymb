-- Migration: 20260113000000_notifications.sql
-- B14: Notifications Backend
-- Implements docs/PRD.md §F15 & docs/ARCHITECTURE.md §2.2 & §7
--
-- 1. Tables:
--    - device_tokens
--    - notification_preferences
--    - notification_outbox
-- 2. Indexes and RLS policies
-- 3. Functions & RPCs:
--    - register_device_token(apns_token, environment)
--    - get_my_notification_preferences()
--    - update_notification_preferences(...)
--    - enqueue_notification(user_id, type, title, body, payload, scheduled_at)
-- 4. Wiring:
--    - friend request -> enqueue notification
--    - achievement unlock -> enqueue notification
--    - challenge finalization -> enqueue notification

-- ============================================================
-- 1. TABLES
-- ============================================================

-- Device Tokens (APNs push tokens)
CREATE TABLE public.device_tokens (
    id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    apns_token  text NOT NULL,
    environment text NOT NULL DEFAULT 'production',
    last_seen   timestamptz NOT NULL DEFAULT now(),
    created_at  timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT valid_env CHECK (environment IN ('sandbox', 'production')),
    UNIQUE (user_id, apns_token)
);

CREATE INDEX device_tokens_user_idx ON public.device_tokens (user_id);

ALTER TABLE public.device_tokens ENABLE ROW LEVEL SECURITY;

CREATE POLICY "device_tokens_manage_own"
    ON public.device_tokens FOR ALL
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

GRANT SELECT, INSERT, UPDATE, DELETE ON public.device_tokens TO authenticated;

-- Notification Preferences
CREATE TABLE public.notification_preferences (
    user_id          uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    overtaken        boolean NOT NULL DEFAULT true,
    challenge_ending boolean NOT NULL DEFAULT true,
    streak_risk      boolean NOT NULL DEFAULT true,
    achievement      boolean NOT NULL DEFAULT true,
    friend_request   boolean NOT NULL DEFAULT true,
    team_invite      boolean NOT NULL DEFAULT true,
    quiet_start      time without time zone,
    quiet_end        time without time zone,
    updated_at       timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.notification_preferences ENABLE ROW LEVEL SECURITY;

CREATE POLICY "notification_preferences_manage_own"
    ON public.notification_preferences FOR ALL
    TO authenticated
    USING (auth.uid() = user_id)
    WITH CHECK (auth.uid() = user_id);

GRANT SELECT, INSERT, UPDATE ON public.notification_preferences TO authenticated;

-- Notification Outbox (internal delivery queue)
CREATE TABLE public.notification_outbox (
    id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id      uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    type         text NOT NULL,
    title        text NOT NULL,
    body         text NOT NULL,
    payload      jsonb NOT NULL DEFAULT '{}'::jsonb,
    status       text NOT NULL DEFAULT 'pending',
    scheduled_at timestamptz NOT NULL DEFAULT now(),
    sent_at      timestamptz,
    error        text,
    created_at   timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT valid_outbox_status CHECK (status IN ('pending', 'sent', 'failed'))
);

CREATE INDEX notification_outbox_pending_idx ON public.notification_outbox (status, scheduled_at);
CREATE INDEX notification_outbox_user_idx ON public.notification_outbox (user_id);

ALTER TABLE public.notification_outbox ENABLE ROW LEVEL SECURITY;

-- No direct client access to notification outbox
REVOKE ALL ON public.notification_outbox FROM authenticated, anon, PUBLIC;

-- ============================================================
-- 2. CLIENT-FACING RPCS
-- ============================================================

-- Register device token
CREATE OR REPLACE FUNCTION public.register_device_token(
    p_apns_token text,
    p_environment text DEFAULT 'production'
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_uid uuid;
    v_env text := COALESCE(p_environment, 'production');
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'ERR_UNAUTHORIZED' USING ERRCODE = '42501';
    END IF;

    IF p_apns_token IS NULL OR trim(p_apns_token) = '' THEN
        RAISE EXCEPTION 'ERR_INVALID_TOKEN' USING ERRCODE = '22023';
    END IF;

    IF v_env NOT IN ('sandbox', 'production') THEN
        v_env := 'production';
    END IF;

    INSERT INTO public.device_tokens (user_id, apns_token, environment, last_seen)
    VALUES (v_uid, trim(p_apns_token), v_env, now())
    ON CONFLICT (user_id, apns_token)
    DO UPDATE SET environment = v_env, last_seen = now();

    RETURN jsonb_build_object('status', 'registered');
END;
$$;

-- Get my preferences
CREATE OR REPLACE FUNCTION public.get_my_notification_preferences()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_uid uuid;
    v_pref record;
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'ERR_UNAUTHORIZED' USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_pref FROM public.notification_preferences WHERE user_id = v_uid;

    IF NOT FOUND THEN
        -- Return default preferences if not yet configured
        RETURN jsonb_build_object(
            'overtaken', true,
            'challenge_ending', true,
            'streak_risk', true,
            'achievement', true,
            'friend_request', true,
            'team_invite', true,
            'quiet_start', null,
            'quiet_end', null
        );
    END IF;

    RETURN jsonb_build_object(
        'overtaken', v_pref.overtaken,
        'challenge_ending', v_pref.challenge_ending,
        'streak_risk', v_pref.streak_risk,
        'achievement', v_pref.achievement,
        'friend_request', v_pref.friend_request,
        'team_invite', v_pref.team_invite,
        'quiet_start', v_pref.quiet_start,
        'quiet_end', v_pref.quiet_end
    );
END;
$$;

-- Update my preferences
CREATE OR REPLACE FUNCTION public.update_notification_preferences(
    p_overtaken boolean DEFAULT NULL,
    p_challenge_ending boolean DEFAULT NULL,
    p_streak_risk boolean DEFAULT NULL,
    p_achievement boolean DEFAULT NULL,
    p_friend_request boolean DEFAULT NULL,
    p_team_invite boolean DEFAULT NULL,
    p_quiet_start time without time zone DEFAULT NULL,
    p_quiet_end time without time zone DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_uid uuid;
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'ERR_UNAUTHORIZED' USING ERRCODE = '42501';
    END IF;

    INSERT INTO public.notification_preferences (
        user_id,
        overtaken,
        challenge_ending,
        streak_risk,
        achievement,
        friend_request,
        team_invite,
        quiet_start,
        quiet_end,
        updated_at
    ) VALUES (
        v_uid,
        COALESCE(p_overtaken, true),
        COALESCE(p_challenge_ending, true),
        COALESCE(p_streak_risk, true),
        COALESCE(p_achievement, true),
        COALESCE(p_friend_request, true),
        COALESCE(p_team_invite, true),
        p_quiet_start,
        p_quiet_end,
        now()
    )
    ON CONFLICT (user_id)
    DO UPDATE SET
        overtaken = COALESCE(p_overtaken, notification_preferences.overtaken),
        challenge_ending = COALESCE(p_challenge_ending, notification_preferences.challenge_ending),
        streak_risk = COALESCE(p_streak_risk, notification_preferences.streak_risk),
        achievement = COALESCE(p_achievement, notification_preferences.achievement),
        friend_request = COALESCE(p_friend_request, notification_preferences.friend_request),
        team_invite = COALESCE(p_team_invite, notification_preferences.team_invite),
        quiet_start = CASE WHEN p_quiet_start IS NOT NULL THEN p_quiet_start ELSE notification_preferences.quiet_start END,
        quiet_end = CASE WHEN p_quiet_end IS NOT NULL THEN p_quiet_end ELSE notification_preferences.quiet_end END,
        updated_at = now();

    RETURN jsonb_build_object('status', 'updated');
END;
$$;

REVOKE ALL ON FUNCTION public.register_device_token(text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.register_device_token(text, text) TO authenticated;

REVOKE ALL ON FUNCTION public.get_my_notification_preferences() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_notification_preferences() TO authenticated;

REVOKE ALL ON FUNCTION public.update_notification_preferences(boolean, boolean, boolean, boolean, boolean, boolean, time without time zone, time without time zone) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.update_notification_preferences(boolean, boolean, boolean, boolean, boolean, boolean, time without time zone, time without time zone) TO authenticated;

-- ============================================================
-- 3. INTERNAL ENQUEUE FUNCTION: enqueue_notification
-- ============================================================
-- Why SECURITY DEFINER is needed (AGENTS.md Rule 9):
-- Inserts notifications into notification_outbox after validating user preferences
-- and adjusting for quiet hours. Never client-callable.
CREATE OR REPLACE FUNCTION public.enqueue_notification(
    p_user_id uuid,
    p_type text,
    p_title text,
    p_body text,
    p_payload jsonb DEFAULT '{}'::jsonb,
    p_scheduled_at timestamptz DEFAULT now()
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_pref record;
    v_allowed boolean := true;
    v_sched timestamptz := COALESCE(p_scheduled_at, now());
    v_tz text;
    v_local_time time without time zone;
    v_local_date date;
BEGIN
    IF p_user_id IS NULL OR p_type IS NULL OR p_title IS NULL OR p_body IS NULL THEN
        RETURN false;
    END IF;

    -- 1. Check user preferences for this notification type
    SELECT * INTO v_pref FROM public.notification_preferences WHERE user_id = p_user_id;

    IF FOUND THEN
        CASE p_type
            WHEN 'overtaken' THEN v_allowed := v_pref.overtaken;
            WHEN 'challenge_ending' THEN v_allowed := v_pref.challenge_ending;
            WHEN 'streak_risk' THEN v_allowed := v_pref.streak_risk;
            WHEN 'achievement' THEN v_allowed := v_pref.achievement;
            WHEN 'friend_request' THEN v_allowed := v_pref.friend_request;
            WHEN 'team_invite' THEN v_allowed := v_pref.team_invite;
            ELSE v_allowed := true;
        END CASE;
    END IF;

    IF NOT v_allowed THEN
        -- Suppressed by user preference
        RETURN false;
    END IF;

    -- 2. Check quiet hours
    IF v_pref.quiet_start IS NOT NULL AND v_pref.quiet_end IS NOT NULL THEN
        SELECT COALESCE(c.iana_timezone, 'Asia/Kolkata') INTO v_tz
        FROM public.profiles p
        LEFT JOIN public.cities c ON c.id = p.city_id
        WHERE p.id = p_user_id;
        v_tz := COALESCE(v_tz, 'Asia/Kolkata');

        v_local_time := (v_sched AT TIME ZONE v_tz)::time without time zone;
        v_local_date := (v_sched AT TIME ZONE v_tz)::date;

        -- If quiet hours span across midnight (e.g. 22:00 to 08:00)
        IF v_pref.quiet_start > v_pref.quiet_end THEN
            IF v_local_time >= v_pref.quiet_start OR v_local_time < v_pref.quiet_end THEN
                -- Delay to quiet_end today or tomorrow
                IF v_local_time >= v_pref.quiet_start THEN
                    v_sched := ((v_local_date + 1)::text || ' ' || v_pref.quiet_end::text)::timestamp AT TIME ZONE v_tz;
                ELSE
                    v_sched := (v_local_date::text || ' ' || v_pref.quiet_end::text)::timestamp AT TIME ZONE v_tz;
                END IF;
            END IF;
        ELSE -- quiet hours within same day (e.g. 13:00 to 15:00)
            IF v_local_time >= v_pref.quiet_start AND v_local_time < v_pref.quiet_end THEN
                v_sched := (v_local_date::text || ' ' || v_pref.quiet_end::text)::timestamp AT TIME ZONE v_tz;
            END IF;
        END IF;
    END IF;

    -- 3. Insert into outbox
    INSERT INTO public.notification_outbox (
        user_id, type, title, body, payload, status, scheduled_at
    ) VALUES (
        p_user_id, p_type, p_title, p_body, COALESCE(p_payload, '{}'::jsonb), 'pending', v_sched
    );

    RETURN true;
END;
$$;

REVOKE ALL ON FUNCTION public.enqueue_notification(uuid, text, text, text, jsonb, timestamptz) FROM PUBLIC, anon, authenticated;

-- ============================================================
-- 4. WIRING
-- ============================================================

-- A. Wire send_friend_request to enqueue friend_request notification
CREATE OR REPLACE FUNCTION public.send_friend_request(p_target_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_uid uuid;
    v_caller_username text;
    v_existing record;
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'ERR_UNAUTHORIZED' USING ERRCODE = '42501';
    END IF;

    IF p_target_user_id IS NULL OR p_target_user_id = v_uid THEN
        RAISE EXCEPTION 'ERR_INVALID_TARGET' USING ERRCODE = '22023';
    END IF;

    SELECT username INTO v_caller_username FROM public.profiles WHERE id = v_uid;

    IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = p_target_user_id) THEN
        RAISE EXCEPTION 'ERR_USER_NOT_FOUND' USING ERRCODE = '22023';
    END IF;

    IF EXISTS (
        SELECT 1 FROM public.friendships
        WHERE status = 'blocked'
          AND ((requester_id = v_uid AND addressee_id = p_target_user_id)
            OR (requester_id = p_target_user_id AND addressee_id = v_uid))
    ) THEN
        RAISE EXCEPTION 'ERR_BLOCKED' USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_existing
    FROM public.friendships
    WHERE (requester_id = v_uid AND addressee_id = p_target_user_id)
       OR (requester_id = p_target_user_id AND addressee_id = v_uid);

    IF FOUND THEN
        IF v_existing.status = 'accepted' THEN
            RETURN jsonb_build_object('status', 'already_friends');
        ELSIF v_existing.status = 'pending' THEN
            IF v_existing.requester_id = p_target_user_id THEN
                UPDATE public.friendships
                SET status = 'accepted', updated_at = now()
                WHERE id = v_existing.id;
                RETURN jsonb_build_object('status', 'accepted');
            ELSE
                RETURN jsonb_build_object('status', 'already_requested');
            END IF;
        END IF;
    END IF;

    INSERT INTO public.friendships (requester_id, addressee_id, status)
    VALUES (v_uid, p_target_user_id, 'pending');

    -- Enqueue push notification to target user
    PERFORM public.enqueue_notification(
        p_target_user_id,
        'friend_request',
        'New Friend Request',
        coalesce(v_caller_username, 'A player') || ' sent you a friend request!',
        jsonb_build_object('requester_id', v_uid, 'username', v_caller_username)
    );

    RETURN jsonb_build_object('status', 'request_sent');
END;
$$;

-- B. Wire evaluate_achievements to enqueue achievement notification
CREATE OR REPLACE FUNCTION public.evaluate_achievements(
    p_user_id uuid,
    p_trigger_event text,
    p_event_data jsonb DEFAULT '{}'::jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_ach           record;
    v_unlocked      boolean;
    v_count         bigint;
    v_quantity      double precision;
    v_rank          bigint;
    v_streak        integer;
    v_day_local     date := CURRENT_DATE;
    v_idem_key      text;
BEGIN
    IF p_user_id IS NULL THEN
        RETURN;
    END IF;

    FOR v_ach IN
        SELECT a.id, a.key, a.display_name, a.condition_type, a.condition_value, a.reward_kp
        FROM public.achievements a
        WHERE NOT EXISTS (
            SELECT 1 FROM public.user_achievements ua
            WHERE ua.user_id = p_user_id AND ua.achievement_id = a.id
        )
    LOOP
        v_unlocked := false;

        CASE v_ach.condition_type
            WHEN 'activity_count' THEN
                IF p_trigger_event = 'activity_submitted' THEN
                    SELECT COUNT(*) INTO v_count FROM public.activities WHERE user_id = p_user_id;
                    IF v_count >= (v_ach.condition_value->>'min_count')::bigint THEN
                        v_unlocked := true;
                    END IF;
                END IF;

            WHEN 'streak_days' THEN
                IF p_trigger_event IN ('streak_updated', 'activity_submitted') THEN
                    SELECT current_streak INTO v_streak FROM public.user_streaks WHERE user_id = p_user_id;
                    IF v_streak IS NOT NULL AND v_streak >= (v_ach.condition_value->>'min_days')::integer THEN
                        v_unlocked := true;
                    END IF;
                END IF;

            WHEN 'cumulative_quantity' THEN
                IF p_trigger_event = 'activity_submitted' THEN
                    SELECT COALESCE(SUM(a.quantity), 0) INTO v_quantity
                    FROM public.activities a
                    JOIN public.habits h ON h.id = a.habit_id
                    WHERE a.user_id = p_user_id AND h.key = (v_ach.condition_value->>'habit_key');

                    IF v_quantity >= (v_ach.condition_value->>'min_quantity')::double precision THEN
                        v_unlocked := true;
                    END IF;
                END IF;

            WHEN 'city_rank' THEN
                IF p_trigger_event IN ('leaderboard_refreshed', 'activity_submitted') THEN
                    SELECT city_rank INTO v_rank FROM public.leaderboard_daily WHERE user_id = p_user_id;
                    IF v_rank IS NOT NULL AND v_rank <= (v_ach.condition_value->>'max_rank')::bigint THEN
                        v_unlocked := true;
                    END IF;
                END IF;

            WHEN 'challenge_win' THEN
                IF p_trigger_event = 'challenge_finalized' THEN
                    IF (p_event_data->>'finish_rank')::integer = 1 THEN
                        v_unlocked := true;
                    END IF;
                END IF;

            WHEN 'friend_count' THEN
                IF p_trigger_event = 'friend_added' THEN
                    SELECT COUNT(*) INTO v_count
                    FROM public.friendships
                    WHERE status = 'accepted' AND (requester_id = p_user_id OR addressee_id = p_user_id);

                    IF v_count >= (v_ach.condition_value->>'min_friends')::bigint THEN
                        v_unlocked := true;
                    END IF;
                END IF;

            ELSE
                v_unlocked := false;
        END CASE;

        IF v_unlocked THEN
            INSERT INTO public.user_achievements (user_id, achievement_id, unlocked_at)
            VALUES (p_user_id, v_ach.id, now())
            ON CONFLICT (user_id, achievement_id) DO NOTHING;

            v_idem_key := 'achievement:' || v_ach.id || ':' || p_user_id;

            INSERT INTO public.kp_ledger (
                user_id, amount, type, source_type, source_id,
                idempotency_key, day_local, metadata, created_at
            ) VALUES (
                p_user_id,
                v_ach.reward_kp,
                'achievement_reward',
                'achievement',
                v_ach.id::text,
                v_idem_key,
                v_day_local,
                jsonb_build_object(
                    'achievement_id', v_ach.id,
                    'achievement_key', v_ach.key,
                    'reward_kp', v_ach.reward_kp
                ),
                now()
            )
            ON CONFLICT (idempotency_key) DO NOTHING;

            -- Enqueue achievement notification
            PERFORM public.enqueue_notification(
                p_user_id,
                'achievement',
                'Achievement Unlocked!',
                'You earned ' || v_ach.display_name || '! ' || v_ach.reward_kp::text || ' KP added.',
                jsonb_build_object('achievement_id', v_ach.id, 'key', v_ach.key, 'reward_kp', v_ach.reward_kp)
            );
        END IF;

    END LOOP;
END;
$$;
