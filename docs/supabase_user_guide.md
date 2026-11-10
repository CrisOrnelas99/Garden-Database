# LCSD Garden Database

## Supabase User Guide

**Purpose:** This guide explains how to access and use the LCSD Garden Database in Supabase to view, add, update, search, and delete records.

The database helps organize school garden information, inventory, supply requests, budgets, planting schedules, and other gardening activities.

Most daily work will take place in one area: **Table Editor**.

## 1. Accessing the Correct Database

1. Open Supabase and sign in with your account.
2. At the top of the screen, find the project name.
3. Click the small up/down arrows beside the project name to open the project selection menu.
4. You should see two projects:
   - **LCSD Garden DataBase** — The main database you will use.
   - **test 2** — A separate testing project.
5. Select **LCSD Garden DataBase**.

**Important:** Always verify that you are working in LCSD Garden DataBase, not the testing project. Changes made in the testing project will not update the main database.

## 2. Opening the Table Editor

Once you are in the correct project:

1. Look at the navigation menu on the left side.
2. Click **Table Editor**, represented by a small table/grid icon.
3. If the navigation menu is collapsed, hover over the icons to see their names.
4. At the top of the Table Editor, locate the schema dropdown.
5. Make sure it is set to **public**.

Always use the `public` schema. The left panel displays the available tables and views.

### Understanding Tables and Views

Tables store information and allow you to add, update, and delete records. Examples include:

- `location` — School locations and garden information.
- `location_group` — Groups of school locations.
- `group_members` — Connects individual schools to location groups.
- `item` — Catalog of supplies, tools, and equipment.
- `inventory_list` — Available inventory and stock quantities.
- `inventory_transaction` — Records inventory distribution and checkout.
- `purchase_request` — Supply and purchasing requests.
- `budget` — Budget information.
- `garden_bed` — Garden bed information.
- `plant` — Plant information.
- `crop_rotation` — Planned crop rotations.
- `irrigation_setup` — Irrigation information.
- `compost_unit` — Composting information.

Views display information collected or calculated from existing tables. They make it easier to review information without manually searching through several tables. Examples include:

- `RestockList` — Supplies that may need restocking.
- `PendingRequests` — Pending purchase requests.
- `SchoolSupply` — School supply information.
- `CropCalendar` — Crop scheduling information.
- `CurrentBedPlantings` — In-ground and harvested planting information with garden bed details.
- `GardenAssets` — Garden asset information.
- `BudgetPurchases` — Budget and purchasing information.
- `FundingSourceSpending` — Spending by funding source.
- `YearlyPurchase` — Yearly purchasing information.

**Important:** Use views primarily to review information. Make changes in the appropriate tables.

## 3. Viewing Information

1. Open Table Editor and make sure the schema is `public`.
2. Select the table or view you want from the left panel.
3. The records will appear in rows and columns.

Each row represents one record. Each column represents a piece of information about that record. For example, in `inventory_list`:

- `item_name` identifies the supply or equipment.
- `cumulative_asset` represents the cumulative asset quantity.
- `instock_total` shows the quantity currently available.

You can scroll horizontally to see additional columns.

## 4. Searching and Filtering Records

Filters help you find specific information without scrolling through the entire table.

### How to Apply a Filter

1. Open the table or view you want to search.
2. Click **Filter** or **Add filter** near the top.
3. Select the column you want to search.
4. Choose a comparison option.
5. Enter the value you want to find.
6. Apply the filter.

You can filter by any available column.

### Common Filter Options

| Filter | Meaning | Example |
|---|---|---|
| Equals | Matches an exact value | `status = Checked Out` |
| Not equal | Excludes a specific value | `status != Checked Out` |
| Greater than | Values above a number | `quantity > 10` |
| Less than | Values below a number | `quantity < 5` |
| Greater or equal | Values at or above a number | `quantity >= 10` |
| Less or equal | Values at or below a number | `quantity <= 5` |
| Like | Matches a text pattern | `item_name LIKE %Gloves%` |
| iLike | Matches text without case sensitivity | `item_name ILIKE %gloves%` |

### Example: Finding a School

To see inventory transactions for Dunbar High School:

1. Open `inventory_transaction`.
2. Click **Filter**.
3. Select `for_school`.
4. Choose **Equals**.
5. Enter `Dunbar High School`.

The table will show matching transactions.

When using Equals, the value must match the stored information accurately. If you are unsure of the exact spelling or capitalization, use iLike with `%` around part of the name.

### Removing Filters

If a table suddenly appears empty, you may have an active filter. Look near the top of the table for the filter and click the **X** to remove it. An empty table does not necessarily mean the records were deleted.

## 5. Sorting Information

Sorting organizes records in a particular order. For example, you might want to see the newest inventory transactions first or the lowest stock quantities.

1. Open a table or view.
2. Click **Sort** near the top.
3. Choose the column you want to sort.
4. Select ascending or descending order.

Examples:

