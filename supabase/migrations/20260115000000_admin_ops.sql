-- Migration: 20260115000000_admin_ops.sql
-- B17: Admin & Ops
-- Implements administrative roles, audit logging, anti-cheat flag moderation, and user inspection.

-- ============================================================
-- 1. TABLES
-- ============================================================

-- Admin roles
CREATE TABLE public.admin_roles (
    id         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    user_id    uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    role       text NOT NULL,
    granted_at timestamptz NOT NULL DEFAULT now(),
    granted_by uuid REFERENCES auth.users(id),

    CONSTRAINT valid_admin_role CHECK (role IN ('super_admin', 'moderator', 'support')),
    UNIQUE (user_id, role)
);

CREATE INDEX admin_roles_user_idx ON public.admin_roles (user_id);

ALTER TABLE public.admin_roles ENABLE ROW LEVEL SECURITY;

-- Audit log: append-only
CREATE TABLE public.audit_log (
    id          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    admin_id    uuid NOT NULL REFERENCES auth.users(id),
    action      text NOT NULL,
    target_type text NOT NULL,
    target_id   text NOT NULL,
    details     jsonb NOT NULL DEFAULT '{}'::jsonb,
    created_at  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX audit_log_admin_idx ON public.audit_log (admin_id, created_at DESC);
CREATE INDEX audit_log_target_idx ON public.audit_log (target_type, target_id);

ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;

-- ============================================================
-- 2. HELPER FUNCTIONS
-- ============================================================

-- Check if user is an admin
CREATE OR REPLACE FUNCTION public.is_admin(p_user_id uuid DEFAULT auth.uid())
RETURNS boolean
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.admin_roles
        WHERE user_id = p_user_id
    );
$$;

-- Check if user has specific role or higher
-- Hierarchy: super_admin > moderator > support
CREATE OR REPLACE FUNCTION public.has_admin_role(p_required_role text, p_user_id uuid DEFAULT auth.uid())
RETURNS boolean
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_roles text[];
BEGIN
    IF p_user_id IS NULL THEN
        RETURN false;
    END IF;

    SELECT array_agg(role) INTO v_roles
    FROM public.admin_roles
    WHERE user_id = p_user_id;

    IF v_roles IS NULL THEN
        RETURN false;
    END IF;

    IF 'super_admin' = ANY(v_roles) THEN
        RETURN true;
    END IF;

    IF p_required_role = 'moderator' AND 'moderator' = ANY(v_roles) THEN
        RETURN true;
    END IF;

    IF p_required_role = 'support' AND ('moderator' = ANY(v_roles) OR 'support' = ANY(v_roles)) THEN
        RETURN true;
    END IF;

    RETURN false;
END;
$$;

-- RLS Policies for admin tables
CREATE POLICY "admin_roles_select_admins"
    ON public.admin_roles FOR SELECT
    TO authenticated
    USING (public.is_admin());

CREATE POLICY "audit_log_select_admins"
    ON public.audit_log FOR SELECT
    TO authenticated
    USING (public.is_admin());

-- Allow admins to inspect all activity flags
CREATE POLICY "activity_flags_select_admin"
    ON public.activity_flags FOR SELECT
    TO authenticated
    USING (public.is_admin());

-- Allow admins to inspect kp_ledger for audit/investigation
CREATE POLICY "kp_ledger_select_admin"
    ON public.kp_ledger FOR SELECT
    TO authenticated
    USING (public.is_admin());

REVOKE ALL ON public.admin_roles FROM PUBLIC, anon;
GRANT SELECT ON public.admin_roles TO authenticated;

REVOKE ALL ON public.audit_log FROM PUBLIC, anon;
GRANT SELECT ON public.audit_log TO authenticated;

-- ============================================================
-- 3. ADMIN RPCS
-- ============================================================

