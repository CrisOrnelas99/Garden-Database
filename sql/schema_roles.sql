
-- Create roles if they do not already exist
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'data_manager')
       AND NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'database_manager') THEN
        EXECUTE 'ALTER ROLE data_manager RENAME TO database_manager';
    ELSIF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'data_manager')
       AND EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'database_manager') THEN
        RAISE EXCEPTION
            'Both data_manager and database_manager exist. Resolve the duplicate role before applying schema_roles.sql.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'database_admin') THEN
        CREATE ROLE database_admin NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'database_manager') THEN
        CREATE ROLE database_manager NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'garden_staff') THEN
        CREATE ROLE garden_staff NOLOGIN;
    END IF;
END $$;

-- Configure role attributes
ALTER ROLE database_admin NOLOGIN CREATEROLE NOBYPASSRLS;
ALTER ROLE database_manager NOLOGIN CREATEROLE NOBYPASSRLS;
ALTER ROLE garden_staff NOLOGIN NOCREATEROLE NOBYPASSRLS;

-- Supabase Data API role switching: allow the API authenticator to assume the
-- two non-admin roles. database_admin is deliberately not exposed to Auth.
GRANT garden_staff, database_manager TO authenticator;

-- Allow postgres to assume database_admin for ownership transfer
GRANT database_admin TO postgres;

-- Give database_admin ownership of the public schema
ALTER SCHEMA public OWNER TO database_admin;

-- Transfer existing table ownership
DO $$
DECLARE obj RECORD;
BEGIN
    FOR obj IN
        SELECT tablename FROM pg_tables
        WHERE schemaname = 'public'
    LOOP
        EXECUTE format(
            'ALTER TABLE public.%I OWNER TO database_admin',
            obj.tablename
        );
    END LOOP;
END $$;

-- Transfer view ownership
DO $$
DECLARE obj RECORD;
BEGIN
    FOR obj IN
        SELECT viewname FROM pg_views
        WHERE schemaname = 'public'
    LOOP
        EXECUTE format(
            'ALTER VIEW public.%I OWNER TO database_admin',
            obj.viewname
        );
    END LOOP;
END $$;

-- Transfer materialized view ownership
DO $$
DECLARE obj RECORD;
BEGIN
    FOR obj IN
        SELECT matviewname FROM pg_matviews
        WHERE schemaname = 'public'
    LOOP
        EXECUTE format(
            'ALTER MATERIALIZED VIEW public.%I OWNER TO database_admin',
            obj.matviewname
        );
    END LOOP;
END $$;

-- Transfer sequence ownership
DO $$
DECLARE obj RECORD;
BEGIN
    FOR obj IN
        SELECT sequencename FROM pg_sequences
        WHERE schemaname = 'public'
    LOOP
        EXECUTE format(
            'ALTER SEQUENCE public.%I OWNER TO database_admin',
            obj.sequencename
        );
    END LOOP;
END $$;

-- Transfer function ownership
DO $$
DECLARE obj RECORD;
BEGIN
    FOR obj IN
        SELECT
            p.proname,
            pg_get_function_identity_arguments(p.oid) AS args
        FROM pg_proc p
        JOIN pg_namespace n ON n.oid = p.pronamespace
        WHERE n.nspname = 'public'
          AND p.prokind = 'f'
    LOOP
        EXECUTE format(
            'ALTER FUNCTION public.%I(%s) OWNER TO database_admin',
            obj.proname,
            obj.args
        );
    END LOOP;
END $$;

-- Transfer custom type and domain ownership
DO $$
DECLARE obj RECORD;
BEGIN
    FOR obj IN
        SELECT typname, typtype
        FROM pg_type
        WHERE typnamespace = 'public'::regnamespace
          AND typtype IN ('e', 'd')
    LOOP
        IF obj.typtype = 'd' THEN
            EXECUTE format(
                'ALTER DOMAIN public.%I OWNER TO database_admin',
                obj.typname
            );
        ELSE
            EXECUTE format(
                'ALTER TYPE public.%I OWNER TO database_admin',
                obj.typname
            );
        END IF;
    END LOOP;
END $$;

-- Schema permissions
GRANT USAGE ON SCHEMA public TO database_admin, database_manager, garden_staff;
GRANT CREATE ON SCHEMA public TO database_admin;

