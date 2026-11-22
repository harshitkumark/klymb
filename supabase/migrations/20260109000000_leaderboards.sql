-- Migration: 20260109000000_leaderboards.sql
-- B10: Leaderboards [REVIEW]
-- Implements docs/ARCHITECTURE.md §6
--
-- 1. Materialized Views:
--    - leaderboard_daily
--    - leaderboard_weekly
--    - leaderboard_alltime
-- 2. Unique & covering indexes for CONCURRENT refresh & fast retrieval
-- 3. refresh_leaderboards() function
-- 4. pg_cron schedule configuration
-- 5. RPCs:
--    - get_leaderboard(scope, period, city_id, limit_val, offset_val)
--    - get_my_rank(scope, period, city_id)

-- ============================================================
-- 1. MATERIALIZED VIEWS
-- ============================================================

-- Daily Leaderboard
-- Aggregates KP for CURRENT_DATE in user local terms or UTC day
CREATE MATERIALIZED VIEW public.leaderboard_daily AS
SELECT
    p.id AS user_id,
    p.username,
    p.display_name,
    p.avatar_preset,
    p.city_id,
    c.name AS city_name,
    COALESCE(SUM(kl.amount), 0)::bigint AS kp,
    RANK() OVER (ORDER BY COALESCE(SUM(kl.amount), 0) DESC)::bigint AS global_rank,
    CASE 
        WHEN p.city_id IS NOT NULL THEN 
            RANK() OVER (PARTITION BY p.city_id ORDER BY COALESCE(SUM(kl.amount), 0) DESC)::bigint 
        ELSE NULL 
    END AS city_rank
FROM public.profiles p
LEFT JOIN public.cities c ON c.id = p.city_id
JOIN public.kp_ledger kl ON kl.user_id = p.id
    AND kl.day_local = CURRENT_DATE
    AND kl.type IN ('earn', 'revoke', 'reinstate')
WHERE NOT EXISTS (
    SELECT 1 FROM public.activity_flags af
    WHERE af.user_id = p.id
      AND af.severity = 'HIGH'
      AND af.status = 'open'
)
AND NOT EXISTS (
    SELECT 1 FROM public.user_trust_score uts
    WHERE uts.user_id = p.id
      AND uts.trust_score < 20
)
GROUP BY p.id, p.username, p.display_name, p.avatar_preset, p.city_id, c.name
HAVING COALESCE(SUM(kl.amount), 0) > 0
WITH DATA;

-- Weekly Leaderboard (current week starting Monday)
CREATE MATERIALIZED VIEW public.leaderboard_weekly AS
SELECT
    p.id AS user_id,
    p.username,
    p.display_name,
    p.avatar_preset,
    p.city_id,
    c.name AS city_name,
    COALESCE(SUM(kl.amount), 0)::bigint AS kp,
    RANK() OVER (ORDER BY COALESCE(SUM(kl.amount), 0) DESC)::bigint AS global_rank,
    CASE 
        WHEN p.city_id IS NOT NULL THEN 
            RANK() OVER (PARTITION BY p.city_id ORDER BY COALESCE(SUM(kl.amount), 0) DESC)::bigint 
        ELSE NULL 
    END AS city_rank
FROM public.profiles p
LEFT JOIN public.cities c ON c.id = p.city_id
JOIN public.kp_ledger kl ON kl.user_id = p.id
    AND kl.day_local >= date_trunc('week', CURRENT_DATE)::date
    AND kl.type IN ('earn', 'revoke', 'reinstate')
WHERE NOT EXISTS (
    SELECT 1 FROM public.activity_flags af
    WHERE af.user_id = p.id
      AND af.severity = 'HIGH'
      AND af.status = 'open'
)
AND NOT EXISTS (
    SELECT 1 FROM public.user_trust_score uts
    WHERE uts.user_id = p.id
      AND uts.trust_score < 20
)
GROUP BY p.id, p.username, p.display_name, p.avatar_preset, p.city_id, c.name
HAVING COALESCE(SUM(kl.amount), 0) > 0
WITH DATA;

-- All-Time Leaderboard
CREATE MATERIALIZED VIEW public.leaderboard_alltime AS
SELECT
    p.id AS user_id,
    p.username,
    p.display_name,
    p.avatar_preset,
    p.city_id,
    c.name AS city_name,
    COALESCE(SUM(kl.amount), 0)::bigint AS kp,
    RANK() OVER (ORDER BY COALESCE(SUM(kl.amount), 0) DESC)::bigint AS global_rank,
    CASE 
        WHEN p.city_id IS NOT NULL THEN 
            RANK() OVER (PARTITION BY p.city_id ORDER BY COALESCE(SUM(kl.amount), 0) DESC)::bigint 
        ELSE NULL 
    END AS city_rank
FROM public.profiles p
LEFT JOIN public.cities c ON c.id = p.city_id
JOIN public.kp_ledger kl ON kl.user_id = p.id
    AND kl.type IN ('earn', 'revoke', 'reinstate')
