# LCSD Garden Program Database

This is a database project for the Lee County School District garden program that focuses on creating a more organized and centralized way to manage garden-related data. The project is based on the program's current use of Google Sheets and will support areas such as inventory and supplies, garden sizes and components, and growing calendars and crop rotations.

The goal is to improve how information is stored, connected, and accessed so staff can better track available resources, locations, distribution, budgets, and other garden program data over time.

## Setting up a new Supabase project

The project owner sets up the database and Auth integration. Partners do not need Supabase dashboard or organization access; they use an invited Supabase Auth account to sign in to the local app.

In the new project's Supabase dashboard, open **SQL Editor**. Run each SQL file below **one at a time**, in this order:

1. [`sql/schema_garden.sql`](sql/schema_garden.sql)
2. [`sql/schema_inventory.sql`](sql/schema_inventory.sql)
3. [`sql/summary_views.sql`](sql/summary_views.sql)
4. [`sql/demo_data.sql`](sql/demo_data.sql) only if you want its prewritten starter records; skip it if you are loading your own data
5. [`sql/schema_roles.sql`](sql/schema_roles.sql) last, after the tables and views exist

After the SQL files, enable the **Custom Access Token** hook in Supabase Auth using the Postgres function `public.custom_access_token_hook`. Invite the first manager through **Authentication → Users → Add user → Send invitation**, then use the SQL Editor to assign the initial app role. Replace the example email with that invited user's email:

```sql
INSERT INTO private.user_role_assignment (user_id, database_role)
SELECT u.id, 'database_manager'
FROM auth.users AS u
WHERE lower(u.email) = lower('manager@example.com')
ON CONFLICT (user_id)
DO UPDATE SET database_role = EXCLUDED.database_role
RETURNING user_id, database_role;
```

The query should return one row with `database_manager`. The project owner must also enable the Data API for the `public` schema and configure Auth's Site URL and Redirect URLs as `http://localhost:8000/`. Update `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` in `frontend/app.py` with the new project's values, then commit and push that frontend configuration before partners use the GitHub updater. The publishable key may be in the public repository; never put a database password or Supabase secret/service-role key there.

