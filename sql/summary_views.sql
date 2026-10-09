-- ============================================================
-- VIEWS
-- ============================================================


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
-- Purchase requests that have not been ordered or delivered
-- ============================================================
CREATE OR REPLACE VIEW "PendingRequests" AS
SELECT
    pr.request_id,
    CASE
        WHEN pr.ordered = FALSE THEN 'Unordered'
        WHEN pr.delivered_to_fns = FALSE THEN 'Undelivered'
    END AS request_status,
    pr.requested_by,
    pr.requesting_for,
    pr.item_name,
    pr.qty_requested,
    pr.total_cost,
    pr.review_status,
    b.budget_name,
    b.funding_source,
    pr.school_year,
    pr.notes
FROM "PurchaseRequest" pr
LEFT JOIN budget b
    ON pr.budget_id = b.budget_id
WHERE pr.ordered = FALSE
   OR pr.delivered_to_fns = FALSE;


-- ============================================================
-- SchoolInventory
-- Inventory and purchase activity for each location
-- ============================================================
CREATE OR REPLACE VIEW "SchoolInventory" AS
SELECT
    l.location_name AS school_name,

    COALESCE(
        (
            SELECT SUM(it.quantity)
            FROM "InventoryTransaction" it
            WHERE it.for_school = l.location_name
              AND it.status = 'Checked Out'
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
-- Purchases grouped by budget name and item
-- ============================================================
CREATE OR REPLACE VIEW "BudgetPurchases" AS
SELECT
    b.budget_name,
    pr.item_name,
    SUM(pr.qty_requested) AS total_quantity_ordered,
    SUM(pr.total_cost) AS total_spent
FROM budget b
JOIN "PurchaseRequest" pr
    ON b.budget_id = pr.budget_id
WHERE pr.ordered = TRUE
GROUP BY
    b.budget_name,
    pr.item_name
ORDER BY
    b.budget_name,
    pr.item_name;


-- ============================================================
-- FundingSourceSpending
-- Spending totals by funding source
-- ============================================================
CREATE OR REPLACE VIEW "FundingSourceSpending" AS
SELECT
    COALESCE(b.funding_source, 'Unassigned') AS funding_source,
    SUM(pr.total_cost) AS total_spent,
    SUM(pr.qty_requested) AS total_quantity_ordered,
    COUNT(*) AS request_count
FROM budget b
JOIN "PurchaseRequest" pr
    ON b.budget_id = pr.budget_id
WHERE pr.ordered = TRUE
GROUP BY COALESCE(b.funding_source, 'Unassigned')
ORDER BY funding_source;


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
    cr.plant_name,
    p.plant_type,
    p.growing_months,
    p.days_to_harvest,
    cr.season,
    cr.planned_planting_date,
    cr.status,
    cr.notes
FROM "CropRotation" cr
JOIN garden g
    ON cr.garden_name = g.garden_name
JOIN location l
    ON g.location_name = l.location_name
JOIN plant p
    ON cr.plant_name = p.plant_name
WHERE cr.planned_planting_date >= CURRENT_DATE
  AND cr.status = 'Planned';