WHERE NOT EXISTS (
    SELECT 1 FROM public.activity_flags af
    WHERE af.user_id = p.id
      AND af.severity = 'HIGH'
      AND af.status = 'open'
)
AND NOT EXISTS (
    SELECT 1 FROM public.user_trust_score uts
    WHERE uts.user_id = p.id
      AND uts.trust_score < 20
)
GROUP BY p.id, p.username, p.display_name, p.avatar_preset, p.city_id, c.name
HAVING COALESCE(SUM(kl.amount), 0) > 0
WITH DATA;

-- ============================================================
-- 2. INDEXES
-- ============================================================

-- Daily indexes
CREATE UNIQUE INDEX leaderboard_daily_user_id_idx ON public.leaderboard_daily (user_id);
CREATE INDEX leaderboard_daily_global_rank_idx ON public.leaderboard_daily (global_rank);
CREATE INDEX leaderboard_daily_city_rank_idx ON public.leaderboard_daily (city_id, city_rank);

-- Weekly indexes
CREATE UNIQUE INDEX leaderboard_weekly_user_id_idx ON public.leaderboard_weekly (user_id);
CREATE INDEX leaderboard_weekly_global_rank_idx ON public.leaderboard_weekly (global_rank);
CREATE INDEX leaderboard_weekly_city_rank_idx ON public.leaderboard_weekly (city_id, city_rank);

-- All-Time indexes
CREATE UNIQUE INDEX leaderboard_alltime_user_id_idx ON public.leaderboard_alltime (user_id);
CREATE INDEX leaderboard_alltime_global_rank_idx ON public.leaderboard_alltime (global_rank);
CREATE INDEX leaderboard_alltime_city_rank_idx ON public.leaderboard_alltime (city_id, city_rank);

-- ============================================================
-- 3. REFRESH FUNCTION
-- ============================================================
-- Why SECURITY DEFINER is needed (AGENTS.md Rule 9):
-- Refreshes materialized views concurrently. Not accessible by client roles.
CREATE OR REPLACE FUNCTION public.refresh_leaderboards(p_period text DEFAULT 'all')
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    IF p_period IN ('all', 'daily') THEN
        REFRESH MATERIALIZED VIEW CONCURRENTLY public.leaderboard_daily;
    END IF;

    IF p_period IN ('all', 'weekly') THEN
        REFRESH MATERIALIZED VIEW CONCURRENTLY public.leaderboard_weekly;
    END IF;

    IF p_period IN ('all', 'alltime') THEN
        REFRESH MATERIALIZED VIEW CONCURRENTLY public.leaderboard_alltime;
    END IF;
END;
$$;

REVOKE ALL ON FUNCTION public.refresh_leaderboards(text) FROM PUBLIC, anon, authenticated;

-- ============================================================
-- 4. PG_CRON SCHEDULE CONFIGURATION (docs/ARCHITECTURE.md §6 & §12)
-- ============================================================
DO $$
BEGIN
    -- Check if pg_cron is installed/enabled
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
        -- Daily every 5 min
        PERFORM cron.schedule(
            'refresh-leaderboard-daily',
            '*/5 * * * *',
            'SELECT public.refresh_leaderboards(''daily'')'
        );
        -- Weekly every 15 min
        PERFORM cron.schedule(
            'refresh-leaderboard-weekly',
            '*/15 * * * *',
            'SELECT public.refresh_leaderboards(''weekly'')'
        );
        -- All-time every 30 min
        PERFORM cron.schedule(
            'refresh-leaderboard-alltime',
            '*/30 * * * *',
            'SELECT public.refresh_leaderboards(''alltime'')'
        );
    END IF;
EXCEPTION WHEN OTHERS THEN
    -- In environments without pg_cron daemon configured, continue smoothly
    RAISE NOTICE 'pg_cron scheduling skipped: %', SQLERRM;
END $$;

-- ============================================================
-- 5. RPC: get_leaderboard
-- ============================================================
-- Why SECURITY DEFINER is needed (AGENTS.md Rule 9):
-- Provides a controlled, sanitized read API for leaderboards without exposing
-- underlying materialized views or profile columns directly to public manipulation.
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
    IF p_scope NOT IN ('global', 'city') THEN
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
            -- User has no city assigned; return empty set
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
    ELSE -- city scope
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
    END IF;
END;
$$;

-- ============================================================
-- 6. RPC: get_my_rank
-- ============================================================
-- Why SECURITY DEFINER is needed (AGENTS.md Rule 9):
-- Efficiently calculates caller's standing and distance to next player.
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

    IF p_scope NOT IN ('global', 'city') THEN
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

    -- Fetch caller's rank and KP from appropriate materialized view
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
    ELSE -- city scope
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
        ELSE -- city
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

-- Permissions (Rule 8: Least privilege)
REVOKE ALL ON FUNCTION public.get_leaderboard(text, text, bigint, integer, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_leaderboard(text, text, bigint, integer, integer) TO authenticated;

REVOKE ALL ON FUNCTION public.get_my_rank(text, text, bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_rank(text, text, bigint) TO authenticated;
