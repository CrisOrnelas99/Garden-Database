-- ============================================================
-- Garden and Planting Schema
-- ============================================================


-- ============================================================
-- garden
-- Garden information for each location
-- ============================================================

CREATE TABLE garden (
    garden_id SERIAL PRIMARY KEY,
    location_name VARCHAR(200) NOT NULL,
    garden_name VARCHAR(200) NOT NULL UNIQUE,
    footprint_sq_ft DECIMAL(10,2),
    garden_status VARCHAR(50),
    garden_manager VARCHAR(100),
    notes TEXT,

    CONSTRAINT fk_garden_location
        FOREIGN KEY (location_name)
        REFERENCES location(location_name)
        ON UPDATE CASCADE
);


-- ============================================================
-- garden_beds
-- Individual garden beds belonging to a garden
-- ============================================================

CREATE TABLE garden_beds (
    bed_id SERIAL PRIMARY KEY,
    garden_name VARCHAR(200) NOT NULL,
    bed_name VARCHAR(100) NOT NULL UNIQUE,
    bed_type VARCHAR(50),
    bed_size VARCHAR(100),
    active BOOLEAN NOT NULL DEFAULT TRUE,
    soil_health VARCHAR(50) DEFAULT 'Good',
    notes TEXT,

    CONSTRAINT fk_garden
        FOREIGN KEY (garden_name)
        REFERENCES garden(garden_name)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);


-- ============================================================
-- irrigation_setup
-- Irrigation systems used by each garden
-- ============================================================

CREATE TABLE irrigation_setup (
    irrigation_id SERIAL PRIMARY KEY,
    garden_name VARCHAR(200) NOT NULL,
    irrigation_type VARCHAR(100),
    status VARCHAR(50),
    notes TEXT,

    CONSTRAINT fk_irrigation_garden
        FOREIGN KEY (garden_name)
        REFERENCES garden(garden_name)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);


-- ============================================================
-- composting_units
-- Composting units used by each garden
-- ============================================================

CREATE TABLE composting_units (
    composting_unit_id SERIAL PRIMARY KEY,
    garden_name VARCHAR(200) NOT NULL,
    composting_type VARCHAR(100),
    status VARCHAR(50),
    notes TEXT,

    CONSTRAINT fk_composting_garden
        FOREIGN KEY (garden_name)
        REFERENCES garden(garden_name)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);


-- ============================================================
-- plant
-- Plant catalog / master plant information
-- ============================================================

CREATE TABLE plant (
    plant_id SERIAL PRIMARY KEY,
    plant_name VARCHAR(100) NOT NULL UNIQUE,
    plant_type VARCHAR(50),
    days_to_harvest INT,
    notes TEXT,

    CONSTRAINT chk_days_to_harvest
        CHECK (days_to_harvest IS NULL OR days_to_harvest > 0)
);


-- ============================================================
-- planting
-- Records plants being grown in individual garden beds
-- ============================================================

CREATE TABLE planting (
    planting_id SERIAL PRIMARY KEY,
    plant_name VARCHAR(100) NOT NULL,
    bed_name VARCHAR(100) NOT NULL,
    planting_date DATE,
    expected_harvest_date DATE,
    school_year VARCHAR(20),
    quantity INT,
    status VARCHAR(50),
    notes TEXT,

    CONSTRAINT fk_planting_plant
        FOREIGN KEY (plant_name)
        REFERENCES plant(plant_name)
        ON UPDATE CASCADE,
    CONSTRAINT fk_planting_bed
        FOREIGN KEY (bed_name)
        REFERENCES garden_beds(bed_name)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT chk_planting_quantity
        CHECK (quantity IS NULL OR quantity > 0)
);


-- ============================================================
-- garden_resource
-- Resources needed for each garden
-- ============================================================

CREATE TABLE garden_resource (
    garden_resource_id SERIAL PRIMARY KEY,
    garden_name VARCHAR(200) NOT NULL,
    item_name VARCHAR(200) NOT NULL,
    quantity_needed INT NOT NULL,
    notes TEXT,

    CONSTRAINT fk_garden_resource_garden
        FOREIGN KEY (garden_name)
        REFERENCES garden(garden_name)
        ON UPDATE CASCADE
        ON DELETE CASCADE,
    CONSTRAINT fk_garden_resource_item
        FOREIGN KEY (item_name)
        REFERENCES item(item_name)
        ON UPDATE CASCADE,
    CONSTRAINT uq_garden_resource
        UNIQUE (garden_name, item_name),
    CONSTRAINT chk_garden_resource_quantity
        CHECK (quantity_needed > 0)
);


-- ============================================================
-- CropRotation
-- Planned crops for individual garden beds
-- ============================================================

CREATE TABLE "CropRotation" (
    rotation_id SERIAL PRIMARY KEY,
    rotation_name VARCHAR(200) NOT NULL UNIQUE,
    garden_name VARCHAR(200) NOT NULL,
    bed_name VARCHAR(100) NOT NULL,
    plant_name VARCHAR(100) NOT NULL,
    planned_planting_date DATE,
    status VARCHAR(50) DEFAULT 'Planned',
    notes TEXT,

    CONSTRAINT fk_rotation_garden
        FOREIGN KEY (garden_name)
        REFERENCES garden(garden_name)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT fk_rotation_bed
        FOREIGN KEY (bed_name)
        REFERENCES garden_beds(bed_name)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT fk_rotation_plant
        FOREIGN KEY (plant_name)
        REFERENCES plant(plant_name)
        ON UPDATE CASCADE
);
