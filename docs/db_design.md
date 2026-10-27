# Garden Database Design

This document summarizes the current PostgreSQL schema. The SQL files contain full table, type, function, and trigger definitions.

## Setup order

1. `sql/schema_inventory.sql`
2. `sql/schema_garden.sql`
3. `sql/summary_views.sql`
4. `sql/demo_data.sql`

## Inventory tables

- `"l-location"` stores schools and program locations, including offices without gardens.
- `"l-group-locations"` stores readable names for one or more locations assigned together.
- `"l-group-assignment"` maps each named group to its member locations.
- `"i-budget"` stores budget names and shared balances.
- `"i-item"` stores the item catalog.
- `"i-inventory_list"` tracks current stock and reorder details.
- `"i-purchase_request"` stores requested items, costs, review and delivery state, and an optional budget. Each request points either directly to one school through `requesting_school` or to a location group through `requesting_school_group`.
- `"i-inventory_transaction"` records checked-in or checked-out inventory. Each transaction points either directly to one school through `for_school` or to a location group through `for_school_group`.

## Garden tables

Garden details are optional fields on `"l-location"`, so an office or a school without a tracked garden can have those fields empty. Garden assets use the location name directly.

- `"g-garden_bed"` stores individual beds and their lifecycle and condition.
- `"g-irrigation_setup"` and `"g-compost_unit"` store zero or more irrigation systems and composting units per location.
- `"g-plant"` stores general plant information.
- `"g-crop_rotation"` tracks plantings by bed, including quantity, sow date, rotation status, and soil health.

## Views and triggers

`summary_views.sql` creates the inventory, purchasing, and garden reporting views. The schema files define triggers for budget totals, purchase costs, inventory quantities, garden bed counts, and crop soil health.

For purchase requests and inventory transactions, at most one school reference may be set: the direct school field or the location group field. Both may be left empty while a record is unassigned. `SchoolSupply` has separate rows for each school and named group, so group activity is not repeated on each member school's row.
