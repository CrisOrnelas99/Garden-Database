--ROLLBACK --rollback if needed

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
-- ============================================================

INSERT INTO budget (
    budget_name,
    budget_amount,
    notes
)
VALUES
(
    'SGLI Materials',
    1000.00,
    'Budget for consumable garden supplies'
),
(
    'GROW RACK',
    2500.00,
    'Budget for reusable garden equipment'
);


-- ============================================================
-- ITEM
-- ============================================================

INSERT INTO item (
    category,
    item_name,
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
-- ============================================================

INSERT INTO "PurchaseRequest" (
    school_year,
    requested_by,
    requesting_for,
    item_name,
    qty_requested,
    delivered_to_fns,
    review_status,
    ordered,
    funding_source,
    notes
)
VALUES
(
    '2026-2027',
    'Alice',
    'Estero High School',
    'Garden Gloves',
    7,
    FALSE,
    'Approved',
    TRUE,
    'SGLI Materials',
    'Gloves for students, has not been delivered'
),
(
    '2026-2027',
    'Alice',
    'Estero High School',
    'Seed Pack',
    10,
    FALSE,
    'Approved',
    TRUE,
    'SGLI Materials',
    'Seeds for fall planting'
),
(
    '2026-2027',
    'Bob',
    'Three Oaks Middle School',
    'Watering Can',
    4,
    FALSE,
    'Approved',
    TRUE,
    'GROW RACK',
    'Additional watering cans'
),
(
    '2026-2027',
    'Bob',
    'Three Oaks Middle School',
    'Garden Shovel',
    2,
    FALSE,
    'Approved',
    TRUE,
    'GROW RACK',
    'Additional garden shovels'
);


-- ============================================================
-- BUDGET EXPENSE
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
