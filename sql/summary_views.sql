-- ============================================================
-- RestockList
-- View items that need to be reordered
-- ============================================================
CREATE OR REPLACE VIEW "RestockList" AS
SELECT
    inventory_id,
    item_name,
    "instock_Total",
    reorder_point,
    storage_location
FROM "InventoryList"
WHERE "instock_Total" <= reorder_point;

-- ============================================================
-- PendingRequests
-- View purchase requests that have not been ordered or delivered
-- ============================================================
CREATE OR REPLACE VIEW "PendingRequests" AS
SELECT
    request_id,

    CASE
        WHEN ordered = FALSE THEN 'Unordered'
        WHEN delivered_to_fns = FALSE THEN 'Undelivered'
    END AS request_status,

    requested_by,
    requesting_for,
    item_name,
    qty_requested,
    total_cost,
    review_status,
    budget_name,
    funding_source,
    notes

FROM "PurchaseRequest"
WHERE ordered = FALSE
   OR delivered_to_fns = FALSE;


-- ============================================================
-- SchoolInventory
-- View inventory and costs for each school
-- ============================================================
CREATE OR REPLACE VIEW "SchoolInventory" AS
SELECT
    l.location_name AS school_name,

    COALESCE(
        (
            SELECT SUM(it.quantity_taken)
            FROM "InventoryTransaction" it
            WHERE it.for_school = l.location_name
        ),
        0
    ) AS items_checked_out,

    COALESCE(
        (
            SELECT SUM(pr.qty_requested)
            FROM "PurchaseRequest" pr
            WHERE pr.requesting_for = l.location_name
            AND (
                pr.ordered = FALSE
                OR pr.delivered_to_fns = FALSE
            )
        ),
        0
    ) AS items_still_requested,

    COALESCE(
        (
            SELECT SUM(pr.total_cost)
            FROM "PurchaseRequest" pr
            WHERE pr.requesting_for = l.location_name
            AND pr.ordered = TRUE
        ),
        0
    ) AS total_spent,

    COALESCE(
        (
            SELECT SUM(pr.total_cost)
            FROM "PurchaseRequest" pr
            WHERE pr.requesting_for = l.location_name
            AND pr.ordered = FALSE
        ),
        0
    ) AS unordered_cost

FROM location l
ORDER BY l.location_name;


-- ============================================================
-- BudgetPurchases
-- view purchases made from each budget
-- ============================================================
CREATE OR REPLACE VIEW "BudgetPurchases" AS
SELECT
    b.budget_name,
    pr.school_year,
    pr.request_id,
    pr.item_name,
    pr.qty_requested,
    pr.total_cost,
    pr.requested_by,
    pr.requesting_for
FROM budget b
LEFT JOIN "PurchaseRequest" pr
    ON b.budget_name = pr.budget_name;


-- ============================================================
-- YearlyPurchaseSummary
-- view purchase request spending by school year
-- ============================================================
CREATE OR REPLACE VIEW "YearlyPurchaseSummary" AS
SELECT
    school_year,

    SUM(total_cost) AS total_requested,

    SUM(
        CASE
            WHEN ordered = TRUE THEN total_cost
            ELSE 0
        END
    ) AS total_spent,

    SUM(
        CASE
            WHEN ordered = FALSE THEN total_cost
            ELSE 0
        END
    ) AS unordered_spending

FROM "PurchaseRequest"
GROUP BY school_year
ORDER BY school_year;


-- ============================================================
-- UpcomingRotations
-- View upcoming planned crops for each school garden
-- ============================================================

CREATE OR REPLACE VIEW "UpcomingRotations" AS
SELECT
    l.location_name AS school_name,
    g.garden_name,
    cr.bed_name,
    cr.rotation_name,
    cr.plant_name,
    cr.planned_planting_date,
    cr.status,
    cr.notes
FROM "CropRotation" cr
JOIN garden g
    ON cr.garden_name = g.garden_name
JOIN location l
    ON g.location_name = l.location_name
WHERE cr.planned_planting_date >= CURRENT_DATE
  AND cr.status = 'Planned';
