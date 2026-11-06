# Garden Database Frontend

A web interface for the LCSD Garden Program database. It lets staff browse,
search, add, edit, and delete records in every table, and view the summary
reports (restock list, pending requests, crop calendar, and more).

The app reads the table structure (columns, types, required fields, dropdown
options) directly from the database, so it works with the existing schema and
never changes it.

> **Heads up:** this connects to the real database. Adding, editing, or
> deleting a record in the app changes the shared Supabase data immediately.
> Browsing is read-only.

## What's inside

```text
frontend/
├── app.py            # Python (Flask) server: serves the pages and talks to Postgres
├── requirements.txt  # Python packages
└── static/
    ├── index.html
    ├── app.js
    └── styles.css
```

## Requirements

- Python 3.9 or newer (`python3 --version`)
- The Supabase database connection string and password

## 1. Get the connection string from Supabase

1. Open the project in Supabase and click **Connect** at the top.
2. Choose the database connection string tab (**Direct** / **Connection string**).
3. Keep **Type** as **URI** and set **Method** to **Session pooler**.
   The "Direct connection" address only works on IPv6 networks and usually
   fails on home or school internet.
4. Copy the string. It looks like:

   ```text
   postgresql://postgres.<project-ref>:[YOUR-PASSWORD]@aws-0-us-east-1.pooler.supabase.com:5432/postgres
   ```

5. Replace `[YOUR-PASSWORD]` (including the brackets) with the database
   password. If the password contains `@ # / ? : %`, URL-encode those
   characters (for example `@` becomes `%40`).

Never commit the connection string or password to GitHub.

## 2. Install (first time only)

From the `frontend` folder:

```bash
cd frontend
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
```

On Windows, use `py -m venv .venv` and `.venv\Scripts\pip install -r requirements.txt`.

## 3. Run

macOS / Linux, from the `frontend` folder:

```bash
export DATABASE_URL='postgresql://postgres.<project-ref>:YOUR_PASSWORD@aws-0-us-east-1.pooler.supabase.com:5432/postgres'
.venv/bin/python app.py
```

Windows (PowerShell), from the `frontend` folder:

```powershell
$env:DATABASE_URL = 'postgresql://postgres.<project-ref>:YOUR_PASSWORD@aws-0-us-east-1.pooler.supabase.com:5432/postgres'
.venv\Scripts\python app.py
```

Then open <http://localhost:8000> in your browser. Stop the server with
`Ctrl+C`. `DATABASE_URL` only lasts for that terminal window, so set it again
in a new one. To use a different port, set `PORT` (for example `PORT=8080`).

## Using the app

- **Dashboard** – location and inventory counts, budget balances, items that
  need restocking, and upcoming plantings.
- **Tables** (sidebar) – each page supports search, column sorting, **+ Add**,
  **Edit**, and **Delete**. Dropdowns are filled from the related tables, and
  in Crop Rotations the bed list is filtered to the selected location.
- **Reports** – read-only pages for each summary view.

Fields the database calculates itself (`remaining_budget`, `bed_count`, and
auto-generated IDs) are shown but not editable. In purchase requests,
`unit_cost_at_request` and `total_cost` are filled in automatically when left
blank. If a database rule rejects a change (for example, checking out more
stock than is available), the error message is shown in the form.

## Windows quick start

From the `frontend` folder, run the launcher in PowerShell:

```powershell
.\Run-GardenApp.ps1
```

The launcher creates the virtual environment if needed, installs the requirements, prompts for the Supabase Session pooler URI with hidden input, opens the app in your browser, and starts the server. Press `Ctrl+C` in the PowerShell window to stop it. Python 3.9 or newer must be installed.

Only run this script from the project copy you downloaded from the trusted class repository. The app connects to the shared database, and its add, edit, and delete actions affect shared records immediately. Do not put the database URI in the script or commit it to GitHub.

## macOS / Linux quick start

From the `frontend` folder, open Terminal and run:

```bash
chmod +x ./run-garden-app.sh
./run-garden-app.sh
```

The launcher creates the virtual environment if needed, installs requirements, prompts for the Supabase Session pooler URI with hidden input, opens the app in your browser when possible, and starts the server. Press `Ctrl+C` in Terminal to stop it. Python 3.9 or newer must be installed.

## Troubleshooting

| Message | Fix |
| --- | --- |
| `could not translate host name "db.<ref>.supabase.co"` | You used the Direct connection string. Switch to **Session pooler**. |
| `password authentication failed` | Wrong password, or special characters that need URL-encoding. |
| `fe_sendauth: no password supplied` | `DATABASE_URL` isn't set in this terminal. Run the `export` line again. |
| `Address already in use` | Something else is on port 8000. Run with `PORT=8080`. |

If you change the database schema, the app picks up the changes automatically
within about five minutes (or restart the server). New tables or views need to
be added to `TABLES` or `VIEWS` at the top of `app.py` to appear in the sidebar.