-- Fail closed for ordinary Supabase API roles. Access is granted below only
-- through the database roles selected by the signed Auth token.
REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM anon, authenticated;
REVOKE ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public FROM anon, authenticated;
REVOKE CREATE ON SCHEMA public FROM anon, authenticated;

-- Full data access for database_admin and database_manager
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public
TO database_admin, database_manager;

GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public
TO database_admin, database_manager;

-- Remove previous garden_staff grants before applying restrictions
REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public
FROM garden_staff;

REVOKE ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public
FROM garden_staff;

-- Give garden_staff full data access to ordinary operational tables
DO $$
DECLARE obj RECORD;
BEGIN
    FOR obj IN
        SELECT tablename
        FROM pg_tables
        WHERE schemaname = 'public'
          AND tablename NOT IN (
              'budget',
              'purchase_request',
              'item'
          )
    LOOP
        EXECUTE format(
            'GRANT ALL PRIVILEGES ON TABLE public.%I TO garden_staff',
            obj.tablename
        );
    END LOOP;
END $$;

-- Purchase costs remain visible to garden_staff. budget_name is withheld with
-- the budget table and budget-specific reporting.
GRANT SELECT (
    request_id,
    request_date,
    requested_by,
    requesting_school,
    requesting_school_group,
    item_name,
    quantity_requested,
    unit_cost_at_request,
    total_cost,
    delivered_to_fns,
    review_status,
    ordered,
    school_year,
    notes
) ON public.purchase_request TO garden_staff;

-- Allow edits to purchase request fields, including costs, but not budget_name.
GRANT INSERT (
    request_date,
    requested_by,
    requesting_school,
    requesting_school_group,
    item_name,
    quantity_requested,
    unit_cost_at_request,
    total_cost,
    delivered_to_fns,
    review_status,
    ordered,
    school_year,
    notes
) ON public.purchase_request TO garden_staff;

GRANT UPDATE (
    request_date,
    requested_by,
    requesting_school,
    requesting_school_group,
    item_name,
    quantity_requested,
    unit_cost_at_request,
    total_cost,
    delivered_to_fns,
    review_status,
    ordered,
    school_year,
    notes
) ON public.purchase_request TO garden_staff;

GRANT DELETE ON public.purchase_request TO garden_staff;

-- Item catalog costs remain visible to garden_staff; budget-specific data is
-- restricted separately.
GRANT SELECT (
    item_id,
    item_name,
    category,
    vendor_name,
    link,
    unit_cost,
    notes
) ON public.item TO garden_staff;

GRANT INSERT (
    item_name,
    category,
    vendor_name,
    link,
    unit_cost,
    notes
) ON public.item TO garden_staff;

GRANT UPDATE (
    item_name,
    category,
    vendor_name,
    link,
    unit_cost,
    notes
) ON public.item TO garden_staff;

GRANT DELETE ON public.item TO garden_staff;

-- Garden staff cannot access the budget table
REVOKE ALL PRIVILEGES ON public.budget FROM garden_staff;

-- Give garden_staff access to nonfinancial views
DO $$
DECLARE obj RECORD;
BEGIN
    FOR obj IN
        SELECT viewname
        FROM pg_views
        WHERE schemaname = 'public'
          AND viewname NOT IN (
              'BudgetPurchases',
              'FundingSourceSpending',
              'YearlyPurchase',
              'SchoolSupply',
              'PendingRequests'
          )
    LOOP
        EXECUTE format(
            'GRANT SELECT ON public.%I TO garden_staff',
            obj.viewname
        );
    END LOOP;
END $$;

-- Hide financial columns in SchoolSupply
GRANT SELECT (
    assignment_type,
    location_name,
    items_currently_checked_out,
    items_still_requested
) ON public."SchoolSupply" TO garden_staff;

-- Pending request cost is visible; the budget-specific views remain restricted.
GRANT SELECT (
    request_date,
    request_status,
    item_name,
    requested_by,
    assigned_locations,
    quantity_requested,
    total_cost,
    review_status,
    notes
) ON public."PendingRequests" TO garden_staff;

-- Give garden_staff sequence access for operational records
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public
TO garden_staff;

-- Allow financial triggers to work without exposing financial columns
ALTER FUNCTION public.calculate_purchase_request_total()
SECURITY DEFINER;

ALTER FUNCTION public.calculate_purchase_request_total()
SET search_path = public, pg_temp;

