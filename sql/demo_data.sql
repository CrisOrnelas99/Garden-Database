-- ============================================================
-- INVENTORY DATA POPULATION
-- ============================================================

-- Optional rollback
-- TRUNCATE TABLE
--     "InventoryTransaction",
--     "PurchaseRequest",
--     "InventoryList",
--     item,
--     budget,
--     location
-- RESTART IDENTITY CASCADE;


-- ============================================================
-- LOCATIONS
-- ============================================================

INSERT INTO location
    (location_name, location_type, contact, email, notes)
VALUES
    ('Hogwarts Academy', 'School', 'Alice Morgan', 'alice@hogwarts.edu', 'Demo school garden'),
    ('Sunshine Elementary', 'School', 'Brian Lee', 'brian@sunshine.edu', 'Demo school garden'),
    ('Green Valley Middle School', 'School', 'Carla Davis', 'carla@greenvalley.edu', 'Demo school garden'),
    ('Oakwood High School', 'School', 'Daniel Smith', 'daniel@oakwood.edu', 'Demo school garden'),
    ('Riverbend Academy', 'School', 'Emily Brown', 'emily@riverbend.edu', 'Demo school garden'),
    ('HLC Office', 'Other', 'Frank Wilson', 'frank@hlc.org', 'Central program office'),
    ('Maple Grove School', 'School', 'Grace Taylor', 'grace@maplegrove.edu', 'Demo school garden'),
    ('Pinecrest Elementary', 'School', 'Henry Moore', 'henry@pinecrest.edu', 'Demo school garden'),
    ('Lakeside Middle School', 'School', 'Isabella Clark', 'isabella@lakeside.edu', 'Demo school garden'),
    ('Cedar Ridge School', 'School', 'James Hall', 'james@cedarridge.edu', 'Demo school garden'),
    ('Meadowbrook Academy', 'School', 'Karen Allen', 'karen@meadowbrook.edu', 'Demo school garden'),
    ('Willow Creek School', 'School', 'Liam Young', 'liam@willowcreek.edu', 'Demo school garden'),
    ('Northside Community School', 'School', 'Mia King', 'mia@northside.edu', 'Demo school garden'),
    ('Eastview Academy', 'School', 'Noah Wright', 'noah@eastview.edu', 'Demo school garden'),
    ('Westfield School', 'School', 'Olivia Scott', 'olivia@westfield.edu', 'Demo school garden');


-- ============================================================
-- BUDGETS
-- ============================================================

INSERT INTO budget
    (budget_name, funding_source, budget_amount, remaining_budget, notes)
VALUES
    ('Garden Supplies', 'SHCF_26-27_#9556', 5000.00, 5000.00, 'General garden supplies'),
    ('Hydroponics', 'Collaboratory_26-27_#9446', 3000.00, 3000.00, 'Hydroponic supplies'),
    ('Garden Maintenance', 'DonatedFunds_5120', 10000.00, 10000.00, 'Garden maintenance'),
    ('Seeds and Soil', 'SHCF_26-27_#9556', 4000.00, 4000.00, 'Seeds and soil supplies'),
    ('Tools and Equipment', 'DonatedFunds_5120', 7500.00, 7500.00, 'Reusable garden tools');


-- ============================================================
-- ITEMS
-- ============================================================

INSERT INTO item
    (category, item_name, vendor_name, quote_link, unit_cost, notes)
