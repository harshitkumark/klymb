-- Migration: 20260102000000_auth_profiles.sql
-- B3: Auth & Profile Creation
-- 1. Table: public.reserved_usernames (blocklist)
-- 2. Revoke direct INSERT on public.profiles from authenticated and anon
-- 3. Trigger: on_auth_user_created on auth.users -> handle_new_user()
-- 4. RPC: public.set_username(text)

-- ============================================================
-- 1. RESERVED_USERNAMES (BLOCKLIST)
-- ============================================================
CREATE TABLE public.reserved_usernames (
    username   text PRIMARY KEY,
    reason     text NOT NULL DEFAULT 'reserved',
    created_at timestamptz NOT NULL DEFAULT now(),

    CONSTRAINT reserved_username_format CHECK (
        username ~ '^[a-z0-9][a-z0-9_]{1,18}[a-z0-9]$'
        AND username !~ '__'
    )
);

ALTER TABLE public.reserved_usernames ENABLE ROW LEVEL SECURITY;

-- Authenticated users can read reserved usernames
CREATE POLICY "reserved_usernames_select_authenticated"
    ON public.reserved_usernames FOR SELECT
    TO authenticated
    USING (true);

-- Seed reserved usernames
INSERT INTO public.reserved_usernames (username, reason) VALUES
    ('admin', 'system reserved'),
    ('administrator', 'system reserved'),
    ('klymb', 'brand reserved'),
    ('klymb_official', 'brand reserved'),
    ('klymb_admin', 'brand reserved'),
    ('support', 'system reserved'),
    ('help', 'system reserved'),
    ('moderator', 'system reserved'),
    ('mod', 'system reserved'),
    ('system', 'system reserved'),
    ('root', 'system reserved'),
    ('official', 'brand reserved');

-- ============================================================
-- 2. LOCK DOWN CLIENT INSERTS ON PROFILES
-- ============================================================
-- Client cannot directly insert into profiles; only the trigger handles it.
REVOKE INSERT ON public.profiles FROM authenticated, anon;

-- ============================================================
-- 3. TRIGGER: handle_new_user() ON auth.users
-- ============================================================
-- Why SECURITY DEFINER is needed (AGENTS.md Rule 9):
-- This trigger executes on auth.users insert during user signup before the client
-- has an authenticated session established with public schema privileges.
-- Definitive privileges are required to insert into public.profiles.
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_username text;
    v_attempts integer := 0;
    v_suffix   text;
BEGIN
    LOOP
        v_attempts := v_attempts + 1;
        -- Generate username: user_ + 6 random hex characters (lowercase)
        v_suffix := lower(substr(md5(random()::text || clock_timestamp()::text), 1, 6));
        v_username := 'user_' || v_suffix;

        -- Verify it is not already taken in profiles and not reserved
        IF NOT EXISTS (SELECT 1 FROM public.profiles WHERE username = v_username)
           AND NOT EXISTS (SELECT 1 FROM public.reserved_usernames WHERE username = v_username) THEN
            EXIT;
        END IF;

        IF v_attempts > 10 THEN
            -- Deterministic fallback: user_ + epoch in hex
            v_username := 'user_' || lower(to_hex(extract(epoch from clock_timestamp())::bigint));
            EXIT;
        END IF;
    END LOOP;

    INSERT INTO public.profiles (
        id,
        username,
        display_name,
        avatar_preset,
        created_at,
        updated_at
    ) VALUES (
        NEW.id,
        v_username,
        NULL,
        'default',
        now(),
        now()
    );

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
    AFTER INSERT ON auth.users
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_new_user();

-- ============================================================
-- 4. RPC: set_username(new_username text)
-- ============================================================
-- Allows authenticated users to change their username with format,
-- blocklist, and uniqueness checks.
--
-- Why SECURITY DEFINER is needed (AGENTS.md Rule 9):
-- Runs with search_path secured and allows updating own profile username
-- without exposing wide update grants on arbitrary columns.
CREATE OR REPLACE FUNCTION public.set_username(new_username text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_uid     uuid;
    v_clean   text;
    v_current text;
BEGIN
    -- 1. Validate caller authentication (AGENTS.md Rule 9)
    v_uid := auth.uid();
    IF v_uid IS NULL THEN
        RAISE EXCEPTION 'ERR_UNAUTHORIZED' USING ERRCODE = '42501';
    END IF;

    -- 2. Validate and sanitize input parameters (AGENTS.md Rule 9)
    IF new_username IS NULL THEN
        RAISE EXCEPTION 'ERR_INVALID_USERNAME_FORMAT' USING ERRCODE = '22023';
    END IF;

    v_clean := lower(trim(new_username));

    -- 3. Validate format: 3-20 chars, lowercase alphanumeric + underscores,
    -- must start/end with alnum, no consecutive underscores (matches profiles constraint)
    IF v_clean !~ '^[a-z0-9][a-z0-9_]{1,18}[a-z0-9]$' OR v_clean ~ '__' THEN
        RAISE EXCEPTION 'ERR_INVALID_USERNAME_FORMAT' USING ERRCODE = '22023';
    END IF;

    -- 4. Check against reserved blocklist
    IF EXISTS (SELECT 1 FROM public.reserved_usernames WHERE username = v_clean) THEN
        RAISE EXCEPTION 'ERR_USERNAME_RESERVED' USING ERRCODE = '23514';
    END IF;

    -- 5. Fetch current username
    SELECT username INTO v_current FROM public.profiles WHERE id = v_uid;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'ERR_PROFILE_NOT_FOUND' USING ERRCODE = 'P0002';
    END IF;

    -- If already current username, return success (no-op)
    IF v_current = v_clean THEN
        RETURN jsonb_build_object(
            'success', true,
            'username', v_clean
        );
    END IF;

    -- 6. Check uniqueness
    IF EXISTS (SELECT 1 FROM public.profiles WHERE username = v_clean AND id != v_uid) THEN
        RAISE EXCEPTION 'ERR_USERNAME_TAKEN' USING ERRCODE = '23505';
    END IF;

    -- 7. Update profile
    UPDATE public.profiles
    SET username = v_clean,
        updated_at = now()
    WHERE id = v_uid;

    RETURN jsonb_build_object(
        'success', true,
        'username', v_clean
    );
END;
$$;

-- Grant permissions (Rule 8: Least Privilege)
REVOKE ALL ON FUNCTION public.set_username(text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.set_username(text) TO authenticated;
