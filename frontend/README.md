# Garden Database Frontend

A local web app for the LCSD Garden Program. The app runs on each user's computer at `http://localhost:8000` and connects to the shared Supabase project over the Supabase Auth and Data APIs. It is not a public website.

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

**One-time setup for an existing project:** the project owner must run the entire [`sql/manager_user_access.sql`](../sql/manager_user_access.sql) file in the Supabase SQL Editor, then restart the local app. Fresh database setups already get these functions from `sql/schema_roles.sql`; the separate file updates an existing project without rerunning the whole schema. The app and its updater never apply SQL automatically.

## Troubleshooting

| Message | Fix |
| --- | --- |
| `Python was not found` | Install Python 3.9 or newer, then reopen PowerShell or Terminal. |
| `Could not reach Supabase Auth` / `Data API` | Check internet access and try again. |
| `no Garden Program role` | Ask the manager to assign a role to the same email used to sign in. |
| `Invalid login credentials` | Check the invited account's email and password. |
| `Address already in use` | Stop the other local app instance, or start with `PORT=8080` (macOS/Linux) / `$env:PORT=8080` (PowerShell). |

