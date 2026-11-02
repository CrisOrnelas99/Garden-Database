-- ============================================================
-- INVENTORY DATA POPULATION
-- ============================================================

-- Optional rollback
-- TRUNCATE TABLE
--     inventory_transaction,
--     purchase_request,
--     group_location,
--     location_group,
--     inventory_list,
--     item,
--     budget,
--     crop_rotation,
--     garden_bed,
--     irrigation_setup,
--     compost_unit,
--     plant,
--     location
-- RESTART IDENTITY CASCADE;


-- ============================================================
-- LOCATIONS
-- ============================================================

INSERT INTO location
    (
        location_name,
        is_hlc,
        contact,
        email,
        garden_status,
        garden_condition,
        bed_count,
        notes
    )
VALUES
    ('Hogwarts', TRUE, 'Alice Morgan', 'alice@hogwarts.edu', 'Active', 'Good', 0, 'Type: Teaching Garden; Footprint: 1200 sq ft; Manager: Alice Morgan. Herbology lessons with Professor Sprout; greenhouse seedlings start here before moving outdoors.'),
    ('Sunshine Elementary', TRUE, 'Brian Lee', 'brian@sunshine.edu', 'Active', 'Good', 0, 'Type: Educational Garden; Footprint: 900 sq ft; Manager: Brian Lee. Used for elementary science activities.'),
    ('Green Valley Middle School', TRUE, 'Carla Davis', 'carla@greenvalley.edu', 'Active', 'Good', 0, 'Type: Hydroponic Garden; Footprint: 650 sq ft; Manager: Carla Davis. Indoor hydroponic growing system.'),
    ('Oakwood High School', TRUE, 'Daniel Smith', 'daniel@oakwood.edu', 'Active', 'Good', 0, 'Type: Teaching Garden; Footprint: 1800 sq ft; Manager: Daniel Smith. Large outdoor teaching garden.'),
    ('Riverbend Academy', TRUE, 'Emily Brown', 'emily@riverbend.edu', 'Active', 'Good', 0, 'Type: Pollinator Garden; Footprint: 1100 sq ft; Manager: Emily Brown. Supports pollinators and native plants.'),
    ('HLC Office', FALSE, 'Frank Wilson', 'frank@hlc.org', NULL, NULL, NULL, 'Central program office; no garden or garden assets are currently tracked.'),
    ('Maple Grove School', TRUE, 'Grace Taylor', 'grace@maplegrove.edu', 'Active', 'Good', 0, 'Type: Vegetable Garden; Footprint: 1400 sq ft; Manager: Grace Taylor. Seasonal vegetable production.'),
    ('Pinecrest Elementary', TRUE, 'Henry Moore', 'henry@pinecrest.edu', 'Active', 'Good', 0, 'Type: Raised Bed Garden; Footprint: 800 sq ft; Manager: Henry Moore. Raised beds for younger students.'),
    ('Lakeside Middle School', TRUE, 'Isabella Clark', 'isabella@lakeside.edu', 'Active', 'Good', 0, 'Type: Food Garden; Footprint: 1600 sq ft; Manager: Isabella Clark. Produces vegetables for school activities.'),
    ('Cedar Ridge School', TRUE, 'James Hall', 'james@cedarridge.edu', 'Active', 'Require Maintenance', 0, 'Type: Herb Garden; Footprint: 700 sq ft; Manager: James Hall. Several beds need soil improvement.'),
    ('Meadowbrook Academy', TRUE, 'Karen Allen', 'karen@meadowbrook.edu', 'Active', 'Good', 0, 'Type: Sustainable Garden; Footprint: 1300 sq ft; Manager: Karen Allen. Uses composting and soil-building practices.'),
    ('Willow Creek School', TRUE, 'Liam Young', 'liam@willowcreek.edu', 'Active', 'Good', 0, 'Type: Demonstration Garden; Footprint: 1000 sq ft; Manager: Liam Young. Demonstrates irrigation methods.'),
    ('Northside Community School', TRUE, 'Mia King', 'mia@northside.edu', 'Active', 'Good', 0, 'Type: Community Garden; Footprint: 2200 sq ft; Manager: Mia King. Shared garden maintained by students and volunteers.'),
    ('Eastview Academy', TRUE, 'Noah Wright', 'noah@eastview.edu', 'Active', 'Good', 0, 'Type: Native Plant Garden; Footprint: 1500 sq ft; Manager: Noah Wright. Primarily active during spring and summer.'),
    ('Westfield School', TRUE, 'Olivia Scott', 'olivia@westfield.edu', 'Active', 'Good', 0, 'Type: Greenhouse Garden; Footprint: 950 sq ft; Manager: Olivia Scott. Protected growing space for seedlings.'),
    ('Brookside School', TRUE, 'Paula Green', 'paula@brookside.edu', 'Planned', NULL, 0, 'School planning a garden; beds have not been installed yet.');


