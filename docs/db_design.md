# Garden Database Design

This document summarizes the current database implementation for inventory,
garden management, planting schedules, and crop rotations. It is a working
design document that can be refined as the community partner provides more
details.

## Current Implementation

The current database is built in PostgreSQL using Supabase and covers
**Inventory & Supplies**, **Garden Sizes & Components**, and
**Growing Calendars & Crop Rotations**.

### Current Schema Files

```text
sql/
├── inventory_schema.sql
├── garden_schema.sql
└── demo_data.sql
├── summary_view.sql
```

The inventory and garden schemas are currently implemented.

### Custom Domains

The inventory schema uses reusable PostgreSQL domains:

- `dollar` — `DECIMAL(12,2)` values that cannot be negative.
- `count` — integer values that cannot be negative.

## Inventory Schema

### `location`

Stores school or program locations that can be referenced throughout the
database.

Information:

- Location ID
- Location name
- location type
- Notes

### `budget`

Stores available budgets and their remaining balances.

Information:

- Budget ID
- Budget name
- Budget amount
- Remaining budget
- Notes

### `item`

Acts as the master catalog for inventory and purchasing items.

Information:

- Item ID
- Category
- Item name
- Vendor name
- Quote link
- Unit cost
- Notes

### `InventoryList`

Tracks items that are currently part of inventory.

Information:

- Inventory ID
- Item name
- Cumulative asset count
- Current stock total
- Reorder point
- Counted status
- Storage location
- Notes

`item_name` references the master `item` table.

### `PurchaseRequest`

Tracks individual supply requests and the budget associated with each
request.

Information:

- Request ID
- School year
- Requested by
- Requesting location
- Item
- Quantity requested
- Total cost
- Delivered status
- Review status
- Ordered status
- Budget
- Funding source
- Notes

The requested item references the `item` table, the requesting location
references `location`, and the assigned budget references `budget`.

### `InventoryTransaction`

Tracks inventory that is taken or distributed.

Information:

- Transaction ID
- Date
- Taken by
- School receiving the item
- Item
- Quantity taken
- Notes

The school references `location`, and the item references
`InventoryList`.



## Garden Schema

The Garden schema maintains garden footprints, irrigation systems,
composting units, active beds, resources, plant information, and crop
rotations. It supports growing calendars, soil health records, and preparation
for upcoming growing cycles.

The existing `location` table connects gardens to school or program locations.
The garden tables are documented together below.

### `garden`

Represents an individual garden at a school or other location.

Information:

- Garden ID
- Garden name
- Location name
- Physical footprint/size
- Bed count
- Status
- Manager
- Notes

A location can have one or more gardens. Garden status and manager information
support tracking each garden's current condition and responsibility.

### `garden_beds`

Represents individual planting beds belonging to a garden.

Information:

- Bed ID
- Garden name
- Bed name
- Bed size
- Bed type
- Active status
- Soil health
- Notes

Individual garden beds support active bed counts and crop rotation planning.

### `IrrigationSetup`

Stores irrigation systems associated with a garden.

Information:

- Irrigation ID
- Garden name
- Irrigation type
- Status
- Notes

A garden can have multiple irrigation systems.

### `CompostingUnit`

Stores composting units associated with a garden.

Information:

- Composting unit ID
- Garden name
- Composting type
- Status
- Notes

A garden can have multiple composting units.

### `garden_resource`

Records resources needed for a garden, using items from the existing inventory
catalog.

Information:

- Garden Resource ID
- Garden name
- Item name
- Quantity needed
- Notes

The records associate a garden with an item and the quantity needed. Users
review the garden's beds and upcoming crops, determine the required supplies,
and manually enter or update the garden's resource needs.

Resource planning is maintained at the garden level. Users do not need to
create a separate resource list for every planned crop in every bed. Required
items and quantities are not automatically inferred from the planting plan.

### `plant`

Acts as the master list of plants or crops used by the garden program.

Information:

- Plant ID
- Plant name
- Plant type
- Days to harvest
- Notes

`plant_type` classifies the plant or crop.

`days_to_harvest` helps users estimate harvest timing when planning planting
schedules. It does not imply that harvest dates are calculated automatically.

Other plant-specific growing information can remain in notes unless the
community partner identifies additional information that needs to be tracked
separately.


### `CropRotation`

Stores planned crops for individual garden beds.

Information:

- Rotation ID
- Rotation name
- Garden name
- Bed name
- Plant name
- Planned planting date
- Status
- Notes

`rotation_id` is the generated primary key. `rotation_name` is required and
unique, so every new rotation must include a distinct name. Garden, bed, and
plant names are required foreign keys to `garden`, `garden_beds`, and
`plant`, respectively. Status defaults to `Planned`.

Each garden can have multiple beds, and each bed can have multiple planned
crops over time.

Example:

```text
Hogwarts Garden
      |
      v
Hogwarts_Bed_1
      |
      +-- Hogwarts Bed 1 Spring 2027 Tomato --> Tomato
      |
      +-- Hogwarts Bed 1 Fall 2027 Lettuce --> Lettuce
```

These rotation names identify distinct plans. `CropRotation` records the
planned crops, planting dates, and statuses for each garden bed.
