-- Migration: 20260106000000_scoring_engine.sql
-- B7: Scoring engine and ledger writes
-- 1. Function: public.score_activity(activity_id bigint) (SECURITY DEFINER, internal only)
-- 2. Wire submit_activities to call score_activity and return earned_kp
-- 3. Function: public.user_kp_total(user_id uuid)
-- 4. View: public.user_daily_kp with security_invoker = true

-- ============================================================
-- 1. SCORING ENGINE: score_activity(activity_id bigint)
-- ============================================================
-- Why SECURITY DEFINER is needed (AGENTS.md Rule 9):
-- Inserts into public.kp_ledger which is locked down from direct client mutation.
-- Strictly server-side: REVOKE ALL from authenticated, anon, PUBLIC.
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
            -- floor(quantity / 1000) * 10
            v_raw_kp := floor(v_act.quantity / 1000.0)::integer * 10;

        WHEN 'running' THEN
            -- floor(quantity * 20)
            v_raw_kp := floor(v_act.quantity * 20.0)::integer;

        WHEN 'walking_distance' THEN
            -- floor(quantity * 12)
            v_raw_kp := floor(v_act.quantity * 12.0)::integer;

        WHEN 'workout' THEN
            -- floor(quantity * 2)
            v_raw_kp := floor(v_act.quantity * 2.0)::integer;

        WHEN 'hydration' THEN
            -- floor(quantity / 250) * 5
            v_raw_kp := floor(v_act.quantity / 250.0)::integer * 5;

        WHEN 'mindfulness' THEN
            -- floor(quantity * 3)
            v_raw_kp := floor(v_act.quantity * 3.0)::integer;

        WHEN 'sleep' THEN
            -- Sleep Quality Curve (docs/KP_RULES.md §2.2):
            -- < 4h: 0, 4-5h: 10, 5-6h: 25, 6-7h: 40, 7-9h: 50, 9-10h: 35, 10-11h: 20, > 11h: 10
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
        -- 0.5x manual multiplier applied before caps
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

    -- Sum earned KP on this habit for day_local
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

    RETURN v_final_kp;
END;
$$;

-- Restrict score_activity to server-side only (not callable by clients)
REVOKE ALL ON FUNCTION public.score_activity(bigint) FROM PUBLIC, anon, authenticated;

-- ============================================================
-- 2. WIRE SUBMIT_ACTIVITIES TO SCORE IN SAME TRANSACTION
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
BEGIN
    -- 1. Validate caller authentication (AGENTS.md Rule 9)
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'ERR_UNAUTHORIZED' USING ERRCODE = '42501';
    END IF;

    -- 2. Validate payload format and batch size
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

    -- 3. Process each sample in the batch
    FOR v_sample IN SELECT * FROM jsonb_array_elements(samples)
    LOOP
        v_habit_key        := v_sample->>'habit_key';
        v_source_sample_id := v_sample->>'source_sample_id';
        v_source           := COALESCE(v_sample->>'source', 'healthkit');
        v_was_user_entered := COALESCE((v_sample->>'was_user_entered')::boolean, false);
        v_device_info      := v_sample->'device_info';

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

-- ============================================================
-- 3. FUNCTION: user_kp_total(user_id uuid)
-- ============================================================
CREATE OR REPLACE FUNCTION public.user_kp_total(p_user_id uuid)
RETURNS integer
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
    SELECT COALESCE(SUM(amount), 0)::integer
    FROM public.kp_ledger
    WHERE user_id = p_user_id;
$$;

GRANT EXECUTE ON FUNCTION public.user_kp_total(uuid) TO authenticated;

-- ============================================================
-- 4. VIEW: user_daily_kp WITH (security_invoker = true)
-- ============================================================
CREATE OR REPLACE VIEW public.user_daily_kp
WITH (security_invoker = true)
AS
SELECT
    user_id,
    day_local,
    COALESCE(SUM(amount), 0)::integer AS daily_kp,
    COALESCE(SUM(amount) FILTER (WHERE type = 'earn'), 0)::integer AS earned_kp,
    COALESCE(SUM(amount) FILTER (WHERE type = 'streak_bonus'), 0)::integer AS streak_kp,
    COALESCE(SUM(amount) FILTER (WHERE type = 'challenge_reward'), 0)::integer AS challenge_kp,
    COALESCE(SUM(amount) FILTER (WHERE type = 'achievement_reward'), 0)::integer AS achievement_kp
FROM public.kp_ledger
GROUP BY user_id, day_local;
