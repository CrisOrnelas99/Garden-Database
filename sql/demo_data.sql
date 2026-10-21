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


-- ============================================================
-- GARDEN DATA POPULATION
-- ============================================================


-- ============================================================
-- GARDENS
-- ============================================================

INSERT INTO garden
    (
        location_name,
        garden_name,
        garden_type,
        footprint_sq_ft,
        garden_status,
        garden_manager,
        notes
    )
VALUES
    ('Hogwarts Academy', 'Hogwarts Herb Garden', 'Teaching Garden', 1200.00, 'Active', 'Alice Morgan', 'Herbs and vegetables for student lessons'),
    ('Sunshine Elementary', 'Sunshine Learning Garden', 'Educational Garden', 900.00, 'Active', 'Brian Lee', 'Used for elementary science activities'),
    ('Green Valley Middle School', 'Green Valley Hydroponics', 'Hydroponic Garden', 650.00, 'Active', 'Carla Davis', 'Indoor hydroponic growing system'),
    ('Oakwood High School', 'Oakwood Teaching Garden', 'Teaching Garden', 1800.00, 'Active', 'Daniel Smith', 'Large outdoor teaching garden'),
    ('Riverbend Academy', 'Riverbend Pollinator Garden', 'Pollinator Garden', 1100.00, 'Active', 'Emily Brown', 'Supports pollinators and native plants'),
    ('Maple Grove School', 'Maple Grove Vegetable Garden', 'Vegetable Garden', 1400.00, 'Active', 'Grace Taylor', 'Seasonal vegetable production'),
    ('Pinecrest Elementary', 'Pinecrest Raised Beds', 'Raised Bed Garden', 800.00, 'Active', 'Henry Moore', 'Raised beds for younger students'),
    ('Lakeside Middle School', 'Lakeside Food Garden', 'Food Garden', 1600.00, 'Active', 'Isabella Clark', 'Produces vegetables for school activities'),
    ('Cedar Ridge School', 'Cedar Ridge Herb Garden', 'Herb Garden', 700.00, 'Needs Attention', 'James Hall', 'Several beds need soil improvement'),
    ('Meadowbrook Academy', 'Meadowbrook Compost Garden', 'Sustainable Garden', 1300.00, 'Active', 'Karen Allen', 'Uses composting and soil-building practices'),
    ('Willow Creek School', 'Willow Creek Demonstration Garden', 'Demonstration Garden', 1000.00, 'Active', 'Liam Young', 'Demonstrates irrigation methods'),
    ('Northside Community School', 'Northside Community Garden', 'Community Garden', 2200.00, 'Active', 'Mia King', 'Shared garden maintained by students and volunteers'),
    ('Eastview Academy', 'Eastview Native Plant Garden', 'Native Plant Garden', 1500.00, 'Seasonal', 'Noah Wright', 'Primarily active during spring and summer'),
    ('Westfield School', 'Westfield Greenhouse Garden', 'Greenhouse Garden', 950.00, 'Active', 'Olivia Scott', 'Protected growing space for seedlings'),
    ('HLC Office', 'HLC Demonstration Garden', 'Demonstration Garden', 500.00, 'Planned', 'Program Staff', 'Future demonstration garden at the central office');


-- ============================================================
-- GARDEN BEDS
-- ============================================================

INSERT INTO garden_beds
    (
        garden_name,
        bed_name,
        bed_type,
        bed_size,
        active,
        soil_health,
        notes
    )
