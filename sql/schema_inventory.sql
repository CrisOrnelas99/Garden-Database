-- ============================================================
-- Inventory Schema
-- ============================================================

-- ============================================================
-- CUSTOM
-- Reusable data types, enums and constraints
-- ============================================================
CREATE DOMAIN dollar AS DECIMAL(12,2)
    CHECK (VALUE >= 0);

CREATE DOMAIN nonnegative_count AS INT
    CHECK (VALUE >= 0);

CREATE TYPE inventory_transaction_status AS ENUM (
    'Checked In',
    'Checked Out'
);

CREATE TYPE condition AS ENUM (
    'Good',
    'Require Maintenance',
    'In Maintenance'
);

CREATE TYPE lifecycle_status AS ENUM (
    'Active',
    'Planned',
    'Inactive'
);


-- ============================================================
-- "l-location"
-- School/office details and optional garden fields.
-- ============================================================
CREATE TABLE "l-location" (
    
    location_id SERIAL PRIMARY KEY,
    location_name VARCHAR(200) NOT NULL UNIQUE,
    contact VARCHAR(100),
    email VARCHAR(200),
    lifecycle_status lifecycle_status,
    condition condition,
    bed_count nonnegative_count,
    notes TEXT,

    CONSTRAINT chk_location_optional_garden_fields
        CHECK (
            bed_count IS NOT NULL
            OR (
                lifecycle_status IS NULL
                AND condition IS NULL
            )
        )
);


-- ============================================================
-- "l-location-group"
-- Group rows store names; member rows point to one group and one location.
-- ============================================================
CREATE TABLE "l-location-group" (
    location_group_id SERIAL PRIMARY KEY,
    location_group_name VARCHAR(200) UNIQUE,
    belongs_to_group VARCHAR(200),
    location_name VARCHAR(200),

    CONSTRAINT chk_location_group_row_type
        CHECK (
            (location_group_name IS NOT NULL
                AND belongs_to_group IS NULL
                AND location_name IS NULL)
            OR
            (location_group_name IS NULL
                AND belongs_to_group IS NOT NULL
                AND location_name IS NOT NULL)
        ),

    CONSTRAINT fk_location_group_belongs_to_group
        FOREIGN KEY (belongs_to_group)
        REFERENCES "l-location-group"(location_group_name)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT fk_location_group_member_location
        FOREIGN KEY (location_name)
        REFERENCES "l-location"(location_name)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT uq_location_group_member
        UNIQUE (belongs_to_group, location_name)
);


-- ============================================================
-- "i-budget"
-- One shared amount and remaining balance per budget name.
-- ============================================================
CREATE TABLE "i-budget" (
    
    budget_id SERIAL PRIMARY KEY,
    budget_name VARCHAR(100) NOT NULL UNIQUE,
    budget_amount dollar NOT NULL,
    remaining_budget dollar,
    notes TEXT
);


-- ============================================================
-- "i-item"
-- Item catalog / master item information
-- ============================================================
CREATE TABLE "i-item" (
    
    item_id SERIAL PRIMARY KEY,
    item_name VARCHAR(200) NOT NULL UNIQUE,
    category VARCHAR(50),
    vendor_name VARCHAR(50),
    link TEXT,
    unit_cost dollar,
    notes TEXT
);


-- ============================================================
-- "i-inventory_list"
-- Actual items currently tracked in inventory
-- ============================================================
CREATE TABLE "i-inventory_list" (
    
    inventory_id SERIAL PRIMARY KEY,
    item_name VARCHAR(200) NOT NULL UNIQUE,
    cumulative_asset nonnegative_count NOT NULL DEFAULT 0,
    instock_total nonnegative_count NOT NULL DEFAULT 0,
    reorder_point nonnegative_count,
    counted BOOLEAN NOT NULL DEFAULT FALSE,
    storage_location VARCHAR(200),
    notes TEXT,

    -- Keep referenced item names stable; stock history triggers depend on this key.
    CONSTRAINT fk_inventory_item
        FOREIGN KEY (item_name)
        REFERENCES "i-item"(item_name)
        ON UPDATE RESTRICT
);


