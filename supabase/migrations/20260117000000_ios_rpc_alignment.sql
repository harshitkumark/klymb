-- Migration: 20260117000000_ios_rpc_alignment.sql
-- Aligns backend RPCs and seed data with iOS client requirements:
-- 1. Table: public.friend_cheers + RLS + cheer_friend RPC
-- 2. RPC: get_my_profile() (returns profile + city_name + derived ledger total_kp)
-- 3. RPC: get_my_streak() (returns user_streaks row or defaults)
-- 4. RPC: get_my_habits() & get_today_habit_progress() (live daily progress from activities + kp_ledger)
-- 5. RPC: get_active_challenges() & seed starter active challenges
-- 6. RPC: get_incoming_friend_requests(), get_friends_with_stats(), search_users_with_status()

-- ============================================================
-- 1. TABLE: friend_cheers + RLS
-- ============================================================
CREATE TABLE IF NOT EXISTS public.friend_cheers (
    id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    sender_id    uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    recipient_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    day_local    date NOT NULL DEFAULT CURRENT_DATE,
    created_at   timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT cannot_cheer_self CHECK (sender_id != recipient_id),
    UNIQUE (sender_id, recipient_id, day_local)
);

CREATE INDEX IF NOT EXISTS friend_cheers_recipient_idx
    ON public.friend_cheers (recipient_id, day_local);

ALTER TABLE public.friend_cheers ENABLE ROW LEVEL SECURITY;

CREATE POLICY "friend_cheers_select_own"
    ON public.friend_cheers FOR SELECT
    TO authenticated
    USING (auth.uid() = sender_id OR auth.uid() = recipient_id);

REVOKE INSERT, UPDATE, DELETE, TRUNCATE ON public.friend_cheers FROM authenticated, anon;
GRANT SELECT ON public.friend_cheers TO authenticated;

