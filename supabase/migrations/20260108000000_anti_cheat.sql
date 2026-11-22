-- Migration: 20260108000000_anti_cheat.sql
-- B9: Anti-cheat rules & flags [REVIEW]
-- Implements docs/ANTI_CHEAT.md threat detection, rate limiting, and trust scoring.
--
-- 1. Table: blocked_sources (source bundle blocklist)
-- 2. Table: activity_flags (flag records per activity)
-- 3. Table: rate_limits (per-user per-endpoint call counters)
-- 4. Function: check_rate_limit(endpoint, max_calls)
-- 5. Function: _insert_flag (internal helper)
-- 6. Function: evaluate_activity_flags(activity_id)
-- 7. View: user_trust_score (derived trust score, internal only)
-- 8. Wire: submit_activities — add rate limit + blocklist check
-- 9. Wire: score_activity — add evaluate_activity_flags call

-- ============================================================
-- 1. BLOCKED_SOURCES TABLE (ANTI_CHEAT.md §6)
-- ============================================================
CREATE TABLE public.blocked_sources (
    id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    bundle_id   text NOT NULL UNIQUE,
    reason      text,
    added_at    timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.blocked_sources ENABLE ROW LEVEL SECURITY;

-- Read-only catalog for authenticated users
CREATE POLICY "blocked_sources_select_authenticated"
    ON public.blocked_sources FOR SELECT
    TO authenticated
    USING (true);

-- No client mutations
REVOKE INSERT, UPDATE, DELETE ON public.blocked_sources FROM authenticated, anon;
GRANT SELECT ON public.blocked_sources TO authenticated;

-- Seed initial blocklist (ANTI_CHEAT.md §6)
INSERT INTO public.blocked_sources (bundle_id, reason) VALUES
    ('com.healthdata.fake%', 'Known fake data generator pattern'),
    ('com.stepfaker.%', 'Known fake step counter pattern'),
    ('%fakesteps%', 'Fake steps pattern match'),
    ('%healthhack%', 'Health hack pattern match');

-- ============================================================
-- 2. ACTIVITY_FLAGS TABLE (ANTI_CHEAT.md §8)
-- ============================================================
CREATE TABLE public.activity_flags (
    id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    activity_id bigint NOT NULL REFERENCES public.activities(id) ON DELETE CASCADE,
    user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    rule        text NOT NULL,
    severity    text NOT NULL,
    status      text NOT NULL DEFAULT 'open',
    detail      jsonb,
    created_at  timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT valid_severity CHECK (severity IN ('HIGH', 'MEDIUM', 'LOW')),
    CONSTRAINT valid_status CHECK (status IN ('open', 'auto_resolved', 'resolved_approved', 'resolved_confirmed'))
);

-- Prevent duplicate flags for same rule on same activity
CREATE UNIQUE INDEX activity_flags_activity_rule_idx
    ON public.activity_flags (activity_id, rule);

-- Lookup by user for trust score and flag history
CREATE INDEX activity_flags_user_idx
    ON public.activity_flags (user_id, severity, created_at);

ALTER TABLE public.activity_flags ENABLE ROW LEVEL SECURITY;

-- Users can read their own flags (for activity detail screens)
CREATE POLICY "activity_flags_select_own"
    ON public.activity_flags FOR SELECT
    TO authenticated
    USING (auth.uid() = user_id);

-- No client mutations — only server-side functions
REVOKE INSERT, UPDATE, DELETE ON public.activity_flags FROM authenticated, anon;
GRANT SELECT ON public.activity_flags TO authenticated;

-- ============================================================
-- 3. RATE_LIMITS TABLE (ANTI_CHEAT.md §7)
-- ============================================================
CREATE TABLE public.rate_limits (
    id              bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id         uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    endpoint        text NOT NULL,
    window_start    timestamptz NOT NULL,
    call_count      integer NOT NULL DEFAULT 1,

    UNIQUE (user_id, endpoint, window_start)
);

ALTER TABLE public.rate_limits ENABLE ROW LEVEL SECURITY;

-- No client access at all — internal table only
-- (RLS enabled + no policies = zero access via RLS)
REVOKE ALL ON public.rate_limits FROM authenticated, anon, PUBLIC;

-- ============================================================
-- 4. FUNCTION: check_rate_limit(endpoint, max_calls)
-- ============================================================
-- Why SECURITY DEFINER is needed (AGENTS.md Rule 9):
-- Writes to rate_limits table which has no client-facing policies.
-- Called from submit_activities to enforce per-user rate limiting.
CREATE OR REPLACE FUNCTION public.check_rate_limit(p_endpoint text, p_max_calls integer)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_uid           uuid;
    v_window_start  timestamptz;
    v_count         integer;
BEGIN
    -- Validate caller (AGENTS.md Rule 9)
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'ERR_UNAUTHORIZED' USING ERRCODE = '42501';
    END IF;

    -- Validate inputs
    IF p_endpoint IS NULL OR p_max_calls IS NULL OR p_max_calls <= 0 THEN
        RAISE EXCEPTION 'ERR_INVALID_PARAMS' USING ERRCODE = '22023';
    END IF;

    -- Truncate to current hour (ANTI_CHEAT.md §7: "truncated to the hour for simplicity")
    v_window_start := date_trunc('hour', now());

    -- Upsert counter — atomic increment
    INSERT INTO public.rate_limits (user_id, endpoint, window_start, call_count)
    VALUES (v_uid, p_endpoint, v_window_start, 1)
    ON CONFLICT (user_id, endpoint, window_start)
    DO UPDATE SET call_count = rate_limits.call_count + 1
    RETURNING call_count INTO v_count;

    IF v_count > p_max_calls THEN
        RAISE EXCEPTION 'ERR_RATE_LIMITED' USING ERRCODE = 'P0429';
    END IF;
END;
$$;

-- Internal only
REVOKE ALL ON FUNCTION public.check_rate_limit(text, integer) FROM PUBLIC, anon, authenticated;

-- ============================================================
-- 5. HELPER: _insert_flag (internal)
-- ============================================================
-- Why SECURITY DEFINER is needed (AGENTS.md Rule 9):
-- Writes to activity_flags and kp_ledger (revoke rows) on behalf of the
-- anti-cheat engine. Never callable by clients.
CREATE OR REPLACE FUNCTION public._insert_flag(
    p_activity_id bigint,
    p_user_id uuid,
    p_rule text,
    p_severity text,
    p_detail jsonb
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_earned_kp     integer;
    v_day_local     date;
BEGIN
    -- Insert flag (idempotent via unique index on activity_id, rule)
    INSERT INTO public.activity_flags (activity_id, user_id, rule, severity, detail)
    VALUES (p_activity_id, p_user_id, p_rule, p_severity, p_detail)
    ON CONFLICT (activity_id, rule) DO NOTHING;

    -- HIGH severity → immediately revoke KP (ANTI_CHEAT.md §3)
    IF p_severity = 'HIGH' THEN
        -- Find the earned KP for this activity
        SELECT amount, day_local INTO v_earned_kp, v_day_local
        FROM public.kp_ledger
        WHERE idempotency_key = 'earn:' || p_activity_id;

        IF v_earned_kp IS NOT NULL AND v_earned_kp > 0 THEN
            -- Insert revoke ledger row (AGENTS.md Rule 7: idempotency key)
            INSERT INTO public.kp_ledger (
                user_id, amount, type, source_type, source_id,
                idempotency_key, day_local, metadata, created_at
            ) VALUES (
                p_user_id,
                -v_earned_kp,
                'revoke',
                'anticheat',
                p_activity_id::text,
                'revoke:' || p_activity_id,
                v_day_local,
                jsonb_build_object(
                    'rule', p_rule,
                    'severity', p_severity,
                    'original_kp', v_earned_kp
                ),
                now()
            )
            ON CONFLICT (idempotency_key) DO NOTHING;
        END IF;
    END IF;
END;
$$;

REVOKE ALL ON FUNCTION public._insert_flag(bigint, uuid, text, text, jsonb) FROM PUBLIC, anon, authenticated;

-- ============================================================
-- 6. FUNCTION: evaluate_activity_flags(activity_id)
-- ============================================================
-- Why SECURITY DEFINER is needed (AGENTS.md Rule 9):
-- Reads activities table and writes to activity_flags and kp_ledger
-- on behalf of the scoring engine. Never callable by clients.
-- Implements threshold rules from docs/ANTI_CHEAT.md §2, §5.
CREATE OR REPLACE FUNCTION public.evaluate_activity_flags(p_activity_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_act               record;
    v_duration_hours    double precision;
    v_duration_min      double precision;
    v_speed_kmh         double precision;
    v_steps_per_hour    double precision;
    v_overlap_count     integer;
    v_non_sleep_hours   double precision;
    v_day_local         date;
    v_timezone          text;
BEGIN
    -- Fetch activity with habit details
    SELECT
        a.id,
        a.user_id,
        a.habit_id,
        a.quantity,
        a.started_at,
        a.ended_at,
        a.source,
        h.key AS habit_key
    INTO v_act
    FROM public.activities a
    JOIN public.habits h ON h.id = a.habit_id
    WHERE a.id = p_activity_id;

    IF NOT FOUND THEN
        RETURN;
    END IF;

    -- Calculate duration in hours and minutes
    v_duration_hours := EXTRACT(EPOCH FROM (v_act.ended_at - v_act.started_at)) / 3600.0;
    v_duration_min := v_duration_hours * 60.0;

    -- Get user timezone for day calculation (OV-R3 needs it)
    SELECT COALESCE(c.iana_timezone, 'Asia/Kolkata') INTO v_timezone
    FROM public.profiles p
    LEFT JOIN public.cities c ON c.id = p.city_id
    WHERE p.id = v_act.user_id;
    v_timezone := COALESCE(v_timezone, 'Asia/Kolkata');
    v_day_local := (v_act.started_at AT TIME ZONE v_timezone)::date;

    -- ========================================
    -- IMPOSSIBLE VALUE CHECKS (ANTI_CHEAT.md §2 T1, T7)
    -- ========================================

    IF v_act.habit_key = 'steps' THEN
        -- T1-R3 / T7-R1: Steps per hour > 15,000
        IF v_duration_hours > 0 THEN
            v_steps_per_hour := v_act.quantity / v_duration_hours;
            IF v_steps_per_hour > 15000 THEN
                PERFORM public._insert_flag(p_activity_id, v_act.user_id, 'T1-R3', 'HIGH',
                    jsonb_build_object('steps_per_hour', round(v_steps_per_hour::numeric, 1), 'threshold', 15000));
            END IF;
        END IF;

        -- T7-R2: Steps > 80,000 in one sample
        IF v_act.quantity > 80000 THEN
            PERFORM public._insert_flag(p_activity_id, v_act.user_id, 'T7-R2', 'HIGH',
                jsonb_build_object('steps', v_act.quantity, 'threshold', 80000));
        END IF;

    ELSIF v_act.habit_key = 'running' THEN
        -- T1-R4 / T7-R3: Running speed > 25 km/h, session > 10 min
        IF v_duration_min > 10 AND v_duration_hours > 0 THEN
            v_speed_kmh := v_act.quantity / v_duration_hours;
            IF v_speed_kmh > 25 THEN
                PERFORM public._insert_flag(p_activity_id, v_act.user_id, 'T1-R4', 'HIGH',
                    jsonb_build_object('speed_kmh', round(v_speed_kmh::numeric, 1), 'threshold', 25));
            END IF;
        END IF;

        -- T7-R4: Running distance > 100 km in one session
        IF v_act.quantity > 100 THEN
            PERFORM public._insert_flag(p_activity_id, v_act.user_id, 'T7-R4', 'HIGH',
                jsonb_build_object('distance_km', v_act.quantity, 'threshold', 100));
        END IF;

    ELSIF v_act.habit_key = 'walking_distance' THEN
        -- T1-R5 / T7-R6: Walking speed > 10 km/h, session > 10 min
        IF v_duration_min > 10 AND v_duration_hours > 0 THEN
            v_speed_kmh := v_act.quantity / v_duration_hours;
            IF v_speed_kmh > 10 THEN
                PERFORM public._insert_flag(p_activity_id, v_act.user_id, 'T1-R5', 'MEDIUM',
                    jsonb_build_object('speed_kmh', round(v_speed_kmh::numeric, 1), 'threshold', 10));
            END IF;
        END IF;

        -- T7-R7: Walking distance > 50 km in one session
        IF v_act.quantity > 50 THEN
            PERFORM public._insert_flag(p_activity_id, v_act.user_id, 'T7-R7', 'MEDIUM',
                jsonb_build_object('distance_km', v_act.quantity, 'threshold', 50));
        END IF;

    ELSIF v_act.habit_key = 'workout' THEN
        -- T7-R8: Workout duration > 480 min (8 hours)
        IF v_act.quantity > 480 THEN
            PERFORM public._insert_flag(p_activity_id, v_act.user_id, 'T7-R8', 'MEDIUM',
                jsonb_build_object('duration_min', v_act.quantity, 'threshold', 480));
        END IF;

    ELSIF v_act.habit_key = 'hydration' THEN
        -- T7-R10: Hydration > 2,000 ml per entry
        IF v_act.quantity > 2000 THEN
            PERFORM public._insert_flag(p_activity_id, v_act.user_id, 'T7-R10', 'MEDIUM',
                jsonb_build_object('volume_ml', v_act.quantity, 'threshold', 2000));
        END IF;

    ELSIF v_act.habit_key = 'sleep' THEN
        -- T7-R12: Sleep > 16 hours in one session
        IF v_act.quantity > 16 THEN
            PERFORM public._insert_flag(p_activity_id, v_act.user_id, 'T7-R12', 'MEDIUM',
                jsonb_build_object('duration_hours', v_act.quantity, 'threshold', 16));
        END IF;

    ELSIF v_act.habit_key = 'mindfulness' THEN
        -- T7-R13: Mindfulness > 180 min in one session
        IF v_act.quantity > 180 THEN
            PERFORM public._insert_flag(p_activity_id, v_act.user_id, 'T7-R13', 'MEDIUM',
                jsonb_build_object('duration_min', v_act.quantity, 'threshold', 180));
        END IF;
    END IF;

    -- ========================================
    -- OVERLAPPING SAMPLE CHECKS (ANTI_CHEAT.md §5)
    -- ========================================

    -- OV-R1: Same-habit time overlap > 50%
    SELECT COUNT(*) INTO v_overlap_count
    FROM public.activities other
    WHERE other.user_id = v_act.user_id
      AND other.habit_id = v_act.habit_id
      AND other.id != p_activity_id
      AND other.started_at < v_act.ended_at
      AND other.ended_at > v_act.started_at
      -- Overlap portion > 50% of the current activity's duration
      AND EXTRACT(EPOCH FROM (
            LEAST(other.ended_at, v_act.ended_at) - GREATEST(other.started_at, v_act.started_at)
          )) / NULLIF(EXTRACT(EPOCH FROM (v_act.ended_at - v_act.started_at)), 0) > 0.5;

    IF v_overlap_count > 0 THEN
        PERFORM public._insert_flag(p_activity_id, v_act.user_id, 'OV-R1', 'MEDIUM',
            jsonb_build_object('overlapping_count', v_overlap_count));
    END IF;

    -- OV-R2: Conflicting habits overlap — activity during sleep
    IF v_act.habit_key IN ('running', 'workout', 'walking_distance', 'steps') THEN
        SELECT COUNT(*) INTO v_overlap_count
        FROM public.activities other
        JOIN public.habits h ON h.id = other.habit_id
        WHERE other.user_id = v_act.user_id
          AND h.key = 'sleep'
          AND other.id != p_activity_id
          AND other.started_at < v_act.ended_at
          AND other.ended_at > v_act.started_at;

        IF v_overlap_count > 0 THEN
            PERFORM public._insert_flag(p_activity_id, v_act.user_id, 'OV-R2', 'HIGH',
                jsonb_build_object('conflict', 'activity_during_sleep'));
        END IF;
    END IF;

    -- OV-R3: > 20 hours non-sleep activity in one day
    IF v_act.habit_key != 'sleep' THEN
        SELECT COALESCE(SUM(
            EXTRACT(EPOCH FROM (a.ended_at - a.started_at)) / 3600.0
        ), 0) INTO v_non_sleep_hours
        FROM public.activities a
        JOIN public.habits h ON h.id = a.habit_id
        WHERE a.user_id = v_act.user_id
          AND h.key != 'sleep'
          AND (a.started_at AT TIME ZONE v_timezone)::date = v_day_local;

        IF v_non_sleep_hours > 20 THEN
            PERFORM public._insert_flag(p_activity_id, v_act.user_id, 'OV-R3', 'HIGH',
                jsonb_build_object('non_sleep_hours', round(v_non_sleep_hours::numeric, 1), 'threshold', 20));
        END IF;
    END IF;

END;
$$;

REVOKE ALL ON FUNCTION public.evaluate_activity_flags(bigint) FROM PUBLIC, anon, authenticated;

-- ============================================================
-- 7. VIEW: user_trust_score (ANTI_CHEAT.md §4)
-- ============================================================
-- Internal only — "Trust score is never shown to the user"
-- Formula: 100 - (HIGH×25) - (MEDIUM×10) - (LOW×2) + min(verified_days, 20)
-- Flags > 90 days old contribute 50% weight
CREATE OR REPLACE VIEW public.user_trust_score AS
SELECT
    p.id AS user_id,
    GREATEST(0, LEAST(100,
        100
        -- Deduct for HIGH severity flags (open or confirmed)
        - COALESCE((
            SELECT SUM(
                CASE WHEN f.created_at < now() - interval '90 days' THEN 13  -- 50% of 25
                     ELSE 25
                END
            )
            FROM public.activity_flags f
            WHERE f.user_id = p.id
              AND f.severity = 'HIGH'
              AND f.status IN ('open', 'resolved_confirmed')
        ), 0)
        -- Deduct for MEDIUM severity flags
        - COALESCE((
            SELECT SUM(
                CASE WHEN f.created_at < now() - interval '90 days' THEN 5  -- 50% of 10
                     ELSE 10
                END
            )
            FROM public.activity_flags f
            WHERE f.user_id = p.id
              AND f.severity = 'MEDIUM'
              AND f.status IN ('open', 'resolved_confirmed')
        ), 0)
        -- Deduct for LOW severity flags
        - COALESCE((
            SELECT SUM(
                CASE WHEN f.created_at < now() - interval '90 days' THEN 1  -- 50% of 2
                     ELSE 2
                END
            )
            FROM public.activity_flags f
            WHERE f.user_id = p.id
              AND f.severity = 'LOW'
              AND f.status IN ('open', 'resolved_confirmed')
        ), 0)
        -- Bonus for verified activity days (max +20)
        + LEAST(20, COALESCE((
            SELECT COUNT(DISTINCT day_local)
            FROM public.kp_ledger l
            WHERE l.user_id = p.id
              AND l.type = 'earn'
              AND (l.metadata->>'verification_status') = 'verified'
        ), 0))
    ))::integer AS trust_score
FROM public.profiles p;

-- Internal only — no client access
REVOKE ALL ON public.user_trust_score FROM authenticated, anon, PUBLIC;

-- ============================================================
-- 8. WIRE: submit_activities — add rate limit + blocklist
-- ============================================================
CREATE OR REPLACE FUNCTION public.submit_activities(samples jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_uid               uuid;
    v_batch_len         integer;
    v_results           jsonb := '[]'::jsonb;
    v_sample            jsonb;
    v_habit_key         text;
    v_habit_id          bigint;
    v_habit_active      boolean;
    v_manual_allowed    boolean;
    v_quantity          double precision;
    v_started_at        timestamptz;
    v_ended_at          timestamptz;
    v_source            text;
    v_source_sample_id  text;
    v_was_user_entered  boolean;
    v_device_info       jsonb;
    v_verification      text;
    v_activity_id       bigint;
    v_earned_kp         integer;
    v_bundle_id         text;
    v_blocked           boolean;
BEGIN
    -- 1. Validate caller authentication (AGENTS.md Rule 9)
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'ERR_UNAUTHORIZED' USING ERRCODE = '42501';
    END IF;

    -- 2. Rate limit check (ANTI_CHEAT.md §7: 60 calls/hour per user)
    PERFORM public.check_rate_limit('submit_activities', 60);

    -- 3. Validate payload format and batch size
    IF samples IS NULL OR jsonb_typeof(samples) != 'array' THEN
        RAISE EXCEPTION 'ERR_INVALID_PAYLOAD' USING ERRCODE = '22023';
    END IF;

    v_batch_len := jsonb_array_length(samples);

    IF v_batch_len > 500 THEN
        RAISE EXCEPTION 'ERR_BATCH_TOO_LARGE' USING ERRCODE = '22023';
    END IF;

    IF v_batch_len = 0 THEN
        RETURN '[]'::jsonb;
    END IF;

    -- 4. Process each sample in the batch
    FOR v_sample IN SELECT * FROM jsonb_array_elements(samples)
    LOOP
        v_habit_key        := v_sample->>'habit_key';
        v_source_sample_id := v_sample->>'source_sample_id';
        v_source           := COALESCE(v_sample->>'source', 'healthkit');
        v_was_user_entered := COALESCE((v_sample->>'was_user_entered')::boolean, false);
        v_device_info      := v_sample->'device_info';

        -- Source bundle blocklist check (ANTI_CHEAT.md §6, T1-R1)
        v_bundle_id := v_device_info->>'bundle_id';
        IF v_bundle_id IS NOT NULL THEN
            SELECT EXISTS (
                SELECT 1 FROM public.blocked_sources bs
                WHERE lower(v_bundle_id) LIKE lower(bs.bundle_id)
            ) INTO v_blocked;

            IF v_blocked THEN
                v_results := v_results || jsonb_build_object(
                    'status', 'rejected',
                    'source_sample_id', v_source_sample_id,
                    'reason', 'blocked_source'
                );
                CONTINUE;
            END IF;
        END IF;

        -- Parse quantity
        BEGIN
            v_quantity := (v_sample->>'quantity')::double precision;
        EXCEPTION WHEN OTHERS THEN
            v_results := v_results || jsonb_build_object(
                'status', 'rejected',
                'source_sample_id', v_source_sample_id,
                'reason', 'invalid_quantity'
            );
            CONTINUE;
        END;

        -- Parse timestamps
        BEGIN
            v_started_at := (v_sample->>'started_at')::timestamptz;
            v_ended_at   := (v_sample->>'ended_at')::timestamptz;
        EXCEPTION WHEN OTHERS THEN
            v_results := v_results || jsonb_build_object(
                'status', 'rejected',
                'source_sample_id', v_source_sample_id,
                'reason', 'invalid_time_range'
            );
            CONTINUE;
        END;

        -- Check quantity
        IF v_quantity IS NULL OR v_quantity <= 0 THEN
            v_results := v_results || jsonb_build_object(
                'status', 'rejected',
                'source_sample_id', v_source_sample_id,
                'reason', 'invalid_quantity'
            );
            CONTINUE;
        END IF;

        -- Check time range sanity
        IF v_started_at IS NULL OR v_ended_at IS NULL OR v_started_at >= v_ended_at THEN
            v_results := v_results || jsonb_build_object(
                'status', 'rejected',
                'source_sample_id', v_source_sample_id,
                'reason', 'invalid_time_range'
            );
            CONTINUE;
        END IF;

        -- Check future date (> now + 1 hour clock drift tolerance)
        IF v_started_at > now() + interval '1 hour' THEN
            v_results := v_results || jsonb_build_object(
                'status', 'rejected',
                'source_sample_id', v_source_sample_id,
                'reason', 'future_date'
            );
            CONTINUE;
        END IF;

        -- Check age limit (< now - 7 days per KP_RULES.md §10)
        IF v_started_at < now() - interval '7 days' THEN
            v_results := v_results || jsonb_build_object(
                'status', 'rejected',
                'source_sample_id', v_source_sample_id,
                'reason', 'too_old'
            );
            CONTINUE;
        END IF;

        -- Check source validity
        IF v_source NOT IN ('healthkit', 'manual') THEN
            v_results := v_results || jsonb_build_object(
                'status', 'rejected',
                'source_sample_id', v_source_sample_id,
                'reason', 'invalid_source'
            );
            CONTINUE;
        END IF;

        -- Check habit existence in catalog
        SELECT id, manual_allowed INTO v_habit_id, v_manual_allowed
        FROM public.habits
        WHERE key = v_habit_key;

        IF v_habit_id IS NULL THEN
            v_results := v_results || jsonb_build_object(
                'status', 'rejected',
                'source_sample_id', v_source_sample_id,
                'reason', 'bad_habit'
            );
            CONTINUE;
        END IF;

        -- Check if habit is active in user's habits
        SELECT active INTO v_habit_active
        FROM public.user_habits
        WHERE user_id = v_uid AND habit_id = v_habit_id;

        IF v_habit_active IS NOT TRUE THEN
            v_results := v_results || jsonb_build_object(
                'status', 'rejected',
                'source_sample_id', v_source_sample_id,
                'reason', 'habit_not_active'
            );
            CONTINUE;
        END IF;

        -- Check manual allowed for this habit if source is manual
        IF v_source = 'manual' AND NOT v_manual_allowed THEN
            v_results := v_results || jsonb_build_object(
                'status', 'rejected',
                'source_sample_id', v_source_sample_id,
                'reason', 'manual_not_allowed'
            );
            CONTINUE;
        END IF;

        -- Classify verification status:
        -- healthkit + was_user_entered false -> verified
        -- manual OR was_user_entered true -> unverified
        IF v_source = 'healthkit' AND NOT v_was_user_entered THEN
            v_verification := 'verified';
        ELSE
            v_verification := 'unverified';
        END IF;

        -- Insert with ON CONFLICT DO NOTHING on dedupe index
        v_activity_id := NULL;
        INSERT INTO public.activities (
            user_id,
            habit_id,
            quantity,
            started_at,
            ended_at,
            source,
            source_sample_id,
            was_user_entered,
            device_info,
            verification_status,
            created_at
        ) VALUES (
            v_uid,
            v_habit_id,
            v_quantity,
            v_started_at,
            v_ended_at,
            v_source,
            v_source_sample_id,
            v_was_user_entered,
            v_device_info,
            v_verification,
            now()
        )
        ON CONFLICT (user_id, source_sample_id) WHERE source_sample_id IS NOT NULL
        DO NOTHING
        RETURNING id INTO v_activity_id;

        IF v_activity_id IS NULL AND v_source_sample_id IS NOT NULL THEN
            -- Duplicate detected
            v_results := v_results || jsonb_build_object(
                'status', 'duplicate',
                'source_sample_id', v_source_sample_id
            );
        ELSE
            -- Score activity in the same transaction
            v_earned_kp := public.score_activity(v_activity_id);

            -- Accepted
            v_results := v_results || jsonb_build_object(
                'status', 'accepted',
                'activity_id', v_activity_id,
                'source_sample_id', v_source_sample_id,
                'verification_status', v_verification,
                'earned_kp', v_earned_kp
            );
        END IF;
    END LOOP;

    RETURN v_results;
END;
$$;

-- Preserve existing grants
REVOKE ALL ON FUNCTION public.submit_activities(jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_activities(jsonb) TO authenticated;

-- ============================================================
-- 9. WIRE: score_activity — add evaluate_activity_flags call
-- ============================================================
CREATE OR REPLACE FUNCTION public.score_activity(p_activity_id bigint)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_act                 record;
    v_timezone            text;
    v_day_local           date;
    v_raw_kp              integer := 0;
    v_effective_kp        integer := 0;
    v_effective_cap       integer;
    v_habit_earned_today  integer := 0;
    v_global_earned_today integer := 0;
    v_habit_room          integer := 0;
    v_global_room         integer := 0;
    v_final_kp            integer := 0;
    v_idempotency_key     text;
BEGIN
    -- 1. Fetch activity details along with habit configuration
    SELECT
        a.id,
        a.user_id,
        a.habit_id,
        a.quantity,
        a.started_at,
        a.ended_at,
        a.source,
        a.was_user_entered,
        a.verification_status,
        h.key AS habit_key,
        h.formula_type,
        h.formula_params,
        h.daily_kp_cap,
        h.manual_kp_cap,
        h.manual_allowed
    INTO v_act
    FROM public.activities a
    JOIN public.habits h ON h.id = a.habit_id
    WHERE a.id = p_activity_id;

    IF NOT FOUND THEN
        RETURN 0;
    END IF;

    -- Check if already scored (idempotency check per AGENTS.md Rule 7)
    v_idempotency_key := 'earn:' || p_activity_id;
    IF EXISTS (SELECT 1 FROM public.kp_ledger WHERE idempotency_key = v_idempotency_key) THEN
        SELECT amount INTO v_final_kp FROM public.kp_ledger WHERE idempotency_key = v_idempotency_key;
        RETURN v_final_kp;
    END IF;

    -- 2. Determine user's local timezone & local day
    SELECT COALESCE(c.iana_timezone, 'Asia/Kolkata') INTO v_timezone
    FROM public.profiles p
    LEFT JOIN public.cities c ON c.id = p.city_id
    WHERE p.id = v_act.user_id;

    v_timezone := COALESCE(v_timezone, 'Asia/Kolkata');
    v_day_local := (v_act.started_at AT TIME ZONE v_timezone)::date;

    -- 3. Calculate Raw KP based on formula (docs/KP_RULES.md §2)
    CASE v_act.habit_key
        WHEN 'steps' THEN
            v_raw_kp := floor(v_act.quantity / 1000.0)::integer * 10;
        WHEN 'running' THEN
            v_raw_kp := floor(v_act.quantity * 20.0)::integer;
        WHEN 'walking_distance' THEN
            v_raw_kp := floor(v_act.quantity * 12.0)::integer;
        WHEN 'workout' THEN
            v_raw_kp := floor(v_act.quantity * 2.0)::integer;
        WHEN 'hydration' THEN
            v_raw_kp := floor(v_act.quantity / 250.0)::integer * 5;
        WHEN 'mindfulness' THEN
            v_raw_kp := floor(v_act.quantity * 3.0)::integer;
        WHEN 'sleep' THEN
            IF v_act.quantity < 4.0 THEN
                v_raw_kp := 0;
            ELSIF v_act.quantity < 5.0 THEN
                v_raw_kp := 10;
            ELSIF v_act.quantity < 6.0 THEN
                v_raw_kp := 25;
            ELSIF v_act.quantity < 7.0 THEN
                v_raw_kp := 40;
            ELSIF v_act.quantity <= 9.0 THEN
                v_raw_kp := 50;
            ELSIF v_act.quantity <= 10.0 THEN
                v_raw_kp := 35;
            ELSIF v_act.quantity <= 11.0 THEN
                v_raw_kp := 20;
            ELSE
                v_raw_kp := 10;
            END IF;
        ELSE
            v_raw_kp := 0;
    END CASE;

    IF v_raw_kp <= 0 THEN
        RETURN 0;
    END IF;

    -- 4. Apply Multiplier (docs/KP_RULES.md §2.3)
    IF v_act.verification_status = 'unverified' THEN
        v_effective_kp := floor(v_raw_kp * 0.5)::integer;
    ELSE
        v_effective_kp := v_raw_kp;
    END IF;

    IF v_effective_kp <= 0 THEN
        RETURN 0;
    END IF;

    -- 5. Per-Habit Cap Enforcement (docs/KP_RULES.md §3.1)
    IF v_act.verification_status = 'unverified' AND v_act.manual_kp_cap IS NOT NULL THEN
        v_effective_cap := v_act.manual_kp_cap;
    ELSE
        v_effective_cap := v_act.daily_kp_cap;
    END IF;

    SELECT COALESCE(SUM(amount), 0)::integer INTO v_habit_earned_today
    FROM public.kp_ledger
    WHERE user_id = v_act.user_id
      AND day_local = v_day_local
      AND type = 'earn'
      AND source_type = 'activity'
      AND (metadata->>'habit_key') = v_act.habit_key;

    v_habit_room := GREATEST(0, v_effective_cap - v_habit_earned_today);
    v_final_kp := LEAST(v_effective_kp, v_habit_room);

    IF v_final_kp <= 0 THEN
        RETURN 0;
    END IF;

    -- 6. Global Daily Cap Enforcement (500 KP per docs/KP_RULES.md §3.2)
    SELECT COALESCE(SUM(amount), 0)::integer INTO v_global_earned_today
    FROM public.kp_ledger
    WHERE user_id = v_act.user_id
      AND day_local = v_day_local
      AND type = 'earn'
      AND source_type = 'activity';

    v_global_room := GREATEST(0, 500 - v_global_earned_today);
    v_final_kp := LEAST(v_final_kp, v_global_room);

    IF v_final_kp <= 0 THEN
        RETURN 0;
    END IF;

    -- 7. Write to Append-Only Ledger (AGENTS.md Rule 1 & 7)
    INSERT INTO public.kp_ledger (
        user_id,
        amount,
        type,
        source_type,
        source_id,
        idempotency_key,
        day_local,
        metadata,
        created_at
    ) VALUES (
        v_act.user_id,
        v_final_kp,
        'earn',
        'activity',
        p_activity_id::text,
        v_idempotency_key,
        v_day_local,
        jsonb_build_object(
            'habit_key', v_act.habit_key,
            'quantity', v_act.quantity,
            'verification_status', v_act.verification_status,
            'raw_kp', v_raw_kp,
            'effective_kp', v_effective_kp
        ),
        now()
    )
    ON CONFLICT (idempotency_key) DO NOTHING;

    -- 8. Evaluate Streaks (docs/KP_RULES.md §4)
    IF v_final_kp > 0 THEN
        PERFORM public.evaluate_user_streak(v_act.user_id, v_day_local);
    END IF;

    -- 9. Evaluate Anti-Cheat Flags (docs/ANTI_CHEAT.md)
    PERFORM public.evaluate_activity_flags(p_activity_id);

    RETURN v_final_kp;
END;
$$;

-- Preserve existing revoke
REVOKE ALL ON FUNCTION public.score_activity(bigint) FROM PUBLIC, anon, authenticated;