-- List anti-cheat flags
CREATE OR REPLACE FUNCTION public.admin_list_flags(
    p_status text DEFAULT NULL,
    p_limit integer DEFAULT 50,
    p_offset integer DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_admin_id uuid;
    v_flags jsonb;
    v_total bigint;
    v_limit integer := LEAST(COALESCE(p_limit, 50), 100);
    v_offset integer := GREATEST(COALESCE(p_offset, 0), 0);
BEGIN
    v_admin_id := auth.uid();
    IF NOT public.has_admin_role('support', v_admin_id) THEN
        RAISE EXCEPTION 'ERR_UNAUTHORIZED' USING ERRCODE = '42501';
    END IF;

    SELECT count(*) INTO v_total
    FROM public.activity_flags af
    WHERE (p_status IS NULL OR af.status = p_status);

    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', af.id,
            'activity_id', af.activity_id,
            'user_id', af.user_id,
            'username', p.username,
            'rule', af.rule,
            'severity', af.severity,
            'status', af.status,
            'detail', af.detail,
            'created_at', af.created_at,
            'activity', jsonb_build_object(
                'quantity', a.quantity,
                'started_at', a.started_at,
                'ended_at', a.ended_at,
                'source', a.source,
                'habit_key', h.key
            )
        ) ORDER BY af.created_at DESC
    ), '[]'::jsonb) INTO v_flags
    FROM (
        SELECT * FROM public.activity_flags
        WHERE (p_status IS NULL OR status = p_status)
        ORDER BY created_at DESC
        LIMIT v_limit OFFSET v_offset
    ) af
    JOIN public.profiles p ON p.id = af.user_id
    JOIN public.activities a ON a.id = af.activity_id
    JOIN public.habits h ON h.id = a.habit_id;

    RETURN jsonb_build_object(
        'total', v_total,
        'limit', v_limit,
        'offset', v_offset,
        'flags', v_flags
    );
END;
$$;

