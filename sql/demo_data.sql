--ROLLBACK --rollback if needed

-- ============================================================
-- INVENTORY DATA
-- ============================================================


-- ============================================================
-- LOCATIONS
-- ============================================================
INSERT INTO location (
    location_name,
    location_type,
    notes
)
VALUES
(
    'Hogwarts Academy',
    'School',
    'Demo school garden'
),
(
    'Sunshine Elementary',
    'School',
    'Demo school garden'
),
(
    'Green Valley Middle School',
    'School',
    'Demo school garden'
),
(
    'Oakwood High School',
    'School',
    'Demo school garden'
),
(
    'Riverbend Academy',
    'School',
    'Demo school garden'
),
(
    'HLC Office',
    'Other',
     NULL
);


-- ============================================================
-- BUDGET
-- ============================================================
INSERT INTO budget (
    budget_name,
    funding_source,
    school_year,
    budget_amount,
    notes
)
VALUES
(
    'Garden Supplies',
    'SHCF_26-27_#9556',
    '2026-2027',
    5000.00,
    'General garden supplies'
),
(
    'Hydroponics',
    'Collaboratory_26-27_#9446',
    '2026-2027',
    3000.00,
    'Hydroponic supplies'
),
(
    'Garden Maintenance',
    'DonatedFunds_5120',
    '2026-2027',
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
    request_date,
    requested_by,
    requesting_for,
    item_name,
    qty_requested,
    delivered_to_fns,
    review_status,
    ordered,
    budget_id,
    school_year,
    notes
)
VALUES
(
    '2026-08-15',
    'Alice',
    'Hogwarts Academy',
    'Plant Pots',
    5,
    TRUE,
    'Ordered',
    TRUE,
    (
        SELECT budget_id
        FROM budget
        WHERE budget_name = 'Garden Supplies'
          AND funding_source = 'SHCF_26-27_#9556'
          AND school_year = '2026-2027'
    ),
    '2026-2027',
    'Pots for garden'
),
(
    '2026-08-16',
    'Bob',
    'Sunshine Elementary',
    'Garden Gloves',
    4,
    TRUE,
    'Ordered',
    TRUE,
    (
        SELECT budget_id
        FROM budget
        WHERE budget_name = 'Garden Supplies'
          AND funding_source = 'SHCF_26-27_#9556'
          AND school_year = '2026-2027'
    ),
    '2026-2027',
    'Gloves for students'
),
(
    '2026-08-17',
    'Cris',
    'Green Valley Middle School',
    'Hydroponic Nutrients',
    3,
    TRUE,
    'Ordered',
    TRUE,
    (
        SELECT budget_id
        FROM budget
        WHERE budget_name = 'Hydroponics'
          AND funding_source = 'Collaboratory_26-27_#9446'
          AND school_year = '2026-2027'
    ),
    '2026-2027',
    'Hydroponic supplies'
),
(
    '2026-08-18',
    'Alice',
    'Oakwood High School',
    'Garden Soil',
    10,
    FALSE,
    'Under Review',
    FALSE,
    (
        SELECT budget_id
        FROM budget
        WHERE budget_name = 'Garden Maintenance'
          AND funding_source = 'DonatedFunds_5120'
          AND school_year = '2026-2027'
    ),
    '2026-2027',
    'Soil for garden beds'
),
(
    '2026-08-19',
    'Bob',
    'Riverbend Academy',
    'Tomato Seeds',
    5,
    FALSE,
    'Under Review',
    FALSE,
    (
        SELECT budget_id
        FROM budget
        WHERE budget_name = 'Garden Supplies'
          AND funding_source = 'SHCF_26-27_#9556'
          AND school_year = '2026-2027'
    ),
    '2026-2027',
    'Seeds for planting'
),
(
    '2026-08-20',
    'Cris',
    'Hogwarts Academy',
    'Hand Trowel',
    3,
    TRUE,
    'Ordered',
    TRUE,
    (
        SELECT budget_id
        FROM budget
        WHERE budget_name = 'Garden Supplies'
          AND funding_source = 'SHCF_26-27_#9556'
          AND school_year = '2026-2027'
    ),
    '2026-2027',
    'Garden tools'
),
(
    '2026-08-21',
    'Alice',
    'Sunshine Elementary',
    'Watering Can',
    2,
    TRUE,
    'Ordered',
    TRUE,
    (
        SELECT budget_id
        FROM budget
        WHERE budget_name = 'Garden Maintenance'
          AND funding_source = 'DonatedFunds_5120'
          AND school_year = '2026-2027'
    ),
    '2026-2027',
    'Watering equipment'
),
(
    '2026-08-22',
    'Bob',
    'Green Valley Middle School',
    'Pruning Shears',
    2,
    FALSE,
    'Under Review',
    FALSE,
    (
        SELECT budget_id
        FROM budget
        WHERE budget_name = 'Garden Maintenance'
          AND funding_source = 'DonatedFunds_5120'
          AND school_year = '2026-2027'
    ),
    '2026-2027',
    'Garden maintenance tools'
);

-- ============================================================
-- INVENTORY TRANSACTIONS
-- ============================================================
INSERT INTO "InventoryTransaction" (
    date,
    status,
    taken_by,
    for_school,
    item_name,
    quantity,
    notes
)
VALUES
(
    '2026-09-01',
    'Checked Out',
    'Alice',
    'Hogwarts Academy',
    'Plant Pots',
    5,
    'Garden planting'
),
(
    '2026-09-03',
    'Checked Out',
    'Bob',
    'Sunshine Elementary',
    'Garden Gloves',
    4,
    'Student garden work'
),
(
    '2026-09-05',
    'Checked Out',
    'Cris',
    'Green Valley Middle School',
    'Hydroponic Nutrients',
    2,
    'Hydroponic system'
),
(
    '2026-09-08',
    'Checked Out',
    'Alice',
    'Oakwood High School',
    'Garden Soil',
    5,
    'Garden beds'
),
(
    '2026-09-10',
    'Checked Out',
    'Bob',
    'Riverbend Academy',
    'Tomato Seeds',
    3,
    'Planting'
),
(
    '2026-09-12',
    'Checked Out',
    'Cris',
    'Hogwarts Academy',
    'Hand Trowel',
    2,
    'Garden tools'
),
(
    '2026-09-15',
    'Checked Out',
    'Alice',
    'Sunshine Elementary',
    'Watering Can',
    2,
    'Garden watering'
),
(
    '2026-09-18',
    'Checked Out',
    'Bob',
    'Green Valley Middle School',
    'Plant Labels',
    8,
    'Plant identification'
);


-- ============================================================
-- GARDEN DATA
-- ============================================================
