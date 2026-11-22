-- Migration: 20260112000000_achievements.sql
-- B13: Achievements
-- Implements docs/PRD.md §F13 & docs/ARCHITECTURE.md §2.2
--
-- 1. Tables:
--    - achievements (catalog)
--    - user_achievements (unlocked instances)
-- 2. Seed initial achievement catalog
-- 3. Functions:
--    - evaluate_achievements(user_id, trigger_event, event_data)
--    - get_my_achievements() RPC
-- 4. Wiring:
--    - score_activity
--    - evaluate_user_streak
--    - finalize_challenge
--    - accept_friend_request

-- ============================================================
-- 1. TABLES
-- ============================================================

CREATE TABLE public.achievements (
    id              bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    key             text NOT NULL UNIQUE,
    display_name    text NOT NULL,
    description     text NOT NULL,
    category        text NOT NULL DEFAULT 'milestone',
    condition_type  text NOT NULL,
    condition_value jsonb NOT NULL DEFAULT '{}',
    reward_kp       integer NOT NULL DEFAULT 50,
    icon            text DEFAULT 'badge.fill',
    created_at      timestamptz NOT NULL DEFAULT now()
);

ALTER TABLE public.achievements ENABLE ROW LEVEL SECURITY;

CREATE POLICY "achievements_select_authenticated"
    ON public.achievements FOR SELECT
    TO authenticated
    USING (true);

REVOKE INSERT, UPDATE, DELETE ON public.achievements FROM authenticated, anon;
GRANT SELECT ON public.achievements TO authenticated;

-- User Achievements (unlocked badges)
CREATE TABLE public.user_achievements (
    id              bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id         uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    achievement_id  bigint NOT NULL REFERENCES public.achievements(id) ON DELETE CASCADE,
    unlocked_at     timestamptz NOT NULL DEFAULT now(),

    UNIQUE (user_id, achievement_id)
);

CREATE INDEX user_achievements_user_idx ON public.user_achievements (user_id);

ALTER TABLE public.user_achievements ENABLE ROW LEVEL SECURITY;

CREATE POLICY "user_achievements_select_authenticated"
    ON public.user_achievements FOR SELECT
    TO authenticated
    USING (true);

REVOKE INSERT, UPDATE, DELETE ON public.user_achievements FROM authenticated, anon;
GRANT SELECT ON public.user_achievements TO authenticated;

-- ============================================================
-- 2. SEED INITIAL CATALOG (docs/PRD.md §F13)
-- ============================================================

INSERT INTO public.achievements (key, display_name, description, category, condition_type, condition_value, reward_kp, icon)
VALUES
    ('first_steps', 'First Steps', 'Submit your first verified or manual activity.', 'milestone', 'activity_count', '{"min_count": 1}', 50, 'figure.walk'),
    ('week_warrior', 'Week Warrior', 'Reach a 7-day streak.', 'streak', 'streak_days', '{"min_days": 7}', 100, 'flame.fill'),
    ('month_master', 'Month Master', 'Reach a 30-day streak.', 'streak', 'streak_days', '{"min_days": 30}', 500, 'calendar.badge.clock'),
    ('century_club', 'Century Club', 'Reach a 100-day streak.', 'streak', 'streak_days', '{"min_days": 100}', 2000, 'crown.fill'),
    ('step_legend', 'Step Legend', 'Accumulate 100,000 lifetime steps.', 'habit', 'cumulative_quantity', '{"habit_key": "steps", "min_quantity": 100000}', 200, 'shoeprints.fill'),
    ('city_star', 'City Star', 'Reach top-10 in your city leaderboard.', 'leaderboard', 'city_rank', '{"max_rank": 10}', 300, 'star.fill'),
    ('challenge_champion', 'Challenge Champion', 'Finish 1st place in any challenge.', 'challenge', 'challenge_win', '{"rank": 1}', 150, 'trophy.fill'),
    ('social_butterfly', 'Social Butterfly', 'Connect with 5 friends.', 'social', 'friend_count', '{"min_friends": 5}', 50, 'person.3.fill')
ON CONFLICT (key) DO NOTHING;

