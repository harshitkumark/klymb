-- Migration: 20260107000000_streaks.sql
-- B8: Streaks and freeze logic
-- 1. Table: public.user_streaks
-- 2. Function: public.evaluate_user_streak(user_id uuid, day_local date)
-- 3. Wire into score_activity() to evaluate streaks on scoring

-- ============================================================
-- 1. USER_STREAKS TABLE
-- ============================================================
CREATE TABLE public.user_streaks (
    user_id                uuid PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    current_streak         integer NOT NULL DEFAULT 0,
    longest_streak         integer NOT NULL DEFAULT 0,
    last_qualified_date    date,
    streak_version         integer NOT NULL DEFAULT 1,
    freezes_available      integer NOT NULL DEFAULT 1,
    freezes_used_this_week integer NOT NULL DEFAULT 0,
    last_freeze_date       date,
    updated_at             timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.user_streaks ENABLE ROW LEVEL SECURITY;

-- Authenticated users can view user streaks (for profile and leaderboards)
CREATE POLICY "user_streaks_select_authenticated"
    ON public.user_streaks FOR SELECT
    TO authenticated
    USING (true);

-- Direct client mutations are strictly revoked
REVOKE INSERT, UPDATE, DELETE ON public.user_streaks FROM authenticated, anon;

-- ============================================================
-- 2. FUNCTION: evaluate_user_streak(user_id uuid, day_local date)
-- ============================================================
-- Evaluates streak status and milestone bonuses for a user on a given local calendar day.
-- Why SECURITY DEFINER is needed (AGENTS.md Rule 9):
-- Updates user_streaks and inserts milestone bonuses into kp_ledger without
-- exposing write grants to clients.
CREATE OR REPLACE FUNCTION public.evaluate_user_streak(p_user_id uuid, p_day_local date)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_verified_kp        integer := 0;
    v_streak             record;
    v_gap                integer;
    v_new_streak         integer := 1;
    v_new_version        integer := 1;
    v_new_longest        integer := 1;
    v_freeze_used        boolean := false;
    v_idem_key           text;
    v_milestones         CONSTANT integer[] := ARRAY[3, 7, 14, 30, 60, 100, 200, 365];
    v_rewards            CONSTANT integer[] := ARRAY[25, 100, 200, 500, 1000, 2500, 5000, 10000];
    i                    integer;
BEGIN
    -- 1. Check verified earned KP for p_day_local (>= 50 KP needed per KP_RULES.md §4.1)
    SELECT COALESCE(SUM(amount), 0)::integer INTO v_verified_kp
    FROM public.kp_ledger
    WHERE user_id = p_user_id
      AND day_local = p_day_local
      AND type = 'earn'
      AND (metadata->>'verification_status') = 'verified';

    IF v_verified_kp < 50 THEN
        RETURN;
    END IF;

    -- 2. Fetch or initialize user streak record
    SELECT * INTO v_streak
    FROM public.user_streaks
    WHERE user_id = p_user_id;

    IF NOT FOUND THEN
        -- First qualifying day ever!
        INSERT INTO public.user_streaks (
            user_id,
            current_streak,
            longest_streak,
            last_qualified_date,
            streak_version,
            freezes_available,
            updated_at
        ) VALUES (
            p_user_id,
            1,
            1,
            p_day_local,
            1,
            1,
            now()
        );
        RETURN;
    END IF;

    -- Already qualified for this date
    IF v_streak.last_qualified_date = p_day_local THEN
        RETURN;
    END IF;

    -- Calculate day gap
    v_gap := p_day_local - v_streak.last_qualified_date;

    IF v_gap < 0 THEN
        -- Past late activity, do not regress streak
        RETURN;
    ELSIF v_gap = 1 THEN
        -- Consecutive calendar day!
        v_new_streak := v_streak.current_streak + 1;
        v_new_version := v_streak.streak_version;
    ELSIF v_gap = 2 AND v_streak.freezes_available > 0 THEN
        -- 1 missed day, freeze available! Auto-apply freeze
        v_new_streak := v_streak.current_streak + 1;
        v_new_version := v_streak.streak_version;
        v_freeze_used := true;
    ELSE
        -- Gap > 1 day without freeze: streak broken!
        v_new_streak := 1;
        v_new_version := v_streak.streak_version + 1;
    END IF;

    v_new_longest := GREATEST(v_streak.longest_streak, v_new_streak);

    -- 3. Update user_streaks record
    UPDATE public.user_streaks
    SET current_streak = v_new_streak,
        longest_streak = v_new_longest,
        last_qualified_date = p_day_local,
        streak_version = v_new_version,
        freezes_available = CASE WHEN v_freeze_used THEN v_streak.freezes_available - 1 ELSE v_streak.freezes_available END,
        freezes_used_this_week = CASE WHEN v_freeze_used THEN v_streak.freezes_used_this_week + 1 ELSE v_streak.freezes_used_this_week END,
        last_freeze_date = CASE WHEN v_freeze_used THEN p_day_local - 1 ELSE v_streak.last_freeze_date END,
        updated_at = now()
    WHERE user_id = p_user_id;

    -- 4. Check & award milestone bonuses (KP_RULES.md §4.2)
    FOR i IN 1..array_length(v_milestones, 1) LOOP
        IF v_new_streak >= v_milestones[i] THEN
            v_idem_key := 'streak:' || p_user_id || ':' || v_milestones[i] || ':v' || v_new_version;

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
                p_user_id,
                v_rewards[i],
                'streak_bonus',
                'streak',
                v_milestones[i]::text,
                v_idem_key,
                p_day_local,
                jsonb_build_object(
                    'milestone_days', v_milestones[i],
                    'streak_version', v_new_version,
                    'current_streak', v_new_streak
                ),
                now()
            )
            ON CONFLICT (idempotency_key) DO NOTHING;
        END IF;
    END LOOP;
END;
$$;

-- Restrict execution to internal server side only
REVOKE ALL ON FUNCTION public.evaluate_user_streak(uuid, date) FROM PUBLIC, anon, authenticated;

-- ============================================================
-- 3. WIRE INTO SCORE_ACTIVITY
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

    RETURN v_final_kp;
END;
$$;
