# Garden Database Design

This document describes the current PostgreSQL tables, their columns, and the reporting views. The SQL files contain the full definitions, constraints, functions, and triggers.

## Developer note

The current schema uses readable names as foreign keys so relationships are easy to recognize in Supabase's table editor. When a frontend is developed, the schema can be changed to use numeric IDs for foreign-key relationships; the frontend can still display names by joining to the related tables. This would require updating the schema and its dependent functions, views, and application code, but it does not require redesigning the data model.

## Setup order

1. `sql/schema_garden.sql` (shared types, locations, and garden tables)
2. `sql/schema_inventory.sql`
3. `sql/summary_views.sql`
4. `sql/demo_data.sql`
5. `sql/schema_roles.sql` (run last, after all tables, views, and data are loaded)

`schema_roles.sql` is Supabase-specific: it uses Supabase Auth roles and
`auth.users`. Run it in the Supabase SQL Editor as the project database owner.
After it succeeds, enable `public.custom_access_token_hook` as the project's
Custom Access Token Hook in Supabase Auth. Assign the first `database_manager`
in `private.user_role_assignment` from the SQL Editor, replacing the email with
the manager's existing Supabase Auth email:

```sql
INSERT INTO private.user_role_assignment (user_id, database_role)
SELECT id, 'database_manager'
FROM auth.users
WHERE email = 'manager@example.com'
ON CONFLICT (user_id)
DO UPDATE SET database_role = EXCLUDED.database_role;
```

After that, a manager can assign application roles with
`public.set_user_database_role`.

## Application database roles

These are Garden Database data roles, separate from Supabase organization
invitation roles. `sql/schema_roles.sql` creates and configures them in the
project database.

- **`staff`** — Can read, add, and edit operational records. Cannot read budget
  tables or budget-only views, or delete ordinary operational records. Can
  edit or delete purchase requests and inventory transactions only when their
  respective date is today. Rows with a `NULL` or older date cannot be edited
  or deleted. Staff access to purchase-request fields remains limited to the
  fields granted in the roles SQL.
- **`finance_staff`** — Can read, add, and edit records, including budgeting
  information, and can edit or delete budget records. Cannot delete ordinary
  operational records or assign roles. Purchase requests and inventory
  transactions can be edited or deleted only when their respective date is
  today; `NULL` or older dates are not editable or deletable.
- **`database_manager`** — Can read, add, edit, and delete records across the
  public tables and views, including budget data. Can assign supported
  application roles and can correct any purchase-request or inventory
  transaction date.
- **Supabase project administrators** — Manage database setup and schema
  changes through Supabase. They use Supabase's own project access; there is no
  separate `system_admin` or `database_admin` application role. The roles SQL
  grants the application role-assignment function to `database_manager`.

The same-day restriction is based on `request_date` or `transaction_date`, not
the time the record was created. Inventory transaction status changes must be
recorded as a new transaction, as enforced by the inventory trigger.

## Reusable types

- `dollar`: nonnegative monetary amount with two decimal places; defined in the inventory schema.
- `nonnegative_count`: nonnegative integer quantity; defined in the garden schema for shared use.
- `inventory_transaction_status`: `Checked In` or `Checked Out`.
- `purchase_request_status`: Requested, Ordered, Delivered to FNS, or Canceled.
- `condition`: `Good`, `Require Maintenance`, or `In Maintenance`; defined in the garden schema for shared use.
- `lifecycle_status`: `Active`, `Planned`, or `Inactive`; defined in the garden schema for shared use.
- `rotation_status`: `Planned`, `In-ground`, `Removed`, or `Harvested`.
- `soil_health_status`: `Good`, `Fair`, or `Needs Replacement`.

## Tables

### location

Stores schools and program locations. Garden fields are optional, so an office or a school without a tracked garden can leave them empty.

- `location_id`: generated primary key.
- `location_name`: required, unique readable name used by related tables.
- `is_hlc`: whether this location belongs to the Healthy Living Collaboration; controls automatic membership in `All HLC Gardens`.
- `contact`: contact person for the location.
- `email`: contact email address.
- `garden_status`: lifecycle of the location's garden, when one is tracked.
- `garden_condition`: current condition of the location's garden, when one is tracked.
- `bed_count`: number of beds at the location; automatically maintained from garden-bed records, including zero after all beds are removed. It can remain `NULL` before bed tracking begins.
- `notes`: additional location or garden details.

Locations cannot be deleted while they have garden beds, irrigation setups, or compost units. A bed cannot be deleted while crop rotations reference it, which prevents accidental loss of garden records.