VALUES
    ('Hogwarts Herb Garden', 'Hogwarts_Bed_1', 'Raised Bed', '4 ft x 12 ft', TRUE, 'Good', 'Herbs and leafy greens'),
    ('Sunshine Learning Garden', 'Sunshine_Bed_1', 'Raised Bed', '4 ft x 10 ft', TRUE, 'Excellent', 'Used by elementary classes'),
    ('Green Valley Hydroponics', 'GreenValley_Channel_1', 'Hydroponic Channel', '3 ft x 16 ft', TRUE, 'Good', 'Indoor hydroponic channel'),
    ('Oakwood Teaching Garden', 'Oakwood_Bed_1', 'In-Ground Bed', '5 ft x 20 ft', TRUE, 'Good', 'Main teaching bed'),
    ('Riverbend Pollinator Garden', 'Riverbend_Bed_1', 'Native Plant Bed', '6 ft x 18 ft', TRUE, 'Excellent', 'Native flowering plants'),
    ('Maple Grove Vegetable Garden', 'MapleGrove_Bed_1', 'Raised Bed', '4 ft x 16 ft', TRUE, 'Good', 'Vegetable production'),
    ('Pinecrest Raised Beds', 'Pinecrest_Bed_1', 'Raised Bed', '3 ft x 10 ft', TRUE, 'Needs Improvement', 'Needs additional compost'),
    ('Lakeside Food Garden', 'Lakeside_Bed_1', 'In-Ground Bed', '5 ft x 18 ft', TRUE, 'Good', 'Food production bed'),
    ('Cedar Ridge Herb Garden', 'CedarRidge_Bed_1', 'Raised Bed', '3 ft x 12 ft', TRUE, 'Poor', 'Soil replacement recommended'),
    ('Meadowbrook Compost Garden', 'Meadowbrook_Bed_1', 'Compost-Amended Bed', '4 ft x 14 ft', TRUE, 'Excellent', 'Amended with finished compost'),
    ('Willow Creek Demonstration Garden', 'WillowCreek_Bed_1', 'Raised Bed', '4 ft x 12 ft', TRUE, 'Good', 'Irrigation demonstration bed'),
    ('Northside Community Garden', 'Northside_Bed_1', 'In-Ground Bed', '6 ft x 20 ft', TRUE, 'Good', 'Community vegetable bed'),
    ('Eastview Native Plant Garden', 'Eastview_Bed_1', 'Native Plant Bed', '5 ft x 18 ft', TRUE, 'Needs Improvement', 'Seasonal native planting area'),
    ('Westfield Greenhouse Garden', 'Westfield_Bench_1', 'Greenhouse Bench', '3 ft x 12 ft', TRUE, NULL, 'Soil health not applicable to bench'),
    ('HLC Demonstration Garden', 'HLC_Bed_1', 'Raised Bed', '4 ft x 8 ft', FALSE, 'Poor', 'Bed awaiting renovation');


-- ============================================================
-- IRRIGATION SETUPS
-- ============================================================

INSERT INTO irrigation_setup
    (
        garden_name,
        irrigation_name,
        irrigation_type,
        status,
        notes
    )
VALUES
    ('Hogwarts Herb Garden', 'Hogwarts Drip Line', 'Drip Irrigation', 'Operational', 'Automatic timer installed'),
    ('Sunshine Learning Garden', 'Sunshine Soaker Hose', 'Soaker Hose', 'Operational', 'Manually connected'),
    ('Green Valley Hydroponics', 'Green Valley Nutrient System', 'Hydroponic Recirculation', 'Operational', 'Indoor nutrient circulation'),
    ('Oakwood Teaching Garden', 'Oakwood Sprinkler Zone', 'Sprinkler', 'Needs Repair', 'Uneven water pressure'),
    ('Riverbend Pollinator Garden', 'Riverbend Manual Hose', 'Garden Hose', 'Operational', 'Used only during dry periods'),
    ('Maple Grove Vegetable Garden', 'Maple Grove Drip Line', 'Drip Irrigation', 'Operational', 'Separate zones for vegetables'),
    ('Pinecrest Raised Beds', 'Pinecrest Soaker Hose', 'Soaker Hose', 'Needs Repair', 'Hose has several leaks'),
    ('Lakeside Food Garden', 'Lakeside Sprinkler', 'Sprinkler', 'Operational', 'Morning watering schedule'),
    ('Cedar Ridge Herb Garden', 'Cedar Ridge Manual Hose', 'Garden Hose', 'Needs Maintenance', 'Connector needs replacement'),
    ('Meadowbrook Compost Garden', 'Meadowbrook Drip System', 'Drip Irrigation', 'Operational', 'Low-water system'),
    ('Willow Creek Demonstration Garden', 'Willow Creek Smart Irrigation', 'Smart Irrigation', 'Operational', 'Moisture sensor enabled'),
    ('Northside Community Garden', 'Northside Drip Line', 'Drip Irrigation', 'Operational', 'Shared maintenance responsibility'),
    ('Eastview Native Plant Garden', 'Eastview Rain Collection', 'Rainwater Collection', 'Seasonal', 'Used during warmer months'),
    ('Westfield Greenhouse Garden', 'Westfield Mist System', 'Misting System', 'Operational', 'Used for seedlings'),
    ('HLC Demonstration Garden', 'HLC Irrigation Unit', 'Soaker Hose', 'Inactive', 'Will be installed after renovation');


