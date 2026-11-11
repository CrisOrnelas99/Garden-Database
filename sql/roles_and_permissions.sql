
-- Create roles if they do not already exist
DO $$
BEGIN
    -- Remove the former internal owner role on databases where an earlier
    -- version of this script created it. Supabase's postgres role remains the
    -- owner of the database objects and handles schema administration.
    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'database_admin') THEN
        EXECUTE 'REASSIGN OWNED BY database_admin TO postgres';
        EXECUTE 'DROP OWNED BY database_admin';
        EXECUTE 'REVOKE database_admin FROM postgres';
        EXECUTE 'DROP ROLE database_admin';
    END IF;

    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'garden_staff')
       AND NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'staff') THEN
        EXECUTE 'ALTER ROLE garden_staff RENAME TO staff';
    ELSIF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'garden_staff')
       AND EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'staff') THEN
        RAISE EXCEPTION
            'Both garden_staff and staff roles exist. Resolve the duplicate role before applying schema_roles.sql.';
    END IF;

    IF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'data_manager')
       AND NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'database_manager') THEN
        EXECUTE 'ALTER ROLE data_manager RENAME TO database_manager';
    ELSIF EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'data_manager')
       AND EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'database_manager') THEN
        RAISE EXCEPTION
            'Both data_manager and database_manager exist. Resolve the duplicate role before applying schema_roles.sql.';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'database_manager') THEN
        CREATE ROLE database_manager NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'staff') THEN
        CREATE ROLE staff NOLOGIN;
    END IF;
    IF NOT EXISTS (SELECT 1 FROM pg_roles WHERE rolname = 'finance_staff') THEN
        CREATE ROLE finance_staff NOLOGIN;
    END IF;
END $$;

-- Configure role attributes
ALTER ROLE database_manager NOLOGIN NOCREATEROLE NOBYPASSRLS;
ALTER ROLE staff NOLOGIN NOCREATEROLE NOBYPASSRLS;
ALTER ROLE finance_staff NOLOGIN NOCREATEROLE NOBYPASSRLS;

-- Supabase Data API role switching: allow the API authenticator to assume the
-- application data roles.
GRANT staff, finance_staff, database_manager TO authenticator;

-- Schema permissions
GRANT USAGE ON SCHEMA public TO database_manager, staff, finance_staff;

-- Fail closed for ordinary Supabase API roles. Access is granted below only
-- through the database roles selected by the signed Auth token.
REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM anon, authenticated;
REVOKE ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public FROM anon, authenticated;
REVOKE CREATE ON SCHEMA public FROM anon, authenticated;

-- Full data access for database_manager
GRANT ALL PRIVILEGES ON ALL TABLES IN SCHEMA public
TO database_manager;

GRANT ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public
TO database_manager;

-- Remove previous staff grants before applying restrictions
REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public
FROM staff;

REVOKE ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public
FROM staff;

-- Finance staff can read and create records, including all financial tables,
-- and can manage existing budget records. Purchase requests and inventory
-- transactions retain their date-limited correction rules. Finance staff
-- cannot delete unrelated operational records.
REVOKE ALL PRIVILEGES ON ALL TABLES IN SCHEMA public FROM finance_staff;
REVOKE ALL PRIVILEGES ON ALL SEQUENCES IN SCHEMA public FROM finance_staff;
GRANT SELECT, INSERT ON ALL TABLES IN SCHEMA public TO finance_staff;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO finance_staff;

-- Clear any prior column-level UPDATE grants. The roles are granted table-level
-- UPDATE on the tables they may edit, keeping permissions simple and consistent.
DO $$
DECLARE obj RECORD;
BEGIN
    FOR obj IN
        SELECT c.table_name, c.column_name
        FROM information_schema.columns c
        JOIN pg_tables t
          ON t.schemaname = c.table_schema
         AND t.tablename = c.table_name
        WHERE c.table_schema = 'public'
    LOOP
        EXECUTE format(
            'REVOKE UPDATE (%I) ON TABLE public.%I FROM staff, finance_staff',
            obj.column_name, obj.table_name
        );
    END LOOP;
END $$;

