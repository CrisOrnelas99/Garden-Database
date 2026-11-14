# Garden Database Frontend

This guide is for day-to-day users of the Garden Program app. Users download this repository from GitHub and run the app locally from its `frontend` folder on their own computer. The app signs each user in through Supabase Auth and uses their authenticated session to access the shared Supabase project through its Data API, where app changes are saved. The app itself is not hosted as a public website.

## What users need

- Python 3.9 or newer
- Internet access
- A Garden Program account invited by a manager
- The account's email and password

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

If Windows reports the downloaded script is not digitally signed, check that the GitHub page you downloaded from has the Garden Database repository name and the owner/account your project manager gave you. If either does not match, delete that download and get the correct repository link from your project manager. If both match, unblock only this script and run it:

```powershell
Unblock-File .\scripts\Run-GardenApp.ps1
.\scripts\Run-GardenApp.ps1
```

The updater updates frontend files only.

If the executable and PowerShell launcher both fail, start the app manually. Open PowerShell in the `frontend` folder and run:

```powershell
py -m venv .venv
.\.venv\Scripts\python.exe -m pip install -r requirements.txt
.\.venv\Scripts\python.exe app.py
```

Open <http://localhost:8000> and keep the PowerShell window open while using the app.

To stop the local server, click the PowerShell or console window and press **Ctrl+C**, or close that window with the **X**. The app will stop running.

## macOS / Linux quick start

From the `frontend` directory:

```bash
python3 -m venv .venv
.venv/bin/python -m pip install -r requirements.txt
.venv/bin/python app.py
```

Open <http://localhost:8000>, sign in, and press Ctrl+C in Terminal to stop the server.

## Accepting an invitation

The project administrator sends new-account invitations from Supabase. Start the local app before opening the invitation email. The standard invitation link signs you in temporarily and opens **Set your password**. Enter and confirm your password, save it, and then sign in with your email and chosen password.

Keep the app running at `http://localhost:8000` while opening email links. Reloading the same tab during password setup keeps the setup screen. If the invitation was already accepted or has expired, use **Forgot password?** to request a new reset link for the existing account. Invitation sending remains in the Supabase dashboard.

## Resetting a password

On the sign-in screen, click **Forgot password?**, enter your account email, and click **Send reset email**. The response does not reveal whether an account exists for that address. Supabase's email delivery settings and sending limits still apply.

Keep the local app and its console window open before opening the reset email. The link opens the local app, where you can enter and confirm a new password. After saving it, sign in with the new password. If the link has expired or was already used, request a new reset email. If you see a connection error, start the app and reopen the email link.

## Permissions and data

- The app's sign-in uses each person's invited Supabase Auth account. A manager must assign that account one of the app roles before it can access records.
- Supabase enforces table and report permissions for every signed-in request. The app shows controls that match those permissions, and database policies remain the authority.
- Changes made in this app affect the shared Supabase data immediately. The local app does not modify database schema.

## Navigation menu

Use the menu on the left to open a page. The pages shown depend on your role. Choose a page under its section; the sections stay open, and the current page is highlighted.

- **Database Manager:** Dashboard, Inventory & Budget, Gardens, Locations, Reports, and Manage (Users, Data, and Log).
- **Finance Staff:** Dashboard, Inventory & Budget, Gardens, Locations, and all Reports.
- **Staff:** Dashboard, Inventory, Gardens, Locations, and Reports without budget information.

## Working with tables and reports

Open a page from the left menu. Tables contain editable records; reports present information for review. Reports are read-only, so update the source information in its table. The pages and data available depend on your app role.

### Reports

Reports are read-only views prepared by the database from information in one or more tables. They can bring related information together or show calculated summaries, so a report may not correspond to a single table row. Use reports to review information; to change something, find and edit the appropriate source record in its table. Reports reflect the underlying data when they are loaded.

### Search, sort, and download

- **Search:** Type in the search box to find text across the displayed row information. Select **+** to add up to two more search boxes. When multiple searches are filled in, a row must match every search term. Use **×** to remove an added search box. Results update as you type.
- **Sort:** Select a column heading to sort by that column. Select it again to reverse the order.
- **Download PDF:** Select the download button to save the table or report currently shown as a PDF. It includes the current search results and sort order. Notes and edit/delete controls are omitted. For crop rotations, switch to **Table** mode before downloading.