### location-group

Stores one readable row for each location group.

- `location_group_id`: generated primary key.
- `location_group_name`: required, unique group name, such as `SchoolBandC`.

### group_members

Connects groups to their member locations. Each row represents one location in one group.

- `location_group_name`: group name referencing `location_group`.
- `location_name`: school or office name referencing `location`.

The schema creates the built-in `All HLC Gardens` group independently of demo data so staff have one reliable group for work applying across every HLC location. Triggers maintain it from `location.is_hlc`: a location inserted with `is_hlc = TRUE` is added automatically, changing the flag to `FALSE` removes it, and creating the group fills it with already-existing HLC locations. The flag is independent of `garden_status`, so an HLC location remains in the group even when its garden is not active or tracked.

`All HLC Gardens` is a live roster, not a snapshot of who belonged to the group when an old request or transaction was created. Requests and transactions assigned to it therefore display the current membership in reports. Do not add or remove its `group_members` rows manually; the schema protects and maintains them. Custom groups, including `18 HLC Gardens` and `19 HLC Gardens`, remain separate and are managed manually.

### budget

Stores the available and remaining amount for each budget.

- `budget_id`: generated primary key.
- `budget_name`: required, unique readable budget name.
- `budget_amount`: total amount available in the budget.
- `remaining_budget`: amount left after ordered purchase requests; recalculated by triggers.
- `notes`: additional budget details.

### item

Catalog of supplies that can be purchased or tracked in inventory.

- `item_id`: generated primary key.
- `item_name`: required, unique item name referenced by requests and inventory records.
- `category`: item category.
- `vendor_name`: vendor or supplier.
- `link`: product or vendor URL.
- `unit_cost`: cost per item, used to calculate purchase-request totals.
- `notes`: additional item details.

### inventory_list

Tracks current stock for catalog items. Each catalog item can have at most one inventory-list row.

- `inventory_id`: generated primary key.
- `item_name`: required item name linked to the item catalog.
- `cumulative_asset`: total quantity acquired into tracked inventory.
- `instock_total`: current quantity available after check-ins and check-outs.
- `reorder_point`: stock level at or below which the item appears on the restock list.
- `counted`: whether the stock has been physically counted.
- `storage_location`: where the stock is kept.
- `notes`: additional inventory details.

### purchase_request

Records requested items, ordering and delivery state, and optional budget and funding-source details.

- `request_id`: generated primary key.
- `request_date`: date the item was requested; defaults to the current date.
- `requested_by`: required name of the requester.
- `requesting_school`: direct location for a single-school request; `NULL` for a group or personal request.
- `requesting_school_group`: group name for a group request; `NULL` for a single-school or personal request.
- `item_name`: required catalog item being requested.
- `unit_cost_at_request`: unit price recorded for this request; defaults to the catalog price when omitted and remains fixed if the catalog price changes.
- `quantity_requested`: required positive quantity.
- `total_cost`: calculated from quantity and the request's unit-price snapshot.
- `status`: Requested, Ordered, Delivered to FNS, or Canceled; defaults to Requested. Ordered and Delivered to FNS count toward spending. Only Delivered to FNS adds stock. Canceled is excluded from pending quantities and spending.
- `review_status`: free-text review or order status.
- `budget_name`: optional budget used for the request.
- `funding_source`: optional funding source text.
- `school_year`: school year associated with the request.
- `notes`: additional request details.

### inventory_transaction

Records inventory check-ins and check-outs. A row may be assigned to one school, one location group, or neither for personal use.

- `transaction_id`: generated primary key.
- `transaction_date`: transaction date; defaults to the current date.
- `status`: required `Checked In` or `Checked Out` status.
- `taken_by`: required name of the person handling the transaction.
- `for_school`: direct location for a single-school transaction; `NULL` for a group or personal transaction.
- `for_school_group`: group name for a group transaction; `NULL` for a single-school or personal transaction.
- `item_name`: required item tracked in inventory.
- `quantity`: required positive transaction quantity.
- `notes`: additional transaction details.

### garden_bed

Stores individual beds for locations. Adding the first bed automatically starts the bed count for that location.

- `bed_id`: generated primary key.
- `location_name`: location that owns the bed.
- `bed_name`: bed name, unique within its location.
- `bed_type`: type of bed.
- `bed_size_sq_ft`: bed area in square feet.
- `lifecycle_status`: whether the bed is active, planned, or inactive.
- `condition`: bed condition.
- `is_full`: whether the bed is full.
- `notes`: additional bed details.