-- Staff can edit all columns on ordinary operational tables, but not budgets
-- or records governed by the same-day purchase/inventory rules below.
DO $$
DECLARE obj RECORD;
BEGIN
    FOR obj IN
        SELECT tablename
        FROM pg_tables
        WHERE schemaname = 'public'
          AND tablename NOT IN (
              'budget', 'purchase_request', 'inventory_transaction',
              'location_group', 'group_members'
          )
    LOOP
        EXECUTE format('GRANT UPDATE ON TABLE public.%I TO staff', obj.tablename);
    END LOOP;
END $$;

-- Finance staff can edit every column on public tables, with purchase requests
-- and inventory transactions retaining their dedicated date policies.
DO $$
DECLARE obj RECORD;
BEGIN
    FOR obj IN
        SELECT tablename
        FROM pg_tables
        WHERE schemaname = 'public'
          AND tablename NOT IN (
              'purchase_request', 'inventory_transaction',
              'location_group', 'group_members'
          )
    LOOP
        EXECUTE format('GRANT UPDATE ON TABLE public.%I TO finance_staff', obj.tablename);
    END LOOP;
END $$;
GRANT UPDATE ON public.location_group, public.group_members TO staff, finance_staff;

-- Let staff read and create ordinary operational rows.
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
            'GRANT SELECT, INSERT ON TABLE public.%I TO staff',
            obj.tablename
        );
    END LOOP;
END $$;

-- Purchase costs remain visible to staff. budget_name is withheld with
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
) ON public.purchase_request TO staff;

-- Staff may create purchase requests and correct allowed fields on today's
-- requests, but budget_name and funding_source remain inaccessible.
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
) ON public.purchase_request TO staff;

-- Staff may correct recent purchase requests, except for hidden budget fields.
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
) ON public.purchase_request TO staff;
GRANT DELETE ON public.purchase_request TO staff;

-- Finance staff may correct all purchase-request fields, but only for rows
-- allowed by the same-day RLS policy below.
GRANT UPDATE, DELETE ON public.purchase_request TO finance_staff;
-- Finance staff can manage budget rows without a date restriction.
GRANT UPDATE, DELETE ON public.budget TO finance_staff;

-- Both roles may correct recent inventory transactions.
GRANT UPDATE, DELETE ON public.inventory_transaction TO staff, finance_staff;

-- Item catalog costs remain visible to staff; budget-specific data is
-- restricted separately.
GRANT SELECT (
    item_id,
    item_name,
    category,
    vendor_name,
    link,
    unit_cost,
    notes
) ON public.item TO staff;

GRANT INSERT (
    item_name,
    category,
    vendor_name,
    link,
    unit_cost,
    notes
) ON public.item TO staff;

-- Staff cannot access the budget table
REVOKE ALL PRIVILEGES ON public.budget FROM staff;

-- Give staff access to nonfinancial views
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
            'GRANT SELECT ON public.%I TO staff',
            obj.viewname
        );
    END LOOP;
END $$;

-- Hide financial columns in SchoolSupply
GRANT SELECT (
    assignment_type,
    location_name,
    items_currently_checked_out,
    purchase_items_pending
) ON public."SchoolSupply" TO staff;

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
) ON public."PendingRequests" TO staff;

-- Give staff sequence access for operational records
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public
TO staff;

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

-- Insert-time stock and bed-count triggers must update derived rows even
-- though staff has no direct UPDATE privilege on those tables.
ALTER FUNCTION public.update_inventory_after_transaction()
SECURITY DEFINER;

ALTER FUNCTION public.update_inventory_after_transaction()
SET search_path = public, pg_temp;

ALTER FUNCTION public.update_inventory_when_received()
SECURITY DEFINER;

ALTER FUNCTION public.update_inventory_when_received()
SET search_path = public, pg_temp;

ALTER FUNCTION public.update_garden_bed_count()
SECURITY DEFINER;

ALTER FUNCTION public.update_garden_bed_count()
SET search_path = public, pg_temp;

