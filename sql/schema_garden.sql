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
    is_hlc BOOLEAN NOT NULL DEFAULT FALSE,
    garden_status lifecycle_status,
    garden_condition condition,
    bed_count nonnegative_count,
    notes TEXT,

    CONSTRAINT chk_location_optional_garden_fields
        CHECK (
            (
                bed_count IS NULL
                AND garden_status IS NULL
                AND garden_condition IS NULL
            )
            OR (
                bed_count IS NOT NULL
                AND garden_status IS NOT NULL
            )
        )
);


-- ============================================================
-- location_group
-- One readable header row per group.
-- ============================================================
CREATE TABLE location_group (
    location_group_id SERIAL PRIMARY KEY,
    location_group_name VARCHAR(200) NOT NULL UNIQUE
);


-- ============================================================
-- group_location
-- One row for each location assigned to a group.
-- ============================================================
CREATE TABLE group_location (
    location_group_name VARCHAR(200) NOT NULL,
    location_name VARCHAR(200) NOT NULL,

    CONSTRAINT pk_group_location
        PRIMARY KEY (location_group_name, location_name),

    CONSTRAINT fk_group_location_group
        FOREIGN KEY (location_group_name)
        REFERENCES location_group(location_group_name)
        ON UPDATE CASCADE
        ON DELETE CASCADE,

    CONSTRAINT fk_group_location_location
        FOREIGN KEY (location_name)
        REFERENCES location(location_name)
        ON UPDATE CASCADE
        ON DELETE CASCADE
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
        ON DELETE RESTRICT,

    CONSTRAINT uq_g_garden_bed
    UNIQUE (location_name, bed_name),

    CONSTRAINT chk_garden_bed_size_nonnegative
        CHECK (bed_size_sq_ft IS NULL OR bed_size_sq_ft >= 0)
);


-- ============================================================
-- irrigation_setup
-- Irrigation systems used by each location's garden
-- ============================================================
CREATE TABLE irrigation_setup (
    irrigation_id SERIAL PRIMARY KEY,
    location_name VARCHAR(200) NOT NULL,
    irrigation_name VARCHAR(100) NOT NULL,
    irrigation_type VARCHAR(100),
    lifecycle_status lifecycle_status,
    condition condition,
    notes TEXT,

    CONSTRAINT chk_irrigation_name_not_blank
        CHECK (BTRIM(irrigation_name) <> ''),

    CONSTRAINT fk_irrigation_location
        FOREIGN KEY (location_name)
        REFERENCES location(location_name)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
);

CREATE UNIQUE INDEX uq_irrigation_location_name_ci
    ON irrigation_setup (location_name, LOWER(BTRIM(irrigation_name)));


-- ============================================================
-- compost_unit
-- Composting units used by each location's garden
-- ============================================================
CREATE TABLE compost_unit (
    compost_unit_id SERIAL PRIMARY KEY,
    location_name VARCHAR(200) NOT NULL,
    unit_name VARCHAR(100) NOT NULL,
    compost_type VARCHAR(100),
    lifecycle_status lifecycle_status,
    condition condition,
    notes TEXT,

    CONSTRAINT chk_compost_unit_name_not_blank
        CHECK (BTRIM(unit_name) <> ''),

    CONSTRAINT fk_compost_location
        FOREIGN KEY (location_name)
        REFERENCES location(location_name)
        ON UPDATE CASCADE
        ON DELETE RESTRICT
);

CREATE UNIQUE INDEX uq_compost_location_unit_name_ci
    ON compost_unit (location_name, LOWER(BTRIM(unit_name)));


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
        ON DELETE RESTRICT,

    CONSTRAINT fk_rotation_g_garden_bed
        FOREIGN KEY (location_name, bed_name)
        REFERENCES garden_bed(location_name, bed_name)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

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


-- Prevent assigning or moving a crop rotation to a bed that is not active.
CREATE OR REPLACE FUNCTION require_active_bed_for_rotation()
RETURNS TRIGGER AS $$
DECLARE
    bed_lifecycle_status lifecycle_status;
BEGIN
    -- Allow FK cascades (for example, renaming a location or bed) to preserve
    -- existing crop-rotation references without revalidating their assignment.
    IF pg_trigger_depth() > 1 THEN
        RETURN NEW;
    END IF;

    SELECT lifecycle_status
    INTO bed_lifecycle_status
    FROM garden_bed
    WHERE location_name = NEW.location_name
      AND bed_name = NEW.bed_name;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            'Garden bed "%" at location "%" does not exist.',
            NEW.bed_name, NEW.location_name;
    END IF;

    IF bed_lifecycle_status IS DISTINCT FROM 'Active' THEN
        RAISE EXCEPTION
            'Cannot assign a crop rotation to bed "%" at location "%" because its lifecycle status is "%". Set the bed lifecycle status to Active first.',
            NEW.bed_name, NEW.location_name, bed_lifecycle_status;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_require_active_bed_for_rotation
BEFORE INSERT OR UPDATE OF location_name, bed_name, plant_name
ON crop_rotation
FOR EACH ROW
EXECUTE FUNCTION require_active_bed_for_rotation();


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