-- ============================================================
-- LOCATION GROUPS
-- Custom named groups can be attached to requests and transactions.
-- The built-in All HLC Gardens group is created and maintained by schema_garden.sql.
-- ============================================================

INSERT INTO location_group (location_group_name)
VALUES
    ('SchoolBandC'),
    ('Triwizard Greenhouse Team')
ON CONFLICT (location_group_name) DO NOTHING;

INSERT INTO group_location
    (
        location_group_name,
        location_name
    )
VALUES
    ('SchoolBandC', 'Sunshine Elementary'),
    ('SchoolBandC', 'Green Valley Middle School'),
    ('Triwizard Greenhouse Team', 'Hogwarts'),
    ('Triwizard Greenhouse Team', 'Sunshine Elementary'),
    ('Triwizard Greenhouse Team', 'Green Valley Middle School')
ON CONFLICT (location_group_name, location_name) DO NOTHING;


-- ============================================================
-- BUDGETS
-- ============================================================

INSERT INTO budget
    (
        budget_name,
        budget_amount,
        remaining_budget,
        notes
    )
VALUES
    ('Garden Supplies', 5000.00, 5000.00, 'Garden supplies, including Hogwarts Herbology lessons'),
    ('Hydroponics', 3000.00, 3000.00, 'Hydroponic supplies'),
    ('Garden Maintenance', 10000.00, 10000.00, 'Garden maintenance'),
    ('Seeds and Soil', 4000.00, 4000.00, 'Seeds and soil supplies'),
    ('Tools and Equipment', 7500.00, 7500.00, 'Reusable garden tools'),
    ('Community Donation', 1200.00, 1200.00, 'Local donation awaiting a named funding source');


-- ============================================================
-- ITEMS
-- ============================================================

INSERT INTO item
    (
        item_name,
        category,
        vendor_name,
        link,
        unit_cost,
        notes
    )
VALUES
    ('Plant Pots', 'Garden', 'Amazon', 'https://amazon.com', 15.99, 'Plant containers'),
    ('Garden Gloves', 'Garden', 'Walmart', 'https://walmart.com', 12.99, 'Protective garden gloves'),
    ('Hand Trowel', 'Garden', 'Amazon', 'https://amazon.com', 9.99, 'Small hand tool'),
    ('Watering Can', 'Garden', 'Walmart', 'https://walmart.com', 14.99, 'Watering equipment'),
    ('Tomato Seeds', 'Seeds', 'Johnny Seeds', 'https://johnnyseeds.com', 6.99, 'Tomato seed packets'),
    ('Lettuce Seeds', 'Seeds', 'Johnny Seeds', 'https://johnnyseeds.com', 5.99, 'Lettuce seed packets'),
    ('Garden Soil', 'Soil', 'Home Depot', 'https://homedepot.com', 8.99, 'General planting soil'),
    ('Plant Labels', 'Garden', 'Amazon', 'https://amazon.com', 7.99, 'Plant identification labels'),
    ('Hydroponic Nutrients', 'Hydroponics', 'Amazon', 'https://amazon.com', 24.99, 'Hydroponic nutrients'),
    ('Pruning Shears', 'Garden', 'Walmart', 'https://walmart.com', 13.99, 'Pruning tool'),
    ('Carrot Seeds', 'Seeds', 'Johnny Seeds', 'https://johnnyseeds.com', 4.99, 'Carrot seed packets'),
    ('Basil Seeds', 'Seeds', 'Johnny Seeds', 'https://johnnyseeds.com', 4.49, 'Basil seed packets'),
    ('Compost Mix', 'Soil', 'Home Depot', 'https://homedepot.com', 11.99, 'Compost and soil amendment for Professor Sprout-approved beds'),
    ('Drip Irrigation Kit', 'Irrigation', 'Home Depot', 'https://homedepot.com', 39.99, 'Small garden irrigation kit'),
    ('Knee Pads', 'Safety', 'Walmart', 'https://walmart.com', 18.99, 'Protective equipment');


-- ============================================================
-- INVENTORY LIST
-- ============================================================

INSERT INTO inventory_list
    (
        item_name,
        cumulative_asset,
        instock_total,
        reorder_point,
        counted,
        storage_location,
        notes
    )
