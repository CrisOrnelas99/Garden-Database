--SAMPLE DATA



-- ============================================================
-- RESET FAILED TRANSACTION IF NEEDED
-- ============================================================

ROLLBACK;

-- ============================================================
-- TEAM MEMBERS
-- ============================================================

INSERT INTO team_member (
    team_member_name,
    notes
)
VALUES
(
    'Alice',
    'Demo team member'
),
(
    'Bob',
    'Demo team member'
);


-- ============================================================
-- LOCATIONS
-- ============================================================

INSERT INTO location (
    location_name,
    notes
)
VALUES
(
    'FGCU',
    'FGCU demonstration location'
),
(
    'Estero High School',
    'Demo high school'
),
(
    'Three Oaks Middle School',
    'Demo middle school'
),
(
    'All HLC Gardens',
    'Represents all HLC garden locations'
),
(
    'FGCU and Estero',
    'Used when activity applies to both locations'
);


-- ============================================================
-- BUDGET
--
-- Initial remaining_budget starts equal to budget_amount.
-- BudgetExpense triggers will calculate the actual remainder.
-- ============================================================

INSERT INTO budget (
    budget_name,
    budget_amount,
    remaining_budget,
    notes
)
VALUES
(
    'SGLI Materials',
    1000.00,
    1000.00,
    'Budget for consumable garden supplies'
),
(
    'GROW RACK',
    2500.00,
    2500.00,
    'Budget for reusable garden equipment'
);


-- ============================================================
-- ITEM
--
-- vendor_name is now normal text.
-- unit_cost is used by PurchaseItem and BudgetExpense triggers.
-- ============================================================

INSERT INTO item (
    category,
    name,
    vendor_name,
    quote_link,
    unit_cost,
    notes
)
VALUES
(
    'Garden Supplies',
    'Garden Gloves',
    'Walmart',
    'https://walmart.com/example',
    10.00,
    'Reusable garden gloves'
),
(
    'Garden Supplies',
    'Potting Soil',
    'Walmart',
    'https://walmart.com/example',
    8.00,
    'Bag of potting soil'
),
(
    'Garden Equipment',
    'Watering Can',
    'Amazon',
    'https://amazon.com/example',
    15.00,
    'Standard watering can'
),
(
    'Garden Equipment',
    'Garden Shovel',
    'Amazon',
    'https://amazon.com/example',
    25.00,
    'General purpose garden shovel'
),
(
    'Seeds',
    'Seed Pack',
    'Walmart',
    'https://walmart.com/example',
    5.00,
    'Vegetable seed pack'
);


-- ============================================================
-- INVENTORY LIST
--
-- Starting stock BEFORE transactions:
--
-- Garden Gloves   = 20
-- Potting Soil    = 15
-- Watering Can    = 8
-- Garden Shovel   = 6
--
-- InventoryTransaction trigger will reduce these afterward.
-- ============================================================

INSERT INTO "InventoryList" (
    item_name,
    cumulative_asset,
    "instock_Total",
    reorder_point,
    counted,
    storage_location,
    notes
)
VALUES
(
    'Garden Gloves',
    20,
    20,
    5,
    TRUE,
    'Connex',
    'Starting demo inventory'
),
(
    'Potting Soil',
    15,
    15,
    5,
    TRUE,
    'SGM Office',
    'Starting demo inventory'
),
(
    'Watering Can',
    8,
    8,
    2,
    TRUE,
    'Connex',
    'Starting demo inventory'
),
(
    'Garden Shovel',
    6,
    6,
    2,
    TRUE,
    'Connex',
    'Starting demo inventory'
);


-- ============================================================
-- PURCHASE REQUEST
--
-- total_cost begins at 0.
-- PurchaseItem trigger will update each request total.
-- ============================================================

INSERT INTO "PurchaseRequest" (
    requested_by,
    requesting_for,
    school_year,
    notes,
    total_cost,
    funding_source
)
VALUES
(
    'Alice',
    'Estero High School',
    '2026-2027',
    'Fall garden supplies',
    0.00,
    'SGLI Materials'
),
(
    'Bob',
    'Three Oaks Middle School',
    '2026-2027',
    'Garden equipment request',
    0.00,
    'GROW RACK'
);


