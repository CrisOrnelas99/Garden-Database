-- ============================================================
-- Inventory Schema
-- ============================================================

-- ============================================================
-- CUSTOM DOMAINS
-- Reusable data types and constraints
-- ============================================================

CREATE DOMAIN dollar AS DECIMAL(12,2)
    CHECK (VALUE >= 0);

CREATE DOMAIN count AS INT
    CHECK (VALUE >= 0);


-- ============================================================
-- location
-- ============================================================

CREATE TABLE location (
    location_id SERIAL PRIMARY KEY,

    location_name VARCHAR(200) NOT NULL UNIQUE,

    notes TEXT
);


-- ============================================================
-- budget
-- ============================================================

CREATE TABLE budget (
    budget_id SERIAL PRIMARY KEY,

    budget_name VARCHAR(50) NOT NULL UNIQUE,

    budget_amount dollar NOT NULL,

    -- Can become negative if expenses exceed budget
    remaining_budget DECIMAL(12,2),

    notes TEXT
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

    school_year VARCHAR(9),

    requested_by VARCHAR(50) NOT NULL,

    requesting_for VARCHAR(200),

    item_name VARCHAR(200) NOT NULL,

    qty_requested count NOT NULL
        CHECK (qty_requested > 0),

    total_cost dollar NOT NULL DEFAULT 0,

    delivered_to_fns BOOLEAN NOT NULL DEFAULT FALSE,

    review_status TEXT,

    ordered BOOLEAN NOT NULL DEFAULT FALSE,

    budget_name VARCHAR(50),

    funding_source VARCHAR(50),

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
        ON UPDATE CASCADE
);


-- ============================================================
-- InventoryTransaction
-- Records inventory being taken from InventoryList
-- ============================================================

CREATE TABLE "InventoryTransaction" (
    transaction_id SERIAL PRIMARY KEY,

    date DATE DEFAULT CURRENT_DATE,

    taken_by VARCHAR(50) NOT NULL,

    for_school VARCHAR(200),

    item_name VARCHAR(200) NOT NULL,

    quantity_taken count NOT NULL
        CHECK (quantity_taken > 0),

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
--FUNCTIONS
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
-- budget.remaining_budget =
-- budget_amount - SUM(PurchaseRequest.total_cost)
-- ============================================================

CREATE OR REPLACE FUNCTION update_remaining_budget()
RETURNS TRIGGER AS $$
BEGIN

    IF TG_OP IN ('INSERT', 'UPDATE') AND NEW.budget_name IS NOT NULL THEN

        UPDATE budget b
        SET remaining_budget =
            b.budget_amount -
            COALESCE(
                (
                    SELECT SUM(pr.total_cost)
                    FROM "PurchaseRequest" pr
                    WHERE pr.budget_name = NEW.budget_name
                ),
                0
            )
        WHERE b.budget_name = NEW.budget_name;

    END IF;


    IF TG_OP = 'DELETE'
       OR (
            TG_OP = 'UPDATE'
            AND OLD.budget_name IS DISTINCT FROM NEW.budget_name
          )
    THEN

        IF OLD.budget_name IS NOT NULL THEN

            UPDATE budget b
            SET remaining_budget =
                b.budget_amount -
                COALESCE(
                    (
                        SELECT SUM(pr.total_cost)
                        FROM "PurchaseRequest" pr
                        WHERE pr.budget_name = OLD.budget_name
                    ),
                    0
                )
            WHERE b.budget_name = OLD.budget_name;

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
BEGIN

    IF TG_OP = 'INSERT' THEN

        SELECT "instock_Total"
        INTO available_stock
        FROM "InventoryList"
        WHERE item_name = NEW.item_name;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                'Item "%" is not present in InventoryList',
                NEW.item_name;
        END IF;

        IF available_stock < NEW.quantity_taken THEN
            RAISE EXCEPTION
                'Not enough "%" in stock. Available: %, requested: %',
                NEW.item_name,
                available_stock,
                NEW.quantity_taken;
        END IF;

        UPDATE "InventoryList"
        SET "instock_Total" =
            "instock_Total" - NEW.quantity_taken
        WHERE item_name = NEW.item_name;

        RETURN NEW;


    ELSIF TG_OP = 'UPDATE' THEN

        IF OLD.item_name = NEW.item_name THEN

            SELECT "instock_Total" + OLD.quantity_taken
            INTO available_stock
            FROM "InventoryList"
            WHERE item_name = NEW.item_name;

            IF NOT FOUND THEN
                RAISE EXCEPTION
                    'Item "%" is not present in InventoryList',
                    NEW.item_name;
            END IF;

            IF available_stock < NEW.quantity_taken THEN
                RAISE EXCEPTION
                    'Not enough "%" in stock. Available: %, requested: %',
                    NEW.item_name,
                    available_stock,
                    NEW.quantity_taken;
            END IF;

            UPDATE "InventoryList"
            SET "instock_Total" =
                "instock_Total"
                + OLD.quantity_taken
                - NEW.quantity_taken
            WHERE item_name = NEW.item_name;

        ELSE

            UPDATE "InventoryList"
            SET "instock_Total" =
                "instock_Total" + OLD.quantity_taken
            WHERE item_name = OLD.item_name;


            SELECT "instock_Total"
            INTO available_stock
            FROM "InventoryList"
            WHERE item_name = NEW.item_name;

            IF NOT FOUND THEN
                RAISE EXCEPTION
                    'Item "%" is not present in InventoryList',
                    NEW.item_name;
            END IF;

            IF available_stock < NEW.quantity_taken THEN
                RAISE EXCEPTION
                    'Not enough "%" in stock. Available: %, requested: %',
                    NEW.item_name,
                    available_stock,
                    NEW.quantity_taken;
            END IF;


            UPDATE "InventoryList"
            SET "instock_Total" =
                "instock_Total" - NEW.quantity_taken
            WHERE item_name = NEW.item_name;

        END IF;

        RETURN NEW;


    ELSIF TG_OP = 'DELETE' THEN

        UPDATE "InventoryList"
        SET "instock_Total" =
            "instock_Total" + OLD.quantity_taken
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