VALUES
    ('Plant Pots', 100, 55, 10, TRUE, 'Garden Storage', 'Inventory item; some reserved for Hogwarts greenhouse seedlings'),
    ('Garden Gloves', 40, 24, 8, TRUE, 'Tool Room', 'Inventory item'),
    ('Hand Trowel', 30, 18, 5, TRUE, 'Tool Room', 'Inventory item'),
    ('Watering Can', 25, 14, 4, TRUE, 'Garden Storage', 'Inventory item'),
    ('Tomato Seeds', 60, 12, 10, TRUE, 'Seed Storage', 'Inventory item; low stock before the next planting'),
    ('Lettuce Seeds', 55, 28, 10, TRUE, 'Seed Storage', 'Inventory item'),
    ('Garden Soil', 80, 10, 15, TRUE, 'Garden Storage', 'Inventory item; below the reorder point'),
    ('Plant Labels', 150, 75, 20, TRUE, 'Garden Storage', 'Inventory item'),
    ('Hydroponic Nutrients', 30, 16, 5, TRUE, 'Hydroponic Storage', 'Inventory item'),
    ('Pruning Shears', 20, 12, 4, TRUE, 'Tool Room', 'Inventory item'),
    ('Carrot Seeds', 50, 30, 10, TRUE, 'Seed Storage', 'Inventory item'),
    ('Basil Seeds', 45, 25, 8, TRUE, 'Seed Storage', 'Inventory item'),
    ('Compost Mix', 70, 38, 12, TRUE, 'Garden Storage', 'Inventory item; use for Herbology beds'),
    ('Drip Irrigation Kit', 12, 7, 2, TRUE, 'Equipment Room', 'Inventory item'),
    ('Knee Pads', 20, 11, 3, FALSE, 'Safety Equipment', 'Inventory item');


-- ============================================================
-- PURCHASE REQUESTS
-- ============================================================

INSERT INTO purchase_request
    (
        request_date,
        requested_by,
        requesting_school,
        item_name,
        quantity_requested,
        delivered_to_fns,
        review_status,
        ordered,
        budget_name,
        funding_source,
        school_year,
        notes
    )