-- Row Level Security for the data roles. Every authenticated database session
-- must assume one of these roles; RLS policies do not grant table privileges.
-- staff and finance_staff can update/delete today's purchase requests and
-- inventory transactions only under the dedicated policies below. Finance
-- staff additionally has full budget-table access. Both roles can edit
-- all columns on permitted operational tables and cannot delete unrelated
-- operational rows.
-- database_manager can access all rows except purchase requests and inventory
-- transactions, which are limited to rows dated today for edit/delete.
-- Supabase postgres owns objects and remains responsible for schema administration.
DROP POLICY IF EXISTS database_manager_read_rows ON public.purchase_request;
DROP POLICY IF EXISTS database_manager_insert_rows ON public.purchase_request;
DROP POLICY IF EXISTS database_manager_recent_purchase_request_update ON public.purchase_request;
DROP POLICY IF EXISTS database_manager_recent_purchase_request_delete ON public.purchase_request;
DROP POLICY IF EXISTS database_manager_read_rows ON public.inventory_transaction;
DROP POLICY IF EXISTS database_manager_insert_rows ON public.inventory_transaction;
DROP POLICY IF EXISTS database_manager_recent_inventory_transaction_update ON public.inventory_transaction;
DROP POLICY IF EXISTS database_manager_recent_inventory_transaction_delete ON public.inventory_transaction;
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
        EXECUTE format('DROP POLICY IF EXISTS database_manager_all_rows ON public.%I', obj.tablename);
        EXECUTE format('DROP POLICY IF EXISTS data_roles_read_rows ON public.%I', obj.tablename);
        EXECUTE format('DROP POLICY IF EXISTS data_roles_insert_rows ON public.%I', obj.tablename);
        EXECUTE format('DROP POLICY IF EXISTS finance_staff_read_rows ON public.%I', obj.tablename);
        EXECUTE format('DROP POLICY IF EXISTS finance_staff_insert_rows ON public.%I', obj.tablename);
        EXECUTE format('DROP POLICY IF EXISTS finance_staff_budget_all_rows ON public.%I', obj.tablename);
        EXECUTE format('DROP POLICY IF EXISTS finance_staff_purchase_request_all_rows ON public.%I', obj.tablename);
        EXECUTE format('DROP POLICY IF EXISTS data_roles_update_operational ON public.%I', obj.tablename);
        EXECUTE format('DROP POLICY IF EXISTS data_roles_update_rows ON public.%I', obj.tablename);
        EXECUTE format('DROP POLICY IF EXISTS staff_recent_purchase_request_update ON public.%I', obj.tablename);
        EXECUTE format('DROP POLICY IF EXISTS staff_recent_purchase_request_delete ON public.%I', obj.tablename);
        EXECUTE format('DROP POLICY IF EXISTS finance_recent_purchase_request_update ON public.%I', obj.tablename);
        EXECUTE format('DROP POLICY IF EXISTS finance_recent_purchase_request_delete ON public.%I', obj.tablename);
        EXECUTE format('DROP POLICY IF EXISTS staff_recent_inventory_transaction_update ON public.%I', obj.tablename);
        EXECUTE format('DROP POLICY IF EXISTS staff_recent_inventory_transaction_delete ON public.%I', obj.tablename);
        EXECUTE format('DROP POLICY IF EXISTS finance_recent_inventory_transaction_update ON public.%I', obj.tablename);
        EXECUTE format('DROP POLICY IF EXISTS finance_recent_inventory_transaction_delete ON public.%I', obj.tablename);
        EXECUTE format('DROP POLICY IF EXISTS data_manager_budget_rows ON public.%I', obj.tablename);
        EXECUTE format('DROP POLICY IF EXISTS database_manager_budget_rows ON public.%I', obj.tablename);

        IF obj.tablename = 'budget' THEN
            EXECUTE format(
                'CREATE POLICY database_manager_budget_rows ON public.%I FOR ALL TO database_manager USING (true) WITH CHECK (true)',
                obj.tablename
            );
            EXECUTE format(
                'CREATE POLICY finance_staff_budget_all_rows ON public.%I FOR ALL TO finance_staff USING (true) WITH CHECK (true)',
                obj.tablename
            );
        ELSE
            IF obj.tablename IN ('purchase_request', 'inventory_transaction') THEN
                EXECUTE format(
                    'CREATE POLICY database_manager_read_rows ON public.%I FOR SELECT TO database_manager USING (true)',
                    obj.tablename
                );
                EXECUTE format(
                    'CREATE POLICY database_manager_insert_rows ON public.%I FOR INSERT TO database_manager WITH CHECK (true)',
                    obj.tablename
                );
            ELSE
                EXECUTE format(
                    'CREATE POLICY database_manager_all_rows ON public.%I FOR ALL TO database_manager USING (true) WITH CHECK (true)',
                    obj.tablename
                );
            END IF;
            EXECUTE format(
                'CREATE POLICY data_roles_read_rows ON public.%I FOR SELECT TO staff USING (true)',
                obj.tablename
            );
            EXECUTE format(
                'CREATE POLICY data_roles_insert_rows ON public.%I FOR INSERT TO staff WITH CHECK (true)',
                obj.tablename
            );
            EXECUTE format(
                'CREATE POLICY finance_staff_read_rows ON public.%I FOR SELECT TO finance_staff USING (true)',
                obj.tablename
            );
            EXECUTE format(
                'CREATE POLICY finance_staff_insert_rows ON public.%I FOR INSERT TO finance_staff WITH CHECK (true)',
                obj.tablename
            );
            IF obj.tablename NOT IN (
                'budget', 'purchase_request', 'inventory_transaction',
                'location_group', 'group_members'
            ) THEN
                EXECUTE format(
                    'CREATE POLICY data_roles_update_rows ON public.%I FOR UPDATE TO staff, finance_staff USING (true) WITH CHECK (true)',
                    obj.tablename
                );
            END IF;
        END IF;
    END LOOP;