-- ============================================================
-- "i-purchase_request"
-- Purchase requests and their assigned budget
-- ============================================================
CREATE TABLE "i-purchase_request" (
    
    request_id SERIAL PRIMARY KEY,
    request_date DATE,
    requested_by VARCHAR(50) NOT NULL,
    requesting_school VARCHAR(200),
    requesting_school_group VARCHAR(200),
    item_name VARCHAR(200) NOT NULL,
    quantity_requested nonnegative_count NOT NULL
        CHECK (quantity_requested > 0),
    total_cost dollar NOT NULL DEFAULT 0,
    delivered_to_fns BOOLEAN NOT NULL DEFAULT FALSE,
    review_status TEXT,
    ordered BOOLEAN NOT NULL DEFAULT FALSE,
    budget_name VARCHAR(100),
    funding_source VARCHAR(100),
    school_year VARCHAR(9),
    notes TEXT,

    CONSTRAINT fk_purchase_request_school
        FOREIGN KEY (requesting_school)
        REFERENCES "l-location"(location_name)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_purchase_request_school_group
        FOREIGN KEY (requesting_school_group)
        REFERENCES "l-location-group"(location_group_name)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT chk_purchase_request_at_most_one_location_assignment
        CHECK (requesting_school IS NULL OR requesting_school_group IS NULL),

    -- Keep referenced item names stable; stock history triggers depend on this key.
    CONSTRAINT fk_purchase_request_item
        FOREIGN KEY (item_name)
        REFERENCES "i-item"(item_name)
        ON UPDATE RESTRICT,

    CONSTRAINT fk_purchase_request_budget
        FOREIGN KEY (budget_name)
        REFERENCES "i-budget"(budget_name)
        ON UPDATE CASCADE,

    CONSTRAINT chk_purchase_request_delivered_must_be_ordered
        CHECK (NOT delivered_to_fns OR ordered)
);


-- ============================================================
-- "i-inventory_transaction"
-- Records inventory being taken from InventoryList
-- ============================================================
CREATE TABLE "i-inventory_transaction" (
    
    transaction_id SERIAL PRIMARY KEY,
    transaction_date DATE DEFAULT CURRENT_DATE,
    status inventory_transaction_status NOT NULL,
    taken_by VARCHAR(50) NOT NULL,
    for_school VARCHAR(200),
    for_school_group VARCHAR(200),
    item_name VARCHAR(200) NOT NULL,
    quantity nonnegative_count NOT NULL
        CHECK (quantity > 0),
    notes TEXT,
    CONSTRAINT fk_inventory_transaction_school
        FOREIGN KEY (for_school)
        REFERENCES "l-location"(location_name)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_inventory_transaction_school_group
        FOREIGN KEY (for_school_group)
        REFERENCES "l-location-group"(location_group_name)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT chk_inventory_transaction_at_most_one_location_assignment
        CHECK (for_school IS NULL OR for_school_group IS NULL),

    CONSTRAINT fk_inventory_transaction_item
        FOREIGN KEY (item_name)
        REFERENCES "i-inventory_list"(item_name)
        ON UPDATE RESTRICT

);


-- ============================================================
-- Inventory FUNCTIONS
-- ============================================================


-- ============================================================
-- TRIGGER 1
-- PurchaseRequest.total_cost =
-- quantity_requested * "i-item".unit_cost
-- ============================================================
CREATE OR REPLACE FUNCTION calculate_purchase_request_total()
RETURNS TRIGGER AS $$
DECLARE
    item_unit_cost NUMERIC;
BEGIN

    SELECT unit_cost
    INTO item_unit_cost
    FROM "i-item"
    WHERE item_name = NEW.item_name;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Item "%" was not found in "i-item"',
            NEW.item_name;
    END IF;

    IF item_unit_cost IS NULL THEN
        RAISE EXCEPTION
            'Item "%" does not have a unit_cost in "i-item"',
            NEW.item_name;
    END IF;

    NEW.total_cost :=
        NEW.quantity_requested * item_unit_cost;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


DROP TRIGGER IF EXISTS trg_calculate_purchase_request_total
ON "i-purchase_request";

CREATE TRIGGER trg_calculate_purchase_request_total
BEFORE INSERT OR UPDATE OF item_name, quantity_requested, total_cost
ON "i-purchase_request"
FOR EACH ROW
EXECUTE FUNCTION calculate_purchase_request_total();


