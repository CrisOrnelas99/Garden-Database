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

The Garden schema is planned to address the community partner's requirement to
maintain records of **physical garden footprints, irrigation setups,
composting units, and active bed counts for each school site**.

The existing `location` table can be reused to connect future garden records
to school or program locations.

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

Could represent an individual garden at a school or other location.

Possible information:

- Garden ID
- Garden name
- Location name
- Physical footprint/size
- Notes

A location could have one or more gardens.

## `GardenBed`

Could represent individual planting beds belonging to a garden.

Possible information:

- Bed ID
- Garden name
- Bed name
- Bed size
- Active status
- Notes

Individual garden beds would allow the database to determine active bed
counts and could later support planting schedules and crop rotation history.

## `IrrigationSetup`

Could store irrigation systems associated with a garden.

Possible information:

- Irrigation ID
- Garden name
- Irrigation type
- Status
- Notes

The exact irrigation information can be refined based on what the community
partner needs to maintain.

## `CompostingUnit`

Could store composting units associated with a garden.

Possible information:

- Composting unit ID
- Garden name
- Composting type
- Status
- Notes

The exact composting information can also be refined based on the community
partner's needs.

---

# Planned Planting Schema

The Planting schema is planned to address the requirement to **plan planting
schedules, manage crop rotations, track seasonal variations, support soil
health, and prepare for growing cycles**.

A future Planting schema could connect to `GardenBed` from the planned Garden
schema.

A possible structure is:

```text
GardenBed
    |
    v
Planting <------ Plant
```

## `Plant`

Could act as the master list of plants or crops used by the garden program.

Possible information:

- Plant ID
- Plant name
- Best season
- Days to harvest
- Notes

`best_season` could identify when a plant is generally best suited for
growing.

`days_to_harvest` could help with planning planting and expected harvest
schedules.

Other plant-specific growing information could remain in notes unless the
community partner identifies additional information that needs to be tracked
separately.

## `Planting`

Could represent a planting event or growing cycle for a specific garden bed.

Possible information:

- Planting ID
- Bed name
- Plant name
- Planting date
- Expected harvest date
- Status
- Notes

The planting record could connect a plant to a specific garden bed and
preserve the history of what has been grown there.

### Planting Schedules

Planting dates, expected harvest dates, plant information, and growing status
could be used to plan and monitor growing cycles.

The best season and days to harvest stored for each plant could also help
with planning future planting schedules.

### Crop Rotation

A separate crop rotation table may not be necessary at first.

The history of planting records for each garden bed could show which plants
were previously grown there.

Example:

```text
Hogwarts_Bed_1
      |
      ├── Tomato
      ├── Green Beans
      └── Lettuce
```

This history could later help with planning crop rotations and maintaining
soil health.

### Seasonal Variations

The planting date could show when each growing cycle actually occurred,
while the plant's best season could provide general information about when
that plant is best suited for growing.

Over time, planting records from different times of the year could be
compared to help identify seasonal differences.

### Growing Cycle Preparation

Plant information such as best season and days to harvest could help with
planning upcoming growing cycles.

The existing inventory and purchasing system could continue to handle
supplies, inventory levels, reorder needs, and purchase requests separately.
