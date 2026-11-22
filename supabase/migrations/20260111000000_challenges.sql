-- Migration: 20260111000000_challenges.sql
-- B12: Challenges
-- Implements docs/ARCHITECTURE.md §2.2 & docs/KP_RULES.md §5
--
-- 1. Tables:
--    - challenges (daily, weekly, community)
--    - challenge_participants (registrations)
--    - challenge_progress (progress tracking, completed_at, rank)
-- 2. Indexes and RLS policies
-- 3. Functions:
--    - join_challenge(challenge_id)
--    - leave_challenge(challenge_id)
--    - get_challenge_standings(challenge_id, limit_val, offset_val)
--    - update_challenge_progress(user_id, habit_key, quantity, activity_time)
--    - finalize_challenge(challenge_id)
-- 4. Wire score_activity to call update_challenge_progress
-- 5. pg_cron schedule definitions

-- ============================================================
-- 1. CHALLENGES TABLES
-- ============================================================

CREATE TABLE public.challenges (
    id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    type        text NOT NULL,                 -- 'daily', 'weekly', 'community'
    title       text NOT NULL,
    description text,
    habit_key   text NOT NULL REFERENCES public.habits(key),
    target      double precision NOT NULL CHECK (target > 0),
    reward_kp   integer NOT NULL DEFAULT 50,
    start_at    timestamptz NOT NULL,
    end_at      timestamptz NOT NULL,
    status      text NOT NULL DEFAULT 'upcoming',
    created_at  timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT valid_challenge_type CHECK (type IN ('daily', 'weekly', 'community')),
    CONSTRAINT valid_challenge_status CHECK (status IN ('upcoming', 'active', 'completed', 'finalized')),
    CONSTRAINT valid_challenge_window CHECK (start_at < end_at)
);

CREATE INDEX challenges_status_idx ON public.challenges (status, start_at, end_at);
CREATE INDEX challenges_habit_idx ON public.challenges (habit_key, status);

ALTER TABLE public.challenges ENABLE ROW LEVEL SECURITY;

-- Read-only catalog of challenges for authenticated users
CREATE POLICY "challenges_select_authenticated"
    ON public.challenges FOR SELECT
    TO authenticated
    USING (true);

REVOKE INSERT, UPDATE, DELETE ON public.challenges FROM authenticated, anon;
GRANT SELECT ON public.challenges TO authenticated;

-- Challenge Participants
CREATE TABLE public.challenge_participants (
    id           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    challenge_id bigint NOT NULL REFERENCES public.challenges(id) ON DELETE CASCADE,
    user_id      uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    joined_at    timestamptz NOT NULL DEFAULT now(),

    UNIQUE (challenge_id, user_id)
);

CREATE INDEX challenge_participants_user_idx ON public.challenge_participants (user_id);

ALTER TABLE public.challenge_participants ENABLE ROW LEVEL SECURITY;

CREATE POLICY "challenge_participants_select_authenticated"
    ON public.challenge_participants FOR SELECT
    TO authenticated
    USING (true);

REVOKE INSERT, UPDATE, DELETE ON public.challenge_participants FROM authenticated, anon;
GRANT SELECT ON public.challenge_participants TO authenticated;

-- Challenge Progress
CREATE TABLE public.challenge_progress (
    id            bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    challenge_id  bigint NOT NULL REFERENCES public.challenges(id) ON DELETE CASCADE,
    user_id       uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    current_value double precision NOT NULL DEFAULT 0.0 CHECK (current_value >= 0),
    completed_at  timestamptz,
    rank          integer,
    updated_at    timestamptz NOT NULL DEFAULT now(),

    UNIQUE (challenge_id, user_id)
);

CREATE INDEX challenge_progress_lookup_idx ON public.challenge_progress (challenge_id, completed_at, current_value DESC);
CREATE INDEX challenge_progress_user_idx ON public.challenge_progress (user_id);

ALTER TABLE public.challenge_progress ENABLE ROW LEVEL SECURITY;

CREATE POLICY "challenge_progress_select_authenticated"
    ON public.challenge_progress FOR SELECT
    TO authenticated
    USING (true);

