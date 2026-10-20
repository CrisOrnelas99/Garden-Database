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


----Garden Bed Summary----

CREATE OR REPLACE VIEW garden_bed_summary AS
SELECT
	g.garden_id,
	g.garden_name,
	g.location_name,
	g.garden_type,
	g.garden_status,
	COUNT(gb.bed_id) AS total_beds
FROM garden as g
LEFT JOIN garden_beds as gb
	ON g.garden_name = gb.garden_name
GROUP BY
	g.garden_id,
	g.garden_name,
	g.location_name,
	g.garden_type,
	gb.bed_id,
	g.garden_status;

----Active Garden Beds----

CREATE OR REPLACE VIEW active_garden_beds AS
SELECT
	bed_id,
	garden_name,
	bed_name,
	bed_type,
	bed_size,
	soil_health
FROM garden_beds
WHERE active = TRUE;

----Crop Rotation Details----

CREATE OR REPLACE VIEW crop_rotation_details AS
SELECT
	cr.rotation_id,
	cr.garden_name,
	cr.bed_name,
	cr.plant_name,
	p.plant_type,
	p.growing_months,
	p.days_to_harvest,
	cr.season,
	cr.planned_planting_date,
	cr.status
FROM "CropRotation" AS cr
JOIN plant as P
	ON cr.plant_name = p.plant_name;

----Garden Equipment Status----
CREATE OR REPLACE VIEW garden_equipment_status AS
SELECT
	g.garden_name,
	'Irrigation' AS equipment_category,
	i.irrigation_name AS equipment_name,
	i.irrigation_type AS equipment_type,
	i.status
FROM garden as g
JOIN irrigation_setup AS i
	ON g.garden_name = i.garden_name

UNION ALL

SELECT
	g.garden_name,
	'Composting' AS equipment_category,
	c.composting_unit_name AS equipment_name,
	c.composting_type AS equipment_type,
	c.status
FROM garden AS g
JOIN composting_units AS c
	ON g.garden_name = c.garden_name;
