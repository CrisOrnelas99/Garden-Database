-- ============================================================
-- Inventory Schema
-- ============================================================


-- ============================================================
-- CUSTOM DOMAINS
-- Reusable data types and constraints
-- ============================================================

CREATE DOMAIN dollar AS DECIMAL(12,2)
    CHECK (VALUE >= 0);

CREATE DOMAIN count AS INT
    CHECK (VALUE >= 0);


-- ============================================================
-- location
-- ============================================================

CREATE TABLE location (
    location_id SERIAL PRIMARY KEY,

    location_name VARCHAR(200) NOT NULL UNIQUE,

    notes TEXT
);


-- ============================================================
-- budget
-- ============================================================

CREATE TABLE budget (
    budget_id SERIAL PRIMARY KEY,

    budget_name VARCHAR(50) NOT NULL UNIQUE,

    budget_amount dollar NOT NULL,

    -- Can become negative if expenses exceed budget
    remaining_budget DECIMAL(12,2),

    notes TEXT
);


-- ============================================================
-- item
-- Item catalog / master item information
-- ============================================================

CREATE TABLE item (
    item_id SERIAL PRIMARY KEY,

    category VARCHAR(50),

    item_name VARCHAR(200) NOT NULL UNIQUE,

    vendor_name VARCHAR(50),

    quote_link TEXT,

    unit_cost dollar,

    notes TEXT
);


-- ============================================================
-- InventoryList
-- Actual items currently tracked in inventory
-- ============================================================

CREATE TABLE "InventoryList" (
    inventory_id SERIAL PRIMARY KEY,

    item_name VARCHAR(200) NOT NULL UNIQUE,

    cumulative_asset count NOT NULL DEFAULT 0,

    "instock_Total" count NOT NULL DEFAULT 0,

    reorder_point count,

    counted BOOLEAN NOT NULL DEFAULT FALSE,

    storage_location VARCHAR(200),

    notes TEXT,

    CONSTRAINT fk_inventory_item
        FOREIGN KEY (item_name)
        REFERENCES item(item_name)
        ON UPDATE CASCADE
);


-- ============================================================
-- PurchaseRequest
-- Purchase requests and their assigned budget
-- ============================================================

CREATE TABLE "PurchaseRequest" (
    request_id SERIAL PRIMARY KEY,

    school_year VARCHAR(9),

    requested_by VARCHAR(50) NOT NULL,

    requesting_for VARCHAR(200),

    item_name VARCHAR(200) NOT NULL,

    qty_requested count NOT NULL
        CHECK (qty_requested > 0),

    total_cost dollar NOT NULL DEFAULT 0,

    delivered_to_fns BOOLEAN NOT NULL DEFAULT FALSE,

    review_status TEXT,

    ordered BOOLEAN NOT NULL DEFAULT FALSE,

    budget_name VARCHAR(50),

    funding_source VARCHAR(50),

    notes TEXT,

    CONSTRAINT fk_purchase_request_requesting_for
        FOREIGN KEY (requesting_for)
        REFERENCES location(location_name)
        ON UPDATE CASCADE,

    CONSTRAINT fk_purchase_request_item
        FOREIGN KEY (item_name)
        REFERENCES item(item_name)
        ON UPDATE CASCADE,

    CONSTRAINT fk_purchase_request_budget
        FOREIGN KEY (budget_name)
        REFERENCES budget(budget_name)
        ON UPDATE CASCADE
);


-- ============================================================
-- InventoryTransaction
-- Records inventory being taken from InventoryList
-- ============================================================

CREATE TABLE "InventoryTransaction" (
    transaction_id SERIAL PRIMARY KEY,

    date DATE DEFAULT CURRENT_DATE,

    taken_by VARCHAR(50) NOT NULL,

    for_school VARCHAR(200),

    item_name VARCHAR(200) NOT NULL,

    quantity_taken count NOT NULL
        CHECK (quantity_taken > 0),

    notes TEXT,

    CONSTRAINT fk_inventory_transaction_school
        FOREIGN KEY (for_school)
        REFERENCES location(location_name)
        ON UPDATE CASCADE,

    CONSTRAINT fk_inventory_transaction_item
        FOREIGN KEY (item_name)
        REFERENCES "InventoryList"(item_name)
        ON UPDATE CASCADE
);
