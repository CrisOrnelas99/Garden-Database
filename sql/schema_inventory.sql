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


-- ============================================================
-- location
-- ============================================================
CREATE TABLE location (
    
    location_id SERIAL PRIMARY KEY,
    location_name VARCHAR(200) NOT NULL UNIQUE,
    contact VARCHAR(100),
    email VARCHAR(200),
    notes TEXT
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
-- InventoryList
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

    CONSTRAINT fk_inventory_item
        FOREIGN KEY (item_name)
        REFERENCES item(item_name)
        ON UPDATE CASCADE
);


-- ============================================================
-- PurchaseRequest
-- Purchase requests and their assigned budget
-- ============================================================
CREATE TABLE purchase_request (
    
    request_id SERIAL PRIMARY KEY,
    request_date DATE,
    requested_by VARCHAR(50) NOT NULL,
    requesting_for VARCHAR(200),
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

    CONSTRAINT fk_purchase_request_requesting_for
        FOREIGN KEY (requesting_for)
        REFERENCES location(location_name)
        ON UPDATE CASCADE,

    CONSTRAINT fk_purchase_request_item
        FOREIGN KEY (item_name)
        REFERENCES item(item_name)
        ON UPDATE CASCADE,

    CONSTRAINT fk_purchase_request_budget
        FOREIGN KEY (budget_name)
        REFERENCES budget(budget_name)
        ON UPDATE CASCADE,

    CONSTRAINT chk_purchase_request_delivered_must_be_ordered
        CHECK (NOT delivered_to_fns OR ordered)
);


-- ============================================================
-- InventoryTransaction
-- Records inventory being taken from InventoryList
-- ============================================================
CREATE TABLE inventory_transaction (
    
    transaction_id SERIAL PRIMARY KEY,
    transaction_date DATE DEFAULT CURRENT_DATE,
    status inventory_transaction_status NOT NULL,
    taken_by VARCHAR(50) NOT NULL,
    for_school VARCHAR(200),
    item_name VARCHAR(200) NOT NULL,
    quantity nonnegative_count NOT NULL
        CHECK (quantity > 0),
    notes TEXT,
    CONSTRAINT fk_inventory_transaction_school
        FOREIGN KEY (for_school)
        REFERENCES location(location_name)
        ON UPDATE CASCADE,

    CONSTRAINT fk_inventory_transaction_item
        FOREIGN KEY (item_name)
        REFERENCES inventory_list(item_name)
        ON UPDATE CASCADE
);


-- ============================================================
-- Inventory FUNCTIONS
-- ============================================================


-- ============================================================
-- TRIGGER 1
-- PurchaseRequest.total_cost =
-- quantity_requested * item.unit_cost
-- ============================================================
CREATE OR REPLACE FUNCTION calculate_purchase_request_total()
RETURNS TRIGGER AS $$
DECLARE
    item_unit_cost NUMERIC;
BEGIN

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

    NEW.total_cost :=
        NEW.quantity_requested * item_unit_cost;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER trg_calculate_purchase_request_total
BEFORE INSERT OR UPDATE OF item_name, quantity_requested
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
    IF NEW.remaining_budget IS NULL THEN
        NEW.remaining_budget := NEW.budget_amount;
    END IF;

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
-- Recalculate the shared remaining budget across all funding sources
-- using ordered requests only
-- ============================================================

-- Recalculate every funding-source row for one shared budget name.
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
-- InventoryTransaction updates InventoryList.instock_Total
-- ============================================================
CREATE OR REPLACE FUNCTION update_inventory_after_transaction()
RETURNS TRIGGER AS $$
DECLARE
    available_stock INT;
    inventory_change INT;
BEGIN

    IF TG_OP = 'INSERT' THEN

        IF NEW.status = 'Checked Out' THEN
            inventory_change := -NEW.quantity;
        ELSE
            inventory_change := NEW.quantity;
        END IF;

        SELECT instock_total
        INTO available_stock
        FROM inventory_list
        WHERE item_name = NEW.item_name;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                'Item "%" is not present in InventoryList',
                NEW.item_name;
        END IF;

        IF available_stock + inventory_change < 0 THEN
            RAISE EXCEPTION
                'Not enough "%" in stock. Available: %, requested: %',
                NEW.item_name,
                available_stock,
                NEW.quantity;
        END IF;

        UPDATE inventory_list
        SET instock_total = instock_total + inventory_change
        WHERE item_name = NEW.item_name;

        RETURN NEW;


    ELSIF TG_OP = 'UPDATE' THEN

        -- Reverse the old transaction
        IF OLD.status = 'Checked Out' THEN
            inventory_change := OLD.quantity;
        ELSE
            inventory_change := -OLD.quantity;
        END IF;

        UPDATE inventory_list
        SET instock_total = instock_total + inventory_change
        WHERE item_name = OLD.item_name;


        -- Apply the new transaction
        IF NEW.status = 'Checked Out' THEN
            inventory_change := -NEW.quantity;
        ELSE
            inventory_change := NEW.quantity;
        END IF;

        SELECT instock_total
        INTO available_stock
        FROM inventory_list
        WHERE item_name = NEW.item_name;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                'Item "%" is not present in InventoryList',
                NEW.item_name;
        END IF;

        IF available_stock + inventory_change < 0 THEN
            RAISE EXCEPTION
                'Not enough "%" in stock. Available: %, requested: %',
                NEW.item_name,
                available_stock,
                NEW.quantity;
        END IF;

        UPDATE inventory_list
        SET instock_total = instock_total + inventory_change
        WHERE item_name = NEW.item_name;

        RETURN NEW;


    ELSIF TG_OP = 'DELETE' THEN

        IF OLD.status = 'Checked Out' THEN
            inventory_change := OLD.quantity;
        ELSE
            inventory_change := -OLD.quantity;
        END IF;

        UPDATE inventory_list
        SET instock_total = instock_total + inventory_change
        WHERE item_name = OLD.item_name;

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
            FROM inventory_list WHERE item_name = NEW.item_name;

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
            FROM inventory_list WHERE item_name = OLD.item_name;

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
                FROM inventory_list WHERE item_name = NEW.item_name;

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
            FROM inventory_list WHERE item_name = OLD.item_name;

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
            FROM inventory_list WHERE item_name = NEW.item_name;

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
-- Recalculate remaining budget when budget amount changes
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

CREATE TRIGGER trg_update_remaining_budget_after_budget_change
BEFORE UPDATE OF budget_amount
ON budget
FOR EACH ROW
EXECUTE FUNCTION update_remaining_budget_after_budget_change();


-- ============================================================
-- TRIGGER 7
-- Recalculate purchase request totals when an item's unit cost changes
-- ============================================================
CREATE OR REPLACE FUNCTION update_purchase_totals_after_item_cost_change()
RETURNS TRIGGER AS $$
BEGIN
    UPDATE purchase_request
    SET total_cost = quantity_requested * NEW.unit_cost
    WHERE item_name = NEW.item_name;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_purchase_totals_after_item_cost_change
AFTER UPDATE OF unit_cost
ON item
FOR EACH ROW
WHEN (OLD.unit_cost IS DISTINCT FROM NEW.unit_cost)
EXECUTE FUNCTION update_purchase_totals_after_item_cost_change();
