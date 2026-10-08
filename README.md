# LCSD Garden Program Database

This is a database project for the Lee County School District garden program that focuses on creating a more organized and centralized way to manage garden-related data. The project is based on the program's current use of Google Sheets and will support areas such as inventory and supplies, garden sizes and components, and growing calendars and crop rotations.

The goal is to improve how information is stored, connected, and accessed so staff can better track available resources, locations, distribution, budgets, and other garden program data over time.

# What We Need to Work On

### Inventory & Supplies

Monitor seed stocks, tools, soil, and equipment across all campuses to avoid duplicate purchasing, prevent shortages, and allocate budgets effectively. The program currently has a rudimentary system for inventory management, supply requests, distribution of supplies, and restocking inventory. However, this could use some refinement.

### Garden Sizes & Components

Maintain up-to-date records of physical garden footprints, irrigation setups, composting units, and active bed counts for each school site.

### Growing Calendars & Crop Rotations

Plan planting schedules, manage crop rotations to maintain soil health, and track seasonal variations systematically while ensuring resources are prepared for the various growing cycles.


# IMPLEMENTATION
The inventory & Supply + Budget is in the inventory schema.                        
The Garden Sizes & Components + Growing Calendars & Crop Rotations tables are all in the garden schema

# Current Inventory Database Schema

The current database schema focuses on the inventory portion of the project.

```mermaid
erDiagram

    BUDGET ||--o{ PURCHASE_REQUEST : funds

    LOCATION ||--o{ PURCHASE_REQUEST : requests_for
    LOCATION ||--o{ INVENTORY_TRANSACTION : distributed_to

    ITEM ||--o{ PURCHASE_REQUEST : requested_item
    ITEM ||--o| INVENTORY_LIST : tracked_in

    INVENTORY_LIST ||--o{ INVENTORY_TRANSACTION : records

    BUDGET {
        int budget_id PK
        varchar budget_name
        decimal budget_amount
        decimal remaining_budget
    }

    LOCATION {
        int location_id PK
        varchar location_name
    }

    ITEM {
        int item_id PK
        varchar item_name
        varchar category
        varchar vendor_name
        decimal unit_cost
    }

    INVENTORY_LIST {
        int inventory_id PK
        varchar item_name FK
        int cumulative_asset
        int instock_Total
        int reorder_point
        boolean counted
        varchar storage_location
    }

    PURCHASE_REQUEST {
        int request_id PK
        varchar requesting_for FK
        varchar item_name FK
        varchar budget_name FK
        int qty_requested
        decimal total_cost
        boolean ordered
        varchar funding_source
    }

    INVENTORY_TRANSACTION {
        int transaction_id PK
        date date
        varchar for_school FK
        varchar item_name FK
        int quantity_taken
    }
```

```mermaid
erDiagram
    LOCATION ||--o{ GARDEN : contains
    GARDEN ||--o{ GARDEN_BEDS : has
    GARDEN ||--o{ IRRIGATION_SETUP : uses
    GARDEN ||--o{ COMPOSTING_UNITS : uses
    GARDEN ||--o{ GARDEN_RESOURCE : needs
    ITEM ||--o{ GARDEN_RESOURCE : supplies
    GARDEN_BEDS ||--o{ PLANTING : records
    PLANT ||--o{ PLANTING : grows
    GARDEN ||--o{ CROP_ROTATION : plans
    GARDEN_BEDS ||--o{ CROP_ROTATION : schedules
    PLANT ||--o{ CROP_ROTATION : includes

    LOCATION {
        int location_id PK
        varchar location_name
        varchar location_type
        text notes
    }

    GARDEN {
        int garden_id PK
        varchar location_name FK
        varchar garden_name UK
        decimal footprint_sq_ft
        varchar garden_status
        varchar garden_manager
        text notes
    }

    GARDEN_BEDS {
        int bed_id PK
        varchar garden_name FK
        varchar bed_name UK
        varchar bed_type
        varchar bed_size
        boolean active
        varchar soil_health
        text notes
    }

    IRRIGATION_SETUP {
        int irrigation_id PK
        varchar garden_name FK
        varchar irrigation_type
        varchar status
        text notes
    }

    COMPOSTING_UNITS {
        int composting_unit_id PK
        varchar garden_name FK
        varchar composting_type
        varchar status
        text notes
    }

    ITEM {
        int item_id PK
        varchar item_name UK
        varchar category
        dollar unit_cost
    }

    GARDEN_RESOURCE {
        int garden_resource_id PK
        varchar garden_name FK
        varchar item_name FK
        count quantity_needed
        text notes
    }

    PLANT {
        int plant_id PK
        varchar plant_name UK
        varchar plant_type
        count days_to_harvest
        text notes
    }

    PLANTING {
        int planting_id PK
        varchar plant_name FK
        varchar bed_name FK
        date planting_date
        date expected_harvest_date
        varchar school_year
        count quantity
        varchar status
        text notes
    }

    CROP_ROTATION {
        int rotation_id PK
        varchar rotation_name UK
        varchar garden_name FK
        varchar bed_name FK
        varchar plant_name FK
        date planned_planting_date
        varchar status
        text notes
    }
```
    
> Authentication and user tracking are planned for a future stage of the project and are not currently part of the inventory schema.
