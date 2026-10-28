-- ============================================================
-- Garden and Shared Schema
-- ============================================================

-- ============================================================
-- SHARED TYPES
-- Used by location, garden, and inventory tables.
-- ============================================================
CREATE DOMAIN nonnegative_count AS INT
    CHECK (VALUE >= 0);

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

CREATE TYPE soil_health_status AS ENUM (
    'Good',
    'Fair',
    'Needs Replacement'
);


-- ============================================================
-- location
-- School/office details and optional garden fields.
-- ============================================================
CREATE TABLE location (
    location_id SERIAL PRIMARY KEY,
    location_name VARCHAR(200) NOT NULL UNIQUE,
    contact VARCHAR(100),
    email VARCHAR(200),
    garden_status lifecycle_status,
    garden_condition condition,
    bed_count nonnegative_count,
    notes TEXT,

    CONSTRAINT chk_location_optional_garden_fields
        CHECK (
            bed_count IS NOT NULL
            OR (
                garden_status IS NULL
                AND garden_condition IS NULL
            )
        )
);


-- ============================================================
-- location_group
-- Group rows store names; member rows point to one group and one location.
-- ============================================================
CREATE TABLE location_group (
    location_group_id SERIAL PRIMARY KEY,
    location_group_name VARCHAR(200) UNIQUE,
    belongs_to_group VARCHAR(200),
    location_name VARCHAR(200),

    CONSTRAINT chk_location_group_row_type
        CHECK (
            (location_group_name IS NOT NULL
                AND belongs_to_group IS NULL
                AND location_name IS NULL)
            OR
            (location_group_name IS NULL
                AND belongs_to_group IS NOT NULL
                AND location_name IS NOT NULL)
        ),

    CONSTRAINT fk_location_group_belongs_to_group
        FOREIGN KEY (belongs_to_group)
        REFERENCES location_group(location_group_name)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT fk_location_group_member_location
        FOREIGN KEY (location_name)
        REFERENCES location(location_name)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT uq_location_group_member
        UNIQUE (belongs_to_group, location_name)
);

-- ============================================================
-- garden_bed
-- Individual garden beds belonging to a location's optional garden
-- ============================================================
CREATE TABLE garden_bed (
    bed_id SERIAL PRIMARY KEY,
    location_name VARCHAR(200) NOT NULL,
    bed_name VARCHAR(100) NOT NULL,
    bed_type VARCHAR(50),
    bed_size_sq_ft DECIMAL(10,2),
    lifecycle_status lifecycle_status,
    condition condition,
    is_full BOOLEAN NOT NULL DEFAULT FALSE,
    notes TEXT,

    CONSTRAINT fk_g_garden_bed_location
        FOREIGN KEY (location_name)
        REFERENCES location(location_name)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT uq_g_garden_bed
    UNIQUE (location_name, bed_name)
);


-- ============================================================
-- irrigation_setup
-- Irrigation systems used by each location's garden
-- ============================================================
CREATE TABLE irrigation_setup (
    irrigation_id SERIAL PRIMARY KEY,
    location_name VARCHAR(200) NOT NULL,
    irrigation_name VARCHAR(100),
    irrigation_type VARCHAR(100),
    lifecycle_status lifecycle_status,
    condition condition,
    notes TEXT,

    CONSTRAINT fk_irrigation_location
        FOREIGN KEY (location_name)
        REFERENCES location(location_name)
        ON UPDATE CASCADE
        ON DELETE CASCADE
);


