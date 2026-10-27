# Garden Database Design

This document summarizes the current PostgreSQL database design for inventory,
school garden management, and crop rotations.

## Current Schema Files

```text
sql/
  schema_inventory.sql
  schema_garden.sql
  demo_data.sql
  summary_views.sql
```

The inventory schema defines shared location, budget, and item tables used by
the inventory and garden schemas.

## Reusable Types

The inventory schema defines `dollar` for nonnegative monetary amounts and
`nonnegative_count` for nonnegative integer quantities. It also defines
`inventory_transaction_status` for check-in and check-out transactions.

The garden schema defines `lifecycle_status` (`Active`, `Planned`, `Inactive`),
`condition` (`Good`, `Require Maintenance`, `In Maintenance`), and
`rotation_status` (`Planned`, `In-ground`, `Removed`, `Harvested`).

## Inventory Schema

### `location`

Stores school and program locations referenced by purchase requests,
inventory transactions, and gardens.

### `budget`

Stores each budget's name, shared budget amount, and remaining balance.

### `item`

Provides the item catalog used by inventory and purchase requests, including
category, vendor, link, and unit cost information.

### `inventory_list`

Tracks catalog items held in inventory, their cumulative asset and in-stock
quantities, reorder point, counted status, and storage location. Its item name
references `item` and is unique, so a catalog item has at most one inventory
record.

### `purchase_request`

Tracks requested items, quantities, costs, request and review details, whether
they were ordered or delivered, and the school year. `requesting_for` refers
to a location and `item_name` refers to the item catalog. `budget_name` is an
optional reference to `budget`; `funding_source` is an optional text value on
the request.

### `inventory_transaction`

Records inventory check-ins and check-outs, including the date, person,
receiving school, item, and quantity. The school and item refer to `location`
and `inventory_list`, respectively. An optional purchase request link can mark
a check-in as the receipt record for an already delivered purchase; that linked
transaction is recorded without adding the same quantity to stock a second time
or counting it as a school check-in in the supply view.

## Garden Schema

### `garden`

Represents a garden at a school or program location. Each garden has a unique
name, lifecycle status, condition, bed count, and notes. Its location refers
to `location`.

### `garden_bed`

Represents an individual bed belonging to a garden, with its name, type, size,
lifecycle status, condition, fullness, and notes. Bed names are unique within
each garden.

### `irrigation_setup` and `compost_unit`

Store irrigation systems and composting units belonging to gardens. A garden
can have zero or more of either. Each record can track lifecycle status,
condition, and notes, along with its system or unit details.

### `plant`

Provides general information about each plant, including its type, growing
period, and days to harvest. Planting-specific details are stored in
`crop_rotation`.

### `crop_rotation`

Tracks plantings for individual beds within a garden, including the plant,
quantity, season, sow date, rotation status, soil health, and notes. Garden,
bed, and plant names reference their respective records. A bed can have
multiple crop rotation records over time.

The crop calendar views can calculate an estimated harvest date from the sow
date and the plant's days to harvest; that calculated date is not stored in
`crop_rotation`.

## Summary Views

`summary_views.sql` defines views for inventory restocking, purchase requests,
school supplies, budget and funding source purchases, yearly purchase totals,
bed plantings, crop calendars, and garden assets. These views present selected
or calculated information without changing the underlying records.
