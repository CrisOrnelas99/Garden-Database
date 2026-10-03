# Garden Database Design

This document summarizes the current database implementation and the
main areas that are planned for later development. It is a working
design document, so the planned tables and fields can be refined as the
community partner provides more details.

## Current Implementation

The current database is built in PostgreSQL using Supabase and focuses
on the **Inventory & Supplies** portion of the project.

### Current Schema Files

```text
sql/
├── inventory_schema.sql
├── garden_schema.sql
├── planting_schema.sql
├── summary_views.sql
└── demo_data.sql
```

The inventory schema is currently implemented. The garden and planting
schemas are planned for later development.

### Custom Domains

The inventory schema uses reusable PostgreSQL domains:

- `dollar` — `DECIMAL(12,2)` values that cannot be negative.
- `count` — integer values that cannot be negative.

### Current Inventory Tables

#### `location`

Stores school or program locations that can be referenced throughout the
database.

Main information:

- Location ID
- Location name
- Notes

#### `budget`

Stores available budgets and their remaining balances.

Main information:

- Budget ID
- Budget name
- Budget amount
- Remaining budget
- Notes

#### `item`

Acts as the master catalog for inventory and purchasing items.

Main information:

- Item ID
- Category
- Item name
- Vendor name
- Quote link
- Unit cost
- Notes

#### `InventoryList`

Tracks items that are currently part of inventory.

Main information:

- Inventory ID
- Item name
- Cumulative asset count
- Current stock total
- Reorder point
- Counted status
- Storage location
- Notes

`item_name` references the master `item` table.

#### `PurchaseRequest`

Tracks individual supply requests and the budget associated with each
request.

Main information:

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

#### `InventoryTransaction`

Tracks inventory that is taken or distributed.

Main information:

- Transaction ID
- Date
- Taken by
- School receiving the item
- Item
- Quantity taken
- Notes

The school references `location`, and the item references
`InventoryList`.

### Current Functions and Triggers

The database currently uses PostgreSQL functions and triggers to
automate several calculations.

#### Purchase Request Total

Automatically calculates:

```text
PurchaseRequest.total_cost =
qty_requested × item.unit_cost
```

#### Remaining Budget

A new budget starts with its remaining budget equal to its budget
amount.

Purchase requests assigned to a budget are used to calculate the
remaining balance:

```text
remaining_budget =
budget_amount - SUM(PurchaseRequest.total_cost)
```

The remaining amount is recalculated when purchase requests are
inserted, updated, or deleted.

The exact point at which a purchase request should count against a
budget may be refined later based on the community partner's workflow.

#### Inventory Transactions

Inventory transactions automatically update the current stock in
`InventoryList`.

For example:

```text
Current Stock:     20
Quantity Taken:     4
                  ----
New Stock:         16
```

The function also prevents a transaction from taking more inventory than
is currently available.

## Current Views

The inventory database also uses views to provide useful information
without storing duplicate data.

#### `RestockList`

Shows inventory items where the current stock is at or below the
reorder point.

Main information:

- Inventory ID
- Item name
- Current stock total
- Reorder point
- Storage location

#### `PendingRequests`

Shows purchase requests that are still pending because they have either
not been ordered or have been ordered but not yet delivered to FNS.

Each request includes a request status of either `Unordered` or
`Undelivered`.

Main information:

- Request ID
- Request status
- Requested by
- Requesting location
- Item
- Quantity requested
- Total cost
- Review status
- Budget
- Funding source
- Notes

#### `SchoolInventory`

Provides a summary of inventory use and purchase request costs for each
school or location.

Main information:

- School name
- Items checked out
- Items still requested
- Total spent
- Unordered cost

`items_checked_out` represents the total quantity taken through inventory
transactions.

`items_still_requested` represents items from purchase requests that
have not yet been ordered or delivered.

`total_spent` represents the cost of purchase requests that have been
ordered.

`unordered_cost` represents the cost of purchase requests that have not
yet been ordered.

#### `BudgetPurchases`

Shows purchase requests associated with each budget.

Main information:

- Budget name
- School year
- Request ID
- Item
- Quantity requested
- Total cost
- Requested by
- Requesting location

#### `YearlyPurchaseSummary`

Summarizes purchase request spending for each school year.

Main information:

- School year
- Total requested
- Total spent
- Unordered spending

`total_requested` represents the total cost of all purchase requests for
the school year.

`total_spent` represents the cost of requests that have been ordered.