-- ============================================================
-- compost_unit
-- Composting units used by each location's garden
-- ============================================================
CREATE TABLE compost_unit (
    compost_unit_id SERIAL PRIMARY KEY,
    location_name VARCHAR(200) NOT NULL,
    unit_name VARCHAR(100),
    compost_type VARCHAR(100),
    lifecycle_status lifecycle_status,
    condition condition,
    notes TEXT,

    CONSTRAINT fk_compost_location
        FOREIGN KEY (location_name)
        REFERENCES location(location_name)
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
    location_name VARCHAR(200) NOT NULL,
    bed_name VARCHAR(100) NOT NULL,
    plant_name VARCHAR(100) NOT NULL,
    quantity nonnegative_count CHECK (quantity > 0),
    season VARCHAR(20),
    sow_date DATE,
    soil_health soil_health_status,
    notes TEXT,

    CONSTRAINT fk_rotation_location
        FOREIGN KEY (location_name)
        REFERENCES location(location_name)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT fk_rotation_g_garden_bed
        FOREIGN KEY (location_name, bed_name)
        REFERENCES garden_bed(location_name, bed_name)
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
-- Keep location.bed_count derived from its garden_bed rows
-- ============================================================
CREATE OR REPLACE FUNCTION protect_garden_bed_count()
RETURNS TRIGGER AS $$
DECLARE
    count_for_location VARCHAR(200);
    location_to_check VARCHAR(200);
BEGIN
    IF TG_OP = 'UPDATE' THEN
        location_to_check := OLD.location_name;
    ELSE
        location_to_check := NEW.location_name;
    END IF;

    IF NEW.bed_count IS NULL
       AND NEW.garden_status IS NULL
       AND NEW.garden_condition IS NULL
    THEN
        IF EXISTS (
            SELECT 1 FROM garden_bed WHERE location_name = location_to_check
            UNION ALL
            SELECT 1 FROM irrigation_setup WHERE location_name = location_to_check
            UNION ALL
            SELECT 1 FROM compost_unit WHERE location_name = location_to_check
        ) THEN
            RAISE EXCEPTION
                'Cannot clear garden details for location "%" while garden assets still reference it',
                location_to_check;
        END IF;

        NEW.bed_count := NULL;
        RETURN NEW;
    END IF;

    IF TG_OP = 'UPDATE'
       AND NEW.location_name IS DISTINCT FROM OLD.location_name THEN
        -- Child rows still use the old location name until their foreign keys cascade.
        count_for_location := OLD.location_name;
    ELSE
        count_for_location := NEW.location_name;
    END IF;

    SELECT COUNT(*)::INT
    INTO NEW.bed_count
    FROM garden_bed
    WHERE location_name = count_for_location;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


DROP TRIGGER IF EXISTS trg_protect_garden_bed_count
ON location;

CREATE TRIGGER trg_protect_garden_bed_count
BEFORE INSERT OR UPDATE OF location_name, garden_status, garden_condition, bed_count
ON location
FOR EACH ROW
EXECUTE FUNCTION protect_garden_bed_count();


-- ============================================================
-- TRIGGER 2
-- Keep location.bed_count in sync with the garden_bed rows
-- ============================================================
CREATE OR REPLACE FUNCTION update_garden_bed_count()
RETURNS TRIGGER AS $$
DECLARE
    parent_rows_updated INT;
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE location
        SET bed_count = bed_count + 1
        WHERE location_name = NEW.location_name;
        RETURN NULL;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE location
        SET bed_count = bed_count - 1
        WHERE location_name = OLD.location_name;
        RETURN NULL;
    ELSIF OLD.location_name IS DISTINCT FROM NEW.location_name THEN
        UPDATE location
        SET bed_count = bed_count - 1
        WHERE location_name = OLD.location_name;

        GET DIAGNOSTICS parent_rows_updated = ROW_COUNT;

        -- A missing old parent means its garden name was changed and cascaded;
        -- its bed_count already reflects the existing beds.
        IF parent_rows_updated > 0 THEN
            UPDATE location
            SET bed_count = bed_count + 1
            WHERE location_name = NEW.location_name;
        END IF;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_garden_bed_count
AFTER INSERT OR UPDATE OF location_name OR DELETE
ON garden_bed
FOR EACH ROW
EXECUTE FUNCTION update_garden_bed_count();


-- ============================================================
-- TRIGGER 3
-- Clear crop_rotation.soil_health when a planting is removed
-- ============================================================
CREATE OR REPLACE FUNCTION clear_removed_crop_soil_status()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status = 'Removed' THEN
        NEW.soil_health := NULL;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- Also clear soil health if a crop rotation is inserted as Removed.
CREATE TRIGGER trg_clear_removed_crop_soil_status
BEFORE INSERT OR UPDATE ON crop_rotation
FOR EACH ROW
EXECUTE FUNCTION clear_removed_crop_soil_status();


-- ============================================================
-- TRIGGER 4
-- Require garden-enabled locations for beds, irrigation, compost, and rotations
-- ============================================================
CREATE OR REPLACE FUNCTION require_location_garden()
RETURNS TRIGGER AS $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM location l
        WHERE l.location_name = NEW.location_name
          AND l.bed_count IS NOT NULL
    ) THEN
        RAISE EXCEPTION
            'Location "%" does not have garden details',
            NEW.location_name;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- Require an existing garden-enabled location for each bed.
CREATE TRIGGER trg_require_garden_for_bed
BEFORE INSERT OR UPDATE OF location_name
ON garden_bed
FOR EACH ROW
EXECUTE FUNCTION require_location_garden();

-- Require an existing garden-enabled location for each irrigation setup.
CREATE TRIGGER trg_require_garden_for_irrigation
BEFORE INSERT OR UPDATE OF location_name
ON irrigation_setup
FOR EACH ROW
EXECUTE FUNCTION require_location_garden();

-- Require an existing garden-enabled location for each compost unit.
CREATE TRIGGER trg_require_garden_for_compost
BEFORE INSERT OR UPDATE OF location_name
ON compost_unit
FOR EACH ROW
EXECUTE FUNCTION require_location_garden();

-- Require an existing garden-enabled location for each crop rotation.
CREATE TRIGGER trg_require_garden_for_rotation
BEFORE INSERT OR UPDATE OF location_name
ON crop_rotation
FOR EACH ROW
EXECUTE FUNCTION require_location_garden();


-- Reconcile any existing counts with the actual garden_bed rows.
UPDATE location l
SET bed_count = (
    SELECT COUNT(*)::INT
    FROM garden_bed b
    WHERE b.location_name = l.location_name
)
WHERE l.bed_count IS NOT NULL
  AND l.bed_count IS DISTINCT FROM (
      SELECT COUNT(*)::INT
      FROM garden_bed b
      WHERE b.location_name = l.location_name
  );