-- ============================================================
-- COMPOSTING UNITS
-- ============================================================

INSERT INTO composting_units
    (
        garden_name,
        composting_unit_name,
        composting_type,
        status,
        notes
    )
VALUES
    ('Hogwarts Herb Garden', 'Hogwarts Compost Bin', 'Three-Bin Compost System', 'Active', 'Used for garden clippings'),
    ('Sunshine Learning Garden', 'Sunshine Tumbler', 'Compost Tumbler', 'Active', 'Used for classroom demonstrations'),
    ('Green Valley Hydroponics', 'Green Valley Worm Bin', 'Worm Composting', 'Active', 'Processes small amounts of organic waste'),
    ('Oakwood Teaching Garden', 'Oakwood Compost Area', 'Open Compost Area', 'Needs Maintenance', 'Needs additional carbon material'),
    ('Riverbend Pollinator Garden', 'Riverbend Leaf Bin', 'Leaf Compost Bin', 'Active', 'Uses collected leaves'),
    ('Maple Grove Vegetable Garden', 'Maple Grove Tumbler', 'Compost Tumbler', 'Active', 'Rotated weekly'),
    ('Pinecrest Raised Beds', 'Pinecrest Classroom Bin', 'Compost Bin', 'Needs Maintenance', 'Bin lid needs repair'),
    ('Lakeside Food Garden', 'Lakeside Compost Bin', 'Compost Bin', 'Active', 'Used for vegetable scraps'),
    ('Cedar Ridge Herb Garden', 'Cedar Ridge Compost Bin', 'Compost Bin', 'Inactive', 'Awaiting soil program review'),
    ('Meadowbrook Compost Garden', 'Meadowbrook Three-Bin System', 'Three-Bin Compost System', 'Active', 'Primary soil amendment source'),
    ('Willow Creek Demonstration Garden', 'Willow Creek Tumbler', 'Compost Tumbler', 'Active', 'Demonstrates composting methods'),
    ('Northside Community Garden', 'Northside Community Bin', 'Compost Bin', 'Active', 'Maintained by volunteers'),
    ('Eastview Native Plant Garden', 'Eastview Leaf Mold Bin', 'Leaf Mold', 'Seasonal', 'Used during fall cleanup'),
    ('Westfield Greenhouse Garden', 'Westfield Worm Bin', 'Worm Composting', 'Active', 'Supports greenhouse seedlings'),
    ('HLC Demonstration Garden', 'HLC Compost Unit', 'Compost Bin', 'Planned', 'Unit will be added during renovation');


-- ============================================================
-- PLANT CATALOG
-- ============================================================

INSERT INTO plant
    (
        plant_name,
        plant_type,
        growing_months,
        days_to_harvest,
        notes
    )