ALTER FUNCTION public.update_remaining_budget()
SECURITY DEFINER;

ALTER FUNCTION public.update_remaining_budget()
SET search_path = public, pg_temp;

ALTER FUNCTION public.recalculate_shared_budget_remaining(character varying)
SECURITY DEFINER;

ALTER FUNCTION public.recalculate_shared_budget_remaining(character varying)
SET search_path = public, pg_temp;

-- Generated All HLC Gardens membership must still be maintained when RLS
-- blocks partners from directly editing its protected membership rows.
ALTER FUNCTION public.sync_all_hlc_gardens_group() SECURITY DEFINER;
ALTER FUNCTION public.sync_all_hlc_gardens_group() SET search_path = public, pg_temp;
ALTER FUNCTION public.sync_all_hlc_gardens_location_status() SECURITY DEFINER;
ALTER FUNCTION public.sync_all_hlc_gardens_location_status() SET search_path = public, pg_temp;

ALTER FUNCTION public.update_remaining_budget_after_budget_change()
SECURITY DEFINER;

ALTER FUNCTION public.update_remaining_budget_after_budget_change()
SET search_path = public, pg_temp;

-- Row Level Security for the data roles. Every authenticated database session
-- must assume one of these roles; RLS policies do not grant table privileges.
-- garden_staff can access operational rows but not budget rows. database_manager
-- can access all rows, including budgets. database_admin owns the objects and
-- remains the schema administrator.
DO $$
DECLARE obj RECORD;
BEGIN
    FOR obj IN
        SELECT tablename
        FROM pg_tables
        WHERE schemaname = 'public'
    LOOP
        EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY', obj.tablename);
        EXECUTE format('DROP POLICY IF EXISTS data_roles_all_rows ON public.%I', obj.tablename);
        EXECUTE format('DROP POLICY IF EXISTS data_manager_budget_rows ON public.%I', obj.tablename);
        EXECUTE format('DROP POLICY IF EXISTS database_manager_budget_rows ON public.%I', obj.tablename);

        IF obj.tablename = 'budget' THEN
            EXECUTE format(
                'CREATE POLICY database_manager_budget_rows ON public.%I FOR ALL TO database_manager USING (true) WITH CHECK (true)',
                obj.tablename
            );
        ELSE
            EXECUTE format(
                'CREATE POLICY data_roles_all_rows ON public.%I FOR ALL TO database_manager, garden_staff USING (true) WITH CHECK (true)',
                obj.tablename
            );
        END IF;
    END LOOP;
END $$;

-- The built-in group and its membership are trigger-maintained from location.is_hlc.
DROP POLICY IF EXISTS data_roles_all_rows ON public.location_group;
DROP POLICY IF EXISTS data_roles_read_groups ON public.location_group;
DROP POLICY IF EXISTS data_roles_write_custom_groups ON public.location_group;
DROP POLICY IF EXISTS data_roles_update_custom_groups ON public.location_group;
DROP POLICY IF EXISTS data_roles_delete_custom_groups ON public.location_group;
CREATE POLICY data_roles_read_groups ON public.location_group
    FOR SELECT TO database_manager, garden_staff USING (true);
CREATE POLICY data_roles_write_custom_groups ON public.location_group
    FOR INSERT TO database_manager, garden_staff
    WITH CHECK (location_group_name <> 'All HLC Gardens');
CREATE POLICY data_roles_update_custom_groups ON public.location_group
    FOR UPDATE TO database_manager, garden_staff
    USING (location_group_name <> 'All HLC Gardens')
    WITH CHECK (location_group_name <> 'All HLC Gardens');
CREATE POLICY data_roles_delete_custom_groups ON public.location_group
    FOR DELETE TO database_manager, garden_staff
    USING (location_group_name <> 'All HLC Gardens');

DROP POLICY IF EXISTS data_roles_all_rows ON public.group_location;
DROP POLICY IF EXISTS data_roles_read_group_locations ON public.group_location;
DROP POLICY IF EXISTS data_roles_write_custom_group_locations ON public.group_location;
DROP POLICY IF EXISTS data_roles_update_custom_group_locations ON public.group_location;
DROP POLICY IF EXISTS data_roles_delete_custom_group_locations ON public.group_location;
CREATE POLICY data_roles_read_group_locations ON public.group_location
    FOR SELECT TO database_manager, garden_staff USING (true);
