-- Migration: 20260104000000_habits.sql
-- B5: User habits
-- 1. Seed 7 core habits per KP_RULES.md
-- 2. RPC: public.set_user_habits(habit_ids bigint[])

-- ============================================================
-- 1. SEED HABITS CATALOG
-- ============================================================
INSERT INTO public.habits (key, display_name, unit, formula_type, formula_params, daily_kp_cap, manual_kp_cap, manual_allowed)
VALUES
    ('steps', 'Steps', 'count', 'linear', '{"rate": 10, "unit_step": 1000}'::jsonb, 150, NULL, false),
    ('running', 'Running', 'km', 'linear', '{"rate": 20}'::jsonb, 200, NULL, false),
    ('walking_distance', 'Walking Distance', 'km', 'linear', '{"rate": 12}'::jsonb, 120, NULL, false),
    ('workout', 'Workout', 'minutes', 'linear', '{"rate": 2}'::jsonb, 120, 40, true),
    ('hydration', 'Hydration', 'ml', 'linear', '{"rate": 5, "unit_step": 250}'::jsonb, 40, 20, true),
    ('sleep', 'Sleep', 'hours', 'curve', '{"curve": "sleep_quality"}'::jsonb, 50, NULL, false),
    ('mindfulness', 'Mindfulness', 'minutes', 'linear', '{"rate": 3}'::jsonb, 45, 15, true)
ON CONFLICT (key) DO UPDATE SET
    display_name = EXCLUDED.display_name,
    unit = EXCLUDED.unit,
    formula_type = EXCLUDED.formula_type,
    formula_params = EXCLUDED.formula_params,
    daily_kp_cap = EXCLUDED.daily_kp_cap,
    manual_kp_cap = EXCLUDED.manual_kp_cap,
    manual_allowed = EXCLUDED.manual_allowed;

-- ============================================================
-- 2. RPC: set_user_habits(habit_ids bigint[])
-- ============================================================
-- Replaces the authenticated user's active habit set atomically.
-- At least 1 habit must be selected.
--
-- Why SECURITY DEFINER is needed (AGENTS.md Rule 9):
-- To execute atomic set replacement securely with search_path control
-- and guarantee consistency across the user_habits table.
CREATE OR REPLACE FUNCTION public.set_user_habits(habit_ids bigint[])
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_uid          uuid;
    v_valid_count  integer;
    v_target_count integer;
BEGIN
    -- 1. Validate caller authentication (AGENTS.md Rule 9)
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'ERR_UNAUTHORIZED' USING ERRCODE = '42501';
    END IF;

    -- 2. Validate input: array must not be null and must have at least 1 habit
    IF habit_ids IS NULL OR cardinality(habit_ids) = 0 THEN
        RAISE EXCEPTION 'ERR_NO_HABITS_SELECTED' USING ERRCODE = '22023';
    END IF;

    -- Count distinct target IDs (handling duplicates in input safely)
    SELECT count(DISTINCT h_id) INTO v_target_count
    FROM unnest(habit_ids) AS h_id;

    IF v_target_count = 0 THEN
        RAISE EXCEPTION 'ERR_NO_HABITS_SELECTED' USING ERRCODE = '22023';
    END IF;

    -- 3. Validate that all habit_ids exist in the catalog
    SELECT count(DISTINCT id) INTO v_valid_count
    FROM public.habits
    WHERE id = ANY(habit_ids);

    IF v_valid_count < v_target_count THEN
        RAISE EXCEPTION 'ERR_HABIT_NOT_FOUND' USING ERRCODE = 'P0002';
    END IF;

    -- 4. Atomic replacement:
    -- Deactivate habits not included in the new set
    UPDATE public.user_habits
    SET active = false
    WHERE user_id = v_uid
      AND active = true
      AND habit_id != ALL(habit_ids);

    -- Upsert new habits as active
    INSERT INTO public.user_habits (user_id, habit_id, active, created_at)
    SELECT v_uid, h_id, true, now()
    FROM (SELECT DISTINCT unnest(habit_ids) AS h_id) sub
    ON CONFLICT (user_id, habit_id)
    DO UPDATE SET active = true;

    RETURN jsonb_build_object(
        'success', true,
        'active_count', v_target_count
    );
END;
$$;

-- Grant permissions (Rule 8: Least Privilege)
REVOKE ALL ON FUNCTION public.set_user_habits(bigint[]) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_user_habits(bigint[]) TO authenticated;