-- ============================================================
-- 2. RPC: cheer_friend(p_target_user_id uuid)
-- ============================================================
-- Why SECURITY DEFINER is needed (AGENTS.md Rule 9):
-- Inserts into friend_cheers (which disallows direct client writes)
-- and enqueues a push notification into notification_outbox.
CREATE OR REPLACE FUNCTION public.cheer_friend(p_target_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_uid            uuid;
    v_sender_name    text;
    v_timezone       text;
    v_day_local      date;
    v_cheer_id       bigint;
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'ERR_UNAUTHORIZED' USING ERRCODE = '42501';
    END IF;

    IF p_target_user_id IS NULL OR p_target_user_id = v_uid THEN
        RAISE EXCEPTION 'ERR_INVALID_TARGET' USING ERRCODE = '22023';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = p_target_user_id) THEN
        RAISE EXCEPTION 'ERR_USER_NOT_FOUND' USING ERRCODE = 'P0002';
    END IF;

    -- Rate limit cheers: 30/hour
    PERFORM public.check_rate_limit('cheer_friend', 30);

    SELECT username INTO v_sender_name FROM public.profiles WHERE id = v_uid;

    SELECT COALESCE(c.iana_timezone, 'Asia/Kolkata') INTO v_timezone
    FROM public.profiles p
    LEFT JOIN public.cities c ON c.id = p.city_id
    WHERE p.id = v_uid;
    v_day_local := (now() AT TIME ZONE COALESCE(v_timezone, 'Asia/Kolkata'))::date;

    INSERT INTO public.friend_cheers (sender_id, recipient_id, day_local)
    VALUES (v_uid, p_target_user_id, v_day_local)
    ON CONFLICT (sender_id, recipient_id, day_local) DO NOTHING
    RETURNING id INTO v_cheer_id;

    IF v_cheer_id IS NOT NULL THEN
        PERFORM public.enqueue_notification(
            p_target_user_id,
            'cheer',
            'You got a cheer!',
            '@' || COALESCE(v_sender_name, 'athlete') || ' cheered you on today!',
            jsonb_build_object('sender_id', v_uid, 'type', 'cheer')
        );
        RETURN jsonb_build_object('status', 'cheered');
    ELSE
        RETURN jsonb_build_object('status', 'already_cheered_today');
    END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.cheer_friend(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.cheer_friend(uuid) TO authenticated;

-- ============================================================
-- 3. RPC: get_my_profile()
-- ============================================================
-- Why SECURITY DEFINER is needed (AGENTS.md Rule 9):
-- Combines profile, city name, and derived SUM(kp_ledger.amount) for auth.uid().
CREATE OR REPLACE FUNCTION public.get_my_profile()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_uid      uuid;
    v_prof     record;
    v_total_kp integer;
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'ERR_UNAUTHORIZED' USING ERRCODE = '42501';
    END IF;

    SELECT
        p.id,
        p.username,
        p.display_name,
        p.avatar_preset,
        p.city_id,
        c.name AS city_name,
        p.city_changed_at,
        p.created_at,
        p.updated_at
    INTO v_prof
    FROM public.profiles p
    LEFT JOIN public.cities c ON c.id = p.city_id
    WHERE p.id = v_uid;

    IF NOT FOUND THEN
        RETURN NULL;
    END IF;

    SELECT COALESCE(SUM(amount), 0)::integer INTO v_total_kp
    FROM public.kp_ledger
    WHERE user_id = v_uid;

    RETURN jsonb_build_object(
        'id', v_prof.id,
        'username', v_prof.username,
        'display_name', v_prof.display_name,
        'avatar_preset', v_prof.avatar_preset,
        'city_id', v_prof.city_id,
        'city_name', v_prof.city_name,
        'city_changed_at', v_prof.city_changed_at,
        'total_kp', v_total_kp,
        'created_at', v_prof.created_at,
        'updated_at', v_prof.updated_at
    );
END;
$$;

REVOKE ALL ON FUNCTION public.get_my_profile() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_profile() TO authenticated;

-- ============================================================
-- 4. RPC: get_my_streak()
-- ============================================================
-- Why SECURITY DEFINER is needed (AGENTS.md Rule 9):
-- Returns streak record strictly scoped to auth.uid() with clean defaults.
CREATE OR REPLACE FUNCTION public.get_my_streak()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_uid    uuid;
    v_streak record;
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'ERR_UNAUTHORIZED' USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_streak
    FROM public.user_streaks
    WHERE user_id = v_uid;

    IF NOT FOUND THEN
        RETURN jsonb_build_object(
            'current_streak', 0,
            'longest_streak', 0,
            'last_active_date', NULL,
            'freezes_remaining', 1
        );
    END IF;

    RETURN jsonb_build_object(
        'current_streak', v_streak.current_streak,
        'longest_streak', v_streak.longest_streak,
        'last_active_date', v_streak.last_qualified_date::text,
        'freezes_remaining', v_streak.freezes_available
    );
END;
$$;

REVOKE ALL ON FUNCTION public.get_my_streak() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_streak() TO authenticated;

-- ============================================================
-- 5. RPCs: get_my_habits() & get_today_habit_progress()
-- ============================================================
-- Why SECURITY DEFINER is needed (AGENTS.md Rule 9):
-- Joins habits catalog with caller's active user_habits and today's activities/kp_ledger.
CREATE OR REPLACE FUNCTION public.get_my_habits()
RETURNS TABLE (
    id            bigint,
    key           text,
    display_name  text,
    unit          text,
    daily_kp_cap  integer,
    manual_kp_cap integer,
    manual_allowed boolean,
    is_selected   boolean
)
LANGUAGE plpgsql
STABLE
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

    RETURN QUERY
    SELECT
        h.id,
        h.key,
        h.display_name,
        h.unit,
        h.daily_kp_cap,
        h.manual_kp_cap,
        h.manual_allowed,
        COALESCE(uh.active, false) AS is_selected
    FROM public.habits h
    LEFT JOIN public.user_habits uh
        ON uh.habit_id = h.id AND uh.user_id = v_uid
    ORDER BY h.id ASC;
END;
$$;

REVOKE ALL ON FUNCTION public.get_my_habits() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_habits() TO authenticated;

CREATE OR REPLACE FUNCTION public.get_today_habit_progress()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_uid        uuid;
    v_timezone   text;
    v_day_local  date;
    v_today_kp   integer := 0;
    v_items      jsonb := '[]'::jsonb;
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'ERR_UNAUTHORIZED' USING ERRCODE = '42501';
    END IF;

    SELECT COALESCE(c.iana_timezone, 'Asia/Kolkata') INTO v_timezone
    FROM public.profiles p
    LEFT JOIN public.cities c ON c.id = p.city_id
    WHERE p.id = v_uid;
    v_timezone := COALESCE(v_timezone, 'Asia/Kolkata');
    v_day_local := (now() AT TIME ZONE v_timezone)::date;

    SELECT COALESCE(SUM(amount), 0)::integer INTO v_today_kp
    FROM public.kp_ledger
    WHERE user_id = v_uid
      AND day_local = v_day_local;

    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'habit_id', h.id,
            'key', h.key,
            'display_name', h.display_name,
            'unit', h.unit,
            'daily_kp_cap', h.daily_kp_cap,
            'current_quantity', COALESCE(act.total_qty, 0),
            'kp_earned_today', COALESCE(led.earned_kp, 0)
        ) ORDER BY h.id ASC
    ), '[]'::jsonb) INTO v_items
    FROM public.user_habits uh
    JOIN public.habits h ON h.id = uh.habit_id
    LEFT JOIN (
        SELECT
            a.habit_id,
            SUM(a.quantity) AS total_qty
        FROM public.activities a
        WHERE a.user_id = v_uid
          AND (a.started_at AT TIME ZONE v_timezone)::date = v_day_local
        GROUP BY a.habit_id
    ) act ON act.habit_id = h.id
    LEFT JOIN (
        SELECT
            (kl.metadata->>'habit_key') AS habit_key,
            SUM(kl.amount)::integer AS earned_kp
        FROM public.kp_ledger kl
        WHERE kl.user_id = v_uid
          AND kl.day_local = v_day_local
          AND kl.type = 'earn'
          AND kl.source_type = 'activity'
        GROUP BY (kl.metadata->>'habit_key')
    ) led ON led.habit_key = h.key
    WHERE uh.user_id = v_uid
      AND uh.active = true;

    RETURN jsonb_build_object(
        'day_local', v_day_local::text,
        'today_kp', v_today_kp,
        'habits', v_items
    );