VALUES
    ('Tomato', 'Fruit Vegetable', 'May-September', 75, 'Warm-season crop'),
    ('Basil', 'Herb', 'May-September', 45, 'Can be harvested repeatedly'),
    ('Lettuce', 'Leafy Green', 'March-June, September-November', 45, 'Cool-season crop'),
    ('Carrot', 'Root Vegetable', 'March-June, August-November', 70, 'Grows well in loose soil'),
    ('Radish', 'Root Vegetable', 'March-May, September-October', 30, 'Fast-growing crop'),
    ('Spinach', 'Leafy Green', 'March-May, September-November', 40, 'Prefers cooler weather'),
    ('Cucumber', 'Fruit Vegetable', 'May-August', 60, 'Needs trellis support'),
    ('Green Bean', 'Legume', 'May-August', 55, 'Warm-season crop'),
    ('Kale', 'Leafy Green', 'March-June, September-November', 60, 'Tolerates cool temperatures'),
    ('Pepper', 'Fruit Vegetable', 'May-September', 80, 'Requires warm soil'),
    ('Zucchini', 'Fruit Vegetable', 'May-August', 50, 'Productive summer crop'),
    ('Peas', 'Legume', 'March-May, September-October', 60, 'Cool-season crop'),
    ('Marigold', 'Flower', 'May-October', 60, 'Attracts pollinators'),
    ('Sunflower', 'Flower', 'May-September', 80, 'Tall pollinator-friendly plant'),
    ('Cilantro', 'Herb', 'March-June, September-November', 45, 'Prefers cooler growing conditions');


-- ============================================================
-- CROP ROTATIONS
-- ============================================================

INSERT INTO "CropRotation"
    (
        garden_name,
        bed_name,
        plant_name,
        season,
        planned_planting_date,
        status,
        notes
    )
VALUES
    ('Hogwarts Herb Garden', 'Hogwarts_Bed_1', 'Basil', 'Summer', '2027-05-15', 'Planned', 'Plant after final frost'),
    ('Sunshine Learning Garden', 'Sunshine_Bed_1', 'Lettuce', 'Spring', '2027-03-20', 'Planned', 'First classroom crop'),
    ('Green Valley Hydroponics', 'GreenValley_Channel_1', 'Spinach','Spring', '2027-03-01', 'In Progress','Hydroponic growing cycle'),
    ('Oakwood Teaching Garden', 'Oakwood_Bed_1', 'Tomato','Summer', '2027-05-01', 'Planned','Needs trellis support'),
    ('Riverbend Pollinator Garden', 'Riverbend_Bed_1', 'Marigold','Summer', '2027-05-10', 'Planned', 'Pollinator border planting'),
    ('Maple Grove Vegetable Garden', 'MapleGrove_Bed_1', 'Carrot','Spring', '2027-03-25', 'Planned','Direct sowing'),
    ('Pinecrest Raised Beds', 'Pinecrest_Bed_1', 'Radish', 'Spring', '2027-03-15', 'Planned','Short rotation crop'),
    ('Lakeside Food Garden', 'Lakeside_Bed_1', 'Cucumber','Summer', '2027-05-20', 'Planned','Trellis required'),
    ('Cedar Ridge Herb Garden', 'CedarRidge_Bed_1', 'Cilantro','Fall', '2027-09-05', 'Delayed','Waiting for soil improvement'),
    ('Meadowbrook Compost Garden', 'Meadowbrook_Bed_1', 'Kale','Fall', '2027-09-10', 'Planned','Use finished compost'),
    ('Willow Creek Demonstration Garden', 'WillowCreek_Bed_1', 'Green Bean','Summer', '2027-05-12', 'In Progress','Irrigation demonstration'),
    ('Northside Community Garden', 'Northside_Bed_1', 'Zucchini','Summer', '2027-05-18', 'Planned','Community planting day'), ('Eastview Native Plant Garden', 'Eastview_Bed_1', 'Sunflower',
     'Summer', '2027-05-05', 'Completed','Previous seasonal planting'),
    ('Westfield Greenhouse Garden', 'Westfield_Bench_1', 'Pepper','Spring', '2027-03-10', 'In Progress','Started indoors'),
    ('HLC Demonstration Garden', 'HLC_Bed_1', 'Peas','Spring', NULL, 'Planned','Date will be selected after renovation');