-- Review / moderate a flag
CREATE OR REPLACE FUNCTION public.admin_review_flag(
    p_flag_id bigint,
    p_resolution text,
    p_notes text DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_admin_id uuid;
    v_flag record;
    v_act record;
    v_idem_key text;
    v_kp_amount integer;
    v_day_local date;
BEGIN
    v_admin_id := auth.uid();
    IF NOT public.has_admin_role('moderator', v_admin_id) THEN
        RAISE EXCEPTION 'ERR_UNAUTHORIZED' USING ERRCODE = '42501';
    END IF;

    IF p_resolution NOT IN ('resolved_approved', 'resolved_confirmed') THEN
        RAISE EXCEPTION 'ERR_INVALID_RESOLUTION' USING ERRCODE = '22023';
    END IF;

    SELECT * INTO v_flag
    FROM public.activity_flags
    WHERE id = p_flag_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'ERR_FLAG_NOT_FOUND' USING ERRCODE = '22023';
    END IF;

    SELECT * INTO v_act
    FROM public.activities
    WHERE id = v_flag.activity_id;

    -- Update flag status
    UPDATE public.activity_flags
    SET status = p_resolution
    WHERE id = p_flag_id;

    -- If approved as false positive: restore KP if it was previously revoked
    IF p_resolution = 'resolved_approved' THEN
        -- Check if there was a revoke ledger row for this activity
        SELECT abs(amount), day_local INTO v_kp_amount, v_day_local
        FROM public.kp_ledger
        WHERE idempotency_key = 'revoke:' || v_flag.activity_id;

        IF FOUND AND v_kp_amount > 0 THEN
            v_idem_key := 'admin_restore:' || v_flag.activity_id;

            INSERT INTO public.kp_ledger (
                user_id, amount, type, source_type, source_id,
                idempotency_key, day_local, metadata, created_at
            ) VALUES (
                v_flag.user_id,
                v_kp_amount,
                'earn',
                'activity',
                v_flag.activity_id::text,
                v_idem_key,
                v_day_local,
                jsonb_build_object(
                    'admin_action', 'flag_dismissed_restore',
                    'flag_id', v_flag.id,
                    'admin_id', v_admin_id,
                    'notes', p_notes
                ),
                now()
            )
            ON CONFLICT (idempotency_key) DO NOTHING;
        END IF;
    END IF;

    -- If confirmed cheating: ensure KP is revoked
    IF p_resolution = 'resolved_confirmed' THEN
        -- Check if already revoked
        IF NOT EXISTS (
            SELECT 1 FROM public.kp_ledger
            WHERE idempotency_key = 'revoke:' || v_flag.activity_id
        ) THEN
            -- Calculate earned KP for this activity to revoke it
            SELECT COALESCE(SUM(amount), 0), max(day_local) INTO v_kp_amount, v_day_local
            FROM public.kp_ledger
            WHERE source_id = v_flag.activity_id::text AND type = 'earn';

            IF v_kp_amount > 0 THEN
                v_idem_key := 'revoke:' || v_flag.activity_id;

                INSERT INTO public.kp_ledger (
                    user_id, amount, type, source_type, source_id,
                    idempotency_key, day_local, metadata, created_at
                ) VALUES (
                    v_flag.user_id,
                    -v_kp_amount,
                    'revoke',
                    'anticheat',
                    v_flag.activity_id::text,
                    v_idem_key,
                    v_day_local,
                    jsonb_build_object(
                        'admin_action', 'flag_confirmed_revoke',
                        'flag_id', v_flag.id,
                        'admin_id', v_admin_id,
                        'notes', p_notes
                    ),
                    now()
                )
                ON CONFLICT (idempotency_key) DO NOTHING;
            END IF;
        END IF;
    END IF;

    -- Record in audit log
    INSERT INTO public.audit_log (
        admin_id, action, target_type, target_id, details
    ) VALUES (
        v_admin_id,
        'review_flag',
        'activity_flag',
        p_flag_id::text,
        jsonb_build_object(
            'previous_status', v_flag.status,
            'resolution', p_resolution,
            'user_id', v_flag.user_id,
            'activity_id', v_flag.activity_id,
            'notes', p_notes
        )
    );

    RETURN jsonb_build_object(
        'status', 'flag_reviewed',
        'flag_id', p_flag_id,
        'resolution', p_resolution
    );
END;
$$;

-- Get user summary for support / moderation
CREATE OR REPLACE FUNCTION public.admin_get_user_summary(p_user_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_admin_id uuid;
    v_profile record;
    v_trust_score integer;
    v_kp_total bigint;
    v_flags_count bigint;
    v_streak integer;
BEGIN
    v_admin_id := auth.uid();
    IF NOT public.has_admin_role('support', v_admin_id) THEN
        RAISE EXCEPTION 'ERR_UNAUTHORIZED' USING ERRCODE = '42501';
    END IF;

    SELECT * INTO v_profile FROM public.profiles WHERE id = p_user_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'ERR_USER_NOT_FOUND' USING ERRCODE = '22023';
    END IF;

    SELECT trust_score INTO v_trust_score FROM public.user_trust_score WHERE user_id = p_user_id;
    SELECT COALESCE(SUM(amount), 0) INTO v_kp_total FROM public.kp_ledger WHERE user_id = p_user_id;
    SELECT count(*) INTO v_flags_count FROM public.activity_flags WHERE user_id = p_user_id;
    SELECT current_streak INTO v_streak FROM public.user_streaks WHERE user_id = p_user_id;

    RETURN jsonb_build_object(
        'user_id', p_user_id,
        'username', v_profile.username,
        'display_name', v_profile.display_name,
        'city_id', v_profile.city_id,
        'trust_score', COALESCE(v_trust_score, 100),
        'kp_total', v_kp_total,
        'current_streak', COALESCE(v_streak, 0),
        'total_flags', v_flags_count,
        'created_at', v_profile.created_at
    );
END;
$$;

-- Grant admin role (super_admin only)
CREATE OR REPLACE FUNCTION public.admin_grant_role(
    p_target_user_id uuid,
    p_role text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_admin_id uuid;
BEGIN
    v_admin_id := auth.uid();
    IF NOT public.has_admin_role('super_admin', v_admin_id) THEN
        RAISE EXCEPTION 'ERR_UNAUTHORIZED' USING ERRCODE = '42501';
    END IF;

    IF p_role NOT IN ('super_admin', 'moderator', 'support') THEN
        RAISE EXCEPTION 'ERR_INVALID_ROLE' USING ERRCODE = '22023';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM auth.users WHERE id = p_target_user_id) THEN
        RAISE EXCEPTION 'ERR_USER_NOT_FOUND' USING ERRCODE = '22023';
    END IF;

    INSERT INTO public.admin_roles (user_id, role, granted_by)
    VALUES (p_target_user_id, p_role, v_admin_id)
    ON CONFLICT (user_id, role) DO NOTHING;

    INSERT INTO public.audit_log (
        admin_id, action, target_type, target_id, details
    ) VALUES (
        v_admin_id,
        'grant_role',
        'admin_role',
        p_target_user_id::text,
        jsonb_build_object('role', p_role)
    );

    RETURN jsonb_build_object('status', 'role_granted', 'role', p_role);
END;
$$;

-- Revoke admin role (super_admin only)
CREATE OR REPLACE FUNCTION public.admin_revoke_role(
    p_target_user_id uuid,
    p_role text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_admin_id uuid;
BEGIN
    v_admin_id := auth.uid();
    IF NOT public.has_admin_role('super_admin', v_admin_id) THEN
        RAISE EXCEPTION 'ERR_UNAUTHORIZED' USING ERRCODE = '42501';
    END IF;

    -- Prevent self-demotion from super_admin if it's the last super_admin
    IF p_target_user_id = v_admin_id AND p_role = 'super_admin' THEN
        IF (SELECT count(*) FROM public.admin_roles WHERE role = 'super_admin') <= 1 THEN
            RAISE EXCEPTION 'ERR_CANNOT_REVOKE_LAST_SUPER_ADMIN' USING ERRCODE = '22023';
        END IF;
    END IF;

    DELETE FROM public.admin_roles
    WHERE user_id = p_target_user_id AND role = p_role;

    INSERT INTO public.audit_log (
        admin_id, action, target_type, target_id, details
    ) VALUES (
        v_admin_id,
        'revoke_role',
        'admin_role',
        p_target_user_id::text,
        jsonb_build_object('role', p_role)
    );

    RETURN jsonb_build_object('status', 'role_revoked', 'role', p_role);
END;
$$;

-- List audit log entries (admins only)
CREATE OR REPLACE FUNCTION public.admin_list_audit_log(
    p_limit integer DEFAULT 50,
    p_offset integer DEFAULT 0
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    v_admin_id uuid;
    v_logs jsonb;
    v_total bigint;
    v_limit integer := LEAST(COALESCE(p_limit, 50), 100);
    v_offset integer := GREATEST(COALESCE(p_offset, 0), 0);
BEGIN
    v_admin_id := auth.uid();
    IF NOT public.has_admin_role('support', v_admin_id) THEN
        RAISE EXCEPTION 'ERR_UNAUTHORIZED' USING ERRCODE = '42501';
    END IF;

    SELECT count(*) INTO v_total FROM public.audit_log;

    SELECT COALESCE(jsonb_agg(
        jsonb_build_object(
            'id', al.id,
            'admin_id', al.admin_id,
            'action', al.action,
            'target_type', al.target_type,
            'target_id', al.target_id,
            'details', al.details,
            'created_at', al.created_at
        ) ORDER BY al.created_at DESC
    ), '[]'::jsonb) INTO v_logs
    FROM (
        SELECT * FROM public.audit_log
        ORDER BY created_at DESC
        LIMIT v_limit OFFSET v_offset
    ) al;

    RETURN jsonb_build_object(
        'total', v_total,
        'limit', v_limit,
        'offset', v_offset,
        'logs', v_logs
    );
END;
$$;

-- Grants
REVOKE ALL ON FUNCTION public.is_admin(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.is_admin(uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.has_admin_role(text, uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.has_admin_role(text, uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.admin_list_flags(text, integer, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_list_flags(text, integer, integer) TO authenticated;

REVOKE ALL ON FUNCTION public.admin_review_flag(bigint, text, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_review_flag(bigint, text, text) TO authenticated;

REVOKE ALL ON FUNCTION public.admin_get_user_summary(uuid) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_get_user_summary(uuid) TO authenticated;

REVOKE ALL ON FUNCTION public.admin_grant_role(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_grant_role(uuid, text) TO authenticated;

REVOKE ALL ON FUNCTION public.admin_revoke_role(uuid, text) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_revoke_role(uuid, text) TO authenticated;

REVOKE ALL ON FUNCTION public.admin_list_audit_log(integer, integer) FROM PUBLIC, anon;
GRANT EXECUTE ON FUNCTION public.admin_list_audit_log(integer, integer) TO authenticated;

-- Comments
COMMENT ON TABLE public.admin_roles IS
    'Stores administrative roles (super_admin, moderator, support) for internal operations.';

COMMENT ON TABLE public.audit_log IS
    'Append-only audit trail for all administrative actions and moderations.';

COMMENT ON FUNCTION public.admin_review_flag(bigint, text, text) IS
    'Moderates an anti-cheat flag: resolves as approved (false positive) or confirmed, adjusting KP ledger if necessary and recording to audit_log.';