END;
$$;

REVOKE ALL ON FUNCTION public.get_today_habit_progress() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_today_habit_progress() TO authenticated;

-- ============================================================
-- 6. RPC: get_active_challenges() & Seed Starter Challenges
-- ============================================================
-- Why SECURITY DEFINER is needed (AGENTS.md Rule 9):
-- Joins challenges, challenge_participants, and challenge_progress for auth.uid().
CREATE OR REPLACE FUNCTION public.get_active_challenges()
RETURNS TABLE (
    id          bigint,
    type        text,
    title       text,
    description text,
    habit_key   text,
    target      double precision,
    reward_kp   integer,
    start_at    timestamptz,
    end_at      timestamptz,
    status      text,
    progress    double precision,
    is_joined   boolean
)
LANGUAGE plpgsql
STABLE
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

    RETURN QUERY
    SELECT
        c.id,
        c.type,
        c.title,
        c.description,
        c.habit_key,
        c.target,
        c.reward_kp,
        c.start_at,
        c.end_at,
        c.status,
        COALESCE(cp.current_value, 0.0)::double precision AS progress,
        (part.id IS NOT NULL) AS is_joined
    FROM public.challenges c
    LEFT JOIN public.challenge_participants part
        ON part.challenge_id = c.id AND part.user_id = v_uid
    LEFT JOIN public.challenge_progress cp
        ON cp.challenge_id = c.id AND cp.user_id = v_uid
    WHERE c.status = 'active'
      AND c.end_at > now()
    ORDER BY c.end_at ASC, c.id ASC;