VALUES
    ('Garden', 'Plant Pots', 'Amazon', 'https://amazon.com', 15.99, 'Plant containers'),
    ('Garden', 'Garden Gloves', 'Walmart', 'https://walmart.com', 12.99, 'Protective garden gloves'),
    ('Garden', 'Hand Trowel', 'Amazon', 'https://amazon.com', 9.99, 'Small hand tool'),
    ('Garden', 'Watering Can', 'Walmart', 'https://walmart.com', 14.99, 'Watering equipment'),
    ('Seeds', 'Tomato Seeds', 'Johnny Seeds', 'https://johnnyseeds.com', 6.99, 'Tomato seed packets'),
    ('Seeds', 'Lettuce Seeds', 'Johnny Seeds', 'https://johnnyseeds.com', 5.99, 'Lettuce seed packets'),
    ('Soil', 'Garden Soil', 'Home Depot', 'https://homedepot.com', 8.99, 'General planting soil'),
    ('Garden', 'Plant Labels', 'Amazon', 'https://amazon.com', 7.99, 'Plant identification labels'),
    ('Hydroponics', 'Hydroponic Nutrients', 'Amazon', 'https://amazon.com', 24.99, 'Hydroponic nutrients'),
    ('Garden', 'Pruning Shears', 'Walmart', 'https://walmart.com', 13.99, 'Pruning tool'),
    ('Seeds', 'Carrot Seeds', 'Johnny Seeds', 'https://johnnyseeds.com', 4.99, 'Carrot seed packets'),
    ('Seeds', 'Basil Seeds', 'Johnny Seeds', 'https://johnnyseeds.com', 4.49, 'Basil seed packets'),
    ('Soil', 'Compost Mix', 'Home Depot', 'https://homedepot.com', 11.99, 'Compost and soil amendment'),
    ('Irrigation', 'Drip Irrigation Kit', 'Home Depot', 'https://homedepot.com', 39.99, 'Small garden irrigation kit'),
    ('Safety', 'Knee Pads', 'Walmart', 'https://walmart.com', 18.99, 'Protective equipment');


-- ============================================================
-- INVENTORY LIST
-- ============================================================

INSERT INTO "InventoryList"
    (
        item_name,
        cumulative_asset,
        "instock_Total",
        reorder_point,
        counted,
        storage_location,
        notes
    )
VALUES
    ('Plant Pots', 100, 55, 10, TRUE, 'Garden Storage', 'Inventory item'),
    ('Garden Gloves', 40, 24, 8, TRUE, 'Tool Room', 'Inventory item'),
    ('Hand Trowel', 30, 18, 5, TRUE, 'Tool Room', 'Inventory item'),
    ('Watering Can', 25, 14, 4, TRUE, 'Garden Storage', 'Inventory item'),
    ('Tomato Seeds', 60, 32, 10, TRUE, 'Seed Storage', 'Inventory item'),
    ('Lettuce Seeds', 55, 28, 10, TRUE, 'Seed Storage', 'Inventory item'),
    ('Garden Soil', 80, 45, 15, TRUE, 'Garden Storage', 'Inventory item'),
    ('Plant Labels', 150, 75, 20, TRUE, 'Garden Storage', 'Inventory item'),
    ('Hydroponic Nutrients', 30, 16, 5, TRUE, 'Hydroponic Storage', 'Inventory item'),
    ('Pruning Shears', 20, 12, 4, TRUE, 'Tool Room', 'Inventory item'),
    ('Carrot Seeds', 50, 30, 10, TRUE, 'Seed Storage', 'Inventory item'),
    ('Basil Seeds', 45, 25, 8, TRUE, 'Seed Storage', 'Inventory item'),
    ('Compost Mix', 70, 38, 12, TRUE, 'Garden Storage', 'Inventory item'),
    ('Drip Irrigation Kit', 12, 7, 2, TRUE, 'Equipment Room', 'Inventory item'),
    ('Knee Pads', 20, 11, 3, FALSE, 'Safety Equipment', 'Inventory item');


-- ============================================================
-- PURCHASE REQUESTS
-- ============================================================