-- ============================================================
-- 3. EVALUATION FUNCTION: evaluate_achievements
-- ============================================================
-- Why SECURITY DEFINER is needed (AGENTS.md Rule 9):
-- Evaluates unlock criteria, inserts into user_achievements, and awards
-- idempotent achievement_reward rows in kp_ledger without exposing write privileges to clients.
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

    -- Iterate all achievements the user has not yet unlocked
    FOR v_ach IN
        SELECT a.id, a.key, a.condition_type, a.condition_value, a.reward_kp
        FROM public.achievements a
        WHERE NOT EXISTS (
            SELECT 1 FROM public.user_achievements ua
            WHERE ua.user_id = p_user_id AND ua.achievement_id = a.id
        )
    LOOP
        v_unlocked := false;

        CASE v_ach.condition_type

            -- Condition 1: First activity / activity count
            WHEN 'activity_count' THEN
                IF p_trigger_event = 'activity_submitted' THEN
                    SELECT COUNT(*) INTO v_count
                    FROM public.activities
                    WHERE user_id = p_user_id;

                    IF v_count >= (v_ach.condition_value->>'min_count')::bigint THEN
                        v_unlocked := true;
                    END IF;
                END IF;

            -- Condition 2: Streak milestones
            WHEN 'streak_days' THEN
                IF p_trigger_event IN ('streak_updated', 'activity_submitted') THEN
                    SELECT current_streak INTO v_streak
                    FROM public.user_streaks
                    WHERE user_id = p_user_id;

                    IF v_streak IS NOT NULL AND v_streak >= (v_ach.condition_value->>'min_days')::integer THEN
                        v_unlocked := true;
                    END IF;
                END IF;

            -- Condition 3: Cumulative quantity for a habit (e.g. 100k steps)
            WHEN 'cumulative_quantity' THEN
                IF p_trigger_event = 'activity_submitted' THEN
                    SELECT COALESCE(SUM(a.quantity), 0) INTO v_quantity
                    FROM public.activities a
                    JOIN public.habits h ON h.id = a.habit_id
                    WHERE a.user_id = p_user_id
                      AND h.key = (v_ach.condition_value->>'habit_key');

                    IF v_quantity >= (v_ach.condition_value->>'min_quantity')::double precision THEN
                        v_unlocked := true;
                    END IF;
                END IF;

            -- Condition 4: City leaderboard rank
            WHEN 'city_rank' THEN
                IF p_trigger_event IN ('leaderboard_refreshed', 'activity_submitted') THEN
                    SELECT city_rank INTO v_rank
                    FROM public.leaderboard_daily
                    WHERE user_id = p_user_id;

                    IF v_rank IS NOT NULL AND v_rank <= (v_ach.condition_value->>'max_rank')::bigint THEN
                        v_unlocked := true;
                    END IF;
                END IF;

            -- Condition 5: Challenge win
            WHEN 'challenge_win' THEN
                IF p_trigger_event = 'challenge_finalized' THEN
                    IF (p_event_data->>'finish_rank')::integer = 1 THEN
                        v_unlocked := true;
                    END IF;
                END IF;

            -- Condition 6: Friend count
            WHEN 'friend_count' THEN
                IF p_trigger_event = 'friend_added' THEN
                    SELECT COUNT(*) INTO v_count
                    FROM public.friendships
                    WHERE status = 'accepted'
                      AND (requester_id = p_user_id OR addressee_id = p_user_id);

                    IF v_count >= (v_ach.condition_value->>'min_friends')::bigint THEN
                        v_unlocked := true;
                    END IF;
                END IF;

            ELSE
                v_unlocked := false;
        END CASE;

        -- If criteria met, record unlock and award reward KP idempotently
        IF v_unlocked THEN
            -- Record unlock
            INSERT INTO public.user_achievements (user_id, achievement_id, unlocked_at)
            VALUES (p_user_id, v_ach.id, now())
            ON CONFLICT (user_id, achievement_id) DO NOTHING;

            -- Idempotency key per PRD §F13: 'achievement:<achievement_id>:<user_id>'
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
        END IF;

    END LOOP;
END;
$$;

REVOKE ALL ON FUNCTION public.evaluate_achievements(uuid, text, jsonb) FROM PUBLIC, anon, authenticated;

