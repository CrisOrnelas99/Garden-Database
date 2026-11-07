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
-- Show the saved school or group assignment as entered on the request.
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
    COALESCE(pr.requesting_school_group, pr.requesting_school)::VARCHAR AS assigned_locations,
    pr.quantity_requested,
    pr.total_cost,
    pr.review_status,
    pr.notes
FROM purchase_request pr
WHERE pr.ordered = FALSE
   OR pr.delivered_to_fns = FALSE;


-- ============================================================
-- SchoolSupply
-- Activity is grouped either by one school or by one named location group.
-- ============================================================
DROP VIEW IF EXISTS "SchoolInventory";
DROP VIEW IF EXISTS "SchoolSupplyActivity";
DROP VIEW IF EXISTS "SchoolSupply";
CREATE VIEW "SchoolSupply" AS
WITH assignments AS (
    SELECT
        'School'::TEXT AS assignment_type,
        l.location_name,
        NULL::VARCHAR(200) AS location_group_name
    FROM location l

    UNION ALL

    SELECT
        'Group'::TEXT AS assignment_type,
        NULL::VARCHAR(200) AS location_name,
        g.location_group_name
    FROM location_group g
    WHERE g.location_group_name IS NOT NULL
),
transaction_totals AS (
    SELECT
        it.for_school AS location_name,
        NULL::VARCHAR(200) AS location_group_name,
        SUM(
            CASE
                WHEN status = 'Checked Out' THEN quantity
                WHEN status = 'Checked In' THEN -quantity
            END
        ) AS items_currently_checked_out
    FROM inventory_transaction it
    WHERE it.for_school IS NOT NULL
    GROUP BY it.for_school

    UNION ALL

    SELECT
        NULL::VARCHAR(200) AS location_name,
        it.for_school_group AS location_group_name,
        SUM(
            CASE
                WHEN status = 'Checked Out' THEN quantity
                WHEN status = 'Checked In' THEN -quantity
            END
        ) AS items_currently_checked_out
    FROM inventory_transaction it
    WHERE it.for_school_group IS NOT NULL
    GROUP BY it.for_school_group
),
request_totals AS (
    SELECT
        pr.requesting_school AS location_name,
        NULL::VARCHAR(200) AS location_group_name,
        SUM(pr.quantity_requested) FILTER (
            WHERE NOT pr.delivered_to_fns
        ) AS purchase_items_pending,
        SUM(pr.total_cost) FILTER (WHERE pr.ordered) AS total_spent
    FROM purchase_request pr
    WHERE pr.requesting_school IS NOT NULL
    GROUP BY pr.requesting_school

    UNION ALL

    SELECT
        NULL::VARCHAR(200) AS location_name,
        pr.requesting_school_group AS location_group_name,
        SUM(pr.quantity_requested) FILTER (
            WHERE NOT pr.delivered_to_fns
        ) AS purchase_items_pending,
        SUM(pr.total_cost) FILTER (WHERE pr.ordered) AS total_spent
    FROM purchase_request pr
    WHERE pr.requesting_school_group IS NOT NULL
    GROUP BY pr.requesting_school_group
)
SELECT
    a.assignment_type,
    COALESCE(a.location_name, a.location_group_name) AS location_name,
    COALESCE(tt.items_currently_checked_out, 0) AS items_currently_checked_out,
    COALESCE(rt.purchase_items_pending, 0) AS purchase_items_pending,
    COALESCE(rt.total_spent, 0) AS total_spent
FROM assignments a
LEFT JOIN transaction_totals tt
    ON tt.location_name IS NOT DISTINCT FROM a.location_name
   AND tt.location_group_name IS NOT DISTINCT FROM a.location_group_name
LEFT JOIN request_totals rt
    ON rt.location_name IS NOT DISTINCT FROM a.location_name
   AND rt.location_group_name IS NOT DISTINCT FROM a.location_group_name
ORDER BY
    CASE a.assignment_type
        WHEN 'School' THEN 0
        WHEN 'Group' THEN 1
    END,
    COALESCE(a.location_name, a.location_group_name);


-- ============================================================
-- BudgetPurchases
-- Ordered purchases grouped by budget name and item
-- ============================================================
DROP VIEW IF EXISTS "BudgetPurchases";
CREATE VIEW "BudgetPurchases" AS
WITH budget_spending AS (
    SELECT
        budget_name,
        SUM(total_cost) AS total_budget_spent
    FROM purchase_request
    WHERE ordered = TRUE
      AND budget_name IS NOT NULL
    GROUP BY budget_name
)
SELECT
    b.budget_name,
    pr.item_name,
    SUM(pr.quantity_requested) AS total_quantity_ordered,
    SUM(pr.total_cost) AS total_spent,
    b.budget_amount AS total_budget,
    bs.total_budget_spent,
    b.remaining_budget
FROM budget b
JOIN purchase_request pr
    ON b.budget_name = pr.budget_name
JOIN budget_spending bs
    ON bs.budget_name = b.budget_name
WHERE pr.ordered = TRUE
GROUP BY
    b.budget_name,
    pr.item_name,
    b.budget_amount,
    bs.total_budget_spent,
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
WITH source_item_spending AS (
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
)
SELECT
    funding_source,
    item_name,
    total_quantity_ordered,
    total_spent,
    SUM(total_spent) OVER (PARTITION BY funding_source) AS total_funding_source_spent
FROM source_item_spending
ORDER BY
    funding_source,
    item_name;


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
-- CurrentBedPlantings
-- In-ground and harvested plantings with bed details
-- ============================================================
DROP VIEW IF EXISTS "BedSummary";
DROP VIEW IF EXISTS "BedPlantingSummary";
DROP VIEW IF EXISTS "BedPlanting";
DROP VIEW IF EXISTS "CurrentBedPlantings";
CREATE VIEW "CurrentBedPlantings" AS
SELECT
    b.location_name,
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
    ON cr.location_name = b.location_name
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
    cr.location_name,
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
    l.location_name,
    items.item_type,
    items.item_name,
    items.lifecycle_status,
    items.condition,
    items.notes
FROM location l
CROSS JOIN LATERAL (
    SELECT
        'Garden Bed'::TEXT AS item_type,
        b.bed_name AS item_name,
        b.lifecycle_status,
        b.condition,
        b.notes
    FROM garden_bed b
    WHERE b.location_name = l.location_name

    UNION ALL

    SELECT
        'Irrigation System'::TEXT AS item_type,
        i.irrigation_name AS item_name,
        i.lifecycle_status,
        i.condition,
        i.notes
    FROM irrigation_setup i
    WHERE i.location_name = l.location_name

    UNION ALL

    SELECT
        'Compost Unit'::TEXT AS item_type,
        c.unit_name AS item_name,
        c.lifecycle_status,
        c.condition,
        c.notes
    FROM compost_unit c
    WHERE c.location_name = l.location_name
) items
WHERE l.bed_count IS NOT NULL
ORDER BY
    l.location_name,
    items.item_type NULLS FIRST,
    items.item_name;
