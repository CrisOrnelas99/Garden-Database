
-- ============================================================
-- TRIGGER 1
-- PurchaseItem.total_cost =
-- qty_requested * item.unit_cost
-- ============================================================

CREATE OR REPLACE FUNCTION calculate_purchase_item_total()
RETURNS TRIGGER AS $$
DECLARE
    item_unit_cost NUMERIC;
BEGIN

    SELECT unit_cost
    INTO item_unit_cost
    FROM item
    WHERE name = NEW.item_name;

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


CREATE TRIGGER trg_calculate_purchase_item_total
BEFORE INSERT OR UPDATE OF item_name, qty_requested
ON "PurchaseItem"
FOR EACH ROW
EXECUTE FUNCTION calculate_purchase_item_total();


-- ============================================================
-- TRIGGER 2
-- PurchaseRequest.total_cost =
-- SUM(PurchaseItem.total_cost)
-- ============================================================

CREATE OR REPLACE FUNCTION update_purchase_request_total()
RETURNS TRIGGER AS $$
BEGIN

    -- Recalculate current/new request
    IF TG_OP IN ('INSERT', 'UPDATE') THEN

        UPDATE "PurchaseRequest"
        SET total_cost = (
            SELECT COALESCE(SUM(total_cost), 0)
            FROM "PurchaseItem"
            WHERE request_id = NEW.request_id
        )
        WHERE request_id = NEW.request_id;

    END IF;


    -- Recalculate old request when deleted
    -- or when item moves to another request
    IF TG_OP = 'DELETE'
       OR (
            TG_OP = 'UPDATE'
            AND OLD.request_id IS DISTINCT FROM NEW.request_id
          )
    THEN

        UPDATE "PurchaseRequest"
        SET total_cost = (
            SELECT COALESCE(SUM(total_cost), 0)
            FROM "PurchaseItem"
            WHERE request_id = OLD.request_id
        )
        WHERE request_id = OLD.request_id;

    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER trg_update_purchase_request_total
AFTER INSERT OR UPDATE OR DELETE
ON "PurchaseItem"
FOR EACH ROW
EXECUTE FUNCTION update_purchase_request_total();


-- ============================================================
-- TRIGGER 3
-- BudgetExpense.total_cost =
-- quantity * item.unit_cost
-- ============================================================

CREATE OR REPLACE FUNCTION calculate_budget_expense_total()
RETURNS TRIGGER AS $$
DECLARE
    item_unit_cost NUMERIC;
BEGIN

    SELECT unit_cost
    INTO item_unit_cost
    FROM item
    WHERE name = NEW.item_name;

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
        NEW.quantity * item_unit_cost;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER trg_calculate_budget_expense_total
BEFORE INSERT OR UPDATE OF item_name, quantity
ON "BudgetExpense"
FOR EACH ROW
EXECUTE FUNCTION calculate_budget_expense_total();


-- ============================================================
-- TRIGGER 4
-- budget.remaining_budget =
-- budget_amount - SUM(BudgetExpense.total_cost)
-- ============================================================

CREATE OR REPLACE FUNCTION update_remaining_budget()
RETURNS TRIGGER AS $$
BEGIN

    -- Recalculate current/new budget
    IF TG_OP IN ('INSERT', 'UPDATE') THEN

        UPDATE budget b
        SET remaining_budget =
            b.budget_amount -
            COALESCE(
                (
                    SELECT SUM(be.total_cost)
                    FROM "BudgetExpense" be
                    WHERE be.budget_name = NEW.budget_name
                ),
                0
            )
        WHERE b.budget_name = NEW.budget_name;

    END IF;


    -- Recalculate old budget if deleted
    -- or expense moved to another budget
    IF TG_OP = 'DELETE'
       OR (
            TG_OP = 'UPDATE'
            AND OLD.budget_name IS DISTINCT FROM NEW.budget_name
          )
    THEN

        UPDATE budget b
        SET remaining_budget =
            b.budget_amount -
            COALESCE(
                (
                    SELECT SUM(be.total_cost)
                    FROM "BudgetExpense" be
                    WHERE be.budget_name = OLD.budget_name
                ),
                0
            )
        WHERE b.budget_name = OLD.budget_name;

    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;


CREATE TRIGGER trg_update_remaining_budget
AFTER INSERT OR UPDATE OR DELETE
ON "BudgetExpense"
FOR EACH ROW
EXECUTE FUNCTION update_remaining_budget();


-- ============================================================
-- TRIGGER 5
-- InventoryTransaction updates InventoryList.instock_Total
-- ============================================================

CREATE OR REPLACE FUNCTION update_inventory_after_transaction()
RETURNS TRIGGER AS $$
DECLARE
    available_stock INT;
BEGIN

    -- ========================================================
    -- INSERT
    -- ========================================================
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


    -- ========================================================
    -- UPDATE
    -- ========================================================
    ELSIF TG_OP = 'UPDATE' THEN

        -- Same inventory item
        IF OLD.item_name = NEW.item_name THEN

            -- Check what stock would be after restoring
            -- the original transaction amount
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

            -- Restore quantity to original item
            UPDATE "InventoryList"
            SET "instock_Total" =
                "instock_Total" + OLD.quantity_taken
            WHERE item_name = OLD.item_name;


            -- Check new item stock
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


            -- Subtract from new item
            UPDATE "InventoryList"
            SET "instock_Total" =
                "instock_Total" - NEW.quantity_taken
            WHERE item_name = NEW.item_name;

        END IF;

        RETURN NEW;


    -- ========================================================
    -- DELETE
    -- Restore inventory when transaction is removed
    -- ========================================================
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