-- ============================================================
-- TRIGGER 2
-- Initialize budget.remaining_budget
-- ============================================================
CREATE OR REPLACE FUNCTION initialize_remaining_budget()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.remaining_budget IS NULL THEN
        NEW.remaining_budget := NEW.budget_amount;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER trg_initialize_remaining_budget
BEFORE INSERT
ON "i-budget"
FOR EACH ROW
EXECUTE FUNCTION initialize_remaining_budget();


-- ============================================================
-- TRIGGER 3
-- Recalculate a budget balance from its ordered purchase requests
-- ============================================================

-- Recalculate the remaining balance for one budget name.
CREATE OR REPLACE FUNCTION recalculate_shared_budget_remaining(
    p_budget_name VARCHAR
)
RETURNS VOID AS $$
BEGIN
    UPDATE "i-budget" b
    SET remaining_budget =
        b.budget_amount
        - COALESCE(
            (
                SELECT SUM(pr.total_cost)
                FROM "i-purchase_request" pr
                WHERE pr.budget_name = p_budget_name
                  AND pr.ordered = TRUE
            ),
            0
        )
    WHERE b.budget_name = p_budget_name;
END;
$$ LANGUAGE plpgsql;

-- Recalculate balances after a purchase request is inserted, changed, or removed.
CREATE OR REPLACE FUNCTION update_remaining_budget()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_OP IN ('INSERT', 'UPDATE')
       AND NEW.budget_name IS NOT NULL
    THEN
        PERFORM recalculate_shared_budget_remaining(NEW.budget_name);
    END IF;

    IF TG_OP = 'DELETE' AND OLD.budget_name IS NOT NULL THEN
        PERFORM recalculate_shared_budget_remaining(OLD.budget_name);
    ELSIF TG_OP = 'UPDATE'
          AND OLD.budget_name IS DISTINCT FROM NEW.budget_name
          AND OLD.budget_name IS NOT NULL
    THEN
        PERFORM recalculate_shared_budget_remaining(OLD.budget_name);
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_remaining_budget
AFTER INSERT OR UPDATE OR DELETE
ON "i-purchase_request"
FOR EACH ROW
EXECUTE FUNCTION update_remaining_budget();


-- ============================================================
-- TRIGGER 4
-- Every inventory transaction updates stock independently.
-- ============================================================
CREATE OR REPLACE FUNCTION update_inventory_after_transaction()
RETURNS TRIGGER AS $$
DECLARE
    available_stock INT;
    inventory_change INT;
BEGIN
    IF TG_OP = 'INSERT' THEN
        inventory_change := CASE
            WHEN NEW.status = 'Checked Out' THEN -NEW.quantity
            ELSE NEW.quantity
        END;

        SELECT instock_total INTO available_stock
        FROM "i-inventory_list"
        WHERE item_name = NEW.item_name
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Item "%" is not present in "i-inventory_list"', NEW.item_name;
        END IF;
        IF available_stock + inventory_change < 0 THEN
            RAISE EXCEPTION
                'Not enough "%" in stock. Available: %, requested: %',
                NEW.item_name, available_stock, NEW.quantity;
        END IF;

        UPDATE "i-inventory_list"
        SET instock_total = instock_total + inventory_change
        WHERE item_name = NEW.item_name;
        RETURN NEW;

    ELSIF TG_OP = 'UPDATE' THEN
        -- Assignment, date, notes, and other descriptive edits do not change stock.
        IF NEW.item_name IS NOT DISTINCT FROM OLD.item_name
           AND NEW.status IS NOT DISTINCT FROM OLD.status
           AND NEW.quantity IS NOT DISTINCT FROM OLD.quantity
        THEN
            RETURN NEW;
        END IF;

        -- Reverse the old transaction before applying its updated movement.
        inventory_change := CASE
            WHEN OLD.status = 'Checked Out' THEN OLD.quantity
            ELSE -OLD.quantity
        END;

        UPDATE "i-inventory_list"
        SET instock_total = instock_total + inventory_change
        WHERE item_name = OLD.item_name
          AND instock_total + inventory_change >= 0;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                'Cannot reverse the previous "%" transaction because the current stock would become negative',
                OLD.item_name;
        END IF;

        inventory_change := CASE
            WHEN NEW.status = 'Checked Out' THEN -NEW.quantity
            ELSE NEW.quantity
        END;

        SELECT instock_total
        INTO available_stock
        FROM "i-inventory_list"
        WHERE item_name = NEW.item_name
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                'Item "%" is not present in InventoryList',
                NEW.item_name;
        END IF;

        IF available_stock + inventory_change < 0 THEN
            RAISE EXCEPTION
                'Not enough "%" in stock. Available: %, requested: %',
                NEW.item_name, available_stock, NEW.quantity;
        END IF;

        UPDATE "i-inventory_list"
        SET instock_total = instock_total + inventory_change
        WHERE item_name = NEW.item_name;

        RETURN NEW;

    ELSIF TG_OP = 'DELETE' THEN
        inventory_change := CASE
            WHEN OLD.status = 'Checked Out' THEN OLD.quantity
            ELSE -OLD.quantity
        END;

        -- Deleting a check-in removes its stock addition; do not allow stock below zero.
        UPDATE "i-inventory_list"
        SET instock_total = instock_total + inventory_change
        WHERE item_name = OLD.item_name
          AND instock_total + inventory_change >= 0;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                'Cannot delete the "%" transaction because the current stock would become negative',
                OLD.item_name;
        END IF;

        RETURN OLD;

    END IF;

