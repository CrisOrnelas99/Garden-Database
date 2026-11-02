-- ============================================================
-- Inventory Schema
-- ============================================================

-- ============================================================
-- CUSTOM
-- Reusable data types, enums and constraints
-- ============================================================
CREATE DOMAIN dollar AS DECIMAL(12,2)
    CHECK (VALUE >= 0);

CREATE TYPE inventory_transaction_status AS ENUM (
    'Checked In',
    'Checked Out'
);

-- ============================================================
-- budget
-- One shared amount and remaining balance per budget name.
-- ============================================================
CREATE TABLE budget (
    
    budget_id SERIAL PRIMARY KEY,
    budget_name VARCHAR(100) NOT NULL UNIQUE,
    budget_amount dollar NOT NULL,
    remaining_budget dollar,
    notes TEXT
);


-- ============================================================
-- item
-- Item catalog / master item information
-- ============================================================
CREATE TABLE item (
    
    item_id SERIAL PRIMARY KEY,
    item_name VARCHAR(200) NOT NULL UNIQUE,
    category VARCHAR(50),
    vendor_name VARCHAR(50),
    link TEXT,
    unit_cost dollar,
    notes TEXT
);


-- ============================================================
-- inventory_list
-- Actual items currently tracked in inventory
-- ============================================================
CREATE TABLE inventory_list (
    
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
        REFERENCES item(item_name)
        ON UPDATE RESTRICT
);


-- ============================================================
-- purchase_request
-- Purchase requests and their assigned budget
-- ============================================================
CREATE TABLE purchase_request (
    
    request_id SERIAL PRIMARY KEY,
    request_date DATE,
    requested_by VARCHAR(50) NOT NULL,
    requesting_school VARCHAR(200),
    requesting_school_group VARCHAR(200),
    item_name VARCHAR(200) NOT NULL,
    unit_cost_at_request dollar NOT NULL,
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
        REFERENCES location(location_name)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_purchase_request_school_group
        FOREIGN KEY (requesting_school_group)
        REFERENCES location_group(location_group_name)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT chk_purchase_request_at_most_one_location_assignment
        CHECK (requesting_school IS NULL OR requesting_school_group IS NULL),

    -- Keep referenced item names stable; stock history triggers depend on this key.
    CONSTRAINT fk_purchase_request_item
        FOREIGN KEY (item_name)
        REFERENCES item(item_name)
        ON UPDATE RESTRICT,

    CONSTRAINT fk_purchase_request_budget
        FOREIGN KEY (budget_name)
        REFERENCES budget(budget_name)
        ON UPDATE CASCADE,

    CONSTRAINT chk_purchase_request_delivered_must_be_ordered
        CHECK (NOT delivered_to_fns OR ordered)
);


-- ============================================================
-- inventory_transaction
-- Records inventory being taken from InventoryList
-- ============================================================
CREATE TABLE inventory_transaction (
    
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
        REFERENCES location(location_name)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_inventory_transaction_school_group
        FOREIGN KEY (for_school_group)
        REFERENCES location_group(location_group_name)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT chk_inventory_transaction_at_most_one_location_assignment
        CHECK (for_school IS NULL OR for_school_group IS NULL),

    CONSTRAINT fk_inventory_transaction_item
        FOREIGN KEY (item_name)
        REFERENCES inventory_list(item_name)
        ON UPDATE RESTRICT

);


-- ============================================================
-- Inventory FUNCTIONS
-- ============================================================


-- ============================================================
-- TRIGGER 1
-- PurchaseRequest.total_cost =
-- quantity_requested * unit_cost_at_request
-- ============================================================
CREATE OR REPLACE FUNCTION calculate_purchase_request_total()
RETURNS TRIGGER AS $$
DECLARE
    item_unit_cost NUMERIC;