REVOKE INSERT, UPDATE, DELETE ON public.challenge_progress FROM authenticated, anon;
GRANT SELECT ON public.challenge_progress TO authenticated;

-- ============================================================
-- 2. CLIENT-FACING RPCS
-- ============================================================

-- Join challenge
CREATE OR REPLACE FUNCTION public.join_challenge(p_challenge_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_uid uuid;
    v_ch record;
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'ERR_UNAUTHORIZED' USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_ch FROM public.challenges WHERE id = p_challenge_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'ERR_CHALLENGE_NOT_FOUND' USING ERRCODE = '22023';
    END IF;

    IF v_ch.status NOT IN ('upcoming', 'active') OR now() > v_ch.end_at THEN
        RAISE EXCEPTION 'ERR_CHALLENGE_NOT_JOINABLE' USING ERRCODE = '22023';
    END IF;

    -- Register participant
    INSERT INTO public.challenge_participants (challenge_id, user_id)
    VALUES (p_challenge_id, v_uid)
    ON CONFLICT (challenge_id, user_id) DO NOTHING;

    -- Initialize progress row
    INSERT INTO public.challenge_progress (challenge_id, user_id, current_value)
    VALUES (p_challenge_id, v_uid, 0.0)
    ON CONFLICT (challenge_id, user_id) DO NOTHING;

    RETURN jsonb_build_object('status', 'joined', 'challenge_id', p_challenge_id);
END;
$$;

-- Leave challenge
CREATE OR REPLACE FUNCTION public.leave_challenge(p_challenge_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_uid uuid;
    v_ch record;
    v_completed_at timestamptz;
BEGIN
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'ERR_UNAUTHORIZED' USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_ch FROM public.challenges WHERE id = p_challenge_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'ERR_CHALLENGE_NOT_FOUND' USING ERRCODE = '22023';
    END IF;

    IF v_ch.status IN ('completed', 'finalized') THEN
        RAISE EXCEPTION 'ERR_CANNOT_LEAVE_FINISHED' USING ERRCODE = '22023';
    END IF;

    SELECT completed_at INTO v_completed_at
    FROM public.challenge_progress
    WHERE challenge_id = p_challenge_id AND user_id = v_uid;

    IF v_completed_at IS NOT NULL THEN
        RAISE EXCEPTION 'ERR_CANNOT_LEAVE_COMPLETED' USING ERRCODE = '22023';
    END IF;

    DELETE FROM public.challenge_participants
    WHERE challenge_id = p_challenge_id AND user_id = v_uid;

    DELETE FROM public.challenge_progress
    WHERE challenge_id = p_challenge_id AND user_id = v_uid;

    RETURN jsonb_build_object('status', 'left', 'challenge_id', p_challenge_id);
END;
$$;

-- Get challenge standings
CREATE OR REPLACE FUNCTION public.get_challenge_standings(
    p_challenge_id bigint,
    p_limit integer DEFAULT 50,
    p_offset integer DEFAULT 0
)
RETURNS TABLE (
    rank integer,
    user_id uuid,
    username text,
    avatar_preset text,
    current_value double precision,
    target double precision,
    completed boolean,
    completed_at timestamptz
)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_limit integer := COALESCE(p_limit, 50);
    v_offset integer := COALESCE(p_offset, 0);
    v_target double precision;
BEGIN
    SELECT c.target INTO v_target FROM public.challenges c WHERE c.id = p_challenge_id;
    IF v_target IS NULL THEN
        RAISE EXCEPTION 'ERR_CHALLENGE_NOT_FOUND' USING ERRCODE = '22023';
    END IF;

    IF v_limit < 1 OR v_limit > 100 THEN
        v_limit := 50;
    END IF;

    IF v_offset < 0 THEN
        v_offset := 0;
    END IF;

    RETURN QUERY
    SELECT
        DENSE_RANK() OVER (
            ORDER BY 
                (cp.completed_at IS NOT NULL) DESC,
                cp.completed_at ASC NULLS LAST,
                cp.current_value DESC
        )::integer AS rank,
        cp.user_id,
        p.username,
        p.avatar_preset,
        cp.current_value,
        v_target AS target,
        (cp.completed_at IS NOT NULL) AS completed,
        cp.completed_at
    FROM public.challenge_progress cp
    JOIN public.profiles p ON p.id = cp.user_id
    WHERE cp.challenge_id = p_challenge_id
    ORDER BY rank ASC, p.username ASC
    LIMIT v_limit OFFSET v_offset;
END;
$$;

REVOKE ALL ON FUNCTION public.join_challenge(bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.join_challenge(bigint) TO authenticated;

REVOKE ALL ON FUNCTION public.leave_challenge(bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.leave_challenge(bigint) TO authenticated;

REVOKE ALL ON FUNCTION public.get_challenge_standings(bigint, integer, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_challenge_standings(bigint, integer, integer) TO authenticated;

-- ============================================================
-- 3. INTERNAL FUNCTION: update_challenge_progress
-- ============================================================
-- Why SECURITY DEFINER is needed (AGENTS.md Rule 9):
-- Updates challenge_progress when an activity is scored. Never client-callable.
CREATE OR REPLACE FUNCTION public.update_challenge_progress(
    p_user_id uuid,
    p_habit_key text,
    p_quantity double precision,
    p_activity_time timestamptz
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_ch record;
    v_new_val double precision;
    v_completed_now boolean;
BEGIN
    IF p_user_id IS NULL OR p_habit_key IS NULL OR p_quantity IS NULL OR p_quantity <= 0 THEN
        RETURN;
    END IF;

    -- Find matching active challenges the user is participating in
    FOR v_ch IN
        SELECT c.id, c.target, cp.current_value, cp.completed_at
        FROM public.challenges c
        JOIN public.challenge_progress cp ON cp.challenge_id = c.id AND cp.user_id = p_user_id
        WHERE c.habit_key = p_habit_key
          AND c.status = 'active'
          AND p_activity_time >= c.start_at
          AND p_activity_time <= c.end_at
    LOOP
        v_new_val := v_ch.current_value + p_quantity;
        v_completed_now := (v_ch.completed_at IS NULL AND v_new_val >= v_ch.target);

        UPDATE public.challenge_progress
        SET current_value = v_new_val,
            completed_at = CASE 
                WHEN v_completed_now THEN COALESCE(p_activity_time, now())
                ELSE completed_at 
            END,
            updated_at = now()
        WHERE challenge_id = v_ch.id AND user_id = p_user_id;
    END LOOP;
END;
$$;

REVOKE ALL ON FUNCTION public.update_challenge_progress(uuid, text, double precision, timestamptz) FROM PUBLIC, anon, authenticated;

-- ============================================================
-- 4. INTERNAL FUNCTION: finalize_challenge
-- ============================================================
-- Why SECURITY DEFINER is needed (AGENTS.md Rule 9):
-- Freezes rankings and writes reward ledger rows. Never client-callable.
-- Strictly idempotent per AGENTS.md Rule 7.
CREATE OR REPLACE FUNCTION public.finalize_challenge(p_challenge_id bigint)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_ch record;
    v_rec record;
    v_rank integer := 0;
    v_completion_reward integer;
    v_top3_bonus integer;
    v_first_bonus integer;
    v_day_local date;
    v_idem_key text;
BEGIN
    SELECT * INTO v_ch
    FROM public.challenges
    WHERE id = p_challenge_id;

    IF NOT FOUND THEN
        RETURN;
    END IF;

    -- If already finalized, do not re-process
    IF v_ch.status = 'finalized' THEN
        RETURN;
    END IF;

    -- Reward matrix per KP_RULES.md §5:
    IF v_ch.type = 'weekly' THEN
        v_completion_reward := 150;
        v_top3_bonus := 300;
        v_first_bonus := 150;
    ELSE -- daily & community default
        v_completion_reward := 50;
        v_top3_bonus := 100;
        v_first_bonus := 50;
    END IF;

    v_day_local := (v_ch.end_at AT TIME ZONE 'Asia/Kolkata')::date;

    -- Iterate completed participants ordered by earliest completion time
    FOR v_rec IN
        SELECT
            cp.user_id,
            cp.current_value,
            cp.completed_at,
            ROW_NUMBER() OVER (ORDER BY cp.completed_at ASC, cp.current_value DESC) AS finish_rank
        FROM public.challenge_progress cp
        WHERE cp.challenge_id = p_challenge_id
          AND cp.completed_at IS NOT NULL
        ORDER BY finish_rank ASC
    LOOP
        v_rank := v_rec.finish_rank;

        -- 1. Base completion reward
        v_idem_key := 'challenge:' || p_challenge_id || ':' || v_rec.user_id || ':completed';
        INSERT INTO public.kp_ledger (
            user_id, amount, type, source_type, source_id,
            idempotency_key, day_local, metadata, created_at
        ) VALUES (
            v_rec.user_id,
            v_completion_reward,
            'challenge_reward',
            'challenge',
            p_challenge_id::text,
            v_idem_key,
            v_day_local,
            jsonb_build_object(
                'challenge_id', p_challenge_id,
                'reward_type', 'completion',
                'finish_rank', v_rank
            ),
            now()
        )
        ON CONFLICT (idempotency_key) DO NOTHING;

        -- 2. Top 3 bonus
        IF v_rank <= 3 THEN
            v_idem_key := 'challenge:' || p_challenge_id || ':' || v_rec.user_id || ':top3';
            INSERT INTO public.kp_ledger (
                user_id, amount, type, source_type, source_id,
                idempotency_key, day_local, metadata, created_at
            ) VALUES (
                v_rec.user_id,
                v_top3_bonus,
                'challenge_reward',
                'challenge',
                p_challenge_id::text,
                v_idem_key,
                v_day_local,
                jsonb_build_object(
                    'challenge_id', p_challenge_id,
                    'reward_type', 'top3_bonus',
                    'finish_rank', v_rank
                ),
                now()
            )
            ON CONFLICT (idempotency_key) DO NOTHING;
        END IF;

        -- 3. 1st place additional bonus
        IF v_rank = 1 THEN
            v_idem_key := 'challenge:' || p_challenge_id || ':' || v_rec.user_id || ':first';
            INSERT INTO public.kp_ledger (
                user_id, amount, type, source_type, source_id,
                idempotency_key, day_local, metadata, created_at
            ) VALUES (
                v_rec.user_id,
                v_first_bonus,
                'challenge_reward',
                'challenge',
                p_challenge_id::text,
                v_idem_key,
                v_day_local,
                jsonb_build_object(
                    'challenge_id', p_challenge_id,
                    'reward_type', 'first_place_bonus',
                    'finish_rank', 1
                ),
                now()
            )
            ON CONFLICT (idempotency_key) DO NOTHING;
        END IF;

        -- Store final rank in progress row
        UPDATE public.challenge_progress
        SET rank = v_rank
        WHERE challenge_id = p_challenge_id AND user_id = v_rec.user_id;
    END LOOP;

    -- Update challenge status
    UPDATE public.challenges
    SET status = 'finalized'
    WHERE id = p_challenge_id;
END;
$$;

REVOKE ALL ON FUNCTION public.finalize_challenge(bigint) FROM PUBLIC, anon, authenticated;

-- ============================================================
-- 5. WIRE: score_activity -> update_challenge_progress
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

    -- 10. Update Challenge Progress (docs/KP_RULES.md §5)
    PERFORM public.update_challenge_progress(v_act.user_id, v_act.habit_key, v_act.quantity, v_act.started_at);

    RETURN v_final_kp;
END;
$$;

REVOKE ALL ON FUNCTION public.score_activity(bigint) FROM PUBLIC, anon, authenticated;

-- ============================================================
-- 6. PG_CRON SCHEDULE FOR CHALLENGES (docs/ARCHITECTURE.md §12)
-- ============================================================
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'pg_cron') THEN
        -- Finalize expired challenges every 5 minutes
        PERFORM cron.schedule(
            'finalize-expired-challenges',
            '*/5 * * * *',
            $cron$
                DO $inner$
                DECLARE
                    v_exp record;
                BEGIN
                    FOR v_exp IN
                        SELECT id FROM public.challenges
                        WHERE status = 'active' AND end_at < now()
                    LOOP
                        PERFORM public.finalize_challenge(v_exp.id);
                    END LOOP;
                END $inner$;
            $cron$
        );
    END IF;
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'pg_cron challenge scheduling skipped: %', SQLERRM;
END $$;