END;
$$;

REVOKE ALL ON FUNCTION public.get_active_challenges() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_active_challenges() TO authenticated;

-- Seed starter active challenges if table is currently empty
INSERT INTO public.challenges (type, title, description, habit_key, target, reward_kp, start_at, end_at, status)
SELECT * FROM (VALUES
    ('daily', '10K Step Sprint', 'Hit 10,000 verified steps today to claim the daily sprint bonus.', 'steps', 10000::double precision, 50, date_trunc('day', now()), date_trunc('day', now()) + interval '1 day', 'active'),
    ('daily', 'Hydration Check', 'Log 2,500 ml of water intake before midnight.', 'hydration', 2500::double precision, 40, date_trunc('day', now()), date_trunc('day', now()) + interval '1 day', 'active'),
    ('weekly', '25K Weekly Runner', 'Accumulate 25 km of running across sessions this week.', 'running', 25::double precision, 150, date_trunc('week', now()), date_trunc('week', now()) + interval '7 days', 'active'),
    ('weekly', 'Zen Mindful Hour', 'Complete 60 minutes of focused mindfulness this week.', 'mindfulness', 60::double precision, 100, date_trunc('week', now()), date_trunc('week', now()) + interval '7 days', 'active'),
    ('community', 'City Endurance 500 Min', 'Push through 500 workout minutes this month to claim the endurance crest.', 'workout', 500::double precision, 300, date_trunc('month', now()), date_trunc('month', now()) + interval '30 days', 'active')
) AS seed(type, title, description, habit_key, target, reward_kp, start_at, end_at, status)
WHERE NOT EXISTS (SELECT 1 FROM public.challenges LIMIT 1);

-- ============================================================
-- 7. SOCIAL RPCs: get_incoming_friend_requests, get_friends_with_stats, search_users_with_status
-- ============================================================
-- Why SECURITY DEFINER is needed (AGENTS.md Rule 9):
-- Aggregates public profile info, city, KP total, streak, and friendship status for auth.uid().
CREATE OR REPLACE FUNCTION public.get_incoming_friend_requests()
RETURNS TABLE (
    id            uuid,
    username      text,
    display_name  text,
    avatar_preset text,
    city_name     text,
    total_kp      integer,
    status        text,
    streak        integer
)
LANGUAGE plpgsql
STABLE
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

    RETURN QUERY
    SELECT
        p.id,
        p.username,
        p.display_name,
        COALESCE(p.avatar_preset, 'default') AS avatar_preset,
        c.name AS city_name,
        COALESCE((SELECT SUM(kl.amount)::integer FROM public.kp_ledger kl WHERE kl.user_id = p.id), 0) AS total_kp,
        'pending_received'::text AS status,
        COALESCE(us.current_streak, 0) AS streak
    FROM public.friendships f
    JOIN public.profiles p ON p.id = f.requester_id
    LEFT JOIN public.cities c ON c.id = p.city_id
    LEFT JOIN public.user_streaks us ON us.user_id = p.id
    WHERE f.addressee_id = v_uid
      AND f.status = 'pending'
    ORDER BY f.created_at DESC;
END;
$$;

REVOKE ALL ON FUNCTION public.get_incoming_friend_requests() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_incoming_friend_requests() TO authenticated;