BEGIN
    IF NEW.unit_cost_at_request IS NULL
       OR (TG_OP = 'UPDATE'
           AND NEW.item_name IS DISTINCT FROM OLD.item_name
           AND NEW.unit_cost_at_request IS NOT DISTINCT FROM OLD.unit_cost_at_request) THEN
        SELECT unit_cost
        INTO item_unit_cost
        FROM item
        WHERE item_name = NEW.item_name;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                'Item "%" was not found in item',
                NEW.item_name;
        END IF;

        IF item_unit_cost IS NULL THEN
            RAISE EXCEPTION
                'Item "%" does not have a unit_cost in item',
                NEW.item_name;
        END IF;

        NEW.unit_cost_at_request := item_unit_cost;
    END IF;

    -- Historical source totals can include shipping or discounts. Retain an
    -- explicitly supplied total on insert; calculate only when no total was
    -- supplied (the table default is zero), or when unit/quantity changes later.
    IF NEW.quantity_requested IS NULL THEN
        RETURN NEW;
    END IF;

    IF TG_OP = 'INSERT' AND NEW.total_cost <> 0 THEN
        RETURN NEW;
    END IF;

    IF TG_OP = 'UPDATE'
       AND NEW.total_cost IS DISTINCT FROM OLD.total_cost THEN
        RETURN NEW;
    END IF;

    NEW.total_cost :=
        NEW.quantity_requested * NEW.unit_cost_at_request;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


DROP TRIGGER IF EXISTS trg_calculate_purchase_request_total
ON purchase_request;

CREATE TRIGGER trg_calculate_purchase_request_total
BEFORE INSERT OR UPDATE OF item_name, unit_cost_at_request, quantity_requested, total_cost
ON purchase_request
FOR EACH ROW
EXECUTE FUNCTION calculate_purchase_request_total();


-- ============================================================
-- TRIGGER 2
-- Initialize budget.remaining_budget
-- ============================================================
CREATE OR REPLACE FUNCTION initialize_remaining_budget()
RETURNS TRIGGER AS $$
BEGIN
    -- Treat the budget amount as authoritative; ignore any entered balance.
    NEW.remaining_budget := NEW.budget_amount;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER trg_initialize_remaining_budget
BEFORE INSERT
ON budget
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
    UPDATE budget b
    SET remaining_budget =
        b.budget_amount
        - COALESCE(
            (
                SELECT SUM(pr.total_cost)
                FROM purchase_request pr
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
ON purchase_request
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
        FROM inventory_list
        WHERE item_name = NEW.item_name
        FOR UPDATE;

        IF NOT FOUND THEN
            RAISE EXCEPTION 'Item "%" is not present in inventory_list', NEW.item_name;
        END IF;
        IF available_stock + inventory_change < 0 THEN
            RAISE EXCEPTION
                'Not enough "%" in stock. Available: %, requested: %',
                NEW.item_name, available_stock, NEW.quantity;
        END IF;

        UPDATE inventory_list
        SET instock_total = instock_total + inventory_change
        WHERE item_name = NEW.item_name;
        RETURN NEW;

    ELSIF TG_OP = 'UPDATE' THEN
        IF NEW.status IS DISTINCT FROM OLD.status THEN
            RAISE EXCEPTION
                'Do not change an inventory transaction status. Add a new row to record another check-in or check-out.';
        END IF;

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

        UPDATE inventory_list
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
        FROM inventory_list
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

        UPDATE inventory_list
        SET instock_total = instock_total + inventory_change
        WHERE item_name = NEW.item_name;

        RETURN NEW;

    ELSIF TG_OP = 'DELETE' THEN
        inventory_change := CASE
            WHEN OLD.status = 'Checked Out' THEN OLD.quantity
            ELSE -OLD.quantity
        END;

        -- Deleting a check-in removes its stock addition; do not allow stock below zero.
        UPDATE inventory_list
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
ON inventory_transaction
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
            FROM inventory_list
            WHERE item_name = NEW.item_name
            FOR UPDATE;

            IF NOT FOUND THEN
                RAISE EXCEPTION 'Item "%" is not present in inventory_list', NEW.item_name;
            END IF;

            UPDATE inventory_list
            SET cumulative_asset = cumulative_asset + inventory_delta,
                instock_total = instock_total + inventory_delta
            WHERE item_name = NEW.item_name;
        END IF;
        RETURN NEW;
    ELSIF TG_OP = 'DELETE' THEN
        IF OLD.delivered_to_fns THEN
            inventory_delta := -OLD.quantity_requested;
            SELECT instock_total INTO available_stock
            FROM inventory_list
            WHERE item_name = OLD.item_name
            FOR UPDATE;

            IF NOT FOUND THEN
                RAISE EXCEPTION 'Item "%" is not present in inventory_list', OLD.item_name;
            END IF;
            IF available_stock < -inventory_delta THEN
                RAISE EXCEPTION 'Cannot remove delivered quantity for "%": only % remain in stock',
                    OLD.item_name, available_stock;
            END IF;

            UPDATE inventory_list
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
                FROM inventory_list
                WHERE item_name = NEW.item_name
                FOR UPDATE;

                IF NOT FOUND THEN
                    RAISE EXCEPTION 'Item "%" is not present in inventory_list', NEW.item_name;
                END IF;
                IF inventory_delta < 0 AND available_stock < -inventory_delta THEN
                    RAISE EXCEPTION 'Cannot reduce delivered quantity for "%": only % remain in stock',
                        NEW.item_name, available_stock;
                END IF;

                UPDATE inventory_list
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
            FROM inventory_list
            WHERE item_name = OLD.item_name
            FOR UPDATE;

            IF NOT FOUND THEN
                RAISE EXCEPTION 'Item "%" is not present in inventory_list', OLD.item_name;
            END IF;
            IF available_stock < -inventory_delta THEN
                RAISE EXCEPTION 'Cannot remove delivered quantity for "%": only % remain in stock',
                    OLD.item_name, available_stock;
            END IF;

            UPDATE inventory_list
            SET cumulative_asset = cumulative_asset + inventory_delta,
                instock_total = instock_total + inventory_delta
            WHERE item_name = OLD.item_name;
        END IF;

        -- Add the new delivery only when its delivered item or state changes.
        IF NEW.delivered_to_fns THEN
            inventory_delta := NEW.quantity_requested;
            SELECT instock_total INTO available_stock
            FROM inventory_list
            WHERE item_name = NEW.item_name
            FOR UPDATE;

            IF NOT FOUND THEN
                RAISE EXCEPTION 'Item "%" is not present in inventory_list', NEW.item_name;
            END IF;

            UPDATE inventory_list
            SET cumulative_asset = cumulative_asset + inventory_delta,
                instock_total = instock_total + inventory_delta
            WHERE item_name = NEW.item_name;
        END IF;

        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_inventory_when_received
ON purchase_request;

CREATE TRIGGER trg_update_inventory_when_received
AFTER INSERT OR UPDATE OR DELETE
ON purchase_request
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
                FROM purchase_request pr
                WHERE pr.budget_name = NEW.budget_name
                  AND pr.ordered = TRUE
            ),
            0
        );

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_remaining_budget_after_budget_change
ON budget;