VALUES
    (
        '2026-08-15', 'Alice Morgan', 'Hogwarts',
        'Plant Pots', 5, TRUE, 'Approved', TRUE,
        'Garden Supplies', 'SHCF_26-27_#9556',
        '2026-2027', 'Pots for spring seedlings in the Hogwarts greenhouse'
    ),
    (
        '2026-08-16', 'Brian Lee', 'Sunshine Elementary',
        'Garden Gloves', 6, TRUE, 'Approved', TRUE,
        'Garden Supplies', 'SHCF_26-27_#9556',
        '2026-2027', 'Gloves for student garden work'
    ),
    (
        '2026-08-17', 'Carla Davis', 'Green Valley Middle School',
        'Hydroponic Nutrients', 4, TRUE, 'Approved', TRUE,
        'Hydroponics', 'Collaboratory_26-27_#9446',
        '2026-2027', 'Hydroponic growing supplies'
    ),
    (
        '2026-08-18', 'Daniel Smith', 'Oakwood High School',
        'Garden Soil', 12, FALSE, 'Under Review', FALSE,
        'Seeds and Soil', 'SHCF_26-27_#9556',
        '2026-2027', 'Soil for garden beds'
    ),
    (
        '2026-08-19', 'Emily Brown', 'Riverbend Academy',
        'Tomato Seeds', 8, FALSE, 'Under Review', FALSE,
        'Seeds and Soil', 'SHCF_26-27_#9556',
        '2026-2027', 'Tomato planting supplies'
    ),
    (
        '2026-08-20', 'Alice Morgan', 'Hogwarts',
        'Hand Trowel', 4, TRUE, 'Approved', TRUE,
        'Tools and Equipment', 'DonatedFunds_5120',
        '2026-2027', 'Additional hand tools for Professor Sprout''s Herbology class'
    ),
    (
        '2026-08-21', 'Brian Lee', 'Sunshine Elementary',
        'Watering Can', 3, TRUE, 'Approved', TRUE,
        'Garden Maintenance', 'DonatedFunds_5120',
        '2026-2027', 'Watering equipment'
    ),
    (
        '2026-08-22', 'Carla Davis', 'Green Valley Middle School',
        'Pruning Shears', 3, FALSE, 'Under Review', FALSE,
        'Tools and Equipment', 'DonatedFunds_5120',
        '2026-2027', 'Garden maintenance tools'
    ),
    (
        '2026-08-23', 'Grace Taylor', 'Maple Grove School',
        'Lettuce Seeds', 10, TRUE, 'Approved', TRUE,
        'Seeds and Soil', 'SHCF_26-27_#9556',
        '2026-2027', 'Lettuce planting supplies'
    ),
    (
        '2026-08-24', 'Henry Moore', 'Pinecrest Elementary',
        'Plant Labels', 20, TRUE, 'Approved', TRUE,
        'Garden Supplies', 'SHCF_26-27_#9556',
        '2026-2027', 'Labels for crop identification'
    ),
    (
        '2026-08-25', 'Isabella Clark', 'Lakeside Middle School',
        'Carrot Seeds', 8, FALSE, 'Under Review', FALSE,
        'Seeds and Soil', 'SHCF_26-27_#9556',
        '2026-2027', 'Carrot planting supplies'
    ),
    (
        '2026-08-26', 'James Hall', 'Cedar Ridge School',
        'Basil Seeds', 8, TRUE, 'Approved', TRUE,
        'Seeds and Soil', 'SHCF_26-27_#9556',
        '2026-2027', 'Herb garden supplies'
    ),
    (
        '2026-08-27', 'Karen Allen', 'Meadowbrook Academy',
        'Compost Mix', 15, TRUE, 'Approved', TRUE,
        'Garden Maintenance', 'DonatedFunds_5120',
        '2026-2027', 'Compost for garden beds'
    ),
    (
        '2026-08-28', 'Liam Young', 'Willow Creek School',
        'Drip Irrigation Kit', 2, FALSE, 'Approved', TRUE,
        'Garden Maintenance', 'DonatedFunds_5120',
        '2026-2027', 'Irrigation equipment'
    ),
    (
        '2026-08-29', 'Mia King', 'Northside Community School',
        'Knee Pads', 4, TRUE, 'Approved', TRUE,
        'Tools and Equipment', 'DonatedFunds_5120',
        '2026-2027', 'Safety equipment for volunteers'
    ),
    (
        '2026-08-30', 'Alice Morgan', 'Hogwarts',
        'Garden Gloves', 3, TRUE, 'Approved', TRUE,
        'Garden Supplies', 'SHCF_26-27_#9556',
        '2026-2027', 'Replacement gloves for the greenhouse team'
    ),
    (
        '2027-08-15', 'Alice Morgan', 'Hogwarts',
        'Plant Pots', 8, FALSE, 'Approved', TRUE,
        'Garden Supplies', 'LocalDonors_26-27',
        '2027-2028', 'Ordered pots for the upcoming greenhouse season; delivery is pending'
    ),
    (
        '2027-08-12', 'Paula Green', 'Brookside School',
        'Lettuce Seeds', 5, FALSE, 'Approved', TRUE,
        'Community Donation', NULL,
        '2027-2028', 'First purchase for a school that is preparing to start a garden'
    );

-- Single-location requests use requesting_school directly. Multi-location
-- requests use requesting_school_group and leave requesting_school NULL.
UPDATE purchase_request
SET requesting_school = 'Hogwarts',
    requesting_school_group = NULL
WHERE request_date IN ('2026-08-15', '2026-08-20', '2026-08-30', '2027-08-15');

UPDATE purchase_request
SET requesting_school = NULL,
    requesting_school_group = 'SchoolBandC'
WHERE request_date IN ('2026-08-16', '2026-08-21');

UPDATE purchase_request
SET requesting_school = NULL,
    requesting_school_group = 'Triwizard Greenhouse Team'
WHERE request_date = '2026-08-17';

UPDATE purchase_request
SET requesting_school = 'Brookside School',
    requesting_school_group = NULL
WHERE request_date = '2027-08-12';

-- The central partner office can order items without having a garden.
INSERT INTO purchase_request
    (
        request_date,
        requested_by,
        requesting_school,
        item_name,
        quantity_requested,
        delivered_to_fns,
        review_status,
        ordered,
        budget_name,
        funding_source,
        school_year,
        notes
    )
VALUES
    (
        '2026-09-02', 'Frank Wilson', 'HLC Office',
        'Knee Pads', 2, FALSE, 'Approved', TRUE,
        'Community Donation', NULL,
        '2026-2027', 'Protective gear ordered for central program staff'
    );

-- A bulk request assigned to all 16 locations, including locations without gardens.
INSERT INTO purchase_request
    (
        request_date,
        requested_by,
        requesting_school_group,
        item_name,
        quantity_requested,
        delivered_to_fns,
        review_status,
        ordered,
        budget_name,
        funding_source,
        school_year,
        notes
    )
