# LCSD Garden Program Database

This is a database project for the Lee County School District garden program that focuses on creating a more organized and centralized way to manage garden-related data. The project is based on the program's current use of Google Sheets and will support areas such as inventory and supplies, garden sizes and components, and growing calendars and crop rotations.

The goal is to improve how information is stored, connected, and accessed so staff can better track available resources, locations, distribution, budgets, and other garden program data over time.

## Setting up a new Supabase project

The project owner sets up the database and Auth integration. Users do not need Supabase dashboard or organization access; they use an invited Supabase Auth account to sign in to the local app.

If you are a regular app user and your project manager is handling the Supabase setup, skip this section and go to the [frontend README](frontend/README.md) for instructions on installing and using the app.

Open the [Supabase dashboard](https://supabase.com/dashboard) to create or select the organization and project.

Regular app users should **not** be added to the Supabase organization. A manager invites them through Supabase Auth, and they use the app; the head Garden Program manager oversees Supabase.

In **Organization Settings → Team**, invite only people who manage or develop the Supabase project. Keep an organization-controlled account as **Owner** for long-term ownership and recovery. Give the head manager **Administrator** and database or frontend developers **Developer**. Owners have full access; Administrators can manage projects but cannot change organization settings, transfer projects, or add Owners; Developers can change project content, including database content, but not project settings. See Supabase's [access control documentation](https://supabase.com/docs/guides/platform/access-control).

Before configuring the Auth hook, set the password requirements in **Authentication → Sign In / Providers → Email**: require at least 8 characters, including lowercase and uppercase letters, a number, and a symbol.

In the new project's Supabase dashboard, open **SQL Editor**. Run each SQL file below **one at a time**, in this order:

1. [`sql/schema_garden.sql`](sql/schema_garden.sql)
2. [`sql/schema_inventory.sql`](sql/schema_inventory.sql)
3. [`sql/summary_views.sql`](sql/summary_views.sql)
4. [`sql/demo_data.sql`](sql/demo_data.sql) for demo purposes if you want to try the app with sample records; skip it if you plan to import your own data
5. [`sql/roles_and_permissions.sql`](sql/roles_and_permissions.sql) last, after the tables and views exist

If you are setting up a different Supabase project yourself, copy its **Project URL** from **Project Settings → Integrations → Data API** and its **Publishable key** from **Project Settings → API Keys**. Put the base Project URL (for example, `https://<project-ref>.supabase.co`, without `/rest/v1/`) in `SUPABASE_URL` and the Publishable key in `SUPABASE_PUBLISHABLE_KEY` in `frontend/app.py`. The URL tells the app which Supabase project to use for sign-in and database requests. Skip this configuration if the developer is setting up the project with you; otherwise, commit and push it before users download or update the app from GitHub. The Publishable key can be public, but never put a database password or `secret`/`service_role` key in the frontend or repository.

After the SQL files, open **Authentication → Auth Hooks → Add Hook** in Supabase. Choose **Custom Access Token**, set **Hook Type** to **Postgres** (not HTTPS), select schema **`public`** and function **`custom_access_token_hook`**, then save the hook. When Supabase issues a user's sign-in token, this hook adds that user's assigned app role to it so the database can apply the correct permissions.

Invite the first manager through **Authentication → Users → Add user → Send invitation**, then use the SQL Editor to assign the initial app role. Replace the example email with that invited user's email:

```sql
INSERT INTO private.user_role_assignment (user_id, database_role)
SELECT u.id, 'database_manager'
FROM auth.users AS u
WHERE lower(u.email) = lower('manager@example.com')
ON CONFLICT (user_id)
DO UPDATE SET database_role = EXCLUDED.database_role
RETURNING user_id, database_role;
```

The query should return one row with `database_manager`.

Go to **Project Settings → Integrations → Data API** and enable the Data API. Then go to **Authentication → URL Configuration** and set the **Site URL** and **Redirect URLs** to `http://localhost:8000/` so invitation and password-reset links return to the local app.


## Frontend App

The `frontend` folder contains a Python web app that runs on each user's computer at `http://localhost:8000`. Each user needs to download this GitHub repository onto their device and run the app from its `frontend` folder. The app is not a public website; it connects over the internet to the shared Supabase project.

Its role-based interface gives each user the appropriate tools to manage Garden Program information. The head project manager and other Supabase organization members can also work directly in the Supabase dashboard when needed, but the frontend is the recommended place for day-to-day garden database work. Users need Python 3.9 or newer, internet access, and an invited Garden Program account with an app role assigned by a database manager.

For full installation, sign-in, and troubleshooting instructions, see the [frontend README](frontend/README.md).
# Project

### Inventory & Supplies

Monitor seed stocks, tools, soil, and equipment across all campuses to avoid duplicate purchasing, prevent shortages, and allocate budgets effectively. The program currently has a rudimentary system for inventory management, supply requests, distribution of supplies, and restocking inventory. However, this could use some refinement.

### Garden Sizes & Components

Maintain up-to-date records of physical garden footprints, irrigation setups, composting units, and active bed counts for each school site.

### Growing Calendars & Crop Rotations

Plan planting schedules, manage crop rotations to maintain soil health, and track seasonal variations systematically while ensuring resources are prepared for the various growing cycles.


## Implementation

The garden schema defines shared types, locations, location groups, and garden tables. The inventory schema defines inventory and budget tables. The summary views report on those tables, and `roles_and_permissions.sql` configures roles, permissions, user display names, and audit logging. The new-project section above gives the exact SQL Editor order.

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

The app authenticates each user through Supabase Auth. App roles are assigned to Auth users and enforced by the Supabase database policies; see `sql/roles_and_permissions.sql` and the Supabase setup guides.