END $$;

-- Database managers can correct/delete only purchase requests and inventory
-- transactions dated today, matching staff and finance_staff. NULL and older
-- dates are blocked. INSERT and SELECT remain available without a date limit.
CREATE POLICY database_manager_recent_purchase_request_update
    ON public.purchase_request FOR UPDATE TO database_manager
    USING (request_date = CURRENT_DATE)
    WITH CHECK (request_date = CURRENT_DATE);
CREATE POLICY database_manager_recent_purchase_request_delete
    ON public.purchase_request FOR DELETE TO database_manager
    USING (request_date = CURRENT_DATE);

CREATE POLICY database_manager_recent_inventory_transaction_update
    ON public.inventory_transaction FOR UPDATE TO database_manager
    USING (transaction_date = CURRENT_DATE)
    WITH CHECK (transaction_date = CURRENT_DATE);
CREATE POLICY database_manager_recent_inventory_transaction_delete
    ON public.inventory_transaction FOR DELETE TO database_manager
    USING (transaction_date = CURRENT_DATE);

-- Edit/delete is limited to rows whose business date is today. Rows with a
-- NULL date are not editable or deletable by any of the three app roles.
CREATE POLICY staff_recent_purchase_request_update
    ON public.purchase_request FOR UPDATE TO staff
    USING (request_date = CURRENT_DATE)
    WITH CHECK (request_date = CURRENT_DATE);
CREATE POLICY staff_recent_purchase_request_delete
    ON public.purchase_request FOR DELETE TO staff
    USING (request_date = CURRENT_DATE);
CREATE POLICY finance_recent_purchase_request_update
    ON public.purchase_request FOR UPDATE TO finance_staff
    USING (request_date = CURRENT_DATE)
    WITH CHECK (request_date = CURRENT_DATE);
CREATE POLICY finance_recent_purchase_request_delete
    ON public.purchase_request FOR DELETE TO finance_staff
    USING (request_date = CURRENT_DATE);
CREATE POLICY staff_recent_inventory_transaction_update
    ON public.inventory_transaction FOR UPDATE TO staff
    USING (transaction_date = CURRENT_DATE)
    WITH CHECK (transaction_date = CURRENT_DATE);
CREATE POLICY staff_recent_inventory_transaction_delete
    ON public.inventory_transaction FOR DELETE TO staff
    USING (transaction_date = CURRENT_DATE);
CREATE POLICY finance_recent_inventory_transaction_update
    ON public.inventory_transaction FOR UPDATE TO finance_staff
    USING (transaction_date = CURRENT_DATE)
    WITH CHECK (transaction_date = CURRENT_DATE);
CREATE POLICY finance_recent_inventory_transaction_delete
    ON public.inventory_transaction FOR DELETE TO finance_staff
    USING (transaction_date = CURRENT_DATE);