VALUES
    (
        '2026-09-04', 'Frank Wilson', 'All HLC Gardens',
        'Garden Gloves', 30, FALSE, 'Approved', TRUE,
        'Garden Supplies', 'SHCF_26-27_#9556',
        '2026-2027', 'Bulk glove order for locations with garden details, including inactive gardens; quantities are not split by location'
    );

-- ============================================================
-- INVENTORY TRANSACTIONS
-- ============================================================

INSERT INTO inventory_transaction
    (
        transaction_date,
        status,
        taken_by,
        for_school,
        item_name,
        quantity,
        notes
    )
VALUES
    ('2026-09-01', 'Checked Out', 'Alice Morgan', 'Hogwarts', 'Plant Pots', 5, 'Seedling planting for Herbology class'),
    ('2026-09-03', 'Checked Out', 'Brian Lee', 'Sunshine Elementary', 'Garden Gloves', 4, 'Student garden work'),
    ('2026-09-05', 'Checked Out', 'Carla Davis', 'Green Valley Middle School', 'Hydroponic Nutrients', 2, 'Hydroponic system'),
    ('2026-09-08', 'Checked Out', 'Daniel Smith', 'Oakwood High School', 'Garden Soil', 5, 'Preparing garden beds'),
    ('2026-09-10', 'Checked Out', 'Emily Brown', 'Riverbend Academy', 'Tomato Seeds', 3, 'Tomato planting'),
    ('2026-09-12', 'Checked Out', 'Alice Morgan', 'Hogwarts', 'Hand Trowel', 2, 'Garden tools returned to the greenhouse after class'),
    ('2026-09-15', 'Checked Out', 'Brian Lee', 'Sunshine Elementary', 'Watering Can', 2, 'Garden watering'),
    ('2026-09-18', 'Checked Out', 'Carla Davis', 'Green Valley Middle School', 'Plant Labels', 8, 'Plant identification'),
    ('2026-09-20', 'Checked Out', 'Grace Taylor', 'Maple Grove School', 'Lettuce Seeds', 4, 'Lettuce planting'),
    ('2026-09-22', 'Checked Out', 'Henry Moore', 'Pinecrest Elementary', 'Plant Labels', 10, 'Labeling crops'),
    ('2026-09-24', 'Checked Out', 'Isabella Clark', 'Lakeside Middle School', 'Carrot Seeds', 3, 'Root crop planting'),
    ('2026-09-26', 'Checked Out', 'James Hall', 'Cedar Ridge School', 'Basil Seeds', 3, 'Herb garden planting'),
    ('2026-09-28', 'Checked Out', 'Karen Allen', 'Meadowbrook Academy', 'Compost Mix', 6, 'Soil improvement'),
    ('2026-09-30', 'Checked Out', 'Liam Young', 'Willow Creek School', 'Drip Irrigation Kit', 1, 'Irrigation setup'),
    ('2026-10-02', 'Checked Out', 'Mia King', 'Northside Community School', 'Knee Pads', 2, 'Volunteer safety equipment'),
    ('2026-10-04', 'Checked In', 'Alice Morgan', 'Hogwarts', 'Garden Gloves', 2, 'Clean gloves returned after Herbology class');

-- Assign selected transactions to named groups. The SchoolBandC movements
-- represent shared activity; their quantities are not split between schools.
UPDATE inventory_transaction
SET for_school = 'Hogwarts',
    for_school_group = NULL
WHERE transaction_date IN ('2026-09-01', '2026-10-04');

UPDATE inventory_transaction
SET for_school = NULL,
    for_school_group = 'SchoolBandC'
WHERE transaction_date IN ('2026-09-03', '2026-09-15');

UPDATE inventory_transaction
SET for_school = NULL,
    for_school_group = 'Triwizard Greenhouse Team'
WHERE transaction_date = '2026-09-05';

INSERT INTO inventory_transaction
    (
        transaction_date,
        status,
        taken_by,
        for_school,
        item_name,
        quantity,
        notes
    )
VALUES
    (
        '2026-10-06', 'Checked Out', 'Frank Wilson', 'HLC Office',
        'Knee Pads', 1, 'Protective gear checked out for the central program office'
    );

INSERT INTO inventory_transaction
    (
        transaction_date,
        status,
        taken_by,
        for_school_group,
        item_name,
        quantity,
        notes
    )
