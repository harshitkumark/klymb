-- Migration: 20260110000000_friends_social.sql
-- B11: Friends and social
-- Implements docs/ARCHITECTURE.md §2.2
--
-- 1. Table: friendships (requests, accept, block)
-- 2. Indexes and RLS policies
-- 3. RPCs:
--    - send_friend_request(target_user_id)
--    - accept_friend_request(requester_user_id)
--    - decline_friend_request(requester_user_id)
--    - remove_friend(friend_user_id)
--    - block_user(target_user_id)
--    - unblock_user(target_user_id)
--    - get_friends(limit_val, offset_val)
--    - search_users(query, limit_val)
-- 4. Extend get_leaderboard and get_my_rank to support scope = 'friends'

-- ============================================================
-- 1. FRIENDSHIPS TABLE
-- ============================================================
CREATE TABLE public.friendships (
    id              bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    requester_id    uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    addressee_id    uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    status          text NOT NULL DEFAULT 'pending',
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT valid_status CHECK (status IN ('pending', 'accepted', 'blocked')),
    CONSTRAINT cannot_friend_self CHECK (requester_id != addressee_id),
    UNIQUE (requester_id, addressee_id)
);

CREATE INDEX friendships_addressee_idx ON public.friendships (addressee_id, status);
CREATE INDEX friendships_requester_idx ON public.friendships (requester_id, status);

ALTER TABLE public.friendships ENABLE ROW LEVEL SECURITY;

-- Users can read their own friendship rows (either as requester or addressee)
CREATE POLICY "friendships_select_own"
    ON public.friendships FOR SELECT
    TO authenticated
    USING (auth.uid() = requester_id OR auth.uid() = addressee_id);

-- Direct client mutations are strictly revoked; mutations occur only via SECURITY DEFINER RPCs
REVOKE INSERT, UPDATE, DELETE ON public.friendships FROM authenticated, anon;
GRANT SELECT ON public.friendships TO authenticated;

-- ============================================================
-- 2. RPCS FOR FRIEND MANAGEMENT
-- ============================================================

-- Send a friend request
CREATE OR REPLACE FUNCTION public.send_friend_request(p_target_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_uid uuid;
    v_existing record;
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'ERR_UNAUTHORIZED' USING ERRCODE = '42501';
    END IF;

    IF p_target_user_id IS NULL OR p_target_user_id = v_uid THEN
        RAISE EXCEPTION 'ERR_INVALID_TARGET' USING ERRCODE = '22023';
    END IF;

    -- Verify target user exists
    IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE id = p_target_user_id) THEN
        RAISE EXCEPTION 'ERR_USER_NOT_FOUND' USING ERRCODE = '22023';
    END IF;

    -- Check if blocked in either direction
    IF EXISTS (
        SELECT 1 FROM public.friendships
        WHERE status = 'blocked'
          AND ((requester_id = v_uid AND addressee_id = p_target_user_id)
            OR (requester_id = p_target_user_id AND addressee_id = v_uid))
    ) THEN
        RAISE EXCEPTION 'ERR_BLOCKED' USING ERRCODE = '42501';
    END IF;

    -- Check existing relationship
    SELECT * INTO v_existing
    FROM public.friendships
    WHERE (requester_id = v_uid AND addressee_id = p_target_user_id)
       OR (requester_id = p_target_user_id AND addressee_id = v_uid);

    IF FOUND THEN
        IF v_existing.status = 'accepted' THEN
            RETURN jsonb_build_object('status', 'already_friends');
        ELSIF v_existing.status = 'pending' THEN
            -- If the other user already requested to be friends with caller, auto-accept!
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

    -- Insert new pending request
    INSERT INTO public.friendships (requester_id, addressee_id, status)
    VALUES (v_uid, p_target_user_id, 'pending');

    RETURN jsonb_build_object('status', 'request_sent');
END;
$$;