END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_inventory_transaction
BEFORE INSERT OR UPDATE OR DELETE
ON "i-inventory_transaction"
FOR EACH ROW
EXECUTE FUNCTION update_inventory_after_transaction();

-- ============================================================
-- TRIGGER 5
-- Update inventory when a purchase request is received,
-- edited, or marked as no longer received
-- ============================================================
CREATE OR REPLACE FUNCTION update_inventory_when_received()
RETURNS TRIGGER AS $$
DECLARE
    inventory_delta INT;
    available_stock INT;
BEGIN
    IF TG_OP = 'INSERT' THEN
        IF NEW.delivered_to_fns THEN
            inventory_delta := NEW.quantity_requested;
            SELECT instock_total INTO available_stock
            FROM "i-inventory_list"
            WHERE item_name = NEW.item_name
            FOR UPDATE;

            IF NOT FOUND THEN
                RAISE EXCEPTION 'Item "%" is not present in "i-inventory_list"', NEW.item_name;
            END IF;

            UPDATE "i-inventory_list"
            SET cumulative_asset = cumulative_asset + inventory_delta,
                instock_total = instock_total + inventory_delta
            WHERE item_name = NEW.item_name;
        END IF;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        IF OLD.delivered_to_fns THEN
            inventory_delta := -OLD.quantity_requested;
            SELECT instock_total INTO available_stock
            FROM "i-inventory_list"
            WHERE item_name = OLD.item_name
            FOR UPDATE;

            IF NOT FOUND THEN
                RAISE EXCEPTION 'Item "%" is not present in "i-inventory_list"', OLD.item_name;
            END IF;
            IF available_stock < -inventory_delta THEN
                RAISE EXCEPTION 'Cannot remove delivered quantity for "%": only % remain in stock',
                    OLD.item_name, available_stock;
            END IF;

            UPDATE "i-inventory_list"
            SET cumulative_asset = cumulative_asset + inventory_delta,
                instock_total = instock_total + inventory_delta
            WHERE item_name = OLD.item_name;
        END IF;
        RETURN OLD;
    ELSE
        -- If the delivered item is unchanged, apply only the quantity difference.
        IF OLD.delivered_to_fns AND NEW.delivered_to_fns
           AND OLD.item_name = NEW.item_name THEN
            inventory_delta := NEW.quantity_requested - OLD.quantity_requested;
            IF inventory_delta <> 0 THEN
                SELECT instock_total INTO available_stock
                FROM "i-inventory_list"
                WHERE item_name = NEW.item_name
                FOR UPDATE;

                IF NOT FOUND THEN
                    RAISE EXCEPTION 'Item "%" is not present in "i-inventory_list"', NEW.item_name;
                END IF;
                IF inventory_delta < 0 AND available_stock < -inventory_delta THEN
                    RAISE EXCEPTION 'Cannot reduce delivered quantity for "%": only % remain in stock',
                        NEW.item_name, available_stock;
                END IF;

                UPDATE "i-inventory_list"
                SET cumulative_asset = cumulative_asset + inventory_delta,
                    instock_total = instock_total + inventory_delta
                WHERE item_name = NEW.item_name;
            END IF;
            RETURN NEW;
        END IF;

        -- Reverse the prior delivery only when its delivered item or state changes.
        IF OLD.delivered_to_fns THEN
            inventory_delta := -OLD.quantity_requested;
            SELECT instock_total INTO available_stock
            FROM "i-inventory_list"
            WHERE item_name = OLD.item_name
            FOR UPDATE;

            IF NOT FOUND THEN
                RAISE EXCEPTION 'Item "%" is not present in "i-inventory_list"', OLD.item_name;
            END IF;
            IF available_stock < -inventory_delta THEN
                RAISE EXCEPTION 'Cannot remove delivered quantity for "%": only % remain in stock',
                    OLD.item_name, available_stock;
            END IF;

            UPDATE "i-inventory_list"
            SET cumulative_asset = cumulative_asset + inventory_delta,
                instock_total = instock_total + inventory_delta
            WHERE item_name = OLD.item_name;
        END IF;

        -- Add the new delivery only when its delivered item or state changes.
        IF NEW.delivered_to_fns THEN
            inventory_delta := NEW.quantity_requested;
            SELECT instock_total INTO available_stock
            FROM "i-inventory_list"
            WHERE item_name = NEW.item_name
            FOR UPDATE;

            IF NOT FOUND THEN
                RAISE EXCEPTION 'Item "%" is not present in "i-inventory_list"', NEW.item_name;
            END IF;

            UPDATE "i-inventory_list"
            SET cumulative_asset = cumulative_asset + inventory_delta,
                instock_total = instock_total + inventory_delta
            WHERE item_name = NEW.item_name;
        END IF;

        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_inventory_when_received
