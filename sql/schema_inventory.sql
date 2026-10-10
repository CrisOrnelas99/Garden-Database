-- ============================================================
-- Inventory Schema
-- ============================================================

-- ============================================================
-- CUSTOM
-- Reusable data types, enums and constraints
-- ============================================================
CREATE DOMAIN dollar AS DECIMAL(12,2)
    CHECK (VALUE >= 0);

CREATE DOMAIN count AS INT
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
    location_type VARCHAR(50),
    contact VARCHAR(100),
    email VARCHAR(200),
    notes TEXT
);


-- ============================================================
-- budget
-- ============================================================
CREATE TABLE budget (
    
    budget_id SERIAL PRIMARY KEY,
    budget_name VARCHAR(100) NOT NULL,
    funding_source VARCHAR(100),
    budget_amount dollar NOT NULL,
    remaining_budget DECIMAL(12,2),
    notes TEXT,

CONSTRAINT uq_budget_allocation
    UNIQUE (budget_name, funding_source)
);


-- ============================================================
-- item
-- Item catalog / master item information
-- ============================================================
CREATE TABLE item (
    
    item_id SERIAL PRIMARY KEY,
    category VARCHAR(50),
    item_name VARCHAR(200) NOT NULL UNIQUE,
    vendor_name VARCHAR(50),
    quote_link TEXT,
    unit_cost dollar,
    notes TEXT
);