`unordered_spending` represents the cost of requests that have not yet
been ordered.

---

# Planned Garden Schema

The Garden schema will address the community partner's requirement to
maintain records of **physical garden footprints, irrigation setups,
composting units, and active bed counts for each school site**.

The existing `location` table can be reused instead of creating another
school table.

A possible structure is:

```text
location
   |
   v
Garden
   |
   +----------> GardenBed
   |
   +----------> IrrigationSetup
   |
   +----------> CompostingUnit
```

## `Garden`

Represents an individual garden at a school or other location.

Possible information:

- Garden ID
- Location
- Garden name
- Physical footprint/size
- Notes

A single location could have more than one garden.

Example:

```text
Example High School
├── Main Garden
└── Courtyard Garden
```

## `GardenBed`

Represents individual beds belonging to a garden.

Possible information:

- Bed ID
- Garden ID
- Bed name
- Bed size
- Active status
- Notes

Instead of manually storing an active bed count in `Garden`, the
database could calculate the number of active beds from the `GardenBed`
records.

Example:

```text
Main Garden
├── Bed 1 - Active
├── Bed 2 - Active
├── Bed 3 - Active
└── Bed 4 - Inactive
```

## `IrrigationSetup`

Stores irrigation systems associated with a garden.

Possible information:

- Irrigation ID
- Garden ID
- Irrigation type
- Status
- Notes

The exact information that should be tracked about irrigation systems
should be refined with the community partner.

## `CompostingUnit`

Stores composting units associated with a garden.

Possible information:

- Composting unit ID
- Garden ID
- Composting type
- Status
- Notes

The exact composting information should also be refined based on what
the community partner needs to maintain.

---

# Planned Planting Schema

The Planting schema will address the requirement to **plan planting
schedules, manage crop rotations, track seasonal variations, support
soil health, and prepare resources for growing cycles**.

The Planting schema will connect to `GardenBed` from the Garden schema.

A possible structure is:

```text
GardenBed
    |
    v
 Planting <------ Plant
    |
    v
PlantingResource
    |
    v
   item
```

## `Plant`

Acts as the master list of plants or crops used by the garden program.

Possible information:

- Plant ID
- Plant name
- Notes

Additional growing information can be added later if the partner
identifies specific plant information they want to track.

## `Planting`

Represents a planting event or growing cycle for a specific garden bed.

Possible information:

- Planting ID
- Plant ID
- Garden bed ID
- Planting date
- Expected harvest date
- Season
- School year
- Notes

Example:

```text
Bed 1 | Tomato      | Fall 2026
Bed 2 | Lettuce     | Fall 2026
Bed 1 | Green Beans | Winter 2027
```

### Planting Schedules

The dates and seasons stored in `Planting` can be used to determine what
is scheduled to be planted and harvested during a particular period.

### Crop Rotation

A separate crop rotation table may not be necessary at first. The
history of `Planting` records can show which crops were previously
planted in each garden bed.

Example:

```text
Bed 1
Fall 2026   -> Tomato
Winter 2027 -> Green Beans
Spring 2027 -> Lettuce
```

This history could later be queried to help plan crop rotations. If the
partner has specific crop rotation or soil-health rules that need to be
stored, additional tables can be added later.

### Seasonal Variations

Keeping planting records by date, season, and school year will preserve
historical information instead of replacing previous schedules. This can
allow growing cycles from different seasons or years to be compared
later.

## `PlantingResource`

This table could connect future planting schedules to the existing
inventory system.

Possible information:

- Planting ID
- Item
- Quantity needed

Example:

```text
Fall Tomato Planting
├── Potting Soil × 5
├── Garden Gloves × 10
└── Seed Pack × 3
```

The item could reference the existing `item` table. This would connect
planned growing cycles with the resources needed to support them.

A future implementation could then compare the resources needed for
upcoming planting cycles with the inventory currently available.

---

# Overall Planned Structure

The three main areas would eventually connect together:

```text
location
   |
   v
Garden
   |
   v
GardenBed
   |
   v
Planting <------ Plant
   |
   v
PlantingResource
   |
   v
 item
   |
   +------> InventoryList
   |
   +------> PurchaseRequest
                 |
                 v
              budget
```

This allows the database to connect:

```text
School Location
      |
      v
Physical Garden
      |
      v
Garden Bed
      |
      v
Growing Cycle
      |
      v
Plant/Crop
      |
      v
Resources Needed
      |
      v
Current Inventory
```

---
