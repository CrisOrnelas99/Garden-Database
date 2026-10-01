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
    location_name VARCHAR(50) NOT NULL UNIQUE,
    notes TEXT
);


-- ============================================================
-- team_member
-- ============================================================

CREATE TABLE team_member (
    team_member_id SERIAL PRIMARY KEY,
    team_member_name VARCHAR(50) NOT NULL UNIQUE,
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

    name VARCHAR(50) NOT NULL UNIQUE,

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

    item_name VARCHAR(50) NOT NULL UNIQUE,

    cumulative_asset count NOT NULL DEFAULT 0,

    "instock_Total" count NOT NULL DEFAULT 0,

    reorder_point count,

    counted BOOLEAN NOT NULL DEFAULT FALSE,

    storage_location VARCHAR(50),

    notes TEXT,

    CONSTRAINT fk_inventory_item
        FOREIGN KEY (item_name)
        REFERENCES item(name)
        ON UPDATE CASCADE
);


-- ============================================================
-- PurchaseRequest
-- One overall purchase request
-- ============================================================

CREATE TABLE "PurchaseRequest" (
    request_id SERIAL PRIMARY KEY,

    requested_by VARCHAR(50) NOT NULL,

    requesting_for VARCHAR(50),

    school_year VARCHAR(9),

    notes TEXT,

    total_cost dollar NOT NULL DEFAULT 0,

    funding_source VARCHAR(50),

    CONSTRAINT fk_purchase_request_requested_by
        FOREIGN KEY (requested_by)
        REFERENCES team_member(team_member_name)
        ON UPDATE CASCADE,

    CONSTRAINT fk_purchase_request_requesting_for
        FOREIGN KEY (requesting_for)
        REFERENCES location(location_name)
        ON UPDATE CASCADE
);


-- ============================================================
-- PurchaseItem
-- Individual items belonging to a PurchaseRequest
-- ============================================================

CREATE TABLE "PurchaseItem" (
    purchase_item_id SERIAL PRIMARY KEY,

    request_id INT NOT NULL,

    item_name VARCHAR(50) NOT NULL,

    qty_requested count NOT NULL
        CHECK (qty_requested > 0),

    total_cost dollar NOT NULL DEFAULT 0,

    delivered_to_fns BOOLEAN NOT NULL DEFAULT FALSE,

    review_status TEXT,

    ordered BOOLEAN NOT NULL DEFAULT FALSE,

    notes TEXT,

    CONSTRAINT fk_purchase_item_request
        FOREIGN KEY (request_id)
        REFERENCES "PurchaseRequest"(request_id)
        ON DELETE CASCADE,

    CONSTRAINT fk_purchase_item_item
        FOREIGN KEY (item_name)
        REFERENCES item(name)
        ON UPDATE CASCADE
);


-- ============================================================
-- BudgetExpense
-- Items actually charged against a budget
-- ============================================================

CREATE TABLE "BudgetExpense" (
    budget_expense_id SERIAL PRIMARY KEY,

    location VARCHAR(50),

    budget_name VARCHAR(50) NOT NULL,

    team_member_name VARCHAR(50),

    item_name VARCHAR(50) NOT NULL,

    quantity count NOT NULL
        CHECK (quantity > 0),

    total_cost dollar NOT NULL DEFAULT 0,

    notes TEXT,

    CONSTRAINT fk_budget_expense_location
        FOREIGN KEY (location)
        REFERENCES location(location_name)
        ON UPDATE CASCADE,

    CONSTRAINT fk_budget_expense_budget
        FOREIGN KEY (budget_name)
        REFERENCES budget(budget_name)
        ON UPDATE CASCADE,

    CONSTRAINT fk_budget_expense_team_member
        FOREIGN KEY (team_member_name)
        REFERENCES team_member(team_member_name)
        ON UPDATE CASCADE,

    CONSTRAINT fk_budget_expense_item
        FOREIGN KEY (item_name)
        REFERENCES item(name)
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

    for_school VARCHAR(50),

    item_name VARCHAR(50) NOT NULL,

    quantity_taken count NOT NULL
        CHECK (quantity_taken > 0),

    notes TEXT,

    CONSTRAINT fk_inventory_transaction_taken_by
        FOREIGN KEY (taken_by)
        REFERENCES team_member(team_member_name)
        ON UPDATE CASCADE,

    CONSTRAINT fk_inventory_transaction_school
        FOREIGN KEY (for_school)
        REFERENCES location(location_name)
        ON UPDATE CASCADE,

    CONSTRAINT fk_inventory_transaction_item
        FOREIGN KEY (item_name)
        REFERENCES "InventoryList"(item_name)
        ON UPDATE CASCADE
);