-- ============================================================
-- PURCHASE ITEMS
--
-- REQUEST 1
--
-- Garden Gloves:
-- 7 × $10.00 = $70.00
--
-- Seed Pack:
-- 10 × $5.00 = $50.00
--
-- REQUEST 1 TOTAL = $120.00
--
--
-- REQUEST 2
--
-- Watering Can:
-- 4 × $15.00 = $60.00
--
-- Garden Shovel:
-- 2 × $25.00 = $50.00
--
-- REQUEST 2 TOTAL = $110.00
--
-- total_cost is NOT manually inserted.
-- Trigger calculates it.
-- ============================================================

INSERT INTO "PurchaseItem" (
    request_id,
    item_name,
    qty_requested,
    delivered_to_fns,
    review_status,
    ordered,
    notes
)
VALUES
(
    1,
    'Garden Gloves',
    7,
    FALSE,
    'Approved',
    TRUE,
    'Gloves for students, has not been delivered'
),
(
    1,
    'Seed Pack',
    10,
    FALSE,
    'Approved',
    TRUE,
    'Seeds for fall planting'
),
(
    2,
    'Watering Can',
    4,
    FALSE,
    'Approved',
    TRUE,
    'Additional watering cans'
),
(
    2,
    'Garden Shovel',
    2,
    FALSE,
    'Approved',
    TRUE,
    'Additional garden shovels'
);


-- ============================================================
-- BUDGET EXPENSE
--
-- SGLI Materials:
--
-- Garden Gloves:
-- 7 × $10.00 = $70.00
--
-- Potting Soil:
-- 5 × $8.00 = $40.00
--
-- Total spent = $110.00
--
-- $1,000.00 - $110.00
-- = $890.00 remaining
--
--
-- GROW RACK:
--
-- Watering Can:
-- 2 × $15.00 = $30.00
--
-- Garden Shovel:
-- 3 × $25.00 = $75.00
--
-- Total spent = $105.00
--
-- $2,500.00 - $105.00
-- = $2,395.00 remaining
--
-- total_cost is calculated automatically.
-- ============================================================

INSERT INTO "BudgetExpense" (
    location,
    budget_name,
    team_member_name,
    item_name,
    quantity,
    notes
)
VALUES
(
    'FGCU',
    'SGLI Materials',
    'Alice',
    'Garden Gloves',
    7,
    'Demo glove expense'
),
(
    'Estero High School',
    'SGLI Materials',
    'Alice',
    'Potting Soil',
    5,
    'Soil for garden beds'
),
(
    'Three Oaks Middle School',
    'GROW RACK',
    'Bob',
    'Watering Can',
    2,
    'Demo watering can expense'
),
(
    'FGCU',
    'GROW RACK',
    'Bob',
    'Garden Shovel',
    3,
    'Demo shovel expense'
);


-- ============================================================
-- INVENTORY TRANSACTIONS
--
-- Starting Stock → Quantity Taken → Final Stock
--
-- Garden Gloves:
-- 20 - 4 = 16
--
-- Potting Soil:
-- 15 - 4 = 11
--
-- Watering Can:
-- 8 - 1 = 7
--
-- Garden Shovel:
-- 6 - 5 = 1
--
-- Inventory trigger calculates the final stock automatically.
-- ============================================================

INSERT INTO "InventoryTransaction" (
    date,
    taken_by,
    for_school,
    item_name,
    quantity_taken,
    notes
)
VALUES
(
    CURRENT_DATE,
    'Alice',
    'Estero High School',
    'Garden Gloves',
    4,
    'Issued for student gardening'
),
(
    CURRENT_DATE,
    'Alice',
    'Estero High School',
    'Potting Soil',
    4,
    'Used for garden beds'
),
(
    CURRENT_DATE,
    'Bob',
    'Three Oaks Middle School',
    'Watering Can',
    1,
    'Issued to school'
),
(
    CURRENT_DATE,
    'Bob',
    'All HLC Gardens',
    'Garden Shovel',
    5,
    'Issued to school'
);
