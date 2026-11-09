-- Existing projects: run this entire file once in the Supabase SQL Editor.
-- Requires schema_roles.sql. Fresh installs already include these definitions there.
-- This updates manager functions only; it does not change garden or budget data.
BEGIN;

-- Return only the account details needed by the manager's Users page.
CREATE OR REPLACE FUNCTION public.list_app_users()
RETURNS TABLE (user_id UUID, email TEXT, database_role TEXT)
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM private.user_role_assignment AS caller
        WHERE caller.user_id = auth.uid()
          AND caller.database_role = 'database_manager'
    ) THEN
        RAISE EXCEPTION 'Only a current database manager can manage app users.'
            USING ERRCODE = '42501';
    END IF;

    RETURN QUERY
    SELECT u.id, u.email::TEXT, assignment.database_role
    FROM auth.users AS u
    LEFT JOIN private.user_role_assignment AS assignment ON assignment.user_id = u.id
    ORDER BY u.email NULLS LAST, u.id;
END;
$$;

-- Assign or change another account's role. Managers cannot change their own role.
CREATE OR REPLACE FUNCTION public.set_user_database_role(
    p_user_id UUID,
    p_database_role TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    -- Serialize role changes so two managers cannot simultaneously demote each other.
    PERFORM pg_catalog.pg_advisory_xact_lock(764721094::BIGINT);
    IF NOT EXISTS (
        SELECT 1 FROM private.user_role_assignment AS caller
        WHERE caller.user_id = auth.uid()
          AND caller.database_role = 'database_manager'
    ) THEN
        RAISE EXCEPTION 'Only a current database manager can manage app users.'
            USING ERRCODE = '42501';
    END IF;
    IF p_user_id = auth.uid() THEN
        RAISE EXCEPTION 'You cannot change your own manager role.'
            USING ERRCODE = '42501';
    END IF;
    IF p_database_role IS NULL
       OR p_database_role NOT IN ('staff', 'finance_staff', 'database_manager') THEN
        RAISE EXCEPTION 'Unsupported database role: %', p_database_role
            USING ERRCODE = '22023';
    END IF;
    IF NOT EXISTS (SELECT 1 FROM auth.users AS u WHERE u.id = p_user_id) THEN
        RAISE EXCEPTION 'This account no longer exists.' USING ERRCODE = '22023';
    END IF;

    INSERT INTO private.user_role_assignment (user_id, database_role)
    VALUES (p_user_id, p_database_role)
    ON CONFLICT (user_id)
    DO UPDATE SET database_role = EXCLUDED.database_role;
END;
$$;

-- Remove another account's app role while keeping its Supabase Auth account.
CREATE OR REPLACE FUNCTION public.remove_user_database_role(p_user_id UUID)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = ''
AS $$
BEGIN
    PERFORM pg_catalog.pg_advisory_xact_lock(764721094::BIGINT);
    IF NOT EXISTS (
        SELECT 1 FROM private.user_role_assignment AS caller
        WHERE caller.user_id = auth.uid()
          AND caller.database_role = 'database_manager'
    ) THEN
        RAISE EXCEPTION 'Only a current database manager can manage app users.'
            USING ERRCODE = '42501';
    END IF;
    IF p_user_id = auth.uid() THEN
        RAISE EXCEPTION 'You cannot remove your own manager access.'
            USING ERRCODE = '42501';
    END IF;

    DELETE FROM private.user_role_assignment AS assignment WHERE assignment.user_id = p_user_id;
END;
$$;

-- Protect the functions even when someone calls the Data API outside the app.
REVOKE EXECUTE ON FUNCTION public.list_app_users()
    FROM PUBLIC, anon, authenticated, staff, finance_staff;
REVOKE EXECUTE ON FUNCTION public.set_user_database_role(UUID, TEXT)
    FROM PUBLIC, anon, authenticated, staff, finance_staff;
REVOKE EXECUTE ON FUNCTION public.remove_user_database_role(UUID)
    FROM PUBLIC, anon, authenticated, staff, finance_staff;
GRANT EXECUTE ON FUNCTION public.list_app_users() TO database_manager;
GRANT EXECUTE ON FUNCTION public.set_user_database_role(UUID, TEXT) TO database_manager;
GRANT EXECUTE ON FUNCTION public.remove_user_database_role(UUID) TO database_manager;

NOTIFY pgrst, 'reload schema';
COMMIT;