ON "i-purchase_request";

CREATE TRIGGER trg_update_inventory_when_received
AFTER INSERT OR UPDATE OR DELETE
ON "i-purchase_request"
FOR EACH ROW
EXECUTE FUNCTION update_inventory_when_received();


-- ============================================================
-- TRIGGER 6
-- Recalculate remaining budget when its amount or stored balance changes
-- Ordered requests only
-- ============================================================

CREATE OR REPLACE FUNCTION update_remaining_budget_after_budget_change()
RETURNS TRIGGER AS $$
BEGIN
    NEW.remaining_budget :=
        NEW.budget_amount
        - COALESCE(
            (
                SELECT SUM(pr.total_cost)
                FROM "i-purchase_request" pr
                WHERE pr.budget_name = NEW.budget_name
                  AND pr.ordered = TRUE
            ),
            0
        );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_remaining_budget_after_budget_change
ON "i-budget";

CREATE TRIGGER trg_update_remaining_budget_after_budget_change
BEFORE UPDATE OF budget_amount, remaining_budget
ON "i-budget"
FOR EACH ROW
EXECUTE FUNCTION update_remaining_budget_after_budget_change();


-- ============================================================
-- TRIGGER 7
-- Recalculate unordered request totals when an item's unit cost changes
-- ============================================================
CREATE OR REPLACE FUNCTION update_purchase_totals_after_item_cost_change()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE "i-purchase_request"
    SET total_cost = quantity_requested * NEW.unit_cost
    WHERE item_name = NEW.item_name
      AND ordered = FALSE;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_purchase_totals_after_item_cost_change
AFTER UPDATE OF unit_cost
ON "i-item"
FOR EACH ROW
WHEN (OLD.unit_cost IS DISTINCT FROM NEW.unit_cost)
EXECUTE FUNCTION update_purchase_totals_after_item_cost_change();