The **Item Spending** report summarizes purchasing by item. It shows the number of non-canceled purchase requests, total quantity ordered, total spending for ordered and delivered requests, and average unit cost. Canceled requests are not included in those totals.

The **School Supply** report has three modes: **Overview** shows current checked-out totals, pending purchase-request counts, and spending; **Purchase Requests** lists pending requests associated with each school or group; and **Checked Out Items** shows current checked-out quantities by item and school/group. Delivered and canceled requests are not counted as pending.

The **Yearly Purchases** report can be switched between a yearly summary and a monthly view. The monthly view shows the School Year beside each Purchase Month, along with ordered purchase-request count, ordered quantity, and spending. Dated requests use a readable month and year label such as `May 2026`; requests without a date appear in a separate `No date` row for their school year.

### Add and edit information

On a table page, select **+ Add** to create a record. To change an existing record, select **Edit** in its row, update the form, and save. Use the available selection lists for fields linked to other records, and leave database-generated fields alone. A report does not have add or edit controls; make changes in the related table instead.

An **ID** is an internal identifier the database uses to distinguish a record and connect it to related information. Leave ID fields as they are; the app and database handle them. Some fields link one record to another. These are foreign keys. When adding or editing information, choose a linked record from the selection list so the relationship points to an existing record. In a table, linked values that look clickable can be selected to preview information from the related record.

### Delete information

If **Delete** is available for a row, select it and confirm. A deletion may be blocked if other information depends on that record. Delete permissions also depend on your role:

- **Staff:** Can delete purchase requests and inventory transactions only when their request or transaction date is today. Cannot delete other rows.
- **Finance Staff:** Can delete budget rows and purchase requests or inventory transactions dated today. Cannot delete other rows.
- **Database Manager:** Can delete rows in other tables. Purchase requests and inventory transactions can be edited or deleted only when their request or transaction date is today.

The same-day rule is based on the date stored in the row. Rows with a blank or earlier date cannot be edited or deleted under this rule. For other tables, Staff and Finance Staff can edit information but cannot delete those rows.

## Manager pages

### Users

Database Managers can search for accounts, set a user's display name, assign or remove the **Staff**, **Finance Staff**, or **Database Manager** app role, and send a password-reset email. Managers cannot change or remove their own role in the app.

New account invitations and Auth account removal are handled in Supabase by the organization administrator. The project owner can also revoke a manager's app role through the Supabase SQL Editor. See the [Supabase user guide](../docs/supabase_user_guide.md) for account-management and SQL instructions.

### Data

Managers can download all Garden Program table rows together as an insertable SQL backup. Save the backup somewhere safe outside the `Garden-Database` folder. If Garden Program data is deleted or lost, a Supabase project administrator can run the latest downloaded file in the Supabase SQL Editor to restore the table rows captured in that snapshot.

This page also has a configurable reminder to download weekly, every two weeks, or monthly, or to turn reminders off. The reminder appears while the app is open.

### Log

Managers can review recorded table additions, edits, and deletions, along with app events such as role or display-name changes, password-reset requests, and data downloads. The Log page includes timestamps, search and date filters, and details about the changed information.

The **Plant Count** report summarizes each plant across the program. It shows the current location count, planned quantity, current total quantity (Planned plus In-ground), in-ground quantity, harvested quantity, and removed quantity. Current locations include only Planned and In-ground rotations.

## Troubleshooting

| Message | Fix |
| --- | --- |
| `Python was not found` | Install Python 3.9 or newer, then reopen PowerShell or Terminal. |
| `Could not reach Supabase Auth` / `Data API` | Check internet access and try again. |
| `no Garden Program role` | Ask the manager to assign a role to the same email used to sign in. |
| `Invalid login credentials` | Check the invited account's email and password. |
| `Address already in use` | Stop the other local app instance, or start with `PORT=8080` (macOS/Linux) / `$env:PORT=8080` (PowerShell), then open <http://localhost:8080>. |
| A role or access change has not appeared | Sign out and sign back in to refresh access. If the user still cannot see a page or data, ask the manager to confirm the assigned role. |
| The app still looks outdated after an update | Close the app, run the updater again, then refresh the browser page. |