CREATE POLICY data_roles_write_custom_group_locations ON public.group_location
    FOR INSERT TO database_manager, garden_staff
    WITH CHECK (location_group_name <> 'All HLC Gardens');
CREATE POLICY data_roles_update_custom_group_locations ON public.group_location
    FOR UPDATE TO database_manager, garden_staff
    USING (location_group_name <> 'All HLC Gardens')
    WITH CHECK (location_group_name <> 'All HLC Gardens');
CREATE POLICY data_roles_delete_custom_group_locations ON public.group_location
    FOR DELETE TO database_manager, garden_staff
    USING (location_group_name <> 'All HLC Gardens');

-- Supabase Auth role assignment and token hook. Assign only garden_staff or
-- database_manager to existing Auth users; database_admin remains out of the API.
CREATE SCHEMA IF NOT EXISTS private;
REVOKE ALL ON SCHEMA private FROM PUBLIC, anon, authenticated;
GRANT USAGE ON SCHEMA private TO supabase_auth_admin;

CREATE TABLE IF NOT EXISTS private.user_role_assignment (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    database_role TEXT NOT NULL
        CHECK (database_role IN ('garden_staff', 'database_manager'))
);
ALTER TABLE private.user_role_assignment
    DROP CONSTRAINT IF EXISTS user_role_assignment_database_role_check;
UPDATE private.user_role_assignment
SET database_role = 'database_manager'
WHERE database_role = 'data_manager';
ALTER TABLE private.user_role_assignment
    ADD CONSTRAINT user_role_assignment_database_role_check
    CHECK (database_role IN ('garden_staff', 'database_manager'));
ALTER TABLE private.user_role_assignment ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.user_role_assignment FROM PUBLIC, anon, authenticated,
    garden_staff, database_manager;
GRANT SELECT ON private.user_role_assignment TO supabase_auth_admin;
DROP POLICY IF EXISTS auth_hook_read_user_role ON private.user_role_assignment;
CREATE POLICY auth_hook_read_user_role ON private.user_role_assignment
    FOR SELECT TO supabase_auth_admin USING (true);

CREATE OR REPLACE FUNCTION public.custom_access_token_hook(event JSONB)
RETURNS JSONB
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = ''
AS $$
DECLARE
    claims JSONB;
    assigned_role TEXT;
BEGIN
    SELECT ura.database_role
    INTO assigned_role
    FROM private.user_role_assignment AS ura
    WHERE ura.user_id = (event ->> 'user_id')::UUID;

    claims := event -> 'claims';
    IF assigned_role IN ('garden_staff', 'database_manager') THEN
        claims := jsonb_set(claims, '{role}', to_jsonb(assigned_role), true);
    ELSE
        claims := jsonb_set(claims, '{role}', '"authenticated"'::JSONB, true);
    END IF;

    RETURN jsonb_set(event, '{claims}', claims, true);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.custom_access_token_hook(JSONB)
    FROM PUBLIC, anon, authenticated, garden_staff, database_manager;
GRANT EXECUTE ON FUNCTION public.custom_access_token_hook(JSONB)
    TO supabase_auth_admin;

-- Allow only database_manager to assign application database roles. Auth user
-- creation/deletion is handled by Supabase Auth and is outside PostgreSQL SQL.
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
    IF p_database_role IS NULL
       OR p_database_role NOT IN ('garden_staff', 'database_manager') THEN
        RAISE EXCEPTION 'Unsupported database role: %', p_database_role;
    END IF;

    INSERT INTO private.user_role_assignment (user_id, database_role)
    VALUES (p_user_id, p_database_role)
    ON CONFLICT (user_id)
    DO UPDATE SET database_role = EXCLUDED.database_role;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.set_user_database_role(UUID, TEXT)
    FROM PUBLIC, anon, authenticated, garden_staff;
GRANT EXECUTE ON FUNCTION public.set_user_database_role(UUID, TEXT)
    TO database_manager;

-- Default permissions for future objects created as database_admin
ALTER DEFAULT PRIVILEGES FOR ROLE database_admin IN SCHEMA public
GRANT ALL PRIVILEGES ON TABLES TO database_manager;

ALTER DEFAULT PRIVILEGES FOR ROLE database_admin IN SCHEMA public
GRANT ALL PRIVILEGES ON SEQUENCES TO database_manager;