INSERT INTO "PurchaseRequest"
    (
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
        '2026-08-15', 'Alice Morgan', 'Hogwarts Academy',
        'Plant Pots', 5, TRUE, 'Approved', TRUE,
        (SELECT budget_id FROM budget
         WHERE budget_name = 'Garden Supplies'
           AND funding_source = 'SHCF_26-27_#9556'),
        '2026-2027', 'Pots for spring seedlings'
    ),
    (
        '2026-08-16', 'Brian Lee', 'Sunshine Elementary',
        'Garden Gloves', 6, TRUE, 'Approved', TRUE,
        (SELECT budget_id FROM budget
         WHERE budget_name = 'Garden Supplies'
           AND funding_source = 'SHCF_26-27_#9556'),
        '2026-2027', 'Gloves for student garden work'
    ),
    (
        '2026-08-17', 'Carla Davis', 'Green Valley Middle School',
        'Hydroponic Nutrients', 4, TRUE, 'Approved', TRUE,
        (SELECT budget_id FROM budget
         WHERE budget_name = 'Hydroponics'
           AND funding_source = 'Collaboratory_26-27_#9446'),
        '2026-2027', 'Hydroponic growing supplies'
    ),
    (
        '2026-08-18', 'Daniel Smith', 'Oakwood High School',
        'Garden Soil', 12, FALSE, 'Under Review', FALSE,
        (SELECT budget_id FROM budget
         WHERE budget_name = 'Seeds and Soil'
           AND funding_source = 'SHCF_26-27_#9556'),
        '2026-2027', 'Soil for garden beds'
    ),
    (
        '2026-08-19', 'Emily Brown', 'Riverbend Academy',
        'Tomato Seeds', 8, FALSE, 'Under Review', FALSE,
        (SELECT budget_id FROM budget
         WHERE budget_name = 'Seeds and Soil'
           AND funding_source = 'SHCF_26-27_#9556'),
        '2026-2027', 'Tomato planting supplies'
    ),
    (
        '2026-08-20', 'Alice Morgan', 'Hogwarts Academy',
        'Hand Trowel', 4, TRUE, 'Approved', TRUE,
        (SELECT budget_id FROM budget
         WHERE budget_name = 'Tools and Equipment'
           AND funding_source = 'DonatedFunds_5120'),
        '2026-2027', 'Additional hand tools'
    ),
    (
        '2026-08-21', 'Brian Lee', 'Sunshine Elementary',
        'Watering Can', 3, TRUE, 'Approved', TRUE,
        (SELECT budget_id FROM budget
         WHERE budget_name = 'Garden Maintenance'
           AND funding_source = 'DonatedFunds_5120'),
        '2026-2027', 'Watering equipment'
    ),
    (
        '2026-08-22', 'Carla Davis', 'Green Valley Middle School',
        'Pruning Shears', 3, FALSE, 'Under Review', FALSE,
        (SELECT budget_id FROM budget
         WHERE budget_name = 'Tools and Equipment'
           AND funding_source = 'DonatedFunds_5120'),
        '2026-2027', 'Garden maintenance tools'
    ),
    (
        '2026-08-23', 'Grace Taylor', 'Maple Grove School',
        'Lettuce Seeds', 10, TRUE, 'Approved', TRUE,
        (SELECT budget_id FROM budget
         WHERE budget_name = 'Seeds and Soil'
           AND funding_source = 'SHCF_26-27_#9556'),
        '2026-2027', 'Lettuce planting supplies'
    ),
    (
        '2026-08-24', 'Henry Moore', 'Pinecrest Elementary',
        'Plant Labels', 20, TRUE, 'Approved', TRUE,
        (SELECT budget_id FROM budget
         WHERE budget_name = 'Garden Supplies'
           AND funding_source = 'SHCF_26-27_#9556'),
        '2026-2027', 'Labels for crop identification'
    ),
    (
        '2026-08-25', 'Isabella Clark', 'Lakeside Middle School',
        'Carrot Seeds', 8, FALSE, 'Under Review', FALSE,
        (SELECT budget_id FROM budget
         WHERE budget_name = 'Seeds and Soil'
           AND funding_source = 'SHCF_26-27_#9556'),
        '2026-2027', 'Carrot planting supplies'
    ),
    (
        '2026-08-26', 'James Hall', 'Cedar Ridge School',
        'Basil Seeds', 8, TRUE, 'Approved', TRUE,
        (SELECT budget_id FROM budget
         WHERE budget_name = 'Seeds and Soil'
           AND funding_source = 'SHCF_26-27_#9556'),
        '2026-2027', 'Herb garden supplies'
    ),
    (
        '2026-08-27', 'Karen Allen', 'Meadowbrook Academy',
        'Compost Mix', 15, TRUE, 'Approved', TRUE,
        (SELECT budget_id FROM budget
         WHERE budget_name = 'Garden Maintenance'
           AND funding_source = 'DonatedFunds_5120'),
        '2026-2027', 'Compost for garden beds'
    ),
    (
        '2026-08-28', 'Liam Young', 'Willow Creek School',
        'Drip Irrigation Kit', 2, FALSE, 'Approved', TRUE,
        (SELECT budget_id FROM budget
         WHERE budget_name = 'Garden Maintenance'
           AND funding_source = 'DonatedFunds_5120'),
        '2026-2027', 'Irrigation equipment'
    ),
    (
        '2026-08-29', 'Mia King', 'Northside Community School',
        'Knee Pads', 4, TRUE, 'Approved', TRUE,
        (SELECT budget_id FROM budget
         WHERE budget_name = 'Tools and Equipment'
           AND funding_source = 'DonatedFunds_5120'),
        '2026-2027', 'Safety equipment for volunteers'
    );