VALUES
    (
        '2026-10-08', 'Checked Out', 'Frank Wilson', 'All HLC Gardens',
        'Garden Gloves', 8, 'Bulk gloves checked out for distribution across locations with garden details'
    );

-- Fail the demo load if any record has neither assignment path or both paths.
DO $$
BEGIN
    IF EXISTS (
        SELECT 1
        FROM purchase_request
        WHERE (requesting_school IS NOT NULL) = (requesting_school_group IS NOT NULL)
    ) THEN
        RAISE EXCEPTION 'Demo purchase request must have exactly one location assignment';
    END IF;

    IF EXISTS (
        SELECT 1
        FROM inventory_transaction
        WHERE (for_school IS NOT NULL) = (for_school_group IS NOT NULL)
    ) THEN
        RAISE EXCEPTION 'Demo inventory transaction must have exactly one location assignment';
    END IF;
END;
$$;


-- ============================================================
-- GARDEN DATA POPULATION
-- ============================================================


-- ============================================================
-- GARDEN BEDS
-- ============================================================

INSERT INTO garden_bed
    (
        location_name,
        bed_name,
        bed_type,
        bed_size_sq_ft,
        lifecycle_status,
        condition,
        is_full,
        notes
    )
VALUES
    ('Hogwarts', 'Hogwarts_Bed_1', 'Raised Bed', 48, 'Active', 'Good', TRUE, 'Herbs and leafy greens for Herbology class; currently full'),
    ('Hogwarts', 'Hogwarts_Bed_2', 'Raised Bed', 48, 'Active', 'Good', FALSE, 'Prepared bed with no planting assigned yet'),
    ('Hogwarts', 'Greenhouse_Bed_1', 'Greenhouse Bench', 36, 'Active', 'Good', TRUE, 'Seedling bench for the Hogwarts greenhouse'),
    ('Sunshine Elementary', 'Sunshine_Bed_1', 'Raised Bed', 40, 'Active', 'Good', FALSE, 'Used by elementary classes'),
    ('Sunshine Elementary', 'Sunshine_Bed_2', 'Raised Bed', 32, 'Planned', 'Good', FALSE, 'Second bed planned for the next school year'),
    ('Green Valley Middle School', 'GreenValley_Channel_1', 'Hydroponic Channel', 48, 'Active', 'Good', FALSE, 'Indoor hydroponic growing system'),
    ('Oakwood High School', 'Oakwood_Bed_1', 'In-Ground Bed', 100, 'Active', 'Good', FALSE, 'Main outdoor teaching bed'),
    ('Riverbend Academy', 'Riverbend_Bed_1', 'Native Plant Bed', 108, 'Active', 'Good', FALSE, 'Native flowering plants'),
    ('Maple Grove School', 'MapleGrove_Bed_1', 'Raised Bed', 64, 'Active', 'Good', FALSE, 'Vegetable production'),
    ('Pinecrest Elementary', 'Pinecrest_Bed_1', 'Raised Bed', 30, 'Active', 'Require Maintenance', FALSE, 'Needs additional compost'),
    ('Lakeside Middle School', 'Lakeside_Bed_1', 'In-Ground Bed', 90, 'Active', 'Good', FALSE, 'Food production bed'),
    ('Cedar Ridge School', 'CedarRidge_Bed_1', 'Raised Bed', 36, 'Active', 'Require Maintenance', FALSE, 'Soil replacement recommended'),
    ('Cedar Ridge School', 'CedarRidge_Bed_2', 'Raised Bed', 36, 'Inactive', 'In Maintenance', FALSE, 'Closed while the soil is being replaced'),
    ('Meadowbrook Academy', 'Meadowbrook_Bed_1', 'Compost-Amended Bed', 56, 'Active', 'Good', FALSE, 'Amended with finished compost'),
    ('Willow Creek School', 'WillowCreek_Bed_1', 'Raised Bed', 48, 'Active', 'Good', FALSE, 'Irrigation demonstration bed'),
    ('Northside Community School', 'Northside_Bed_1', 'In-Ground Bed', 120, 'Active', 'Good', FALSE, 'Community vegetable bed'),
    ('Eastview Academy', 'Eastview_Bed_1', 'Native Plant Bed', 90, 'Active', 'Require Maintenance', FALSE, 'Seasonal native planting area'),
    ('Westfield School', 'Westfield_Bench_1', 'Greenhouse Bench', 36, 'Active', NULL, FALSE, 'Soil health not applicable to bench'),
    ('Meadowbrook Academy', 'Meadowbrook_Bed_2', 'Raised Bed', 56, 'Inactive', 'Require Maintenance', FALSE, 'Resting bed while the soil recovers');