-- The built-in group and its membership are trigger-maintained from location.is_hlc.
DROP POLICY IF EXISTS data_roles_all_rows ON public.location_group;
DROP POLICY IF EXISTS database_manager_all_rows ON public.location_group;
DROP POLICY IF EXISTS data_roles_read_rows ON public.location_group;
DROP POLICY IF EXISTS data_roles_insert_rows ON public.location_group;
DROP POLICY IF EXISTS data_roles_read_groups ON public.location_group;
DROP POLICY IF EXISTS data_roles_write_custom_groups ON public.location_group;
DROP POLICY IF EXISTS data_roles_update_custom_groups ON public.location_group;
DROP POLICY IF EXISTS data_roles_delete_custom_groups ON public.location_group;
CREATE POLICY data_roles_read_groups ON public.location_group
    FOR SELECT TO database_manager, staff, finance_staff USING (true);
CREATE POLICY data_roles_write_custom_groups ON public.location_group
    FOR INSERT TO database_manager, staff, finance_staff
    WITH CHECK (location_group_name <> 'All HLC Gardens');
CREATE POLICY data_roles_update_custom_groups ON public.location_group
    FOR UPDATE TO database_manager, staff, finance_staff
    USING (location_group_name <> 'All HLC Gardens')
    WITH CHECK (location_group_name <> 'All HLC Gardens');
CREATE POLICY data_roles_delete_custom_groups ON public.location_group
    FOR DELETE TO database_manager
    USING (location_group_name <> 'All HLC Gardens');

DROP POLICY IF EXISTS data_roles_all_rows ON public.group_members;
DROP POLICY IF EXISTS database_manager_all_rows ON public.group_members;
DROP POLICY IF EXISTS data_roles_read_rows ON public.group_members;
DROP POLICY IF EXISTS data_roles_insert_rows ON public.group_members;
DROP POLICY IF EXISTS data_roles_read_group_members ON public.group_members;
DROP POLICY IF EXISTS data_roles_write_custom_group_members ON public.group_members;
DROP POLICY IF EXISTS data_roles_update_custom_group_members ON public.group_members;
DROP POLICY IF EXISTS data_roles_delete_custom_group_members ON public.group_members;
CREATE POLICY data_roles_read_group_members ON public.group_members
    FOR SELECT TO database_manager, staff, finance_staff USING (true);
CREATE POLICY data_roles_write_custom_group_members ON public.group_members
    FOR INSERT TO database_manager, staff, finance_staff
    WITH CHECK (location_group_name <> 'All HLC Gardens');
CREATE POLICY data_roles_update_custom_group_members ON public.group_members
    FOR UPDATE TO database_manager, staff, finance_staff
    USING (location_group_name <> 'All HLC Gardens')
    WITH CHECK (location_group_name <> 'All HLC Gardens');
CREATE POLICY data_roles_delete_custom_group_members ON public.group_members
    FOR DELETE TO database_manager
    USING (location_group_name <> 'All HLC Gardens');

-- Supabase Auth role assignment and token hook.
CREATE SCHEMA IF NOT EXISTS private;
REVOKE ALL ON SCHEMA private FROM PUBLIC, anon, authenticated;
GRANT USAGE ON SCHEMA private TO supabase_auth_admin;

-- Prevent a role from changing the date to restart the correction window.
-- All three data roles may only edit rows dated today; NULL dates are blocked.
CREATE OR REPLACE FUNCTION private.guard_recent_record_date_edit()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = ''
AS $$
DECLARE
    old_row JSONB := to_jsonb(OLD);
    new_row JSONB := to_jsonb(NEW);
    date_column TEXT;
    old_date DATE;
    new_date DATE;
BEGIN
    IF current_user NOT IN ('staff', 'finance_staff', 'database_manager') THEN
        RETURN NEW;
    END IF;

    IF TG_TABLE_NAME = 'purchase_request' THEN
        date_column := 'request_date';
    ELSE
        date_column := 'transaction_date';
    END IF;

    old_date := (old_row ->> date_column)::DATE;
    new_date := (new_row ->> date_column)::DATE;

    IF old_date IS NULL THEN
        RAISE EXCEPTION 'Rows with a NULL date cannot be edited by staff, finance_staff, or database_manager.';
    ELSIF old_date IS DISTINCT FROM CURRENT_DATE THEN
        RAISE EXCEPTION 'Only rows dated today can be edited by staff, finance_staff, or database_manager.';
    ELSIF new_date IS DISTINCT FROM old_date THEN
        RAISE EXCEPTION 'The record date cannot be changed during the correction window.';
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS zz_guard_recent_purchase_request_date
    ON public.purchase_request;