-- ============================================================
-- INVENTORY TRANSACTIONS
-- ============================================================

INSERT INTO "InventoryTransaction"
    (
        date,
        status,
        taken_by,
        for_school,
        item_name,
        quantity,
        notes
    )
VALUES
    ('2026-09-01', 'Checked Out', 'Alice Morgan', 'Hogwarts Academy', 'Plant Pots', 5, 'Seedling planting'),
    ('2026-09-03', 'Checked Out', 'Brian Lee', 'Sunshine Elementary', 'Garden Gloves', 4, 'Student garden work'),
    ('2026-09-05', 'Checked Out', 'Carla Davis', 'Green Valley Middle School', 'Hydroponic Nutrients', 2, 'Hydroponic system'),
    ('2026-09-08', 'Checked Out', 'Daniel Smith', 'Oakwood High School', 'Garden Soil', 5, 'Preparing garden beds'),
    ('2026-09-10', 'Checked Out', 'Emily Brown', 'Riverbend Academy', 'Tomato Seeds', 3, 'Tomato planting'),
    ('2026-09-12', 'Checked Out', 'Alice Morgan', 'Hogwarts Academy', 'Hand Trowel', 2, 'Garden tools'),
    ('2026-09-15', 'Checked Out', 'Brian Lee', 'Sunshine Elementary', 'Watering Can', 2, 'Garden watering'),
    ('2026-09-18', 'Checked Out', 'Carla Davis', 'Green Valley Middle School', 'Plant Labels', 8, 'Plant identification'),
    ('2026-09-20', 'Checked Out', 'Grace Taylor', 'Maple Grove School', 'Lettuce Seeds', 4, 'Lettuce planting'),
    ('2026-09-22', 'Checked Out', 'Henry Moore', 'Pinecrest Elementary', 'Plant Labels', 10, 'Labeling crops'),
    ('2026-09-24', 'Checked Out', 'Isabella Clark', 'Lakeside Middle School', 'Carrot Seeds', 3, 'Root crop planting'),
    ('2026-09-26', 'Checked Out', 'James Hall', 'Cedar Ridge School', 'Basil Seeds', 3, 'Herb garden planting'),
    ('2026-09-28', 'Checked Out', 'Karen Allen', 'Meadowbrook Academy', 'Compost Mix', 6, 'Soil improvement'),
    ('2026-09-30', 'Checked Out', 'Liam Young', 'Willow Creek School', 'Drip Irrigation Kit', 1, 'Irrigation setup'),
    ('2026-10-02', 'Checked Out', 'Mia King', 'Northside Community School', 'Knee Pads', 2, 'Volunteer safety equipment');
