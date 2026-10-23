-- ============================================================
-- VIEWS
-- ============================================================


-- ============================================================
-- RestockList
-- Items at or below their reorder point, with ordering details
-- ============================================================
DROP VIEW IF EXISTS "RestockList";
CREATE VIEW "RestockList" AS
SELECT
    il.inventory_id,
    il.item_name,
    il.instock_total,
    il.reorder_point,
    il.counted,
    il.storage_location
FROM inventory_list il
WHERE il.instock_total <= il.reorder_point;


-- ============================================================
-- PendingRequests
-- Purchase requests that have not been ordered or delivered
-- ============================================================
DROP VIEW IF EXISTS "PendingRequests";
CREATE VIEW "PendingRequests" AS
SELECT
    pr.request_date,
    CASE
        WHEN pr.ordered = FALSE THEN 'Unordered'
        WHEN pr.delivered_to_fns = FALSE THEN 'Undelivered'
    END AS request_status,
    pr.item_name,
    pr.requested_by,
    pr.requesting_for,
    pr.quantity_requested,
    pr.total_cost,
    pr.review_status,
    pr.notes
FROM purchase_request pr
WHERE pr.ordered = FALSE
   OR pr.delivered_to_fns = FALSE;


-- ============================================================
-- SchoolSupply
-- Net inventory out, outstanding requests, and spending by school
-- ============================================================
DROP VIEW IF EXISTS "SchoolInventory";
DROP VIEW IF EXISTS "SchoolSupplyActivity";
DROP VIEW IF EXISTS "SchoolSupply";
CREATE VIEW "SchoolSupply" AS
SELECT
    l.location_name AS school_name,

    COALESCE(
        (
            SELECT SUM(
                CASE
                    WHEN it.status = 'Checked Out' THEN it.quantity
                    WHEN it.status = 'Checked In' THEN -it.quantity
                END
            )
            FROM inventory_transaction it
            WHERE it.for_school = l.location_name
        ),
        0
    ) AS items_currently_checked_out,

    COALESCE(
        (
            SELECT SUM(pr.quantity_requested)
            FROM purchase_request pr
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
            FROM purchase_request pr
            WHERE pr.requesting_for = l.location_name
              AND pr.ordered = TRUE
        ),
        0
    ) AS total_spent
FROM location l
ORDER BY l.location_name;


-- ============================================================
-- BudgetPurchases
-- Ordered purchases grouped by budget name and item
-- ============================================================
DROP VIEW IF EXISTS "BudgetPurchases";
CREATE VIEW "BudgetPurchases" AS
SELECT
    b.budget_name,
    pr.item_name,
    SUM(pr.quantity_requested) AS total_quantity_ordered,
    SUM(pr.total_cost) AS total_spent,
    b.remaining_budget
FROM budget b
JOIN purchase_request pr
    ON b.budget_name = pr.budget_name
WHERE pr.ordered = TRUE
GROUP BY
    b.budget_name,
    pr.item_name,
    b.remaining_budget
ORDER BY
    b.budget_name,
    pr.item_name;


-- ============================================================
-- FundingSourceSpending
-- Ordered quantities and spending by funding source and item
-- ============================================================
DROP VIEW IF EXISTS "FundingSourceSpending";
CREATE VIEW "FundingSourceSpending" AS
SELECT
    COALESCE(NULLIF(BTRIM(pr.funding_source), ''), 'Unassigned') AS funding_source,
    pr.item_name,
    SUM(pr.quantity_requested) AS total_quantity_ordered,
    SUM(pr.total_cost) AS total_spent
FROM purchase_request pr
WHERE pr.ordered = TRUE
GROUP BY
    COALESCE(NULLIF(BTRIM(pr.funding_source), ''), 'Unassigned'),
    pr.item_name
ORDER BY
    funding_source,
    pr.item_name;


-- ============================================================
-- YearlyPurchase
-- view purchase request spending by school year
-- ============================================================
DROP VIEW IF EXISTS "YearlyPurchaseSummary";
DROP VIEW IF EXISTS "YearlyPurchase";
CREATE VIEW "YearlyPurchase" AS
SELECT
    school_year,
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
    ) AS pending_spending
FROM purchase_request
GROUP BY school_year
ORDER BY school_year;


-- ============================================================
-- BedPlanting
-- In-ground and harvested plantings with bed details
-- ============================================================
DROP VIEW IF EXISTS "BedSummary";
DROP VIEW IF EXISTS "BedPlantingSummary";
DROP VIEW IF EXISTS "BedPlanting";
CREATE VIEW "BedPlanting" AS
SELECT
    b.garden_name,
    b.bed_name,
    cr.plant_name,
    cr.quantity,
    b.condition AS bed_condition,
    b.is_full,
    cr.season,
    cr.status AS rotation_status,
    cr.sow_date,
    CASE
        WHEN cr.sow_date IS NULL OR p.days_to_harvest IS NULL THEN NULL
        ELSE cr.sow_date + p.days_to_harvest
    END AS expected_harvest_date,
    cr.soil_health,
    cr.notes AS rotation_notes
FROM garden_bed b
LEFT JOIN crop_rotation cr
    ON cr.garden_name = b.garden_name
   AND cr.bed_name = b.bed_name
LEFT JOIN plant p
    ON p.plant_name = cr.plant_name
WHERE cr.status IN ('In-ground', 'Harvested');


-- ============================================================
-- CropCalendar
-- Scheduled, growing, and completed crop rotations
-- ============================================================
DROP VIEW IF EXISTS "CropCalendar";
CREATE VIEW "CropCalendar" AS
SELECT
    cr.garden_name,
    cr.bed_name,
    cr.status AS rotation_status,
    cr.season,
    cr.plant_name,
    cr.quantity,
    cr.sow_date,
    CASE
        WHEN cr.sow_date IS NULL OR p.days_to_harvest IS NULL THEN NULL
        ELSE cr.sow_date + p.days_to_harvest
    END AS expected_harvest_date,
    cr.soil_health,
    cr.notes
FROM crop_rotation cr
JOIN plant p
    ON p.plant_name = cr.plant_name;


-- ============================================================
-- GardenAssets
-- One row per garden bed, irrigation system, or compost unit
-- ============================================================
DROP VIEW IF EXISTS "GardenSummary";
DROP VIEW IF EXISTS "GardenAssets";
CREATE VIEW "GardenAssets" AS
SELECT
    g.garden_name,
    items.item_type,
    items.item_name,
    items.lifecycle_status,
    items.condition,
    items.notes
FROM garden g
LEFT JOIN LATERAL (
    SELECT
        'Garden Bed'::TEXT AS item_type,
        b.bed_name AS item_name,
        b.lifecycle_status,
        b.condition,
        b.notes
    FROM garden_bed b
    WHERE b.garden_name = g.garden_name

    UNION ALL

    SELECT
        'Irrigation System'::TEXT AS item_type,
        i.irrigation_name AS item_name,
        i.lifecycle_status,
        i.condition,
        i.notes
    FROM irrigation_setup i
    WHERE i.garden_name = g.garden_name

    UNION ALL

    SELECT
        'Compost Unit'::TEXT AS item_type,
        c.unit_name AS item_name,
        c.lifecycle_status,
        c.condition,
        c.notes
    FROM compost_unit c
    WHERE c.garden_name = g.garden_name
) items ON TRUE
ORDER BY
    g.garden_name,
    items.item_type NULLS FIRST,
    items.item_name;
