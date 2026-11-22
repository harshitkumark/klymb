-- Migration: 20260103000000_cities.sql
-- B4: Cities and city assignment
-- 1. Index on profiles(city_id) for city leaderboards
-- 2. Seed 30 major cities (22 Indian + 8 Global)
-- 3. RPC: public.set_city(new_city_id bigint) with 30-day change limit

-- ============================================================
-- 1. INDEX AND CONSTRAINTS FOR CITIES
-- ============================================================
CREATE INDEX IF NOT EXISTS profiles_city_id_idx ON public.profiles (city_id);

ALTER TABLE public.cities
    ADD CONSTRAINT cities_name_country_key UNIQUE (name, country);

-- ============================================================
-- 2. SEED 30 MAJOR CITIES
-- ============================================================
-- Note: latitude/longitude are intentionally NULL to respect privacy (no precise location stored).
INSERT INTO public.cities (name, country, iana_timezone) VALUES
    ('Bengaluru', 'India', 'Asia/Kolkata'),
    ('Mumbai', 'India', 'Asia/Kolkata'),
    ('Delhi', 'India', 'Asia/Kolkata'),
    ('Hyderabad', 'India', 'Asia/Kolkata'),
    ('Chennai', 'India', 'Asia/Kolkata'),
    ('Kolkata', 'India', 'Asia/Kolkata'),
    ('Pune', 'India', 'Asia/Kolkata'),
    ('Ahmedabad', 'India', 'Asia/Kolkata'),
    ('Jaipur', 'India', 'Asia/Kolkata'),
    ('Surat', 'India', 'Asia/Kolkata'),
    ('Lucknow', 'India', 'Asia/Kolkata'),
    ('Chandigarh', 'India', 'Asia/Kolkata'),
    ('Kochi', 'India', 'Asia/Kolkata'),
    ('Indore', 'India', 'Asia/Kolkata'),
    ('Bhopal', 'India', 'Asia/Kolkata'),
    ('Nagpur', 'India', 'Asia/Kolkata'),
    ('Patna', 'India', 'Asia/Kolkata'),
    ('Bhubaneswar', 'India', 'Asia/Kolkata'),
    ('Coimbatore', 'India', 'Asia/Kolkata'),
    ('Visakhapatnam', 'India', 'Asia/Kolkata'),
    ('Gurugram', 'India', 'Asia/Kolkata'),
    ('Noida', 'India', 'Asia/Kolkata'),
    ('Singapore', 'Singapore', 'Asia/Singapore'),
    ('Dubai', 'United Arab Emirates', 'Asia/Dubai'),
    ('London', 'United Kingdom', 'Europe/London'),
    ('New York', 'United States', 'America/New_York'),
    ('San Francisco', 'United States', 'America/Los_Angeles'),
    ('Tokyo', 'Japan', 'Asia/Tokyo'),
    ('Sydney', 'Australia', 'Australia/Sydney'),
    ('Toronto', 'Canada', 'America/Toronto')
ON CONFLICT DO NOTHING;

-- ============================================================
-- 3. RPC: set_city(new_city_id bigint)
-- ============================================================
-- Allows authenticated users to set or change their city.
-- Limit: One change per 30 days (first assignment during onboarding has no limit).
--
-- Why SECURITY DEFINER is needed (AGENTS.md Rule 9):
-- Controls mutation of city_id and city_changed_at with strict business logic
-- and validation, preventing direct unauthorized column updates on profiles.
CREATE OR REPLACE FUNCTION public.set_city(new_city_id bigint)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_uid             uuid;
    v_current_city_id bigint;
    v_changed_at      timestamptz;
BEGIN
    -- 1. Validate caller authentication (AGENTS.md Rule 9)
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'ERR_UNAUTHORIZED' USING ERRCODE = '42501';
    END IF;

    -- 2. Validate new_city_id parameter (AGENTS.md Rule 9)
    IF new_city_id IS NULL THEN
        RAISE EXCEPTION 'ERR_INVALID_CITY' USING ERRCODE = '22023';
    END IF;

    -- 3. Verify city exists
    IF NOT EXISTS (SELECT 1 FROM public.cities WHERE id = new_city_id) THEN
        RAISE EXCEPTION 'ERR_CITY_NOT_FOUND' USING ERRCODE = 'P0002';
    END IF;

    -- 4. Fetch user's current city state
    SELECT city_id, city_changed_at
    INTO v_current_city_id, v_changed_at
    FROM public.profiles
    WHERE id = v_uid;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'ERR_PROFILE_NOT_FOUND' USING ERRCODE = 'P0002';
    END IF;

    -- If already set to the same city, return success (no-op)
    IF v_current_city_id = new_city_id THEN
        RETURN jsonb_build_object(
            'success', true,
            'city_id', new_city_id,
            'message', 'City already set'
        );
    END IF;

    -- 5. Enforce 30-day cooldown (only if city was previously set)
    IF v_current_city_id IS NOT NULL AND v_changed_at IS NOT NULL THEN
        IF v_changed_at > now() - interval '30 days' THEN
            RAISE EXCEPTION 'ERR_CITY_CHANGE_COOLDOWN' USING ERRCODE = '22023';
        END IF;
    END IF;

    -- 6. Update user's city
    UPDATE public.profiles
    SET city_id = new_city_id,
        city_changed_at = now(),
        updated_at = now()
    WHERE id = v_uid;

    RETURN jsonb_build_object(
        'success', true,
        'city_id', new_city_id
    );
END;
$$;

-- Grant permissions (Rule 8: Least Privilege)
REVOKE ALL ON FUNCTION public.set_city(bigint) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_city(bigint) TO authenticated;