Beds cannot be deleted while crop rotations reference them.

### irrigation_setup

Stores zero or more irrigation systems for each location with garden details.

- `irrigation_id`: generated primary key.
- `location_name`: location that owns the irrigation setup.
- `irrigation_name`: readable name for the setup.
- `irrigation_type`: type of irrigation system.
- `lifecycle_status`: whether the setup is active, planned, or inactive.
- `condition`: current condition of the setup.
- `notes`: additional irrigation details.

### compost_unit

Stores zero or more composting units for each location with garden details.

- `compost_unit_id`: generated primary key.
- `location_name`: location that owns the compost unit.
- `unit_name`: readable name for the unit.
- `compost_type`: type of composting unit.
- `lifecycle_status`: whether the unit is active, planned, or inactive.
- `condition`: current condition of the unit.
- `notes`: additional composting details.

### plant

Catalog of general information about plants. Planting-specific details are stored in crop rotations.

- `plant_id`: generated primary key.
- `plant_name`: required, unique plant name.
- `plant_type`: type of plant.
- `growing_period`: general growing period.
- `days_to_harvest`: expected number of days from sowing to harvest.
- `notes`: additional plant details.

### crop_rotation

Tracks plantings by bed within a location's garden.

- `rotation_id`: generated primary key.
- `status`: planting status; defaults to `Planned`.
- `location_name`: location where the planting is scheduled or growing.
- `bed_name`: bed where the planting is assigned.
- `plant_name`: plant in the rotation.
- `quantity`: number of plants sown or planned.
- `season`: growing season for the planting.
- `sow_date`: date the planting was sown.
- `soil_health`: soil-health assessment for the planting; cleared when status is `Removed`.
- `notes`: additional planting details.

## Using location groups

Use the **Location Groups** and **Group Members** pages under **Locations** to organize schools into groups. Create a custom group in Location Groups, then add one row in Group Members for each school or office that belongs to it. Select the existing group and location for each membership. A group needs at least one member before it can be used on a purchase request or inventory transaction. The group page lets you view its associated schools.

**All HLC Gardens** is maintained automatically from each location's HLC setting. Do not add or remove its membership manually. When a location is marked as HLC, it is included automatically; clearing that setting removes it. This is a live group, so reports show its current members.

When creating or editing a purchase request, choose either a single **Requesting School** or a **Requesting School Group**. For an inventory transaction, choose either a single school or a group in the corresponding assignment fields. Leave both blank when the record is not assigned to a school or group. The form clears the other assignment when you choose one, so a record cannot be assigned to both at once. The requester or handler is recorded separately in **Requested By** or **Taken By**.

The app and database check that selected schools and groups exist. The database also prevents removing a group's last school while purchase requests or inventory transactions still use that group.

## Views

Views provide readable reports without changing the underlying records.

- `RestockList`: identifies inventory items at or below their reorder point.
- `PendingRequests`: lists Requested and Ordered purchases awaiting delivery, showing their status and saved school or group assignment. Delivered to FNS and Canceled requests are excluded.
- `SchoolSupply`: summarizes inventory and purchasing activity in separate rows for each school and each named group. It shows current checked-out items, pending purchase-request counts, and spending. Group totals stay on the group row.
- The School Supply report also provides detailed purchase-request and currently checked-out-item modes for the associated schools and groups.
- `BudgetPurchases`: groups ordered quantities and item spending by budget and item, with budget-level totals.
- `FundingSourceSpending`: groups ordered quantities and spending by funding source and item, with funding-source totals.
- `ItemSpending`: summarizes each item’s non-canceled purchase-request count, ordered quantity, total spending, and average unit cost. Spending totals include ordered and delivered requests.
- `YearlyPurchase`: summarizes ordered and unordered request spending by school year and provides monthly ordered-purchase totals. Dated requests use a readable month and year label; requests without a date appear in a separate `No date` row.
- `CurrentBedPlantings`: shows in-ground and harvested plantings with the associated bed details and estimated harvest date.
- `CropCalendar`: shows planned, current, and past crop rotations with an estimated harvest date.
- `GardenAssets`: lists each bed, irrigation system, and compost unit with its location and lifecycle and condition statuses.
- `PlantCount`: summarizes each plant's current location count, planned quantity, current total quantity (Planned plus In-ground), in-ground quantity, harvested quantity, and removed quantity.

## Functions and triggers

The schema functions and triggers calculate purchase costs and budget balances, update inventory quantities for transactions and delivered requests, maintain garden bed counts, clear soil health for removed crops, and validate group membership references.
