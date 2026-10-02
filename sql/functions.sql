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