- Sort `transaction_date` descending to see newer transactions first.
- Sort `instock_total` ascending to see the lowest stock quantities first.
- Sort `item_name` ascending to organize supplies alphabetically.

Sorting only changes how the information is displayed. It does not change the records themselves.

## 6. Adding New Records

1. Open Table Editor and select the table you want to update.
2. Click the green **Insert** button in the upper-right corner.
3. Choose to insert a new row.
4. Fill in the required fields and any optional fields that apply.
5. Click **Save**.

### Important Rules When Adding Records

- **Leave ID fields alone.** Columns such as `item_id`, `transaction_id`, and `location_id` are automatically generated by the database. You do not need to enter an ID.
- **Understand NULL values.** `NULL` means the field currently has no value. For example, if a notes field is `NULL`, no notes have been entered. Some fields are optional and can remain empty. Required fields must have a value before the record can be saved.
- **Use the small editor icon.** Some fields have a small editor or selection icon on the right side. Click it to enter or select the appropriate value. For fields connected to another table, this may open a list of existing records.

### Example: Adding an Inventory Transaction

1. Open `inventory_transaction` and click **Insert**.
2. Leave `transaction_id` unchanged.
3. Select the appropriate status.
4. Enter the person's name in `taken_by`.
5. Select an existing `item_name` and enter the quantity.
6. Select the appropriate `for_school` or `for_school_group`, as applicable.
7. Leave `transaction_date` blank if you want the current date automatically entered.
8. Add any optional notes and click **Save**.

Make sure the quantity, item, and receiving location are correct before saving, since inventory transactions may affect stock totals.

## 7. Understanding Connected Records

Some columns are connected to information stored in another table. These are called foreign key relationships. For example:

- An inventory transaction references an item from `inventory_list`.
- A school name references a record in `location`.
- A location group references a record in `location_group`.

This helps prevent incorrect or inconsistent information.

### What Happens If a Value Doesn't Exist?

Suppose you try to enter a school name that has not been added to the `location` table. The database may reject the entry because that school does not exist in the referenced table.

To resolve this:

1. Check whether the value already exists in the referenced table.
2. Verify the spelling.
3. If it is a genuinely new school or item, add it to the appropriate table first, if authorized.
4. Return to the original table and complete your entry.

**Tip:** Whenever a field offers a record-selection icon, use it instead of manually typing the value. This reduces spelling mistakes and relationship errors.

## 8. Editing Existing Records

1. Open the table and find the record you want to change.
2. Double-click the column value you want to edit.
3. Enter the updated information or select a new value.
4. Save or confirm the change if prompted.

For example, you could update a garden's status, correct an item description, or change a contact email. You do not need to create a new row just to change an existing value.

**Important:** Be careful when changing quantities, budget values, or transaction records because some database functions automatically calculate or update related information.

## 9. Deleting Records

If a record was entered incorrectly and needs to be removed:

1. Open the appropriate table and find the row you want to delete.
2. Click the small checkbox on the far-left side of that row. A checkmark will appear.
3. Click the red **Delete 1 row** button near the top.
4. Review the selection and confirm the deletion.

You can select multiple rows, but always verify which records are selected.

**Important:** Deleting a record may affect other information or be blocked because another table references it. Do not delete records simply because they are old or no longer active. If you are unsure whether something should be deleted, ask before proceeding.

## 10. Using Views for Gardening Activities

Views organize information already stored in the database.

- **Checking inventory:** Open `inventory_list` to review available supplies. Use `RestockList` to identify items that may need to be reordered.
- **Reviewing school supplies:** Open `SchoolSupply` and filter by school to focus on a specific location.
- **Reviewing purchase requests:** Open `PendingRequests` to review requests that still need attention. Open `BudgetPurchases`, `FundingSourceSpending`, or `YearlyPurchase` to review purchasing and spending information.
- **Reviewing gardens and planting:** Open `GardenAssets` to review garden-related information. Use `CurrentBedPlantings` for in-ground and harvested plantings, and `CropCalendar` for crop scheduling, including planned plantings.

You can use these views to determine which gardening records or supplies need updating. Views are primarily for reviewing information; make changes in the underlying tables.

## 11. Changing the Appearance

Supabase allows you to switch between light and dark mode.

1. Click your profile icon in the upper-right corner.
2. Find the **Theme** section.
3. Choose **System** (matches your device settings), **Dark** (dark background), or **Light** (light background).

This only changes the appearance of Supabase. It does not affect your database information.

## 12. Using the Supabase AI Assistant

Supabase includes an AI Assistant that can help answer questions about the database. You can access it using the AI Assistant icon near the upper-right area of the dashboard.

The assistant may be useful for understanding relationships between tables, finding where information is stored, explaining a column or table, or creating read-only queries to view specific records.

### Important AI Safety Rules

Use the AI Assistant with caution and only when needed. Use it to help view and understand data, not to modify the database structure. Do not ask it to delete tables or views, drop database objects, remove columns, change relationships, modify functions/triggers/permissions, or delete or overwrite existing records.