See the [frontend README](frontend/README.md#project-administrator-set-up-a-new-supabase-project) for the full dashboard steps, Auth hook selection, user invitations, and app setup.

## Frontend App

The `frontend` folder contains a Python web app. Each partner downloads the repository ZIP from GitHub (**Code → Download ZIP**), unzips it, and runs the app locally at `http://localhost:8000`. The app is not hosted as a public website. It connects over the internet to the shared Supabase project.

Partners need Python 3.9 or newer, internet access, and an invited Garden Program account. They run `frontend/Run-GardenApp.exe` on Windows or use the PowerShell fallback at `frontend/scripts/Run-GardenApp.ps1`. On macOS/Linux they use the manual Python setup. The app does not need a Supabase database password or connection URI; each person signs in with their own Auth account. See [frontend/README.md](frontend/README.md) for steps.

Changes made in the app affect the shared Supabase records immediately. Requests use the signed-in person's account and Supabase role policies. Frontend updates do not apply database or SQL changes.
# What We Need to Work On

### Inventory & Supplies

Monitor seed stocks, tools, soil, and equipment across all campuses to avoid duplicate purchasing, prevent shortages, and allocate budgets effectively. The program currently has a rudimentary system for inventory management, supply requests, distribution of supplies, and restocking inventory. However, this could use some refinement.

### Garden Sizes & Components

Maintain up-to-date records of physical garden footprints, irrigation setups, composting units, and active bed counts for each school site.

### Growing Calendars & Crop Rotations

Plan planting schedules, manage crop rotations to maintain soil health, and track seasonal variations systematically while ensuring resources are prepared for the various growing cycles.


## Implementation

The garden schema defines shared types, locations, location groups, and garden tables. The inventory schema defines inventory and budget tables. The summary views report on those tables, and `schema_roles.sql` configures database roles and access rules. The new-project section above gives the exact SQL Editor order.

# Current Database Schema

The current inventory schema focuses on the inventory portion of the project(does not include all columns).

```mermaid
erDiagram

    BUDGET o|--o{ PURCHASE_REQUEST : funds

    LOCATION o|--o{ PURCHASE_REQUEST : requesting_school
    LOCATION o|--o{ INVENTORY_TRANSACTION : for_school
    LOCATION_GROUP o|--o{ PURCHASE_REQUEST : requesting_school_group
    LOCATION_GROUP o|--o{ INVENTORY_TRANSACTION : for_school_group
    LOCATION_GROUP ||--o{ GROUP_MEMBERS : has_members
    LOCATION ||--o{ GROUP_MEMBERS : belongs_to
    LOCATION ||--o{ GARDEN : has

    ITEM ||--o{ PURCHASE_REQUEST : requested_item
    ITEM ||--o| INVENTORY_LIST : tracked_in

    INVENTORY_LIST ||--o{ INVENTORY_TRANSACTION : records

    BUDGET {
        int budget_id PK
        varchar budget_name UK
        decimal budget_amount
        decimal remaining_budget
    }

    LOCATION {
        int location_id PK
        varchar location_name
    }

    LOCATION_GROUP {
        int location_group_id PK
        varchar location_group_name UK
    }

    GROUP_MEMBERS {
        varchar location_group_name PK, FK
        varchar location_name PK, FK
    }

    ITEM {
        int item_id PK
        varchar item_name UK
        decimal unit_cost
    }

    INVENTORY_LIST {
        int inventory_id PK
        varchar item_name FK, UK
        int cumulative_asset
        int instock_total
        int reorder_point
    }

    PURCHASE_REQUEST {
        int request_id PK
        varchar requesting_school FK
        varchar requesting_school_group FK
        varchar item_name FK
        varchar budget_name FK
        varchar funding_source
        int quantity_requested
        decimal unit_cost_at_request
        decimal total_cost
        boolean ordered
    }

    INVENTORY_TRANSACTION {
        int transaction_id PK
        date transaction_date
        varchar status
        varchar for_school FK
        varchar for_school_group FK
        varchar item_name FK
        int quantity
    }
```

`LOCATION_GROUP` stores one row per group. `group_members` stores one row per member location, using readable group and location names as foreign keys.

The schema creates the built-in `All HLC Gardens` group and maintains membership for locations where `is_hlc` is `TRUE`, independently of garden status; demo data is not required. Purchase requests and inventory transactions may use one direct location, one location group, or neither for personal use; entering one assignment clears the other. Location and bed records with dependent garden records cannot be deleted.

The current garden schema focuses on the garden portion of the project(does not include all columns).

```mermaid
erDiagram
    LOCATION ||--o{ GARDEN_BED : has
    LOCATION ||--o{ IRRIGATION_SETUP : uses
    LOCATION ||--o{ COMPOST_UNIT : uses
    LOCATION ||--o{ CROP_ROTATION : plans
    GARDEN_BED ||--o{ CROP_ROTATION : schedules
    PLANT ||--o{ CROP_ROTATION : includes

    LOCATION {
        int location_id PK
        varchar location_name UK
        varchar garden_status
        varchar garden_condition
        int bed_count
    }

    GARDEN_BED {
        int bed_id PK
        varchar location_name FK
        varchar bed_name
        decimal bed_size_sq_ft
        varchar lifecycle_status
        varchar condition
    }

    IRRIGATION_SETUP {
        int irrigation_id PK
        varchar location_name FK
        varchar irrigation_name
        varchar irrigation_type
        varchar lifecycle_status
        varchar condition
    }

    COMPOST_UNIT {
        int compost_unit_id PK
        varchar location_name FK
        varchar unit_name
        varchar compost_type
        varchar lifecycle_status
        varchar condition
    }

    PLANT {
        int plant_id PK
        varchar plant_name UK
        varchar plant_type
        int days_to_harvest
    }

    CROP_ROTATION {
        int rotation_id PK
        varchar status
        varchar location_name FK
        varchar bed_name
        varchar plant_name FK
        int quantity
        date sow_date
    }
```

The app authenticates each partner through Supabase Auth. App roles are assigned to Auth users and enforced by the Supabase database policies; see `sql/schema_roles.sql` and the Supabase setup guides.