-- ============================================================
-- IRRIGATION SETUPS
-- ============================================================

INSERT INTO irrigation_setup
    (
        location_name,
        irrigation_name,
        irrigation_type,
        lifecycle_status,
        condition,
        notes
    )
VALUES
    ('Hogwarts', 'Hogwarts Drip Line', 'Drip Irrigation', 'Active', 'Good', 'Automatic timer installed; the Herbology club keeps watch'),
    ('Hogwarts', 'Hogwarts Hand Watering Zone', 'Garden Hose', 'Active', 'Good', 'Backup watering for newly sown rows'),
    ('Sunshine Elementary', 'Sunshine Soaker Hose', 'Soaker Hose', 'Active', 'Good', 'Manually connected'),
    ('Green Valley Middle School', 'Green Valley Nutrient System', 'Hydroponic Recirculation', 'Active', 'Good', 'Indoor hydroponic nutrient circulation'),
    ('Green Valley Middle School', 'Green Valley Backup Pump', 'Hydroponic Pump', 'Planned', NULL, 'Backup pump planned for the next maintenance cycle'),
    ('Oakwood High School', 'Oakwood Sprinkler Zone', 'Sprinkler', 'Active', 'Require Maintenance', 'Uneven water pressure'),
    ('Riverbend Academy', 'Riverbend Manual Hose', 'Garden Hose', 'Active', 'Good', 'Used only during dry periods'),
    ('Maple Grove School', 'Maple Grove Drip Line', 'Drip Irrigation', 'Active', 'Good', 'Separate zones for vegetables'),
    ('Pinecrest Elementary', 'Pinecrest Soaker Hose', 'Soaker Hose', 'Active', 'Require Maintenance', 'Hose has several leaks'),
    ('Lakeside Middle School', 'Lakeside Sprinkler', 'Sprinkler', 'Active', 'Good', 'Morning watering schedule'),
    ('Cedar Ridge School', 'Cedar Ridge Manual Hose', 'Garden Hose', 'Active', 'Require Maintenance', 'Connector needs replacement'),
    ('Meadowbrook Academy', 'Meadowbrook Drip System', 'Drip Irrigation', 'Active', 'Good', 'Low-water system'),
    ('Willow Creek School', 'Willow Creek Smart Irrigation', 'Smart Irrigation', 'Active', 'Good', 'Moisture sensor enabled'),
    ('Northside Community School', 'Northside Drip Line', 'Drip Irrigation', 'Active', 'Good', 'Shared maintenance responsibility'),
    ('Eastview Academy', 'Eastview Rain Collection', 'Rainwater Collection', 'Active', 'Good', 'Used during warmer months'),
    ('Westfield School', 'Westfield Mist System', 'Misting System', 'Active', 'Good', 'Used for seedlings'),
    ('Willow Creek School', 'Willow Creek Rain Barrel Line', 'Rainwater Collection', 'Planned', NULL, 'Expansion planned for the next growing season');


-- ============================================================
-- COMPOSTING UNITS
-- ============================================================

INSERT INTO compost_unit
    (
        location_name,
        unit_name,
        compost_type,
        lifecycle_status,
        condition,
        notes
    )
VALUES
    ('Hogwarts', 'Hogwarts Compost Bin', 'Three-Bin Compost System', 'Active', 'Good', 'Used for garden clippings; Professor Sprout approves'),
    ('Green Valley Middle School', 'Green Valley Worm Bin', 'Worm Composting', 'Active', 'Good', 'Processes small amounts of organic waste'),
    ('Oakwood High School', 'Oakwood Compost Area', 'Open Compost Area', 'Active', 'Require Maintenance', 'Needs additional carbon material'),
    ('Riverbend Academy', 'Riverbend Leaf Bin', 'Leaf Compost Bin', 'Active', 'Good', 'Uses collected leaves'),
    ('Maple Grove School', 'Maple Grove Tumbler', 'Compost Tumbler', 'Active', 'Good', 'Rotated weekly'),
    ('Pinecrest Elementary', 'Pinecrest Classroom Bin', 'Compost Bin', 'Active', 'In Maintenance', 'Bin lid is being repaired'),
    ('Lakeside Middle School', 'Lakeside Compost Bin', 'Compost Bin', 'Active', 'Good', 'Used for vegetable scraps'),
    ('Cedar Ridge School', 'Cedar Ridge Compost Bin', 'Compost Bin', 'Inactive', NULL, 'Awaiting soil program review'),
    ('Meadowbrook Academy', 'Meadowbrook Three-Bin System', 'Three-Bin Compost System', 'Active', 'Good', 'Primary soil amendment source'),
    ('Meadowbrook Academy', 'Meadowbrook Leaf Mold Bin', 'Leaf Mold Bin', 'Active', 'Good', 'Separate unit for fallen leaves'),
    ('Willow Creek School', 'Willow Creek Tumbler', 'Compost Tumbler', 'Active', 'Good', 'Demonstrates composting methods'),
    ('Northside Community School', 'Northside Community Bin', 'Compost Bin', 'Active', 'Good', 'Maintained by volunteers'),
    ('Eastview Academy', 'Eastview Leaf Mold Bin', 'Leaf Mold', 'Active', 'Good', 'Used during fall cleanup'),
    ('Westfield School', 'Westfield Worm Bin', 'Worm Composting', 'Active', 'Good', 'Supports greenhouse seedlings'),
    ('Cedar Ridge School', 'Cedar Ridge Planned Bin', 'Compost Bin', 'Planned', NULL, 'Planned after the current soil renovation is complete');


