# LCSD garden program database
This is a database project for the Lee County School District garden program that focuses on creating a more organized and centralized way to manage garden-related data. The project is based on the program’s current use of Google Sheets and will support areas such as inventory and supplies, garden sizes and components, and growing calendars and crop rotations. The goal is to improve how information is stored, connected, and accessed so staff can better track available resources, locations, distribution, budgets, and other garden program data over time.

# What we need to work on
Inventory & Supplies: 
Monitor seed stocks, tools, soil, and equipment across all campuses to avoid duplicate purchasing, prevent shortages, and allocate budget effectively. We have a rudimentary system for inventory management, supply requests, distribution of supplies, and restocking inventory.  However, this could use some refinement. 

Garden Sizes & Components: 
Maintain up-to-date records of physical garden footprints, irrigation setups, composting units, and active bed counts for each school site.

Growing Calendars & Crop Rotations: 
Plan planting schedules, manage crop rotations to maintain soil health, and track seasonal variations systematically. While simultaneously ensuring we have the resources prepped for the various growing cycles. 

## Current Inventory Database Schema

The current ERD for the inventory portion of the database is shown below.

![Inventory Database ERD](docs/ERD_inventory_schema.jpeg)

                         ┌──────────────┐
                         │ team_member  │
                         └──────┬───────┘
                 ┌──────────────┼──────────────────────
                 ▼              ▼                     ▼
          [PurchaseRequest] [BudgetExpense] [InventoryTransaction]
                     │          ▲             ▲
                     │          │             │
                     |          │             │
                     │          │       [location]
                     |          │             │
                     │          │             │
                  [item] ───────┘             │        [budget]
                     │                        │
                     ▼                        │
              [InventoryList] ────────────────┘