If the AI Assistant generates SQL, make sure it is a read-only `SELECT` query before running it. Never execute commands such as `DROP`, `DELETE`, `TRUNCATE`, `ALTER`, or `UPDATE` through the AI Assistant without approval. If you are unsure what a query does, do not run it.

## 13. Accounts, Invitations, and Application Roles

There are two different kinds of Supabase accounts. They provide different levels of access and should not be confused.

### Supabase organization or project members

Organization/project members can sign in to the Supabase dashboard. Their Supabase organization role controls access to project settings and development tools and may provide powerful database access. Keep membership limited to project administrators and technical maintainers who need dashboard access. Regular service-learning partners do **not** need to be invited to the Supabase organization or added as project members.

### Supabase Auth users for the local app

Partners receive an Auth user invitation so they can sign in to the local Garden Database app. This does not grant Supabase dashboard access.

1. In the project dashboard, go to **Authentication → Users → Add user → Send invitation** and enter the partner's email.
2. The partner starts the local app at `http://localhost:8000` before opening the invitation link. The link returns to the local app so they can set their password.
3. A database manager assigns `staff`, `finance_staff`, or `database_manager` from the app's **Manage Users** page. An invited Auth user without an assigned app role cannot access garden records.

New invitations are sent from Supabase Auth. Managers can assign or remove app roles and request password-reset emails in the frontend; they do not need to make each partner a Supabase organization member.

### Custom Access Token Hook (one-time project setup)

The project's Custom Access Token Hook attaches the app role to the Auth user's signed token at sign-in. Supabase then uses that role for database permissions and policies.

1. The project owner runs the repository's SQL setup files in order, with `schema_roles.sql` last. That file creates `public.custom_access_token_hook` and the private role-assignment table.
2. In the Supabase dashboard, open **Authentication → Hooks** (sometimes labeled **Hooks (Beta)**) and add a **Custom Access Token** hook.
3. Select **Postgres**, schema **`public`**, and function **`custom_access_token_hook`**. Do not select HTTPS.

The hook reads the app role from `private.user_role_assignment`. The `staff`, `finance_staff`, and `database_manager` roles are PostgreSQL data roles used by the application. They are distinct from Supabase organization roles such as Owner or Administrator.

### Email password requirements

To review the password rules enforced by Supabase Auth, open **Authentication → Sign In / Providers → Email** in the project dashboard. Check the minimum password length and required character types. Supabase Auth enforces these requirements when users set or change passwords, including through the local app's invitation and password-reset forms. These rules are configured in Supabase; the frontend only checks that the two password entries match. Supabase recommends a minimum length of at least 8 characters and supports requiring digits, lowercase and uppercase letters, and symbols. Leaked-password protection is available on Pro and higher plans. See [Supabase password security](https://supabase.com/docs/guides/auth/password-security).

### Assigning the first database manager

The first manager must be assigned by the project owner because there is not yet an app manager who can assign roles. First invite that person through **Authentication → Users → Add user → Send invitation**, then run this in the Supabase **SQL Editor**, replacing the example email with the exact invited email:

```sql
INSERT INTO private.user_role_assignment (user_id, database_role)
SELECT u.id, 'database_manager'
FROM auth.users AS u
WHERE lower(u.email) = lower('manager@example.com')
ON CONFLICT (user_id)
DO UPDATE SET database_role = EXCLUDED.database_role
RETURNING user_id, database_role;
```

The query should return one row with `database_manager`. After the manager signs in, they can assign app roles to other Auth users through **Manage Users**.

## 14. What Areas of Supabase Should You Use?

For regular database activities, primarily use:

**Table Editor → `public` schema → Tables and Views**

This is where you can review school and garden information; add, update, search, filter, and sort records; review inventory and purchasing information; and delete records when necessary.

For ordinary partner work, use the local app; partners do not need the Supabase dashboard. Project administrators use **Authentication → Users** to send app invitations and **Manage Users** in the frontend to assign roles. The SQL Editor, Auth Hooks, Data API settings, database configuration, and infrastructure settings are for project setup and maintenance and should only be changed by authorized project administrators.

## 15. Quick Troubleshooting

| Problem | What to do |
|---|---|
| I cannot find the gardening tables | Make sure you're in LCSD Garden DataBase and the `public` schema. |
| My table is empty | Check for active filters and remove them using the X. |
| I cannot find a record | Verify the spelling or try an iLike filter. |
| My new record will not save | Check required fields and confirm referenced records exist. |
| A school or item isn't available to select | Add it to the appropriate referenced table first, if authorized. |
| I see NULL | The field has no value; it may be optional. |
| I don't know what ID to enter | Leave automatically generated ID fields alone. |
| A deletion fails | Another record may depend on it; do not force the deletion. |
| I accidentally changed something | Stop and notify the database team so the change can be reviewed. |
| I don't understand a table or relationship | Ask the database team or use the AI Assistant for read-only explanations. |