-- ============================================================
-- TRIGGERS 5 AND 6
-- Keep All HLC Gardens membership synchronized with HLC locations.
-- ============================================================
CREATE OR REPLACE FUNCTION sync_all_hlc_gardens_group()
RETURNS TRIGGER AS $$
BEGIN
    IF TG_TABLE_NAME = 'location' THEN
        IF NEW.is_hlc THEN
            INSERT INTO group_location (location_group_name, location_name)
            SELECT 'All HLC Gardens', NEW.location_name
            FROM location_group
            WHERE location_group_name = 'All HLC Gardens'
            ON CONFLICT (location_group_name, location_name) DO NOTHING;
        END IF;
    ELSIF TG_TABLE_NAME = 'location_group' THEN
        IF NEW.location_group_name = 'All HLC Gardens' THEN
            INSERT INTO group_location (location_group_name, location_name)
            SELECT NEW.location_group_name, l.location_name
            FROM location l
            WHERE l.is_hlc
            ON CONFLICT (location_group_name, location_name) DO NOTHING;
        END IF;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Add new HLC locations to the built-in group.
CREATE TRIGGER trg_add_location_to_all_hlc_gardens
AFTER INSERT ON location
FOR EACH ROW
EXECUTE FUNCTION sync_all_hlc_gardens_group();

-- Populate All HLC Gardens when created or renamed to its reserved name.
CREATE TRIGGER trg_populate_all_hlc_gardens_group
AFTER INSERT OR UPDATE OF location_group_name
ON location_group
FOR EACH ROW
EXECUTE FUNCTION sync_all_hlc_gardens_group();

-- ============================================================
-- TRIGGER 7
-- Keep All HLC Gardens membership aligned with is_hlc.
-- ============================================================
CREATE OR REPLACE FUNCTION sync_all_hlc_gardens_location_status()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.is_hlc THEN
        INSERT INTO group_location (location_group_name, location_name)
        SELECT 'All HLC Gardens', NEW.location_name
        FROM location_group
        WHERE location_group_name = 'All HLC Gardens'
        ON CONFLICT (location_group_name, location_name) DO NOTHING;
    ELSE
        DELETE FROM group_location
        WHERE location_group_name = 'All HLC Gardens'
          AND location_name = NEW.location_name;
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_sync_all_hlc_gardens_location_status
AFTER UPDATE OF is_hlc
ON location
FOR EACH ROW
WHEN (OLD.is_hlc IS DISTINCT FROM NEW.is_hlc)
EXECUTE FUNCTION sync_all_hlc_gardens_location_status();

-- Protect the built-in group from accidental deletion or rename.
CREATE OR REPLACE FUNCTION protect_all_hlc_gardens_group()
RETURNS TRIGGER AS $$
BEGIN
    IF OLD.location_group_name = 'All HLC Gardens' THEN
        IF TG_OP = 'DELETE' THEN
            RAISE EXCEPTION
                'The built-in All HLC Gardens group cannot be deleted or renamed.';
        ELSIF NEW.location_group_name IS DISTINCT FROM OLD.location_group_name THEN
            RAISE EXCEPTION
                'The built-in All HLC Gardens group cannot be deleted or renamed.';
        END IF;
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ============================================================
-- TRIGGER 8
-- Keep the built-in group available independently of demo data.
-- ============================================================
CREATE TRIGGER trg_protect_all_hlc_gardens_group
BEFORE DELETE OR UPDATE OF location_group_name
ON location_group
FOR EACH ROW
EXECUTE FUNCTION protect_all_hlc_gardens_group();

-- ============================================================
-- TRIGGER 9
-- Prevent direct edits to automatically maintained All HLC Gardens membership.
-- Nested changes from location/status triggers and FK cascades remain allowed.
-- ============================================================
CREATE OR REPLACE FUNCTION protect_all_hlc_gardens_membership()
RETURNS TRIGGER AS $$
DECLARE
    membership_group_name VARCHAR(200);
BEGIN
    IF TG_OP = 'INSERT' THEN
        membership_group_name := NEW.location_group_name;
    ELSIF TG_OP = 'UPDATE' THEN
        IF OLD.location_group_name = 'All HLC Gardens'
           OR NEW.location_group_name = 'All HLC Gardens' THEN
            membership_group_name := 'All HLC Gardens';
        ELSE
            RETURN NEW;
        END IF;
    ELSE
        membership_group_name := OLD.location_group_name;
    END IF;

    IF membership_group_name = 'All HLC Gardens'
       AND pg_trigger_depth() = 1 THEN
        RAISE EXCEPTION
            'Membership in All HLC Gardens is maintained automatically from is_hlc and cannot be edited directly.';
    END IF;

    IF TG_OP = 'DELETE' THEN
        RETURN OLD;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_protect_all_hlc_gardens_membership
BEFORE INSERT OR UPDATE OR DELETE
ON group_location
FOR EACH ROW
EXECUTE FUNCTION protect_all_hlc_gardens_membership();

-- Create the built-in group independently of demo data.
INSERT INTO location_group (location_group_name)
VALUES ('All HLC Gardens')
ON CONFLICT (location_group_name) DO NOTHING;
