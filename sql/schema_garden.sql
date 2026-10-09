-- ============================================================
-- Garden Schema
-- ============================================================


-- ============================================================
-- garden
-- Garden information for each location
-- ============================================================
CREATE TABLE garden (
    garden_id SERIAL PRIMARY KEY,
    location_name VARCHAR(200) NOT NULL,
    garden_name VARCHAR(200) NOT NULL UNIQUE,
    garden_type VARCHAR(100),
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
    bed_name VARCHAR(100) NOT NULL,
    bed_type VARCHAR(50),
    bed_size VARCHAR(100),
    active BOOLEAN NOT NULL DEFAULT TRUE,
    soil_health VARCHAR(50) DEFAULT 'Good',
    notes TEXT,

    CONSTRAINT fk_garden
        FOREIGN KEY (garden_name)
        REFERENCES garden(garden_name)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT uq_garden_bed
    UNIQUE (garden_name, bed_name)
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
    growing_months VARCHAR(100),
    days_to_harvest count,
    notes TEXT,

    CONSTRAINT chk_days_to_harvest
        CHECK (days_to_harvest IS NULL OR days_to_harvest > 0)
);


-- ============================================================
-- CropRotation
-- Planned crops for individual garden beds
-- ============================================================
CREATE TABLE "CropRotation" (
    rotation_id SERIAL PRIMARY KEY,
    garden_name VARCHAR(200) NOT NULL,
    bed_name VARCHAR(100) NOT NULL,
    plant_name VARCHAR(100) NOT NULL,
    season VARCHAR(20),
    planned_planting_date DATE,
    status VARCHAR(50) DEFAULT 'Planned',
    notes TEXT,

    CONSTRAINT fk_rotation_garden
        FOREIGN KEY (garden_name)
        REFERENCES garden(garden_name)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT fk_rotation_garden_bed
        FOREIGN KEY (garden_name, bed_name)
        REFERENCES garden_beds(garden_name, bed_name)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT fk_rotation_plant
        FOREIGN KEY (plant_name)
        REFERENCES plant(plant_name)
        ON UPDATE CASCADE
);


-- ============================================================
-- Garden Functions
-- ============================================================
