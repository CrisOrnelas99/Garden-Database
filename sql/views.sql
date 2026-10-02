
--View items that need to be reordered
CREATE OR REPLACE VIEW "RestockList" AS
SELECT
    inventory_id,
    item_name,
    "instock_Total",
    reorder_point,
    storage_location
FROM "InventoryList"
WHERE "instock_Total" <= reorder_point;


--view purchase requests that have not been ordered yet
CREATE OR REPLACE VIEW "PendingPurchaseRequests" AS
SELECT
    request_id,
    school_year,
    requested_by,
    requesting_for,
    item_name,
    qty_requested,
    total_cost,
    delivered_to_fns,
    review_status,
    budget_name,
    funding_source,
    notes
FROM "PurchaseRequest"
WHERE ordered = FALSE;


--view inventory that schools use
CREATE OR REPLACE VIEW "SchoolInventoryUsage" AS
SELECT
    for_school,
    item_name,
    SUM(quantity_taken) AS total_quantity_taken
FROM "InventoryTransaction"
WHERE for_school IS NOT NULL
GROUP BY for_school, item_name
ORDER BY for_school, item_name;


--view items used from budget
CREATE OR REPLACE VIEW "BudgetPurchaseSummary" AS
SELECT
    b.budget_name,
    b.budget_amount,
    b.remaining_budget,
    pr.request_id,
    pr.item_name,
    pr.qty_requested,
    pr.total_cost,
    pr.requested_by,
    pr.requesting_for
FROM budget b
LEFT JOIN "PurchaseRequest" pr
    ON b.budget_name = pr.budget_name;