CREATE TRIGGER trg_update_remaining_budget_after_budget_change
BEFORE UPDATE OF budget_amount, remaining_budget
ON budget
FOR EACH ROW
EXECUTE FUNCTION update_remaining_budget_after_budget_change();


-- Reconcile any existing balances with the ordered purchase requests.
UPDATE budget b
SET remaining_budget = b.budget_amount - COALESCE(
    (
        SELECT SUM(pr.total_cost)
        FROM purchase_request pr
        WHERE pr.budget_name = b.budget_name
          AND pr.ordered = TRUE
    ),
    0
)
WHERE b.remaining_budget IS DISTINCT FROM b.budget_amount - COALESCE(
    (
        SELECT SUM(pr.total_cost)
        FROM purchase_request pr
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
    IF TG_TABLE_NAME = 'purchase_request' THEN
        SELECT requesting_school_group
        INTO group_name_to_check
        FROM purchase_request
        WHERE request_id = NEW.request_id;
    ELSIF TG_TABLE_NAME = 'inventory_transaction' THEN
        SELECT for_school_group
        INTO group_name_to_check
        FROM inventory_transaction
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
    FROM location_group
    WHERE location_group_name = group_name_to_check
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Location group "%" does not exist', group_name_to_check;
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM group_location
        WHERE location_group_name = group_name_to_check
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
ON purchase_request
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION ensure_referenced_group_has_locations();

-- TRIGGER 9: validate an inventory transaction's group after all transaction changes.
CREATE CONSTRAINT TRIGGER trg_require_inventory_transaction_group_locations
AFTER INSERT OR UPDATE
ON inventory_transaction
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
    group_name_to_check := OLD.location_group_name;

    -- A parent group rename cascades its name to member rows. If the old name
    -- no longer exists, this deferred event does not remove a membership.
    PERFORM 1
    FROM location_group
    WHERE location_group_name = group_name_to_check
    FOR UPDATE;

    IF NOT FOUND THEN
        RETURN NULL;
    END IF;

    -- This built-in group may legitimately have no locations with garden details.
    IF group_name_to_check = 'All HLC Gardens' THEN
        RETURN NULL;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM group_location
        WHERE location_group_name = group_name_to_check
    ) THEN
        RETURN NULL;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM purchase_request
        WHERE requesting_school_group = group_name_to_check
    ) OR EXISTS (
        SELECT 1
        FROM inventory_transaction
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
ON group_location
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION prevent_emptying_referenced_location_group();


-- ============================================================
-- TRIGGER 11
-- Prevent deleting inventory rows that still have stock or purchase requests.
-- Pending requests may still be created before an inventory_list row exists;
-- the delivery trigger requires that row before marking a request delivered.
-- ============================================================
CREATE OR REPLACE FUNCTION prevent_inventory_list_delete_when_in_use()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.instock_total > 0 THEN
        RAISE EXCEPTION
            'Cannot remove "%" from inventory_list while % items are in stock',
            OLD.item_name, OLD.instock_total;
    END IF;

    IF EXISTS (
        SELECT 1
        FROM purchase_request
        WHERE item_name = OLD.item_name
    ) THEN
        RAISE EXCEPTION
            'Cannot remove "%" from inventory_list while purchase requests reference it',
            OLD.item_name;
    END IF;

    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_prevent_inventory_list_delete_when_in_use
BEFORE DELETE
ON inventory_list
FOR EACH ROW
EXECUTE FUNCTION prevent_inventory_list_delete_when_in_use();


-- ============================================================
-- TRIGGERS 12 AND 13
-- Allow personal rows with no location; otherwise allow one assignment only.
-- Selecting one assignment path clears the other on updates.
-- ============================================================
CREATE OR REPLACE FUNCTION normalize_purchase_request_location_assignment()
RETURNS TRIGGER AS $$
DECLARE
    school_changed BOOLEAN;
    group_changed BOOLEAN;
BEGIN
    IF TG_OP = 'UPDATE' THEN
        school_changed := NEW.requesting_school IS DISTINCT FROM OLD.requesting_school;
        group_changed := NEW.requesting_school_group IS DISTINCT FROM OLD.requesting_school_group;

        IF NEW.requesting_school IS NOT NULL
           AND NEW.requesting_school_group IS NOT NULL THEN
            IF school_changed AND NOT group_changed THEN
                NEW.requesting_school_group := NULL;
            ELSIF group_changed AND NOT school_changed THEN
                NEW.requesting_school := NULL;
            ELSE
                RAISE EXCEPTION
                    'Choose either a school or a location group for a purchase request, not both.';
            END IF;
        END IF;
    END IF;

    IF NEW.requesting_school IS NOT NULL
       AND NEW.requesting_school_group IS NOT NULL THEN
        RAISE EXCEPTION
            'Choose either a school or a location group for a purchase request, not both.';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Normalize and validate a purchase request's school/group assignment.
CREATE TRIGGER trg_purchase_request_location_assignment
BEFORE INSERT OR UPDATE OF requesting_school, requesting_school_group
ON purchase_request
FOR EACH ROW
EXECUTE FUNCTION normalize_purchase_request_location_assignment();


CREATE OR REPLACE FUNCTION normalize_inventory_transaction_location_assignment()
RETURNS TRIGGER AS $$
DECLARE
    school_changed BOOLEAN;
    group_changed BOOLEAN;
BEGIN
    IF TG_OP = 'UPDATE' THEN
        school_changed := NEW.for_school IS DISTINCT FROM OLD.for_school;
        group_changed := NEW.for_school_group IS DISTINCT FROM OLD.for_school_group;

        IF NEW.for_school IS NOT NULL
           AND NEW.for_school_group IS NOT NULL THEN
            IF school_changed AND NOT group_changed THEN
                NEW.for_school_group := NULL;
            ELSIF group_changed AND NOT school_changed THEN
                NEW.for_school := NULL;
            ELSE
                RAISE EXCEPTION
                    'Choose either a school or a location group for an inventory transaction, not both.';
            END IF;
        END IF;
    END IF;

    IF NEW.for_school IS NOT NULL
       AND NEW.for_school_group IS NOT NULL THEN
        RAISE EXCEPTION
            'Choose either a school or a location group for an inventory transaction, not both.';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Normalize and validate an inventory transaction's school/group assignment.
CREATE TRIGGER trg_inventory_transaction_location_assignment
BEFORE INSERT OR UPDATE OF for_school, for_school_group
ON inventory_transaction
FOR EACH ROW
EXECUTE FUNCTION normalize_inventory_transaction_location_assignment();