CREATE OR REPLACE FUNCTION public.get_friends_with_stats(
    p_limit integer DEFAULT 50,
    p_offset integer DEFAULT 0
)
RETURNS TABLE (
    id            uuid,
    username      text,
    display_name  text,
    avatar_preset text,
    city_name     text,
    total_kp      integer,
    status        text,
    streak        integer
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_uid    uuid;
    v_limit  integer := LEAST(GREATEST(COALESCE(p_limit, 50), 1), 100);
    v_offset integer := GREATEST(COALESCE(p_offset, 0), 0);
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'ERR_UNAUTHORIZED' USING ERRCODE = '42501';
    END IF;

    RETURN QUERY
    SELECT
        f_user.id,
        f_user.username,
        f_user.display_name,
        COALESCE(f_user.avatar_preset, 'default') AS avatar_preset,
        c.name AS city_name,
        COALESCE((SELECT SUM(kl.amount)::integer FROM public.kp_ledger kl WHERE kl.user_id = f_user.id), 0) AS total_kp,
        'friends'::text AS status,
        COALESCE(us.current_streak, 0) AS streak
    FROM public.friendships f
    JOIN public.profiles f_user ON f_user.id = (
        CASE WHEN f.requester_id = v_uid THEN f.addressee_id ELSE f.requester_id END
    )
    LEFT JOIN public.cities c ON c.id = f_user.city_id
    LEFT JOIN public.user_streaks us ON us.user_id = f_user.id
    WHERE f.status = 'accepted'
      AND (f.requester_id = v_uid OR f.addressee_id = v_uid)
    ORDER BY f_user.username ASC
    LIMIT v_limit OFFSET v_offset;
END;
$$;

REVOKE ALL ON FUNCTION public.get_friends_with_stats(integer, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_friends_with_stats(integer, integer) TO authenticated;

CREATE OR REPLACE FUNCTION public.search_users_with_status(
    p_query text,
    p_limit integer DEFAULT 20
)
RETURNS TABLE (
    id            uuid,
    username      text,
    display_name  text,
    avatar_preset text,
    city_name     text,
    total_kp      integer,
    status        text,
    streak        integer
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_uid     uuid;
    v_limit   integer := LEAST(GREATEST(COALESCE(p_limit, 20), 1), 50);
    v_cleaned text;
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'ERR_UNAUTHORIZED' USING ERRCODE = '42501';
    END IF;

    IF p_query IS NULL OR char_length(trim(p_query)) < 2 THEN
        RETURN;
    END IF;

    v_cleaned := trim(lower(p_query));

    RETURN QUERY
    SELECT
        p.id,
        p.username,
        p.display_name,
        COALESCE(p.avatar_preset, 'default') AS avatar_preset,
        c.name AS city_name,
        COALESCE((SELECT SUM(kl.amount)::integer FROM public.kp_ledger kl WHERE kl.user_id = p.id), 0) AS total_kp,
        COALESCE((
            SELECT CASE
                WHEN f.status = 'accepted' THEN 'friends'
                WHEN f.status = 'pending' AND f.requester_id = v_uid THEN 'pending_sent'
                WHEN f.status = 'pending' AND f.addressee_id = v_uid THEN 'pending_received'
                ELSE 'none'
            END
            FROM public.friendships f
            WHERE (f.requester_id = v_uid AND f.addressee_id = p.id)
               OR (f.requester_id = p.id AND f.addressee_id = v_uid)
            LIMIT 1
        ), 'none') AS status,
        COALESCE(us.current_streak, 0) AS streak
    FROM public.profiles p
    LEFT JOIN public.cities c ON c.id = p.city_id
    LEFT JOIN public.user_streaks us ON us.user_id = p.id
    WHERE p.id != v_uid
      AND (lower(p.username) LIKE v_cleaned || '%' OR lower(COALESCE(p.display_name, '')) LIKE '%' || v_cleaned || '%')
      AND NOT EXISTS (
          SELECT 1 FROM public.friendships f
          WHERE f.status = 'blocked'
            AND ((f.requester_id = v_uid AND f.addressee_id = p.id)
              OR (f.requester_id = p.id AND f.addressee_id = v_uid))
      )
    ORDER BY p.username ASC
    LIMIT v_limit;
END;
$$;

REVOKE ALL ON FUNCTION public.search_users_with_status(text, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.search_users_with_status(text, integer) TO authenticated;
