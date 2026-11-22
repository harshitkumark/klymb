-- Migration: 20260105000000_activity_submission.sql
-- B6: Activity submission RPC
-- Validates, dedupes, classifies, and inserts batches of activity samples (up to 500)

-- ============================================================
-- RPC: submit_activities(samples jsonb)
-- ============================================================
-- Why SECURITY DEFINER is needed (AGENTS.md Rule 9):
-- Inserts into public.activities on behalf of authenticated users without granting
-- direct client INSERT privileges on activities. Strictly enforces user ownership
-- (auth.uid()), deduplication, input sanitization, and verification status.
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
            -- Accepted
            v_results := v_results || jsonb_build_object(
                'status', 'accepted',
                'activity_id', v_activity_id,
                'source_sample_id', v_source_sample_id,
                'verification_status', v_verification
            );
        END IF;
    END LOOP;

    RETURN v_results;
END;
$$;

-- Grant permissions (Rule 8: Least Privilege)
REVOKE ALL ON FUNCTION public.submit_activities(jsonb) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.submit_activities(jsonb) TO authenticated;
