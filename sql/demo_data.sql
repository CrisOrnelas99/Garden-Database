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
    'Hogwarts Academy',
    'Demo school garden'
),
(
    'Sunshine Elementary',
    'Demo school garden'
),
(
    'Green Valley Middle School',
    'Demo school garden'
),
(
    'Oakwood High School',
    'Demo school garden'
),
(
    'Riverbend Academy',
    'Demo school garden'
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
    'Garden Supplies',
    5000.00,
    'General garden supplies'
),
(
    'Hydroponics',
    3000.00,
    'Hydroponic supplies'
),
(
    'Garden Maintenance',
    10000.00,
    'Garden maintenance'
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
    'Garden',
    'Plant Pots',
    'Amazon',
    'https://amazon.com',
    15.99,
    'Plant containers'
),
(
    'Garden',
    'Garden Gloves',
    'Walmart',
    'https://walmart.com',
    12.99,
    'Garden gloves'
),
(
    'Garden',
    'Hand Trowel',
    'Amazon',
    'https://amazon.com',
    9.99,
    'Garden hand tool'
),
(
    'Garden',
    'Watering Can',
    'Walmart',
    'https://walmart.com',
    14.99,
    'Watering equipment'
),
(
    'Seeds',
    'Tomato Seeds',
    'Amazon',
    'https://amazon.com',
    6.99,
    'Tomato seeds'
),
(
    'Seeds',
    'Lettuce Seeds',
    'Walmart',
    'https://walmart.com',
    5.99,
    'Lettuce seeds'
),
(
    'Soil',
    'Garden Soil',
    'Walmart',
    'https://walmart.com',
    8.99,
    'Garden soil'
),
(
    'Garden',
    'Plant Labels',
    'Amazon',
    'https://amazon.com',
    7.99,
    'Plant identification labels'
),
(
    'Hydroponics',
    'Hydroponic Nutrients',
    'Amazon',
    'https://amazon.com',
    24.99,
    'Hydroponic plant nutrients'
),
(
    'Garden',
    'Pruning Shears',
    'Walmart',
    'https://walmart.com',
    13.99,
    'Garden pruning tool'
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
    'Plant Pots',
    100,
    50,
    10,
    TRUE,
    'Garden Storage',
    'Inventory item'
),
(
    'Garden Gloves',
    30,
    20,
    5,
    TRUE,
    'Tool Room',
    'Inventory item'
),
(
    'Hand Trowel',
    20,
    15,
    5,
    TRUE,
    'Tool Room',
    'Inventory item'
),
(
    'Watering Can',
    15,
    10,
    3,
    TRUE,
    'Garden Storage',
    'Inventory item'
),
(
    'Tomato Seeds',
    40,
    20,
    5,
    TRUE,
    'Seed Storage',
    'Inventory item'
),
(
    'Lettuce Seeds',
    30,
    15,
    5,
    TRUE,
    'Seed Storage',
    'Inventory item'
),
(
    'Garden Soil',
    50,
    25,
    10,
    TRUE,
    'Garden Storage',
    'Inventory item'
),
(
    'Plant Labels',
    100,
    40,
    10,
    TRUE,
    'Garden Storage',
    'Inventory item'
),
(
    'Hydroponic Nutrients',
    15,
    8,
    3,
    TRUE,
    'Hydroponic Storage',
    'Inventory item'
),
(
    'Pruning Shears',
    10,
    6,
    2,
    FALSE,
    'Tool Room',
    'Inventory item'
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
    budget_name,
    funding_source,
    notes
)
VALUES
(
    '2026-2027',
    'Alice',
    'Hogwarts Academy',
    'Plant Pots',
    5,
    TRUE,
    'Ordered',
    TRUE,
    'Garden Supplies',
    NULL,
    'Pots for garden'
),
(
    '2026-2027',
    'Bob',
    'Sunshine Elementary',
    'Garden Gloves',
    4,
    TRUE,
    'Ordered',
    TRUE,
    'Garden Supplies',
    NULL,
    'Gloves for students'
),
(
    '2026-2027',
    'Cris',
    'Green Valley Middle School',
    'Hydroponic Nutrients',
    3,
    TRUE,
    'Ordered',
    TRUE,
    'Hydroponics',
    NULL,
    'Hydroponic supplies'
),
(
    '2026-2027',
    'Alice',
    'Oakwood High School',
    'Garden Soil',
    10,
    FALSE,
    'Under Review',
    FALSE,
    'Garden Maintenance',
    NULL,
    'Soil for garden beds'
),
(
    '2026-2027',
    'Bob',
    'Riverbend Academy',
    'Tomato Seeds',
    5,
    FALSE,
    'Under Review',
    FALSE,
    'Garden Supplies',
    NULL,
    'Seeds for planting'
),
(
    '2026-2027',
    'Cris',
    'Hogwarts Academy',
    'Hand Trowel',
    3,
    TRUE,
    'Ordered',
    TRUE,
    'Garden Supplies',
    NULL,
    'Garden tools'
),
(
    '2026-2027',
    'Alice',
    'Sunshine Elementary',
    'Watering Can',
    2,
    TRUE,
    'Ordered',
    TRUE,
    'Garden Maintenance',
    NULL,
    'Watering equipment'
),
(
    '2026-2027',
    'Bob',
    'Green Valley Middle School',
    'Pruning Shears',
    2,
    FALSE,
    'Under Review',
    FALSE,
    'Garden Maintenance',
    NULL,
    'Garden maintenance tools'
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
    '2026-09-01',
    'Alice',
    'Hogwarts Academy',
    'Plant Pots',
    5,
    'Garden planting'
),
(
    '2026-09-03',
    'Bob',
    'Sunshine Elementary',
    'Garden Gloves',
    4,
    'Student garden work'
),
(
    '2026-09-05',
    'Cris',
    'Green Valley Middle School',
    'Hydroponic Nutrients',
    2,
    'Hydroponic system'
),
(
    '2026-09-08',
    'Alice',
    'Oakwood High School',
    'Garden Soil',
    5,
    'Garden beds'
),
(
    '2026-09-10',
    'Bob',
    'Riverbend Academy',
    'Tomato Seeds',
    3,
    'Planting'
),
(
    '2026-09-12',
    'Cris',
    'Hogwarts Academy',
    'Hand Trowel',
    2,
    'Garden tools'
),
(
    '2026-09-15',
    'Alice',
    'Sunshine Elementary',
    'Watering Can',
    2,
    'Garden watering'
),
(
    '2026-09-18',
    'Bob',
    'Green Valley Middle School',
    'Plant Labels',
    8,
    'Plant identification'
);
