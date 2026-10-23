-- ============================================================
-- Garden Schema
-- ============================================================

-- ============================================================
-- CUSTOM
-- Reusable status types
-- ============================================================
CREATE TYPE condition AS ENUM (
    'Good',
    'Require Maintenance',
    'In Maintenance'
);

CREATE TYPE lifecycle_status AS ENUM (
    'Active',
    'Planned',
    'Inactive'
);

CREATE TYPE rotation_status AS ENUM (
    'Planned',
    'In-ground',
    'Removed',
    'Harvested'
);

-- ============================================================
-- garden
-- Garden information for each location
-- ============================================================
CREATE TABLE garden (
    garden_id SERIAL PRIMARY KEY,
    location_name VARCHAR(200) NOT NULL,
    garden_name VARCHAR(200) NOT NULL UNIQUE,
    lifecycle_status lifecycle_status,
    condition condition,
    bed_count nonnegative_count NOT NULL DEFAULT 0,
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
CREATE TABLE garden_bed (
    bed_id SERIAL PRIMARY KEY,
    garden_name VARCHAR(200) NOT NULL,
    bed_name VARCHAR(100) NOT NULL,
    bed_type VARCHAR(50),
    bed_size_sq_ft DECIMAL(10,2),
    lifecycle_status lifecycle_status,
    condition condition,
    is_full BOOLEAN NOT NULL DEFAULT FALSE,
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
    irrigation_name VARCHAR(100),
    irrigation_type VARCHAR(100),
    lifecycle_status lifecycle_status,
    condition condition,
    notes TEXT,

    CONSTRAINT fk_irrigation_garden
        FOREIGN KEY (garden_name)
        REFERENCES garden(garden_name)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);


-- ============================================================
-- compost_unit
-- Composting units used by each garden
-- ============================================================
CREATE TABLE compost_unit (
    compost_unit_id SERIAL PRIMARY KEY,
    garden_name VARCHAR(200) NOT NULL,
    unit_name VARCHAR(100),
    compost_type VARCHAR(100),
    lifecycle_status lifecycle_status,
    condition condition,
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
    growing_period VARCHAR(100),
    days_to_harvest nonnegative_count,
    notes TEXT,

    CONSTRAINT chk_days_to_harvest
        CHECK (days_to_harvest IS NULL OR days_to_harvest > 0)
);


-- ============================================================
-- CropRotation
-- Planned crops for individual garden beds
-- ============================================================
CREATE TABLE crop_rotation (
    rotation_id SERIAL PRIMARY KEY,
    status rotation_status DEFAULT 'Planned',
    garden_name VARCHAR(200) NOT NULL,
    bed_name VARCHAR(100) NOT NULL,
    plant_name VARCHAR(100) NOT NULL,
    quantity nonnegative_count CHECK (quantity > 0),
    season VARCHAR(20),
    sow_date DATE,
    soil_health VARCHAR(50),
    notes TEXT,

    CONSTRAINT fk_rotation_garden
        FOREIGN KEY (garden_name)
        REFERENCES garden(garden_name)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT fk_rotation_garden_bed
        FOREIGN KEY (garden_name, bed_name)
        REFERENCES garden_bed(garden_name, bed_name)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT fk_rotation_plant
        FOREIGN KEY (plant_name)
        REFERENCES plant(plant_name)
        ON UPDATE CASCADE
);


-- ============================================================
-- FUNCTIONS AND TRIGGERS
-- ============================================================


-- ============================================================
-- TRIGGER 1
-- Keep garden.bed_count in sync with the garden_bed rows
-- ============================================================
CREATE OR REPLACE FUNCTION update_garden_bed_count()
RETURNS TRIGGER AS $$
DECLARE
    parent_rows_updated INT;
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE garden
        SET bed_count = bed_count + 1
        WHERE garden_name = NEW.garden_name;
        RETURN NULL;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE garden
        SET bed_count = bed_count - 1
        WHERE garden_name = OLD.garden_name;
        RETURN NULL;
    ELSIF OLD.garden_name IS DISTINCT FROM NEW.garden_name THEN
        UPDATE garden
        SET bed_count = bed_count - 1
        WHERE garden_name = OLD.garden_name;

        GET DIAGNOSTICS parent_rows_updated = ROW_COUNT;

        -- A missing old parent means its name was changed and cascaded;
        -- that parent's bed_count already moved with the garden row.
        IF parent_rows_updated > 0 THEN
            UPDATE garden
            SET bed_count = bed_count + 1
            WHERE garden_name = NEW.garden_name;
        END IF;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_garden_bed_count
AFTER INSERT OR UPDATE OF garden_name OR DELETE
ON garden_bed
FOR EACH ROW
EXECUTE FUNCTION update_garden_bed_count();

