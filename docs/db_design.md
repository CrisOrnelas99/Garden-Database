# Garden Database Design

This document describes the current PostgreSQL tables, their columns, and the reporting views. The SQL files contain the full definitions, constraints, functions, and triggers.

## Developer note

The current schema uses readable names as foreign keys so relationships are easy to recognize in Supabase's table editor. When a frontend is developed, the schema can be changed to use numeric IDs for foreign-key relationships; the frontend can still display names by joining to the related tables. This would require updating the schema and its dependent functions, views, and application code, but it does not require redesigning the data model.

## Setup order

1. `sql/schema_inventory.sql`
2. `sql/schema_garden.sql`
3. `sql/summary_views.sql`
4. `sql/demo_data.sql`

## Reusable types

- `dollar`: nonnegative monetary amount with two decimal places.
- `nonnegative_count`: nonnegative integer quantity.
- `inventory_transaction_status`: `Checked In` or `Checked Out`.
- `condition`: `Good`, `Require Maintenance`, or `In Maintenance`.
- `lifecycle_status`: `Active`, `Planned`, or `Inactive`.
- `rotation_status`: `Planned`, `In-ground`, `Removed`, or `Harvested`.
- `soil_health_status`: `Good`, `Fair`, or `Needs Replacement`.

## Tables

### location

Stores schools and program locations. Garden fields are optional, so an office or a school without a tracked garden can leave them empty.

- `location_id`: generated primary key.
- `location_name`: required, unique readable name used by related tables.
- `contact`: contact person for the location.
- `email`: contact email address.
- `lifecycle_status`: lifecycle of the location's garden, when one is tracked.
- `condition`: current condition of the location's garden, when one is tracked.
- `bed_count`: number of beds at the location; maintained from garden-bed records. `NULL` means garden details are not tracked.
- `notes`: additional location or garden details.

### location-group

Stores group headers and their member locations in one self-referencing table. Each row is either a group header or a group member.

- `location_group_id`: generated primary key for the row.
- `location_group_name`: unique group name on a header row, such as `SchoolBandC`; `NULL` on member rows.
- `belongs_to_group`: name of the group this member row belongs to; `NULL` on header rows.
- `location_name`: school or office on a member row; `NULL` on header rows.

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
- `request_date`: date the item was requested.
- `requested_by`: required name of the requester.
- `requesting_school`: direct location for a single-school request; `NULL` for group or unassigned requests.
- `requesting_school_group`: group name for a group request; `NULL` for direct or unassigned requests.
- `item_name`: required catalog item being requested.
- `quantity_requested`: required positive quantity.
- `total_cost`: calculated from quantity and the item's unit cost.
- `delivered_to_fns`: whether the requested item has been delivered to FNS.
- `review_status`: free-text review or order status.
- `ordered`: whether the request has been ordered.
- `budget_name`: optional budget used for the request.
- `funding_source`: optional funding source text.
- `school_year`: school year associated with the request.
- `notes`: additional request details.

### inventory_transaction

Records inventory check-ins and check-outs.

- `transaction_id`: generated primary key.
- `transaction_date`: transaction date; defaults to the current date.
- `status`: required `Checked In` or `Checked Out` status.
- `taken_by`: required name of the person handling the transaction.
- `for_school`: direct location for a single-school transaction; `NULL` for group or unassigned transactions.
- `for_school_group`: group name for a group transaction; `NULL` for direct or unassigned transactions.
- `item_name`: required item tracked in inventory.
- `quantity`: required positive transaction quantity.
- `notes`: additional transaction details.

### garden_bed

Stores individual beds for locations with garden details.

- `bed_id`: generated primary key.
- `location_name`: location that owns the bed.
- `bed_name`: bed name, unique within its location.
- `bed_type`: type of bed.
- `bed_size_sq_ft`: bed area in square feet.
- `lifecycle_status`: whether the bed is active, planned, or inactive.
- `condition`: bed condition.
- `is_full`: whether the bed is full.
- `notes`: additional bed details.

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

In Supabase, add a group header row by filling `location_group_name` and leaving `belongs_to_group` and `location_name` empty. Then add one member row per school: leave `location_group_name` empty and fill `belongs_to_group` with the group's name and `location_name` with the school's existing name. The `location_group_id` is generated automatically.

For example, create `SchoolBandC` and add two schools:

```sql
INSERT INTO "l-location-group" (location_group_name)
VALUES ('SchoolBandC');

INSERT INTO "l-location-group" (belongs_to_group, location_name)
VALUES
    ('SchoolBandC', 'Sunshine Elementary'),
    ('SchoolBandC', 'Green Valley Middle School');
```

For a purchase request, set `requesting_school` for one school or `requesting_school_group` for a group. For an inventory transaction, use `for_school` or `for_school_group` in the same way. The direct-school and group fields cannot both be filled; both may be `NULL` while a record is unassigned. When switching an existing row, clear the current field and set the new one together:

```sql
UPDATE "i-purchase_request"
SET requesting_school = NULL,
    requesting_school_group = 'SchoolBandC'
WHERE request_id = 123;

UPDATE "i-inventory_transaction"
SET for_school = NULL,
    for_school_group = 'SchoolBandC'
WHERE transaction_id = 123;
```

Developers can get a group's schools by joining its header row to its member rows:

```sql
SELECT group_row.location_group_name, member_row.location_name
FROM "l-location-group" AS group_row
JOIN "l-location-group" AS member_row
    ON member_row.belongs_to_group = group_row.location_group_name
WHERE group_row.location_group_name IS NOT NULL;
```

The foreign keys require member rows to use existing school names and valid group names. A referenced group must have at least one school, and the database prevents removing its final school while requests or transactions still reference it.

## Views

Views provide readable reports without changing the underlying records.

- `RestockList`: identifies inventory items at or below their reorder point.
- `PendingRequests`: lists purchase requests that are unordered or not yet delivered, and expands group requests to their member schools.
- `SchoolSupply`: summarizes inventory and purchasing activity in separate rows for each school and each named group. Group totals stay on the group row.
- `BudgetPurchases`: groups ordered quantities and item spending by budget and item, with budget-level totals.
- `FundingSourceSpending`: groups ordered quantities and spending by funding source and item, with funding-source totals.
- `YearlyPurchase`: summarizes ordered and unordered request spending by school year.
- `BedPlanting`: shows in-ground and harvested plantings with the associated bed details and estimated harvest date.
- `CropCalendar`: shows planned, current, and past crop rotations with an estimated harvest date.
- `GardenAssets`: lists each bed, irrigation system, and compost unit with its location and lifecycle and condition statuses.

## Functions and triggers

The schema functions and triggers calculate purchase costs and budget balances, update inventory quantities for transactions and delivered requests, maintain garden bed counts, clear soil health for removed crops, and validate group membership references.