-- ============================================================
-- InventoryList
-- Actual items currently tracked in inventory
-- ============================================================
CREATE TABLE "InventoryList" (
    
    inventory_id SERIAL PRIMARY KEY,
    item_name VARCHAR(200) NOT NULL UNIQUE,
    cumulative_asset count NOT NULL DEFAULT 0,
    "instock_Total" count NOT NULL DEFAULT 0,
    reorder_point count,
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
CREATE TABLE "PurchaseRequest" (
    
    request_id SERIAL PRIMARY KEY,
    request_date DATE,
    requested_by VARCHAR(50) NOT NULL,
    requesting_for VARCHAR(200),
    item_name VARCHAR(200) NOT NULL,
    qty_requested count NOT NULL,
    total_cost dollar NOT NULL DEFAULT 0,
    delivered_to_fns BOOLEAN NOT NULL DEFAULT FALSE,
    review_status TEXT,
    ordered BOOLEAN NOT NULL DEFAULT FALSE,
    budget_id INT,
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
        FOREIGN KEY (budget_id)
        REFERENCES budget(budget_id)
        ON UPDATE CASCADE
);


-- ============================================================
-- InventoryTransaction
-- Records inventory being taken from InventoryList
-- ============================================================
CREATE TABLE "InventoryTransaction" (
    
    transaction_id SERIAL PRIMARY KEY,
    date DATE DEFAULT CURRENT_DATE,
    status inventory_transaction_status NOT NULL,
    taken_by VARCHAR(50) NOT NULL,
    for_school VARCHAR(200),
    item_name VARCHAR(200) NOT NULL,
    quantity count NOT NULL
        CHECK (quantity > 0),
    notes TEXT,
    CONSTRAINT fk_inventory_transaction_school
        FOREIGN KEY (for_school)
        REFERENCES location(location_name)
        ON UPDATE CASCADE,

    CONSTRAINT fk_inventory_transaction_item
        FOREIGN KEY (item_name)
        REFERENCES "InventoryList"(item_name)
        ON UPDATE CASCADE
);


-- ============================================================
-- Inventory FUNCTIONS
-- ============================================================


-- ============================================================
-- TRIGGER 1
-- PurchaseRequest.total_cost =
-- qty_requested * item.unit_cost
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
        NEW.qty_requested * item_unit_cost;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER trg_calculate_purchase_request_total
BEFORE INSERT OR UPDATE OF item_name, qty_requested
ON "PurchaseRequest"
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
-- Recalculate remaining budget using ordered requests only
-- ============================================================

CREATE OR REPLACE FUNCTION update_remaining_budget()
RETURNS TRIGGER AS $$
BEGIN
    -- Recalculate the new budget allocation
    IF TG_OP IN ('INSERT', 'UPDATE')
       AND NEW.budget_id IS NOT NULL
    THEN
        UPDATE budget b
        SET remaining_budget =
            b.budget_amount
            - COALESCE(
                (
                    SELECT SUM(pr.total_cost)
                    FROM "PurchaseRequest" pr
                    WHERE pr.budget_id = NEW.budget_id
                      AND pr.ordered = TRUE
                ),
                0
            )
        WHERE b.budget_id = NEW.budget_id;
    END IF;


    -- Recalculate the old budget allocation when needed
    IF TG_OP = 'DELETE'
       OR (
            TG_OP = 'UPDATE'
            AND OLD.budget_id IS DISTINCT FROM NEW.budget_id
          )
    THEN
        IF OLD.budget_id IS NOT NULL THEN
            UPDATE budget b
            SET remaining_budget =
                b.budget_amount
                - COALESCE(
                    (
                        SELECT SUM(pr.total_cost)
                        FROM "PurchaseRequest" pr
                        WHERE pr.budget_id = OLD.budget_id
                          AND pr.ordered = TRUE
                    ),
                    0
                )
            WHERE b.budget_id = OLD.budget_id;
        END IF;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_remaining_budget
AFTER INSERT OR UPDATE OR DELETE
ON "PurchaseRequest"
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

        SELECT "instock_Total"
        INTO available_stock
        FROM "InventoryList"
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

        UPDATE "InventoryList"
        SET "instock_Total" = "instock_Total" + inventory_change
        WHERE item_name = NEW.item_name;

        RETURN NEW;


    ELSIF TG_OP = 'UPDATE' THEN

        -- Reverse the old transaction
        IF OLD.status = 'Checked Out' THEN
            inventory_change := OLD.quantity;
        ELSE
            inventory_change := -OLD.quantity;
        END IF;

        UPDATE "InventoryList"
        SET "instock_Total" = "instock_Total" + inventory_change
        WHERE item_name = OLD.item_name;


        -- Apply the new transaction
        IF NEW.status = 'Checked Out' THEN
            inventory_change := -NEW.quantity;
        ELSE
            inventory_change := NEW.quantity;
        END IF;

        SELECT "instock_Total"
        INTO available_stock
        FROM "InventoryList"
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

        UPDATE "InventoryList"
        SET "instock_Total" = "instock_Total" + inventory_change
        WHERE item_name = NEW.item_name;

        RETURN NEW;


    ELSIF TG_OP = 'DELETE' THEN

        IF OLD.status = 'Checked Out' THEN
            inventory_change := OLD.quantity;
        ELSE
            inventory_change := -OLD.quantity;
        END IF;

        UPDATE "InventoryList"
        SET "instock_Total" = "instock_Total" + inventory_change
        WHERE item_name = OLD.item_name;

        RETURN OLD;

    END IF;

END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_inventory_transaction
BEFORE INSERT OR UPDATE OR DELETE
ON "InventoryTransaction"
FOR EACH ROW
EXECUTE FUNCTION update_inventory_after_transaction();

-- ============================================================
-- TRIGGER 5
-- Update inventory when a purchase request is received,
-- edited, or marked as no longer received
-- ============================================================
CREATE OR REPLACE FUNCTION update_inventory_when_received()
RETURNS TRIGGER AS $$
BEGIN
    -- Remove inventory for an old delivered request
    IF TG_OP IN ('UPDATE', 'DELETE')
       AND OLD.delivered_to_fns = TRUE
    THEN
        UPDATE "InventoryList"
        SET cumulative_asset = cumulative_asset - OLD.qty_requested,
            "instock_Total" = "instock_Total" - OLD.qty_requested
        WHERE item_name = OLD.item_name;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                'Item "%" is not present in InventoryList',
                OLD.item_name;
        END IF;
    END IF;

    -- Add inventory for a newly delivered request
    IF TG_OP IN ('INSERT', 'UPDATE')
       AND NEW.delivered_to_fns = TRUE
    THEN
        UPDATE "InventoryList"
        SET cumulative_asset = cumulative_asset + NEW.qty_requested,
            "instock_Total" = "instock_Total" + NEW.qty_requested
        WHERE item_name = NEW.item_name;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                'Item "%" is not present in InventoryList',
                NEW.item_name;
        END IF;
    END IF;

    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_update_inventory_when_received
ON "PurchaseRequest";

CREATE TRIGGER trg_update_inventory_when_received
AFTER INSERT OR UPDATE OR DELETE
ON "PurchaseRequest"
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
                FROM "PurchaseRequest" pr
                WHERE pr.budget_id = NEW.budget_id
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
    UPDATE "PurchaseRequest"
    SET total_cost = qty_requested * NEW.unit_cost
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