CREATE TRIGGER zz_guard_recent_purchase_request_date
    BEFORE UPDATE ON public.purchase_request
    FOR EACH ROW EXECUTE FUNCTION private.guard_recent_record_date_edit();

DROP TRIGGER IF EXISTS zz_guard_recent_inventory_transaction_date
    ON public.inventory_transaction;
CREATE TRIGGER zz_guard_recent_inventory_transaction_date
    BEFORE UPDATE ON public.inventory_transaction
    FOR EACH ROW EXECUTE FUNCTION private.guard_recent_record_date_edit();

CREATE TABLE IF NOT EXISTS private.user_role_assignment (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    database_role TEXT NOT NULL
        CHECK (database_role IN ('staff', 'finance_staff', 'database_manager'))
);
ALTER TABLE private.user_role_assignment
    DROP CONSTRAINT IF EXISTS user_role_assignment_database_role_check;
UPDATE private.user_role_assignment
SET database_role = 'database_manager'
WHERE database_role = 'data_manager';
UPDATE private.user_role_assignment
SET database_role = 'staff'
WHERE database_role = 'garden_staff';
ALTER TABLE private.user_role_assignment
    ADD CONSTRAINT user_role_assignment_database_role_check
    CHECK (database_role IN ('staff', 'finance_staff', 'database_manager'));
ALTER TABLE private.user_role_assignment ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.user_role_assignment FROM PUBLIC, anon, authenticated,
    staff, finance_staff, database_manager;
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
    IF assigned_role IN ('staff', 'finance_staff', 'database_manager') THEN
        claims := jsonb_set(claims, '{role}', to_jsonb(assigned_role), true);
    ELSE
        claims := jsonb_set(claims, '{role}', '"authenticated"'::JSONB, true);
    END IF;

    RETURN jsonb_set(event, '{claims}', claims, true);
END;
$$;

REVOKE EXECUTE ON FUNCTION public.custom_access_token_hook(JSONB)
    FROM PUBLIC, anon, authenticated, staff, finance_staff, database_manager;
GRANT EXECUTE ON FUNCTION public.custom_access_token_hook(JSONB)
    TO supabase_auth_admin;

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

-- Default permissions for future objects created as postgres
ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
GRANT ALL PRIVILEGES ON TABLES TO database_manager;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
GRANT ALL PRIVILEGES ON SEQUENCES TO database_manager;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
GRANT SELECT, INSERT ON TABLES TO finance_staff;

ALTER DEFAULT PRIVILEGES FOR ROLE postgres IN SCHEMA public
GRANT USAGE, SELECT ON SEQUENCES TO finance_staff;

-- Manager-maintained display names stay in the private schema, outside the Data API.
CREATE TABLE IF NOT EXISTS private.user_profile (
    user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    display_name TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    notes TEXT,
    CONSTRAINT user_profile_display_name_length
        CHECK (display_name IS NULL OR char_length(display_name) <= 100)
);
ALTER TABLE private.user_profile ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.user_profile FROM PUBLIC, anon, authenticated, staff, finance_staff, database_manager;

CREATE OR REPLACE FUNCTION public.list_user_profiles()
RETURNS TABLE (user_id UUID, display_name TEXT)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM private.user_role_assignment a
        WHERE a.user_id = auth.uid() AND a.database_role = 'database_manager'
    ) THEN
        RAISE EXCEPTION 'Only a current database manager can manage user profiles.' USING ERRCODE = '42501';
    END IF;
    RETURN QUERY SELECT p.user_id, p.display_name FROM private.user_profile p;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_my_display_name()
RETURNS TEXT LANGUAGE sql STABLE SECURITY DEFINER SET search_path = '' AS $$
    SELECT p.display_name FROM private.user_profile p WHERE p.user_id = auth.uid()
$$;

