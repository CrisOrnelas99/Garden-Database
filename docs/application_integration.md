# Frontend Setup and Database Integration

This guide describes how a future web frontend could connect to this project. It is a starting point, not a frontend implementation. The current database remains usable through the Supabase Dashboard Table Editor.

## How the pieces fit together

```text
Browser app -> Supabase client/API -> PostgreSQL database
```

With Supabase, a browser app can use the Supabase client library and the project's generated Data API. A basic React app can be hosted as static files by a frontend hosting service; it does not need an always-running application server. Supabase hosts the database, API, and optional authentication. Its Dashboard is for managing the project and its data, rather than building a custom partner-facing interface.

For a different database provider, use this general pattern instead:

```text
Browser app -> Your backend/API -> Database
```

Keep database connection strings and passwords on the backend. Do not connect a browser directly to PostgreSQL with database credentials.

## Connecting a frontend to Supabase

1. Create or select the Supabase project that contains the database.
2. For a new, empty project, load the SQL in dependency order: `sql/schema_garden.sql`, `sql/schema_inventory.sql`, `sql/summary_views.sql`, then `sql/demo_data.sql` if demo rows are wanted. For an existing project with data, apply reviewed migrations instead of rerunning the full schema files.
3. In the Supabase Dashboard, get the Project URL and publishable API key from the project's **Connect** dialog.
4. Install the Supabase client library for the chosen frontend framework and create a client using those values.
5. Add authentication if users need individual accounts.
6. Configure Row Level Security (RLS), policies, and grants before allowing a frontend to read or write project data.
7. Build forms and lists around the tables and views, then deploy the frontend to a web host.

## Database roles and row access

After the schemas and views exist, apply `sql/schema_roles.sql` as an administrator. It configures three database roles: `database_admin` owns and can manage the schema and objects; `data_manager` can manage data and database roles but cannot create or alter schema objects; `garden_staff` can manage operational rows while budget tables and budget-related reports stay unavailable. Garden staff can see item and purchase request costs. The `SchoolSupply` view omits its spending column. The automatically maintained `All HLC Gardens` group and its membership can be viewed but not edited directly.

The script also creates `private.user_role_assignment` and the `custom_access_token_hook` function. For partner API access, enable the hook in **Authentication → Hooks → Custom Access Token**. Invite users through **Authentication → Users → Add user → Send invitation**. Then assign each user's Auth UUID to `garden_staff` or `data_manager` in `private.user_role_assignment`; the hook places that PostgreSQL role in the signed JWT. Users without an assignment retain the `authenticated` role and receive no table grants. `database_admin` is deliberately not assignable through Auth; keep that role and the Supabase project owner account private. Supabase project access roles are separate: do not give partners Dashboard project access if they must not run SQL or change schema.

For a Vite/React app, the public connection settings can be stored in a local `.env` file:

```env
VITE_SUPABASE_URL=https://your-project-ref.supabase.co
VITE_SUPABASE_PUBLISHABLE_KEY=your-publishable-key
```

Example client initialization:

```js
import { createClient } from '@supabase/supabase-js'

export const supabase = createClient(
  import.meta.env.VITE_SUPABASE_URL,
  import.meta.env.VITE_SUPABASE_PUBLISHABLE_KEY
)
```

The Project URL identifies the Supabase project. A publishable key is intended for public client code, but it is not an access policy: RLS and database permissions determine what users can read or change. Never put a Supabase secret key or legacy `service_role` key in frontend code; those privileged keys bypass RLS.


Official references: [Supabase React quickstart](https://supabase.com/docs/guides/getting-started/quickstarts/reactjs), [API keys](https://supabase.com/docs/guides/getting-started/api-keys), and [database security](https://supabase.com/docs/guides/database/secure-data).

## Using another database provider

The frontend framework can stay similar, but the connection layer changes. Use that provider's client library only in a trusted server environment, or build a backend API that talks to the database. The browser calls your backend API; the backend validates the request and keeps database credentials private. Authentication and access rules must be implemented for the selected provider and deployment.

## Current name-based foreign keys

This database uses readable names for several foreign keys so linked records are easy to recognize in the Supabase Table Editor. Examples include:

- `garden_bed.location_name` -> `location.location_name`
- `crop_rotation.plant_name` -> `plant.plant_name`
- `crop_rotation(location_name, bed_name)` -> `garden_bed(location_name, bed_name)`
- `group_location.location_group_name` -> `location_group.location_group_name`
- `group_location.location_name` -> `location.location_name`
- Inventory requests and transactions reference readable location, group, item, and budget names.

The referenced names are unique, but names are still labels that people can edit. A later frontend can keep showing names while using stable numeric IDs internally: dropdowns display a location or plant name, but submit its ID as the selected value.

## Moving foreign keys from names to IDs later

This is a database migration, not just a frontend setting. The migration should be done deliberately and in stages:

1. Keep the current name columns and add nullable ID foreign-key columns to the referencing tables.
2. Backfill each ID by joining the existing name to its parent row. For example, fill `garden_bed.location_id` by matching `garden_bed.location_name` to `location.location_name`.
3. Check that every old reference found exactly one parent and that no new ID is missing. Add and validate the new foreign-key constraints and indexes.
4. Update functions, triggers, views, demo data, and frontend queries to use IDs for relationships. Views and frontend dropdowns can join to parent tables to show readable names.
5. Deploy the application so it reads and writes IDs. Once all dependent code has switched, make required ID columns `NOT NULL` where appropriate and remove the old name-based foreign keys/columns in a later migration.

For the garden relationship, `crop_rotation` can use `bed_id` to identify its bed and get the location through `garden_bed -> location`. If `crop_rotation` also keeps a separate `location_id`, add a composite constraint to ensure that the selected bed belongs to that location; otherwise the two fields could disagree.

For shared locations, migrate both the group membership table and the assignment fields: `group_location` would store `location_group_id` and `location_id`, while purchase requests and inventory transactions would reference either a direct `location_id` or a `location_group_id`. Preserve the existing rule that one assignment path is selected at a time.

Names can remain as unique display fields after the migration. IDs are used for relationships; names are joined in for people to read. Existing Supabase data should be changed with reviewed migrations and a backup, not by rerunning the full `CREATE TABLE` schema files.
