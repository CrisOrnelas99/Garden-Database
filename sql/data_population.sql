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
    'Gulf Elementary School',
    'School garden location'
),
(
    'Buckingham Exceptional Center',
    'School garden location'
),
(
    'Caloosa Middle School',
    'School garden location'
),
(
    'Cape Coral High School',
    'School garden location'
),
(
    'Heights Elementary',
    'School garden location'
),
(
    'The Alva School',
    'School garden location'
),
(
    'All 19 HLC Gardens',
    'All HLC garden locations'
),
(
    'General HLC',
    'General HLC location'
),
(
    'HLC Office',
    'HLC office location'
),
(
    'School Garden Training',
    'School garden training'
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
    'SGLT Materials',
    1000.00,
    'Materials budget'
),
(
    'Grow Rack',
    3200.00,
    'Grow rack budget'
),
(
    'Garden Start-up and Maintenance',
    40000.00,
    'Garden budget'
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
    'Garden - 4 inch nursery pots',
    'Amazon',
    'https://amazon.com',
    20.89,
    'Garden item'
),
(
    'Garden',
    'Garden - Black 2.5 in pots, bulk',
    'Greenhouse Megastore',
    'https://walmart.com',
    96.00,
    'Garden item'
),
(
    'Garden',
    'Garden - Euro pots 6in (17cm), Case',
    'Greenhouse Megastore',
    'https://walmart.com',
    117.00,
    'Garden item'
),
(
    'Garden',
    'Garden - Garden gloves, Adult Large 6pk',
    'Amazon',
    'https://amazon.com',
    15.45,
    'Garden gloves'
),
(
    'Garden',
    'Garden - Garden gloves, Kids large 6pk',
    'Amazon',
    'https://amazon.com',
    14.99,
    'Garden gloves'
),
(
    'Garden',
    'Garden - Germination Cell & Flat Tray + plant labels, 10 sets',
    'Amazon',
    'https://amazon.com',
    45.99,
    'Garden growing supplies'
),
(
    'Garden',
    'Garden - Sakata Seeds',
    'Sakata',
    'https://walmart.com',
    10.00,
    'Garden seeds'
),
(
    'Hydroponics',
    'Hydroponics - Micro line, drip line 10x125ft',
    'Amazon',
    'https://amazon.com',
    25.00,
    'Hydroponic supplies'
),
(
    'Media',
    'Media - Jolly Gardener Grower''s mix',
    'Walmart',
    'https://walmart.com',
    20.00,
    'Growing media'
),
(
    'Garden',
    'Garden - Tomato Tape, 1/2 x150, 24 ct',
    'Amazon',
    'https://amazon.com',
    32.99,
    'Garden supplies'
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
    'Garden - 4 inch nursery pots',
    0,
    0,
    5,
    TRUE,
    'SGM Office',
    'Inventory item'
),
(
    'Garden - Black 2.5 in pots, bulk',
    1000,
    940,
    5,
    TRUE,
    'SGM Office',
    'Inventory item'
),
(
    'Garden - Euro pots 6in (17cm), Case',
    302,
    302,
    5,
    TRUE,
    'SGM Office',
    'Inventory item'
),
(
    'Garden - Garden gloves, Adult Large 6pk',
    10,
    10,
    5,
    TRUE,
    'SGM Office',
    'Inventory item'
),
(
    'Garden - Garden gloves, Kids large 6pk',
    3,
    3,
    5,
    TRUE,
    'SGM Office',
    'Inventory item'
),
(
    'Garden - Germination Cell & Flat Tray + plant labels, 10 sets',
    4,
    4,
    0,
    TRUE,
    'SGM Office',
    'Inventory item'
),
(
    'Garden - Sakata Seeds',
    10,
    10,
    5,
    TRUE,
    'SGM Office',
    'Inventory item'
),
(
    'Hydroponics - Micro line, drip line 10x125ft',
    7,
    7,
    2,
    TRUE,
    'SGM Office',
    'Inventory item'
),
(
    'Media - Jolly Gardener Grower''s mix',
    155,
    155,
    10,
    TRUE,
    'SGM Office',
    'Inventory item'
),
(
    'Garden - Tomato Tape, 1/2 x150, 24 ct',
    0,
    0,
    5,
    FALSE,
    'Connex',
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
    funding_source,
    notes
)
VALUES
(
    '2026-2027',
    'Daniela',
    'All 19 HLC Gardens',
    'Garden - Tomato Tape, 1/2 x150, 24 ct',
    1,
    TRUE,
    'Ordered',
    TRUE,
    'Garden Start-up and Maintenance',
    'Garden supplies'
),
(
    '2026-2027',
    'Susie',
    'School Garden Training',
    'Garden - 4 inch nursery pots',
    5,
    TRUE,
    'Ordered',
    TRUE,
    'SGLT Materials',
    'Training supplies'
),
(
    '2026-2027',
    'Mary',
    'All 19 HLC Gardens',
    'Garden - Garden gloves, Adult Large 6pk',
    2,
    TRUE,
    'Ordered',
    TRUE,
    'Garden Start-up and Maintenance',
    'Garden supplies'
),
(
    '2026-2027',
    'Daniela',
    'Cape Coral High School',
    'Garden - Garden gloves, Kids large 6pk',
    2,
    FALSE,
    'Under Review',
    FALSE,
    'Garden Start-up and Maintenance',
    'Garden supplies'
),
(
    '2026-2027',
    'Leisha',
    'General HLC',
    'Garden - Germination Cell & Flat Tray + plant labels, 10 sets',
    1,
    TRUE,
    'Ordered',
    TRUE,
    'SGLT Materials',
    'Growing supplies'
),
(
    '2026-2027',
    'Mark',
    'Caloosa Middle School',
    'Hydroponics - Micro line, drip line 10x125ft',
    1,
    TRUE,
    'Ordered',
    TRUE,
    'Grow Rack',
    'Hydroponic supplies'
),
(
    '2026-2027',
    'Mark',
    'Gulf Elementary School',
    'Garden - Sakata Seeds',
    1,
    TRUE,
    'Ordered',
    TRUE,
    'Garden Start-up and Maintenance',
    'Garden seeds'
),
(
    '2026-2027',
    'Mary',
    'The Alva School',
    'Media - Jolly Gardener Grower''s mix',
    5,
    TRUE,
    'Ordered',
    TRUE,
    'Garden Start-up and Maintenance',
    'Growing media'
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
    'School Garden Training',
    'SGLT Materials',
    'Susie',
    'Garden - 4 inch nursery pots',
    5,
    'Materials expense'
),
(
    'All 19 HLC Gardens',
    'Garden Start-up and Maintenance',
    'Daniela',
    'Garden - Tomato Tape, 1/2 x150, 24 ct',
    1,
    'Garden expense'
),
(
    'Caloosa Middle School',
    'Grow Rack',
    'Mark',
    'Hydroponics - Micro line, drip line 10x125ft',
    1,
    'Grow rack expense'
),
(
    'Cape Coral High School',
    'Garden Start-up and Maintenance',
    'Daniela',
    'Garden - Garden gloves, Kids large 6pk',
    2,
    'Garden expense'
),
(
    'All 19 HLC Gardens',
    'Garden Start-up and Maintenance',
    'Mary',
    'Garden - Garden gloves, Adult Large 6pk',
    2,
    'Garden expense'
),
(
    'General HLC',
    'SGLT Materials',
    'Leisha',
    'Garden - Germination Cell & Flat Tray + plant labels, 10 sets',
    1,
    'Materials expense'
),
(
    'Gulf Elementary School',
    'Garden Start-up and Maintenance',
    'Mark',
    'Garden - Sakata Seeds',
    1,
    'Garden expense'
),
(
    'The Alva School',
    'Garden Start-up and Maintenance',
    'Mary',
    'Media - Jolly Gardener Grower''s mix',
    5,
    'Garden expense'
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
    'Mark',
    'Gulf Elementary School',
    'Garden - Sakata Seeds',
    1,
    'Seeds'
),
(
    '2026-09-01',
    'Mark',
    'Buckingham Exceptional Center',
    'Hydroponics - Micro line, drip line 10x125ft',
    1,
    'Hydroponic supplies'
),
(
    '2026-09-14',
    'Mark',
    'Caloosa Middle School',
    'Hydroponics - Micro line, drip line 10x125ft',
    1,
    'Hydroponic supplies'
),
(
    '2026-09-15',
    'Mark',
    'Cape Coral High School',
    'Garden - Sakata Seeds',
    1,
    'Seeds'
),
(
    '2026-09-15',
    'Mary',
    'Caloosa Middle School',
    'Garden - Garden gloves, Kids large 6pk',
    2,
    'Garden gloves'
),
(
    '2026-09-22',
    'Mark',
    'Caloosa Middle School',
    'Media - Jolly Gardener Grower''s mix',
    4,
    'Growing media'
),
(
    '2026-09-22',
    'Mark',
    'Cape Coral High School',
    'Media - Jolly Gardener Grower''s mix',
    5,
    'Growing media'
),
(
    '2026-09-23',
    'Mark',
    'The Alva School',
    'Media - Jolly Gardener Grower''s mix',
    10,
    'Garden restart'
);