CREATE OR REPLACE FUNCTION public.set_user_display_name(p_user_id UUID, p_display_name TEXT)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
    user_email TEXT;
    new_name TEXT := NULLIF(btrim(p_display_name), '');
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM private.user_role_assignment a
        WHERE a.user_id = auth.uid() AND a.database_role = 'database_manager'
    ) THEN
        RAISE EXCEPTION 'Only a current database manager can manage user profiles.' USING ERRCODE = '42501';
    END IF;
    IF new_name IS NOT NULL AND char_length(new_name) > 100 THEN
        RAISE EXCEPTION 'Display name must be 100 characters or fewer.' USING ERRCODE = '22023';
    END IF;
    SELECT u.email INTO user_email FROM auth.users u WHERE u.id = p_user_id;
    IF NOT FOUND THEN
        RAISE EXCEPTION 'This account no longer exists.' USING ERRCODE = '22023';
    END IF;
    INSERT INTO private.user_profile(user_id, display_name)
    VALUES (p_user_id, new_name)
    ON CONFLICT (user_id) DO UPDATE
       SET display_name = EXCLUDED.display_name, updated_at = now();
    IF new_name IS NOT NULL THEN
        UPDATE public.purchase_request SET requested_by = new_name WHERE requested_by = user_email;
        UPDATE public.inventory_transaction SET taken_by = new_name WHERE taken_by = user_email;
    END IF;
END;
$$;

REVOKE EXECUTE ON FUNCTION public.list_user_profiles() FROM PUBLIC, anon, authenticated, staff, finance_staff;
REVOKE EXECUTE ON FUNCTION public.get_my_display_name() FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.set_user_display_name(UUID, TEXT) FROM PUBLIC, anon, authenticated, staff, finance_staff;
GRANT EXECUTE ON FUNCTION public.list_user_profiles() TO database_manager;
GRANT EXECUTE ON FUNCTION public.get_my_display_name() TO staff, finance_staff, database_manager;
GRANT EXECUTE ON FUNCTION public.set_user_display_name(UUID, TEXT) TO database_manager;

-- Append-only history for row changes in public tables. Direct access is private;
-- only the manager-checked listing function can return audit entries.
CREATE TABLE IF NOT EXISTS private.audit_log (
    audit_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    changed_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    actor_user_id UUID,
    actor_email TEXT,
    action TEXT NOT NULL CHECK (action IN ('INSERT', 'UPDATE', 'DELETE')),
    table_name TEXT NOT NULL,
    row_key JSONB NOT NULL,
    old_data JSONB,
    new_data JSONB
);
ALTER TABLE private.audit_log ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.audit_log FROM PUBLIC, anon, authenticated, staff, finance_staff, database_manager;

CREATE OR REPLACE FUNCTION private.capture_row_change()
RETURNS TRIGGER LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
DECLARE
    old_row JSONB;
    new_row JSONB;
    row_data JSONB;
    key_data JSONB := '{}'::JSONB;
    pk_column RECORD;
BEGIN
    IF TG_OP <> 'INSERT' THEN old_row := to_jsonb(OLD); END IF;
    IF TG_OP <> 'DELETE' THEN new_row := to_jsonb(NEW); END IF;
    row_data := COALESCE(new_row, old_row);
    FOR pk_column IN
        SELECT a.attname
        FROM pg_catalog.pg_index i
        JOIN pg_catalog.pg_attribute a ON a.attrelid = i.indrelid AND a.attnum = ANY(i.indkey)
        WHERE i.indrelid = TG_RELID AND i.indisprimary
    LOOP
        key_data := key_data || jsonb_build_object(pk_column.attname, row_data -> pk_column.attname);
    END LOOP;
    INSERT INTO private.audit_log(actor_user_id, actor_email, action, table_name, row_key, old_data, new_data)
    VALUES (auth.uid(), auth.jwt() ->> 'email', TG_OP, TG_TABLE_SCHEMA || '.' || TG_TABLE_NAME,
            key_data, old_row, new_row);
    IF TG_OP = 'DELETE' THEN RETURN OLD; END IF;
    RETURN NEW;
END;
$$;

DO $$
DECLARE t RECORD;
BEGIN
    FOR t IN SELECT c.relname FROM pg_catalog.pg_class c
             JOIN pg_catalog.pg_namespace n ON n.oid = c.relnamespace
             WHERE n.nspname = 'public' AND c.relkind IN ('r','p')
    LOOP
        EXECUTE format('DROP TRIGGER IF EXISTS audit_row_changes ON public.%I', t.relname);
        EXECUTE format('CREATE TRIGGER audit_row_changes AFTER INSERT OR UPDATE OR DELETE ON public.%I FOR EACH ROW EXECUTE FUNCTION private.capture_row_change()', t.relname);
    END LOOP;