-- ============================================================
-- 4. CLIENT RPC: get_my_achievements
-- ============================================================
CREATE OR REPLACE FUNCTION public.get_my_achievements()
RETURNS TABLE (
    id bigint,
    key text,
    display_name text,
    description text,
    category text,
    reward_kp integer,
    icon text,
    unlocked boolean,
    unlocked_at timestamptz
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
        a.id,
        a.key,
        a.display_name,
        a.description,
        a.category,
        a.reward_kp,
        a.icon,
        (ua.unlocked_at IS NOT NULL) AS unlocked,
        ua.unlocked_at
    FROM public.achievements a
    LEFT JOIN public.user_achievements ua ON ua.achievement_id = a.id AND ua.user_id = v_uid
    ORDER BY (ua.unlocked_at IS NOT NULL) DESC, a.id ASC;
END;
$$;

REVOKE ALL ON FUNCTION public.get_my_achievements() FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.get_my_achievements() TO authenticated;

-- ============================================================
-- 5. WIRING
-- ============================================================

-- A. Wire score_activity to evaluate achievements
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

    -- 11. Evaluate Achievements (docs/PRD.md §F13)
    PERFORM public.evaluate_achievements(v_act.user_id, 'activity_submitted', jsonb_build_object('habit_key', v_act.habit_key, 'quantity', v_act.quantity));

    RETURN v_final_kp;
END;
$$;

-- B. Wire evaluate_user_streak to evaluate achievements
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
    SELECT COALESCE(SUM(amount), 0)::integer INTO v_verified_kp
    FROM public.kp_ledger
    WHERE user_id = p_user_id
      AND day_local = p_day_local
      AND type = 'earn'
      AND (metadata->>'verification_status') = 'verified';

    IF v_verified_kp < 50 THEN
        RETURN;
    END IF;

    SELECT * INTO v_streak
    FROM public.user_streaks
    WHERE user_id = p_user_id;

    IF NOT FOUND THEN
        INSERT INTO public.user_streaks (
            user_id, current_streak, longest_streak, last_qualified_date, streak_version, freezes_available, updated_at
        ) VALUES (
            p_user_id, 1, 1, p_day_local, 1, 1, now()
        );

        -- Evaluate achievements on initial streak
        PERFORM public.evaluate_achievements(p_user_id, 'streak_updated', jsonb_build_object('current_streak', 1));
        RETURN;
    END IF;

    IF v_streak.last_qualified_date = p_day_local THEN
        RETURN;
    END IF;

    v_gap := p_day_local - v_streak.last_qualified_date;

    IF v_gap < 0 THEN
        RETURN;
    ELSIF v_gap = 1 THEN
        v_new_streak := v_streak.current_streak + 1;
        v_new_version := v_streak.streak_version;
    ELSIF v_gap = 2 AND v_streak.freezes_available > 0 THEN
        v_new_streak := v_streak.current_streak + 1;
        v_new_version := v_streak.streak_version;
        v_freeze_used := true;
    ELSE
        v_new_streak := 1;
        v_new_version := v_streak.streak_version + 1;
    END IF;

    v_new_longest := GREATEST(v_streak.longest_streak, v_new_streak);

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

    FOR i IN 1..array_length(v_milestones, 1) LOOP
        IF v_new_streak >= v_milestones[i] THEN
            v_idem_key := 'streak:' || p_user_id || ':' || v_milestones[i] || ':v' || v_new_version;

            INSERT INTO public.kp_ledger (
                user_id, amount, type, source_type, source_id,
                idempotency_key, day_local, metadata, created_at
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

    -- Evaluate streak achievements
    PERFORM public.evaluate_achievements(p_user_id, 'streak_updated', jsonb_build_object('current_streak', v_new_streak));
END;
$$;

-- C. Wire finalize_challenge to evaluate challenge achievements
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

    IF v_ch.status = 'finalized' THEN
        RETURN;
    END IF;

    IF v_ch.type = 'weekly' THEN
        v_completion_reward := 150;
        v_top3_bonus := 300;
        v_first_bonus := 150;
    ELSE
        v_completion_reward := 50;
        v_top3_bonus := 100;
        v_first_bonus := 50;
    END IF;

    v_day_local := (v_ch.end_at AT TIME ZONE 'Asia/Kolkata')::date;

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

        UPDATE public.challenge_progress
        SET rank = v_rank
        WHERE challenge_id = p_challenge_id AND user_id = v_rec.user_id;

        -- Evaluate challenge achievements (e.g. challenge_champion)
        PERFORM public.evaluate_achievements(v_rec.user_id, 'challenge_finalized', jsonb_build_object('challenge_id', p_challenge_id, 'finish_rank', v_rank));
    END LOOP;

    UPDATE public.challenges
    SET status = 'finalized'
    WHERE id = p_challenge_id;
END;
$$;

-- D. Wire accept_friend_request to evaluate friend achievements
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

    -- Evaluate achievements for both users (social_butterfly)
    PERFORM public.evaluate_achievements(v_uid, 'friend_added', jsonb_build_object('friend_id', p_requester_user_id));
    PERFORM public.evaluate_achievements(p_requester_user_id, 'friend_added', jsonb_build_object('friend_id', v_uid));

    RETURN jsonb_build_object('status', 'accepted');
END;
$$;
