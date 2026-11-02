
-- Create roles if they do not already exist
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'database_admin') THEN
        CREATE ROLE database_admin NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'data_manager') THEN
        CREATE ROLE data_manager NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'garden_staff') THEN
        CREATE ROLE garden_staff NOLOGIN;
    END IF;
END $$;

-- Configure role attributes
ALTER ROLE database_admin NOLOGIN CREATEROLE;
ALTER ROLE data_manager NOLOGIN CREATEROLE;
ALTER ROLE garden_staff NOLOGIN NOCREATEROLE;

-- Allow postgres to assume database_admin for ownership transfer
GRANT database_admin TO postgres WITH SET TRUE;

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
GRANT USAGE ON SCHEMA public TO database_admin, data_manager, garden_staff;
GRANT CREATE ON SCHEMA public TO database_admin;

-- Full data access for database_admin and data_manager
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public
TO database_admin, data_manager;

GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public
TO database_admin, data_manager;

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

-- Allow garden_staff to view nonfinancial purchase request columns
GRANT SELECT (
    request_id,
    request_date,
    requested_by,
    requesting_school,
    requesting_school_group,
    item_name,
    quantity_requested,
    delivered_to_fns,
    review_status,
    ordered,
    school_year,
    notes
) ON public.purchase_request TO garden_staff;

-- Allow garden_staff to insert and update nonfinancial purchase request columns
GRANT INSERT (
    request_date,
    requested_by,
    requesting_school,
    requesting_school_group,
    item_name,
    quantity_requested,
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
    delivered_to_fns,
    review_status,
    ordered,
    school_year,
    notes
) ON public.purchase_request TO garden_staff;

GRANT DELETE ON public.purchase_request TO garden_staff;

-- Hide item.unit_cost while preserving access to the item catalog
GRANT SELECT (
    item_id,
    item_name,
    category,
    vendor_name,
    link,
    notes
) ON public.item TO garden_staff;

GRANT INSERT (
    item_name,
    category,
    vendor_name,
    link,
    notes
) ON public.item TO garden_staff;

GRANT UPDATE (
    item_name,
    category,
    vendor_name,
    link,
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

-- Hide total_cost in PendingRequests
GRANT SELECT (
    request_date,
    request_status,
    item_name,
    requested_by,
    assigned_locations,
    quantity_requested,
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

ALTER FUNCTION public.update_remaining_budget_after_budget_change()
SECURITY DEFINER;

ALTER FUNCTION public.update_remaining_budget_after_budget_change()
SET search_path = public, pg_temp;

-- Default permissions for future objects created as database_admin
ALTER DEFAULT PRIVILEGES FOR ROLE database_admin IN SCHEMA public
GRANT ALL PRIVILEGES ON TABLES TO data_manager;

ALTER DEFAULT PRIVILEGES FOR ROLE database_admin IN SCHEMA public
GRANT ALL PRIVILEGES ON SEQUENCES TO data_manager;
