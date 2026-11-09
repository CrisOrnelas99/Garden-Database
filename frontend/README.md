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

### Install Python first

You need Python 3.9 or newer, an internet connection to install the app's Python packages, and a web browser. The launcher installs the packages listed in `requirements.txt` automatically. You do not need to install Git or a database server to run the app.

- **Windows:** Install Python from [python.org/downloads](https://www.python.org/downloads/) and reopen PowerShell. You can also use the official Python Install Manager with `winget install 9NQ7512CXL7T`. Confirm installation with `py --version`.
- **macOS:** Install Python 3 from [python.org/downloads](https://www.python.org/downloads/), then reopen Terminal and confirm with `python3 --version`.
- **Linux:** Install Python 3, its `venv` support, and `pip` with your distribution's package manager. For Ubuntu or Debian, run `sudo apt update` followed by `sudo apt install python3 python3-venv python3-pip`. Confirm with `python3 --version`.

Use the official Python downloads page if you are unsure which installer matches your computer. The database URI is needed when starting the app; enter it at the launcher's hidden prompt and never commit it to GitHub or share it in chat.

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

1. Install Python 3.9 or newer and unzip the complete GitHub repository.
2. Keep the frontend folder together. Do not move Run-GardenApp.exe out of that folder.
3. Double-click Run-GardenApp.exe. It checks GitHub for frontend file updates, installs the Python packages the first time, prompts for the Supabase Session pooler URI, and opens the app in a browser. Leave the console window open while using the app; close it to stop the app.

The updater changes frontend files only; it does not run database or SQL updates. Before replacing local frontend files, it saves a backup under %LOCALAPPDATA%\GardenDatabase\frontend-backups. The executable contains no database credentials. Enter the connection URI each time the app starts.

If the executable does not work, use the PowerShell fallback from the frontend folder:

    .\scripts\Run-GardenApp.ps1

The fallback creates the virtual environment if needed, installs the requirements, prompts for the Supabase Session pooler URI with hidden input, opens the app in your browser, and starts the server. Press Ctrl+C in the PowerShell window to stop it. Python 3.9 or newer must be installed.

If Windows says the downloaded script is not digitally signed, first make sure it came from the trusted class repository. Then, from the frontend folder, unblock only the fallback script and run it:

    Unblock-File .\scripts\Run-GardenApp.ps1
    .\scripts\Run-GardenApp.ps1

This removes the downloaded-file mark from this one script; it does not change PowerShell's execution policy. Only run scripts from the trusted class repository.

## macOS / Linux quick start

The Windows executable and PowerShell fallback are for Windows. On macOS or Linux, use the manual setup commands from the frontend folder:

    python3 -m venv .venv
    .venv/bin/python -m pip install -r requirements.txt
    export DATABASE_URL='postgresql://postgres.<project-ref>:YOUR_PASSWORD@aws-0-us-east-1.pooler.supabase.com:5432/postgres'
    .venv/bin/python app.py

Replace the example URI with the project's Supabase Session pooler URI. Open http://localhost:8000 in a browser and press Ctrl+C in Terminal to stop the server.

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