-- ============================================================
-- PLANT CATALOG
-- ============================================================

INSERT INTO plant
    (
        plant_name,
        plant_type,
        growing_period,
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

INSERT INTO crop_rotation
    (
        location_name,
        bed_name,
        plant_name,
        quantity,
        season,
        sow_date,
        status,
        soil_health,
        notes
    )
VALUES
    ('Hogwarts', 'Hogwarts_Bed_1', 'Basil', 12, 'Summer', NULL, 'Planned', NULL, 'Plant after final frost; reserved for Gryffindor Herbology'),
    ('Hogwarts', 'Hogwarts_Bed_1', 'Lettuce', 8, 'Spring', '2026-03-10', 'Harvested', 'Good', 'Earlier crop in the same bed'),
    ('Hogwarts', 'Greenhouse_Bed_1', 'Tomato', 6, 'Fall', '2026-09-01', 'In-ground', NULL, 'Started indoors before transplanting'),
    ('Sunshine Elementary', 'Sunshine_Bed_1', 'Lettuce', 6, 'Spring', NULL, 'Planned', NULL, 'First classroom crop'),
    ('Green Valley Middle School', 'GreenValley_Channel_1', 'Spinach', 10, 'Fall', '2026-09-15', 'In-ground', 'Good', 'Hydroponic growing cycle'),
    ('Oakwood High School', 'Oakwood_Bed_1', 'Tomato', 8, 'Summer', NULL, 'Planned', NULL, 'Needs trellis support'),
    ('Riverbend Academy', 'Riverbend_Bed_1', 'Marigold', 10, 'Summer', NULL, 'Planned', NULL, 'Pollinator border planting'),
    ('Maple Grove School', 'MapleGrove_Bed_1', 'Carrot', 20, 'Spring', NULL, 'Planned', NULL, 'Direct sowing'),
    ('Pinecrest Elementary', 'Pinecrest_Bed_1', 'Radish', 12, 'Spring', NULL, 'Planned', NULL, 'Short rotation crop'),
    ('Lakeside Middle School', 'Lakeside_Bed_1', 'Cucumber', 4, 'Summer', NULL, 'Planned', NULL, 'Trellis required'),
    ('Cedar Ridge School', 'CedarRidge_Bed_1', 'Cilantro', 10, 'Fall', NULL, 'Planned', NULL, 'Waiting for soil improvement'),
    ('Cedar Ridge School', 'CedarRidge_Bed_1', 'Basil', 6, 'Summer', '2026-05-15', 'Removed', 'Needs Replacement', 'Removed when the soil problem was identified'),
    ('Meadowbrook Academy', 'Meadowbrook_Bed_1', 'Kale', 8, 'Fall', NULL, 'Planned', NULL, 'Use finished compost'),
    ('Willow Creek School', 'WillowCreek_Bed_1', 'Green Bean', 12, 'Fall', '2026-09-10', 'In-ground', 'Good', 'Irrigation demonstration'),
    ('Northside Community School', 'Northside_Bed_1', 'Zucchini', 3, 'Summer', NULL, 'Planned', NULL, 'Community planting day'),
    ('Eastview Academy', 'Eastview_Bed_1', 'Sunflower', 6, 'Summer', '2026-06-01', 'Harvested', 'Fair', 'Previous seasonal planting'),
    ('Westfield School', 'Westfield_Bench_1', 'Pepper', 6, 'Fall', '2026-08-10', 'In-ground', NULL, 'Started indoors');