END;
$$;

CREATE OR REPLACE FUNCTION public.list_audit_log()
RETURNS TABLE (audit_id BIGINT, changed_at TIMESTAMPTZ, actor_user_id UUID, actor_email TEXT,
               action TEXT, table_name TEXT, row_key JSONB, old_data JSONB, new_data JSONB)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM private.user_role_assignment a
                   WHERE a.user_id = auth.uid() AND a.database_role = 'database_manager') THEN
        RAISE EXCEPTION 'Only a current database manager can view the audit log.' USING ERRCODE = '42501';
    END IF;
    RETURN QUERY SELECT l.audit_id,l.changed_at,l.actor_user_id,l.actor_email,l.action,l.table_name,l.row_key,l.old_data,l.new_data
                 FROM private.audit_log l ORDER BY l.changed_at DESC LIMIT 500;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.list_audit_log() FROM PUBLIC, anon, authenticated, staff, finance_staff;
GRANT EXECUTE ON FUNCTION public.list_audit_log() TO database_manager;

-- Separate account/application events from row-level data changes.
CREATE TABLE IF NOT EXISTS private.application_event (
    event_id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    occurred_at TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    actor_user_id UUID,
    actor_email TEXT,
    event_type TEXT NOT NULL,
    details JSONB NOT NULL DEFAULT '{}'::JSONB
);
ALTER TABLE private.application_event ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON private.application_event FROM PUBLIC, anon, authenticated, staff, finance_staff, database_manager;

CREATE OR REPLACE FUNCTION public.record_app_event(p_event_type TEXT, p_details JSONB DEFAULT '{}'::JSONB)
RETURNS VOID LANGUAGE plpgsql SECURITY DEFINER SET search_path = '' AS $$
BEGIN
    IF p_event_type NOT IN ('BACKUP_DOWNLOAD','PASSWORD_RESET_REQUEST','ROLE_CHANGED','ROLE_REMOVED','DISPLAY_NAME_CHANGED') THEN
        RAISE EXCEPTION 'Unsupported application event.' USING ERRCODE = '22023';
    END IF;
    IF p_event_type IN ('BACKUP_DOWNLOAD','ROLE_CHANGED','ROLE_REMOVED','DISPLAY_NAME_CHANGED')
       AND NOT EXISTS (SELECT 1 FROM private.user_role_assignment a WHERE a.user_id = auth.uid() AND a.database_role = 'database_manager') THEN
        RAISE EXCEPTION 'Only a database manager can record this event.' USING ERRCODE = '42501';
    END IF;
    INSERT INTO private.application_event(actor_user_id, actor_email, event_type, details)
    VALUES (auth.uid(), auth.jwt() ->> 'email', p_event_type,
            CASE WHEN jsonb_typeof(p_details) = 'object' THEN p_details ELSE '{}'::JSONB END);
END;
$$;

CREATE OR REPLACE FUNCTION public.list_application_events()
RETURNS TABLE (event_id BIGINT, occurred_at TIMESTAMPTZ, actor_user_id UUID, actor_email TEXT, event_type TEXT, details JSONB)
LANGUAGE plpgsql STABLE SECURITY DEFINER SET search_path = '' AS $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM private.user_role_assignment a WHERE a.user_id = auth.uid() AND a.database_role = 'database_manager') THEN
        RAISE EXCEPTION 'Only a current database manager can view application events.' USING ERRCODE = '42501';
    END IF;
    RETURN QUERY SELECT e.event_id,e.occurred_at,e.actor_user_id,e.actor_email,e.event_type,e.details
                 FROM private.application_event e ORDER BY e.occurred_at DESC LIMIT 500;
END;
$$;
REVOKE EXECUTE ON FUNCTION public.record_app_event(TEXT, JSONB) FROM PUBLIC, anon;
REVOKE EXECUTE ON FUNCTION public.list_application_events() FROM PUBLIC, anon, authenticated, staff, finance_staff;
GRANT EXECUTE ON FUNCTION public.record_app_event(TEXT, JSONB) TO staff, finance_staff, database_manager;
GRANT EXECUTE ON FUNCTION public.list_application_events() TO database_manager;