-- Reconcile any existing balances with the ordered purchase requests.
UPDATE "i-budget" b
SET remaining_budget = b.budget_amount - COALESCE(
    (
        SELECT SUM(pr.total_cost)
        FROM "i-purchase_request" pr
        WHERE pr.budget_name = b.budget_name
          AND pr.ordered = TRUE
    ),
    0
)
WHERE b.remaining_budget IS DISTINCT FROM b.budget_amount - COALESCE(
    (
        SELECT SUM(pr.total_cost)
        FROM "i-purchase_request" pr
        WHERE pr.budget_name = b.budget_name
          AND pr.ordered = TRUE
    ),
    0
);


-- ============================================================
-- TRIGGER 8 AND TRIGGER 9
-- Require purchase requests and inventory transactions to reference
-- a location group that has at least one assigned location.
-- Deferred checks allow a group and its location rows to be created
-- in the same transaction, including when a group name is updated.
-- ============================================================
CREATE OR REPLACE FUNCTION ensure_referenced_group_has_locations()
RETURNS TRIGGER AS $$
DECLARE
    group_name_to_check VARCHAR(200);
BEGIN
    IF TG_TABLE_NAME = 'i-purchase_request' THEN
        SELECT requesting_school_group
        INTO group_name_to_check
        FROM "i-purchase_request"
        WHERE request_id = NEW.request_id;
    ELSIF TG_TABLE_NAME = 'i-inventory_transaction' THEN
        SELECT for_school_group
        INTO group_name_to_check
        FROM "i-inventory_transaction"
        WHERE transaction_id = NEW.transaction_id;
    ELSE
        RAISE EXCEPTION 'Unsupported table for location group validation: %', TG_TABLE_NAME;
    END IF;

    -- The row may have been deleted or reassigned later in the same transaction.
    IF NOT FOUND THEN
        RETURN NULL;
    END IF;

    -- A null group name means the row uses its direct location foreign key.
    IF group_name_to_check IS NULL THEN
        RETURN NULL;
    END IF;

    PERFORM 1
    FROM "l-location-group"
    WHERE location_group_name = group_name_to_check
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Location group "%" does not exist', group_name_to_check;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM "l-location-group"
        WHERE belongs_to_group = group_name_to_check
    ) THEN
        RAISE EXCEPTION
            'Location group "%" has no assigned locations',
            group_name_to_check;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;


-- TRIGGER 8: validate a purchase request's group after all transaction changes.
CREATE CONSTRAINT TRIGGER trg_require_purchase_request_group_locations
AFTER INSERT OR UPDATE
ON "i-purchase_request"
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION ensure_referenced_group_has_locations();

-- TRIGGER 9: validate an inventory transaction's group after all transaction changes.
CREATE CONSTRAINT TRIGGER trg_require_inventory_transaction_group_locations
AFTER INSERT OR UPDATE
ON "i-inventory_transaction"
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION ensure_referenced_group_has_locations();


-- ============================================================
-- TRIGGER 10
-- Keep a referenced location group from losing its final location.
-- The deferred check permits replacing or moving members within one transaction.
-- ============================================================
CREATE OR REPLACE FUNCTION prevent_emptying_referenced_location_group()
RETURNS TRIGGER AS $$
DECLARE
    group_name_to_check VARCHAR(200);
BEGIN
    -- Only member rows can remove a location from a group.
    IF OLD.belongs_to_group IS NULL THEN
        RETURN NULL;
    END IF;

    group_name_to_check := OLD.belongs_to_group;

    -- A parent group rename cascades its name to member rows. If the old name
    -- no longer exists, this deferred event does not remove a membership.
    PERFORM 1
    FROM "l-location-group"
    WHERE location_group_name = group_name_to_check
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN NULL;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM "l-location-group"
        WHERE belongs_to_group = group_name_to_check
    ) THEN
        RETURN NULL;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM "i-purchase_request"
        WHERE requesting_school_group = group_name_to_check
    ) OR EXISTS (
        SELECT 1
        FROM "i-inventory_transaction"
        WHERE for_school_group = group_name_to_check
    ) THEN
        RAISE EXCEPTION
            'Cannot remove the final location from referenced group "%"',
            group_name_to_check;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;


-- TRIGGER 10: prevent a used group from becoming unassigned.
CREATE CONSTRAINT TRIGGER trg_prevent_emptying_referenced_location_group
AFTER DELETE OR UPDATE
ON "l-location-group"
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION prevent_emptying_referenced_location_group();