-- Accept friend request
CREATE OR REPLACE FUNCTION public.accept_friend_request(p_requester_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_uid uuid;
    v_id bigint;
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'ERR_UNAUTHORIZED' USING ERRCODE = '42501';
    END IF;

    -- Check pending request where current user is addressee
    SELECT id INTO v_id
    FROM public.friendships
    WHERE requester_id = p_requester_user_id
      AND addressee_id = v_uid
      AND status = 'pending';

    IF v_id IS NULL THEN
        RAISE EXCEPTION 'ERR_REQUEST_NOT_FOUND' USING ERRCODE = '22023';
    END IF;

    UPDATE public.friendships
    SET status = 'accepted', updated_at = now()
    WHERE id = v_id;

    RETURN jsonb_build_object('status', 'accepted');
END;
$$;

-- Decline friend request
CREATE OR REPLACE FUNCTION public.decline_friend_request(p_requester_user_id uuid)
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

    DELETE FROM public.friendships
    WHERE requester_id = p_requester_user_id
      AND addressee_id = v_uid
      AND status = 'pending';

    RETURN jsonb_build_object('status', 'declined');
END;
$$;

-- Remove friend
CREATE OR REPLACE FUNCTION public.remove_friend(p_friend_user_id uuid)
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

    DELETE FROM public.friendships
    WHERE status = 'accepted'
      AND ((requester_id = v_uid AND addressee_id = p_friend_user_id)
        OR (requester_id = p_friend_user_id AND addressee_id = v_uid));

    RETURN jsonb_build_object('status', 'removed');
END;
$$;

-- Block user
CREATE OR REPLACE FUNCTION public.block_user(p_target_user_id uuid)
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

    IF p_target_user_id IS NULL OR p_target_user_id = v_uid THEN
        RAISE EXCEPTION 'ERR_INVALID_TARGET' USING ERRCODE = '22023';
    END IF;

    -- Delete any existing non-blocked relationship in either direction
    DELETE FROM public.friendships
    WHERE (requester_id = v_uid AND addressee_id = p_target_user_id)
       OR (requester_id = p_target_user_id AND addressee_id = v_uid);

    -- Insert blocked record with current user as requester
    INSERT INTO public.friendships (requester_id, addressee_id, status)
    VALUES (v_uid, p_target_user_id, 'blocked')
    ON CONFLICT (requester_id, addressee_id)
    DO UPDATE SET status = 'blocked', updated_at = now();

    RETURN jsonb_build_object('status', 'blocked');
END;
$$;

-- Unblock user
CREATE OR REPLACE FUNCTION public.unblock_user(p_target_user_id uuid)
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

    DELETE FROM public.friendships
    WHERE requester_id = v_uid
      AND addressee_id = p_target_user_id
      AND status = 'blocked';

    RETURN jsonb_build_object('status', 'unblocked');
END;
$$;

-- Get friends list
CREATE OR REPLACE FUNCTION public.get_friends(
    p_limit integer DEFAULT 50,
    p_offset integer DEFAULT 0
)
RETURNS TABLE (
    friend_id uuid,
    username text,
    display_name text,
    avatar_preset text,
    city_name text,
    since timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_uid uuid;
    v_limit integer := COALESCE(p_limit, 50);
    v_offset integer := COALESCE(p_offset, 0);
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'ERR_UNAUTHORIZED' USING ERRCODE = '42501';
    END IF;

    IF v_limit < 1 OR v_limit > 100 THEN
        v_limit := 50;
    END IF;

    IF v_offset < 0 THEN
        v_offset := 0;
    END IF;

    RETURN QUERY
    SELECT
        f_user.id AS friend_id,
        f_user.username,
        f_user.display_name,
        f_user.avatar_preset,
        c.name AS city_name,
        f.updated_at AS since
    FROM public.friendships f
    JOIN public.profiles f_user ON f_user.id = (
        CASE WHEN f.requester_id = v_uid THEN f.addressee_id ELSE f.requester_id END
    )
    LEFT JOIN public.cities c ON c.id = f_user.city_id
    WHERE f.status = 'accepted'
      AND (f.requester_id = v_uid OR f.addressee_id = v_uid)
    ORDER BY f_user.username ASC
    LIMIT v_limit OFFSET v_offset;
END;
$$;

-- Search users by username (prefix search, rate-limited, excludes blocked users, strictly public fields)
CREATE OR REPLACE FUNCTION public.search_users(
    p_query text,
    p_limit integer DEFAULT 20
)
RETURNS TABLE (
    user_id uuid,
    username text,
    display_name text,
    avatar_preset text,
    city_name text
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_uid uuid;
    v_limit integer := COALESCE(p_limit, 20);
    v_cleaned text;
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'ERR_UNAUTHORIZED' USING ERRCODE = '42501';
    END IF;

    -- Rate limit searches: 60 calls/hour per user
    PERFORM public.check_rate_limit('search_users', 60);

    IF p_query IS NULL OR char_length(trim(p_query)) < 2 THEN
        RETURN;
    END IF;

    v_cleaned := trim(lower(p_query));
    IF v_limit < 1 OR v_limit > 50 THEN
        v_limit := 20;
    END IF;

    RETURN QUERY
    SELECT
        p.id AS user_id,
        p.username,
        p.display_name,
        p.avatar_preset,
        c.name AS city_name
    FROM public.profiles p
    LEFT JOIN public.cities c ON c.id = p.city_id
    WHERE p.id != v_uid
      AND lower(p.username) LIKE v_cleaned || '%'
      -- Exclude users if blocked in either direction
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

-- Grants for friend management
REVOKE ALL ON FUNCTION public.send_friend_request(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.send_friend_request(uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.accept_friend_request(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.accept_friend_request(uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.decline_friend_request(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.decline_friend_request(uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.remove_friend(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.remove_friend(uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.block_user(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.block_user(uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.unblock_user(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.unblock_user(uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.get_friends(integer, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_friends(integer, integer) TO authenticated;

REVOKE ALL ON FUNCTION public.search_users(text, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.search_users(text, integer) TO authenticated;

-- ============================================================
-- 3. EXTEND GET_LEADERBOARD AND GET_MY_RANK FOR 'FRIENDS' SCOPE
-- ============================================================

CREATE OR REPLACE FUNCTION public.get_leaderboard(
    p_scope text DEFAULT 'global',
    p_period text DEFAULT 'daily',
    p_city_id bigint DEFAULT NULL,
    p_limit integer DEFAULT 50,
    p_offset integer DEFAULT 0
)
RETURNS TABLE (
    rank bigint,
    user_id uuid,
    username text,
    display_name text,
    avatar_preset text,
    city_id bigint,
    city_name text,
    kp bigint
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id uuid;
    v_target_city_id bigint := p_city_id;
    v_limit integer := COALESCE(p_limit, 50);
    v_offset integer := COALESCE(p_offset, 0);
BEGIN
    -- 1. Validate caller authentication
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'ERR_UNAUTHORIZED' USING ERRCODE = '42501';
    END IF;

    -- 2. Validate parameters
    IF p_scope NOT IN ('global', 'city', 'friends') THEN
        RAISE EXCEPTION 'ERR_INVALID_SCOPE' USING ERRCODE = '22023';
    END IF;

    IF p_period NOT IN ('daily', 'weekly', 'alltime') THEN
        RAISE EXCEPTION 'ERR_INVALID_PERIOD' USING ERRCODE = '22023';
    END IF;

    IF v_limit < 1 OR v_limit > 100 THEN
        v_limit := 50;
    END IF;

    IF v_offset < 0 THEN
        v_offset := 0;
    END IF;

    -- If scope is city and city_id not passed, use caller's city
    IF p_scope = 'city' AND v_target_city_id IS NULL THEN
        SELECT p.city_id INTO v_target_city_id
        FROM public.profiles p
        WHERE p.id = v_caller_id;

        IF v_target_city_id IS NULL THEN
            RETURN;
        END IF;
    END IF;

    -- 3. Return ranked rows based on scope and period
    IF p_scope = 'global' THEN
        IF p_period = 'daily' THEN
            RETURN QUERY
            SELECT l.global_rank, l.user_id, l.username, l.display_name, l.avatar_preset, l.city_id, l.city_name, l.kp
            FROM public.leaderboard_daily l
            ORDER BY l.global_rank ASC
            LIMIT v_limit OFFSET v_offset;
        ELSIF p_period = 'weekly' THEN
            RETURN QUERY
            SELECT l.global_rank, l.user_id, l.username, l.display_name, l.avatar_preset, l.city_id, l.city_name, l.kp
            FROM public.leaderboard_weekly l
            ORDER BY l.global_rank ASC
            LIMIT v_limit OFFSET v_offset;
        ELSE
            RETURN QUERY
            SELECT l.global_rank, l.user_id, l.username, l.display_name, l.avatar_preset, l.city_id, l.city_name, l.kp
            FROM public.leaderboard_alltime l
            ORDER BY l.global_rank ASC
            LIMIT v_limit OFFSET v_offset;
        END IF;

    ELSIF p_scope = 'city' THEN
        IF p_period = 'daily' THEN
            RETURN QUERY
            SELECT l.city_rank, l.user_id, l.username, l.display_name, l.avatar_preset, l.city_id, l.city_name, l.kp
            FROM public.leaderboard_daily l
            WHERE l.city_id = v_target_city_id
            ORDER BY l.city_rank ASC
            LIMIT v_limit OFFSET v_offset;
        ELSIF p_period = 'weekly' THEN
            RETURN QUERY
            SELECT l.city_rank, l.user_id, l.username, l.display_name, l.avatar_preset, l.city_id, l.city_name, l.kp
            FROM public.leaderboard_weekly l
            WHERE l.city_id = v_target_city_id
            ORDER BY l.city_rank ASC
            LIMIT v_limit OFFSET v_offset;
        ELSE
            RETURN QUERY
            SELECT l.city_rank, l.user_id, l.username, l.display_name, l.avatar_preset, l.city_id, l.city_name, l.kp
            FROM public.leaderboard_alltime l
            WHERE l.city_id = v_target_city_id
            ORDER BY l.city_rank ASC
            LIMIT v_limit OFFSET v_offset;
        END IF;

    ELSE -- friends scope: filter to caller + caller's accepted friends
        IF p_period = 'daily' THEN
            RETURN QUERY
            WITH friend_list AS (
                SELECT v_caller_id AS u_id
                UNION
                SELECT (CASE WHEN f.requester_id = v_caller_id THEN f.addressee_id ELSE f.requester_id END) AS u_id
                FROM public.friendships f
                WHERE f.status = 'accepted'
                  AND (f.requester_id = v_caller_id OR f.addressee_id = v_caller_id)
            )
            SELECT
                RANK() OVER (ORDER BY l.kp DESC)::bigint AS rank,
                l.user_id, l.username, l.display_name, l.avatar_preset, l.city_id, l.city_name, l.kp
            FROM public.leaderboard_daily l
            JOIN friend_list fl ON fl.u_id = l.user_id
            ORDER BY rank ASC
            LIMIT v_limit OFFSET v_offset;
        ELSIF p_period = 'weekly' THEN
            RETURN QUERY
            WITH friend_list AS (
                SELECT v_caller_id AS u_id
                UNION
                SELECT (CASE WHEN f.requester_id = v_caller_id THEN f.addressee_id ELSE f.requester_id END) AS u_id
                FROM public.friendships f
                WHERE f.status = 'accepted'
                  AND (f.requester_id = v_caller_id OR f.addressee_id = v_caller_id)
            )
            SELECT
                RANK() OVER (ORDER BY l.kp DESC)::bigint AS rank,
                l.user_id, l.username, l.display_name, l.avatar_preset, l.city_id, l.city_name, l.kp
            FROM public.leaderboard_weekly l
            JOIN friend_list fl ON fl.u_id = l.user_id
            ORDER BY rank ASC
            LIMIT v_limit OFFSET v_offset;
        ELSE
            RETURN QUERY
            WITH friend_list AS (
                SELECT v_caller_id AS u_id
                UNION
                SELECT (CASE WHEN f.requester_id = v_caller_id THEN f.addressee_id ELSE f.requester_id END) AS u_id
                FROM public.friendships f
                WHERE f.status = 'accepted'
                  AND (f.requester_id = v_caller_id OR f.addressee_id = v_caller_id)
            )
            SELECT
                RANK() OVER (ORDER BY l.kp DESC)::bigint AS rank,
                l.user_id, l.username, l.display_name, l.avatar_preset, l.city_id, l.city_name, l.kp
            FROM public.leaderboard_alltime l
            JOIN friend_list fl ON fl.u_id = l.user_id
            ORDER BY rank ASC
            LIMIT v_limit OFFSET v_offset;
        END IF;
    END IF;
END;
$$;

-- Extend get_my_rank for 'friends' scope
CREATE OR REPLACE FUNCTION public.get_my_rank(
    p_scope text DEFAULT 'global',
    p_period text DEFAULT 'daily',
    p_city_id bigint DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_caller_id uuid;
    v_target_city_id bigint := p_city_id;
    v_my_rank bigint;
    v_my_kp bigint;
    v_next_user record;
    v_kp_to_overtake bigint := 0;
BEGIN
    v_caller_id := auth.uid();
    IF v_caller_id IS NULL THEN
        RAISE EXCEPTION 'ERR_UNAUTHORIZED' USING ERRCODE = '42501';
    END IF;

    IF p_scope NOT IN ('global', 'city', 'friends') THEN
        RAISE EXCEPTION 'ERR_INVALID_SCOPE' USING ERRCODE = '22023';
    END IF;

    IF p_period NOT IN ('daily', 'weekly', 'alltime') THEN
        RAISE EXCEPTION 'ERR_INVALID_PERIOD' USING ERRCODE = '22023';
    END IF;

    IF p_scope = 'city' AND v_target_city_id IS NULL THEN
        SELECT p.city_id INTO v_target_city_id
        FROM public.profiles p
        WHERE p.id = v_caller_id;

        IF v_target_city_id IS NULL THEN
            RETURN jsonb_build_object(
                'rank', null,
                'kp', 0,
                'next_user', null,
                'kp_to_overtake', 0
            );
        END IF;
    END IF;

    -- Fetch caller's rank and KP
    IF p_scope = 'global' THEN
        IF p_period = 'daily' THEN
            SELECT l.global_rank, l.kp INTO v_my_rank, v_my_kp
            FROM public.leaderboard_daily l WHERE l.user_id = v_caller_id;
        ELSIF p_period = 'weekly' THEN
            SELECT l.global_rank, l.kp INTO v_my_rank, v_my_kp
            FROM public.leaderboard_weekly l WHERE l.user_id = v_caller_id;
        ELSE
            SELECT l.global_rank, l.kp INTO v_my_rank, v_my_kp
            FROM public.leaderboard_alltime l WHERE l.user_id = v_caller_id;
        END IF;

    ELSIF p_scope = 'city' THEN
        IF p_period = 'daily' THEN
            SELECT l.city_rank, l.kp INTO v_my_rank, v_my_kp
            FROM public.leaderboard_daily l WHERE l.user_id = v_caller_id AND l.city_id = v_target_city_id;
        ELSIF p_period = 'weekly' THEN
            SELECT l.city_rank, l.kp INTO v_my_rank, v_my_kp
            FROM public.leaderboard_weekly l WHERE l.user_id = v_caller_id AND l.city_id = v_target_city_id;
        ELSE
            SELECT l.city_rank, l.kp INTO v_my_rank, v_my_kp
            FROM public.leaderboard_alltime l WHERE l.user_id = v_caller_id AND l.city_id = v_target_city_id;
        END IF;

    ELSE -- friends scope
        SELECT fr.rank, fr.kp INTO v_my_rank, v_my_kp
        FROM public.get_leaderboard('friends', p_period, NULL, 100, 0) fr
        WHERE fr.user_id = v_caller_id;
    END IF;

    IF v_my_rank IS NULL THEN
        RETURN jsonb_build_object(
            'rank', null,
            'kp', 0,
            'next_user', null,
            'kp_to_overtake', 0
        );
    END IF;

    -- If rank > 1, find the user immediately above
    IF v_my_rank > 1 THEN
        IF p_scope = 'global' THEN
            IF p_period = 'daily' THEN
                SELECT l.username, l.global_rank AS rank, l.kp INTO v_next_user
                FROM public.leaderboard_daily l
                WHERE l.global_rank < v_my_rank
                ORDER BY l.global_rank DESC LIMIT 1;
            ELSIF p_period = 'weekly' THEN
                SELECT l.username, l.global_rank AS rank, l.kp INTO v_next_user
                FROM public.leaderboard_weekly l
                WHERE l.global_rank < v_my_rank
                ORDER BY l.global_rank DESC LIMIT 1;
            ELSE
                SELECT l.username, l.global_rank AS rank, l.kp INTO v_next_user
                FROM public.leaderboard_alltime l
                WHERE l.global_rank < v_my_rank
                ORDER BY l.global_rank DESC LIMIT 1;
            END IF;

        ELSIF p_scope = 'city' THEN
            IF p_period = 'daily' THEN
                SELECT l.username, l.city_rank AS rank, l.kp INTO v_next_user
                FROM public.leaderboard_daily l
                WHERE l.city_id = v_target_city_id AND l.city_rank < v_my_rank
                ORDER BY l.city_rank DESC LIMIT 1;
            ELSIF p_period = 'weekly' THEN
                SELECT l.username, l.city_rank AS rank, l.kp INTO v_next_user
                FROM public.leaderboard_weekly l
                WHERE l.city_id = v_target_city_id AND l.city_rank < v_my_rank
                ORDER BY l.city_rank DESC LIMIT 1;
            ELSE
                SELECT l.username, l.city_rank AS rank, l.kp INTO v_next_user
                FROM public.leaderboard_alltime l
                WHERE l.city_id = v_target_city_id AND l.city_rank < v_my_rank
                ORDER BY l.city_rank DESC LIMIT 1;
            END IF;

        ELSE -- friends scope
            SELECT fr.username, fr.rank, fr.kp INTO v_next_user
            FROM public.get_leaderboard('friends', p_period, NULL, 100, 0) fr
            WHERE fr.rank < v_my_rank
            ORDER BY fr.rank DESC LIMIT 1;
        END IF;

        IF v_next_user.username IS NOT NULL THEN
            v_kp_to_overtake := (v_next_user.kp - v_my_kp) + 1;
        END IF;
    END IF;

    RETURN jsonb_build_object(
        'rank', v_my_rank,
        'kp', v_my_kp,
        'next_user', CASE 
            WHEN v_next_user.username IS NOT NULL THEN 
                jsonb_build_object('username', v_next_user.username, 'rank', v_next_user.rank)
            ELSE null 
        END,
        'kp_to_overtake', v_kp_to_overtake
    );
END;
$$;
