# Garden Database

## Supabase User Guide

**Audience:** This guide is for the organization's Supabase Owner/Administrator and authorized project Developers. It covers Supabase project administration and occasional database maintenance; it is not for regular app users.

Regular users work in the local frontend with an invited Supabase Auth account. They should not be added to the Supabase organization or project. Supabase organization roles are separate from Garden app roles and can grant broader dashboard and database access. See the [frontend README](../frontend/README.md) for app use and the [root README](../README.md#setting-up-a-new-supabase-project) for the overall project setup.

## 1. Open the intended project

1. Open the [Supabase dashboard](https://supabase.com/dashboard) and sign in.
2. Select the organization and project specified by the project owner.
3. Verify that you selected the intended production or test project before making changes. Projects do not share data or settings.

## 2. Set up a new project's database

For a new project, open **SQL Editor** from the dashboard's left menu and select **New query**. From the downloaded repository, open each SQL file, copy its full contents into the SQL Editor, and select **Run**. Run one file at a time and wait for it to complete before proceeding:

1. `sql/schema_garden.sql`
2. `sql/schema_inventory.sql`
3. `sql/summary_views.sql`
4. `sql/demo_data.sql` only if you want the prewritten starter records; skip it if you will load your own data.
5. `sql/roles_and_permissions.sql` last, after the tables and views exist.

This order is for a new project. Do not rerun the full schema setup on an existing project without reviewing the SQL and current database state first.

## 3. Configure the app connection and sign-in

### Enable the Data API and find the Project URL

1. Open **Integrations → Data API** in the project dashboard.
2. Confirm **Enable Data API** is on.
3. Find **API URL** and copy the displayed URL. The frontend needs the base Project URL, which is the project HTTPS address without the `/rest/v1/` suffix. Do not use a PostgreSQL connection string.

### Find the Publishable key

1. Open **Project Settings → API Keys**.
2. Find **Publishable key** and copy its value. It typically starts with `sb_publishable_`.
3. Do not use a Secret key, legacy `service_role` key, or database password in the frontend.

Only an authorized project maintainer can retrieve these values from that project's dashboard and configure the repository for it. If setting up this repository for a different Supabase project, put that project's base URL in `SUPABASE_URL` and its Publishable key in `SUPABASE_PUBLISHABLE_KEY` in `frontend/app.py`. Commit and push the updated configuration before users download or update the app. Regular app users should use the project's configured app files and should not replace these values.

The Project URL and Publishable key identify the project and app; they do not grant Garden data access by themselves. A user still needs to sign in with an invited Supabase Auth account and have a Garden app role assigned. A Publishable key may be public, but never put a database password or Secret/`service_role` key in the frontend or repository. See Supabase's [Data API documentation](https://supabase.com/docs/guides/api) and [API keys documentation](https://supabase.com/docs/guides/getting-started/api-keys).

### Configure Auth redirects and password requirements

In **Authentication → URL Configuration**, set the **Site URL** and add the same address under **Redirect URLs**:

```text
http://localhost:8000/
```

In **Authentication → Sign In / Providers → Email**, keep email/password sign-in enabled, turn off **Allow new users to sign up** so accounts are invitation-only, and require passwords to be at least 8 characters with lowercase and uppercase letters, digits, and symbols. Supabase Auth applies these rules when users set or reset passwords. See [Supabase password security](https://supabase.com/docs/guides/auth/password-security).

### Configure the Custom Access Token Hook

The hook adds the assigned Garden app role to a user's sign-in token so Postgres can enforce the matching grants and policies. After running the SQL files above:

1. Open **Authentication → Auth Hooks → Add Hook**.
2. Choose **Custom Access Token**.
3. Set **Hook Type** to **Postgres**, schema to `public`, and function to `custom_access_token_hook`; save the hook.

## 4. Manage Supabase organization membership

Organization membership is for people who need direct access to the Supabase dashboard or project: the long-term organization Owner, the head Garden Program manager who administers Supabase, and authorized developers maintaining the database or frontend. Do not add regular app users here; invite them through Supabase Auth as described below.

- **Owner:** Full access to the organization and its projects. Keep an organization-controlled Owner account for long-term ownership and recovery.
- **Administrator:** Broad project and member-management access, except changing organization settings, transferring projects outside the organization, or adding Owners. This is appropriate for the head Garden Program manager.
- **Developer:** Read-only access to organization resources and full access to project content, including database content, but cannot change project settings. This is appropriate for authorized technical maintainers.

To invite a member, open **Organization Settings → Team**, invite the person's Supabase account by email, and assign the role matching their responsibility. Organization-level roles apply across the organization's projects. If project-scoped roles are available on your plan, grant access only to the needed project.

To change a member's role or project access, find them under **Organization Settings → Team** and update their access. To remove their organization membership, use that member's remove action. This removes their dashboard and project access, but does not delete their separate Supabase account or their Garden app Auth account. Cancel a pending invitation from Team settings if it has not been accepted. Keep at least one Owner; arrange a replacement before removing or leaving as the only Owner.

Removing organization membership does not remove a Garden app role. Remove app access separately through **Manage Users** in the frontend, or delete the Auth user under **Authentication → Users** if the person should no longer sign in. See Supabase's [access-control documentation](https://supabase.com/docs/guides/platform/access-control).

## 5. Invite app users and assign app roles

### Invite regular app users

After users have downloaded the repository, an authorized Supabase administrator can invite them from **Authentication → Users → Add user → Send invitation**. Users should start the local app before opening the invitation email. The link returns to the app, where they set a password and sign in. A Database Manager assigns their Garden app role from **Manage Users**. An invited account without an app role cannot access garden records. App users do not need Supabase organization membership.

### Assign or restore the first Database Manager

The first manager must be assigned by the project owner. Invite the person through **Authentication → Users → Add user → Send invitation**, then run this in the Supabase **SQL Editor**, replacing the placeholder with the invited user's email:

```sql
INSERT INTO private.user_role_assignment (user_id, database_role)
SELECT u.id, 'database_manager'
FROM auth.users AS u
WHERE lower(u.email) = lower('REPLACE_WITH_MANAGER_EMAIL')
ON CONFLICT (user_id)
DO UPDATE SET database_role = EXCLUDED.database_role
RETURNING user_id, database_role;
```

The query should return one row with `database_manager`. The same query can restore or reassign an existing Auth user's manager role.

### Remove app access or an Auth account

To remove an app role but keep the sign-in account, a Database Manager can use **Manage Users → Remove access** in the frontend. Managers cannot remove their own role there. To revoke a manager role, the project owner can run this in the Supabase **SQL Editor**, replacing the placeholder email:

```sql
DELETE FROM private.user_role_assignment AS assignment
USING auth.users AS account
WHERE assignment.user_id = account.id
  AND lower(account.email) = lower('REPLACE_WITH_MANAGER_EMAIL')
RETURNING assignment.user_id, assignment.database_role;
```

To prevent a user from signing in, an authorized Supabase administrator can open **Authentication → Users**, find the account, choose **Delete user**, and confirm. This also removes the account's app-role assignment and display-name profile, but does not delete its existing Garden Program records.

## 6. Work with information in Table Editor

Use the Table Editor only when you have authorized dashboard access and need to inspect or maintain data directly. For routine work, users should use the frontend, where their Garden app role applies.

### Open and view tables

1. Select **Table Editor** from the dashboard's left menu.
2. Set the schema selector to **public**.
3. Select a table or view from the left panel. Rows are records and columns are their stored information.

### Search, filter, and sort

Use **Filter** or **Add filter**, select a column and comparison, enter a value, then apply the filter. Available comparisons include equality, inequality, numeric comparisons, and text matching. Remove an active filter with its **X**. If no rows appear, check for active filters and confirm the selected project.

Use **Sort** to choose a column and ascending or descending order. Sorting changes only the display order.

### Add and update rows

Select a table, choose **Insert**, add a row, enter required information, and select **Save**. Leave database-generated ID fields alone. `NULL` means a field has no value; required fields cannot be left empty. For fields related to another table, use the available record selector and select an existing record. The database may reject missing or invalid references.

To update a row, locate it, edit the relevant value, and save or confirm the change. Be careful when changing quantities, budget values, or transaction records because database functions may calculate or update related information.

### Delete rows

Select the row using its checkbox, choose **Delete 1 row**, review the selection, and confirm. Supabase may block deletion if other rows depend on the selected record. Some membership links may be removed automatically with a related location or group. Do not force a deletion if you are unsure about its effects.

## 7. Use the Supabase AI Assistant carefully

The AI Assistant can help explain database relationships, locate information, explain a column, or draft read-only queries. Use it to view and understand data, not to modify the database structure or existing records.

Before running generated SQL, confirm it is a read-only `SELECT` query. Do not run `DROP`, `DELETE`, `TRUNCATE`, `ALTER`, or `UPDATE` commands without appropriate authorization and review. If you are unsure what a query does, do not run it.

## 8. Restore a downloaded table-data backup

A Database Manager can download the table-data `.sql` file from the frontend's **Manage → Data** page. To restore it, open the intended project in Supabase, go to **SQL Editor**, choose **New query**, open the downloaded file in a text editor, copy all its contents into the query, and select **Run**. Verify the selected project and file before running it.

You do not need to delete current table data first. The file is an upsert snapshot, not a generated diff: it inserts rows from the snapshot and updates rows with matching primary keys to the saved snapshot values. It does not remove rows currently in the database but absent from the snapshot. It restores table rows, not Auth accounts, schema, views, or permissions. The script manages the inventory triggers during loading and restores them after a successful run. If the database schema changed since the download, review the file before running it.

## 9. Troubleshooting

| Problem | What to check |
|---|---|
| Tables or views are missing | Confirm the intended project and the `public` schema. Check that the new-project SQL files were run in order. |
| A table looks empty | Remove active filters and verify the selected project. |
| A record cannot be found or selected | Check the spelling and whether the referenced information exists in its source table. |
| A save fails because a reference is missing | Add the referenced record first, if authorized, then retry. |
| An invitation or password-reset link cannot connect to `localhost:8000` | Start the local app before opening the email link, then reopen the link. |
| A user signs in but cannot access garden information | Ask a Database Manager to assign an app role. The first manager must be assigned by the project owner. After a role change, sign out and sign in again. |
| The app cannot connect to Supabase Auth or the Data API | Check internet access, the Project URL and Publishable key in `frontend/app.py`, and that **Enable Data API** is on. |
| An invitation email is not sent | Check Supabase Auth email delivery limits. The built-in email service has low sending limits; wait for the limit to reset or configure custom SMTP. |
| A signed-in user has no database role | Confirm the Custom Access Token hook uses **Postgres**, schema `public`, and function `custom_access_token_hook`. Then sign out and sign in again. |
| A deletion is blocked | Another record may depend on it. Do not force-delete it; ask the project maintainer to review the relationship. |

For the project creation checklist, see the [root README](../README.md#setting-up-a-new-supabase-project).
