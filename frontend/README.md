# Garden Database Frontend

A local web app for the LCSD Garden Program. The app runs on each user's computer at `http://localhost:8000` and connects to the shared Supabase project over the Supabase Auth and Data APIs. It is not a public website.

## Project administrator: set up a new Supabase project

Use this checklist when creating a replacement Supabase project for the app. The project owner performs these steps. Partners do not need Supabase organization or dashboard accounts to use the frontend; they need an invited Auth user in this project.

### 1. Create the project and enable its Data API

Create or select the Supabase organization, then create a project inside it. Keep the database password in the project administrator's password manager; partners do not use it.

In the project dashboard, open **Integrations → Data API** (or **Project Settings → Data API**, depending on the dashboard layout). Make sure the Data API is enabled and `public` is an exposed schema. `public` is usually exposed by default. Do not expose the `private` schema; it stores role assignments for the Auth hook. Supabase documents the [Data API](https://supabase.com/docs/guides/api) and [API schema exposure](https://supabase.com/docs/guides/api/using-custom-schemas).

### 2. Configure Auth email sign-in and local redirects

In **Authentication → URL Configuration**, set the **Site URL** to:

```text
http://localhost:8000/
```

Add the same URL to **Redirect URLs**. The invite and password-reset links must return to the local app. In **Authentication → Sign In / Providers → Email**, keep email/password sign-in enabled and turn off **Allow new users to sign up** so accounts are invitation-only. Supabase Auth sends the invitations and reset links; its built-in email service has low sending limits, so configure custom SMTP if its limits or delivery are not sufficient. See [Auth redirect URLs](https://supabase.com/docs/guides/auth/redirect-urls) and [inviting users](https://supabase.com/docs/guides/auth/users).

### 3. Create the schema, views, and roles

As the project owner, open **SQL Editor** and run each file from this repository, in order, one at a time:

1. [`sql/schema_garden.sql`](../sql/schema_garden.sql)
2. [`sql/schema_inventory.sql`](../sql/schema_inventory.sql)
3. [`sql/summary_views.sql`](../sql/summary_views.sql)
4. [`sql/demo_data.sql`](../sql/demo_data.sql), only if you want the prewritten starter records
5. [`sql/roles_and_permissions.sql`](../sql/roles_and_permissions.sql), last

The last file creates the PostgreSQL roles, permissions and policies, the private role-assignment table, the access-token hook, manager functions, display-name profiles, and private audit logging. Do not run it before creating the tables and views. For an existing project, review project-specific SQL changes before rerunning this consolidated setup file.

### 4. Enable the Custom Access Token Hook

In **Authentication → Hooks** (shown as **Hooks (Beta)** in some dashboards), add or enable a **Custom Access Token** hook. Select **Postgres**, schema **`public`**, and function **`custom_access_token_hook`**. Do not select HTTPS; the function was created by `roles_and_permissions.sql`.

Before Supabase issues a sign-in token, this hook looks up the user's role in `private.user_role_assignment` and puts that role in the token's `role` claim. Supabase then uses that role when enforcing database grants and row policies. A user without an assignment receives no Garden Program data role and cannot access app records. See Supabase's [Custom Access Token Hook guide](https://supabase.com/docs/guides/auth/auth-hooks/custom-access-token-hook).

### 5. Bootstrap the first Database Manager

First create the initial manager's Auth user: open **Authentication → Users → Add user → Send invitation**, enter the manager's email, and send the invitation. This creates the Auth user; it does not give them Supabase dashboard or organization membership.

As the project owner, run this in SQL Editor, replacing the example email with the exact invited email:

```sql
INSERT INTO private.user_role_assignment (user_id, database_role)
SELECT u.id, 'database_manager'
FROM auth.users AS u
WHERE lower(u.email) = lower('manager@example.com')
ON CONFLICT (user_id)
DO UPDATE SET database_role = EXCLUDED.database_role
RETURNING user_id, database_role;
```

The query should return one row with `database_manager`. If it returns no rows, confirm that the invitation created an Auth user and that the email matches. The manager should start the local app before opening the invitation email, set their password, and sign in. Once signed in, they can assign roles from the app's **Manage Users** page; only a project owner can do the initial bootstrap.

#### Emergency app-role recovery (project owner only)

Use these commands in the Supabase SQL Editor as the project owner. They change app-role assignments only; they do not delete Auth accounts or program records.

To revoke one person's app access while keeping their Auth account, replace the example email:

```sql
DELETE FROM private.user_role_assignment AS assignment
USING auth.users AS account
WHERE assignment.user_id = account.id
  AND lower(account.email) = lower('person@example.com')
RETURNING assignment.user_id, assignment.database_role;
```

To revoke every app role (this removes app access for everyone and leaves no manager who can restore access through the app):

```sql
DELETE FROM private.user_role_assignment
RETURNING user_id, database_role;
```

To restore a Database Manager or bootstrap a replacement, replace the example email with an existing Auth user's email:

```sql
INSERT INTO private.user_role_assignment (user_id, database_role)
SELECT u.id, 'database_manager'
FROM auth.users AS u
WHERE lower(u.email) = lower('manager@example.com')
ON CONFLICT (user_id)
DO UPDATE SET database_role = EXCLUDED.database_role
RETURNING user_id, database_role;
```

Role changes take effect when affected users receive a refreshed sign-in token. If all roles were removed, only the project owner can restore a manager with the SQL above.

### 6. Point the frontend at the new project

In the dashboard, copy the **Project URL** from **Integrations → Data API** and the **Publishable key** from **Project Settings → API Keys**. In `frontend/app.py`, replace the default values for `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` with those values. Use the project's base URL (for example, `https://<project-ref>.supabase.co`), not a `postgresql://` connection string.

The project URL and publishable key are intended for app use and may be in the public repository. Never put the database password, a Supabase secret key (`sb_secret_...`), or the legacy `service_role` key in the frontend or GitHub. Each request also carries the user's signed-in Auth token, and the SQL roles and policies enforce access. See [Supabase API keys](https://supabase.com/docs/guides/api/api-keys) and [API security](https://supabase.com/docs/guides/api/securing-your-api).

Commit and push the updated frontend configuration before partners download or update the app. The Windows updater gets its files from the repository's `main` branch, so leaving the new project URL/key only in a local copy will not configure copies downloaded by partners.

### 7. Invite the rest of the team

For each partner, go to **Authentication → Users → Add user → Send invitation** and invite their email. Do not add partners as Supabase organization or project members just so they can use the app. They open the local app, accept the invitation, set a password, and sign in. A Database Manager then selects their account and assigns `staff`, `finance_staff`, or `database_manager` on **Manage Users**. Until a role is assigned, the user cannot access app data. Supabase describes this as an [Auth user invitation](https://supabase.com/docs/guides/auth/users#inviting-users); it is separate from inviting someone to the Supabase organization.

### Security model in brief

The app no longer uses a shared PostgreSQL pooler URL. That connection used one database identity for every partner. Instead, each person signs in through Supabase Auth, and the app sends that user's signed token to the Supabase Data API. The custom token hook maps the Auth user to a database role; Postgres grants and policies decide what that role can do. The public publishable key identifies the project, while the signed user token and database permissions control access. Partners use the local app only; changes they make there are saved to this shared Supabase project.

## What partners need

- Python 3.9 or newer
- Internet access
- A Garden Program account invited by a manager
- The account's email and password

Partners do **not** need a Supabase database password or connection URI. They sign in through the app. Supabase applies each account's assigned role to its data access.

### Install Python

- **Windows:** Install Python from [python.org/downloads](https://www.python.org/downloads/) and select the Python launcher option. Reopen PowerShell and confirm with `py --version`.
- **macOS:** Install Python 3 from [python.org/downloads](https://www.python.org/downloads/) and confirm with `python3 --version` in Terminal.
- **Linux:** Install Python 3, `venv`, and `pip` using your distribution's package manager. For Ubuntu or Debian: `sudo apt update` then `sudo apt install python3 python3-venv python3-pip`.

## Windows quick start

1. Download the repository ZIP from GitHub (**Code → Download ZIP**) and unzip it.
2. Open the extracted `Garden-Database-main` folder, then open `frontend`. Keep the folder together; do not move `Run-GardenApp.exe` by itself.
3. Double-click `Run-GardenApp.exe`. It checks for frontend file updates, creates the Python environment and installs required packages the first time, then opens the local app in your browser. Leave its console window open while using the app.
4. Sign in with the email and password for your invited Garden Program account.

If the executable is blocked or does not work, from PowerShell opened in `frontend`, run:

```powershell
.\scripts\Run-GardenApp.ps1
```

If Windows reports the downloaded script is not digitally signed, confirm it came from the trusted class repository, then unblock only this script and run it:

```powershell
Unblock-File .\scripts\Run-GardenApp.ps1
.\scripts\Run-GardenApp.ps1
```

Press Ctrl+C in the console window to stop the local server. The updater updates frontend files only; it does not apply SQL or database schema updates. It keeps a backup of previous frontend files under `%LOCALAPPDATA%\GardenDatabase\frontend-backups`.

## macOS / Linux quick start

From the `frontend` directory:

```bash
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
.venv/bin/python app.py
```

Open <http://localhost:8000>, sign in, and press Ctrl+C in Terminal to stop the server.

## Manual Windows setup

From PowerShell in the `frontend` directory:

```powershell
py -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe app.py
```

Open <http://localhost:8000> and sign in. Leave the PowerShell window open while using the app; Ctrl+C stops it.

## Accepting an invitation

The project administrator sends new-account invitations from Supabase. Start the local app before opening the invitation email. The standard invitation link signs you in temporarily and opens **Set your password**. Enter and confirm your password, save it, and then sign in with your email and chosen password.

Keep the app running at `http://localhost:8000` while opening email links. Reloading the same tab during password setup keeps the setup screen. If the invitation was already accepted or has expired, use **Forgot password?** to request a new reset link for the existing account. Invitation sending remains in the Supabase dashboard.

## Resetting a password

On the sign-in screen, click **Forgot password?**, enter your account email, and click **Send reset email**. The response does not reveal whether an account exists for that address. Supabase's email delivery settings and sending limits still apply.

Keep the local app and its console window open before opening the reset email. The link opens the local app, where you can enter and confirm a new password. After saving it, sign in with the new password. If the link has expired or was already used, request a new reset email. If you see a connection error, start the app and reopen the email link.

## Reading long notes

Hover over a Notes cell to read its full text in a popup. You can also focus it with the keyboard or tap it on a touchscreen. The preview wraps text and preserves line breaks, and long notes can be scrolled inside the popup. Press Escape or click outside to close it. The table's row heights and column widths stay unchanged.

## Navigation menu

The sidebar groups pages under **Locations**, **Gardens**, **Inventory & Budget**, **Reports**, and **Manage** where permitted. Sections stay expanded so their links are always visible. The current page and its section are highlighted. Keyboard users can Tab directly through the links.

## Unsaved changes

If you change a record form, the app asks before discarding your edits through **Cancel**, the close button, **Escape**, page navigation, or sign-out. Unchanged forms close without a warning. Refreshing or closing the browser tab may display the browser's own warning; browsers control that message and cannot guarantee it in every situation, such as a forced browser shutdown. The warning does not save a draft.

Unsaved role selections are preserved while searching the Users list. Refreshing that list, leaving it, or signing out asks before discarding pending role changes. Saving one person's role keeps any other pending selections. Entered new passwords also trigger a warning before leaving the password-reset form.

## Permissions and data

- The app's sign-in uses each person's invited Supabase Auth account. A manager must assign that account one of the app roles before it can access records.
- Supabase enforces table and report permissions for every signed-in request. The app shows controls that match those permissions, and database policies remain the authority.
- Changes made in this app affect the shared Supabase data immediately. The local app does not modify database schema.

## Managing users

Database managers have a **Users** page in the sidebar. Search for an existing account, choose **Staff**, **Finance Staff**, or **Database Manager**, and click **Save**. Use **Remove access** to remove an app role while keeping the account and its records. Changes require confirmation. You cannot change or remove your own manager role.

Managers can click **Send password reset email** next to an account and confirm the recipient. Supabase sends the reset link; the manager never sees or chooses the password. The recipient must run their local app at `http://localhost:8000` before opening the link, then use the existing new-password form. Accounts without an email address cannot receive a reset email. Supabase email limits and delivery settings still apply.

The project administrator should allow `http://localhost:8000/` in Supabase Auth's URL Configuration so recovery links return to the local app. This feature uses the public publishable key and the existing manager directory function; no secret key or additional SQL update is needed beyond the Users page setup below.

New account invitations are still sent through Supabase by the project administrator. Users appear here once their Auth accounts exist, including accounts with no assigned role. Initial manager assignment still uses the SQL Editor as described in the database setup guide.

Role changes apply when the user's token refreshes or expires. Refreshing the browser page now requests a fresh sign-in token and reloads permissions; the user can also sign out and sign in again. An already-open page does not instantly receive changes from another person's computer. The management functions also check the manager's current database assignment, so a removed manager cannot keep assigning roles using an old token.

For an existing project that already has the row-change audit log, run [`sql/application_event_log.sql`](../sql/application_event_log.sql) once in Supabase SQL Editor to add account/app events. Fresh projects get both audit streams from [`sql/roles_and_permissions.sql`](../sql/roles_and_permissions.sql). The app and its updater never apply SQL automatically.

## Troubleshooting

| Message | Fix |
| --- | --- |
| `Python was not found` | Install Python 3.9 or newer, then reopen PowerShell or Terminal. |
| `Could not reach Supabase Auth` / `Data API` | Check internet access and try again. |
| `no Garden Program role` | Ask the manager to assign a role to the same email used to sign in. |
| `Invalid login credentials` | Check the invited account's email and password. |
| `Address already in use` | Stop the other local app instance, or start with `PORT=8080` (macOS/Linux) / `$env:PORT=8080` (PowerShell). |

