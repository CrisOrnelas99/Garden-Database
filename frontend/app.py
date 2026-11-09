"""Local Flask app; authenticated data requests are enforced by Supabase Postgres roles."""

import base64
import copy
import datetime
import json
import os
from urllib.parse import quote

import requests
from flask import Flask, g, jsonify, request, send_from_directory

# These are the public Supabase project URL and publishable key. They identify
# the project and are safe to include in the public GitHub repository. Access
# is protected by Supabase Auth and the database role/RLS policies below; never
# put a database password, secret key, or service-role key in this app.
SUPABASE_URL = os.environ.get("SUPABASE_URL", "https://ecpxuuzqumtdhlewbmdt.supabase.co").rstrip("/")
SUPABASE_PUBLISHABLE_KEY = os.environ.get("SUPABASE_PUBLISHABLE_KEY", "sb_publishable_eBf3BZwPQvO9nHC1eD64Fg_Uit1YMGg")
ROLES = {"staff", "finance_staff", "database_manager"}

TABLES = {
    "location": {"label": "Locations", "group": "Locations", "readonly": ["bed_count"]},
    "location_group": {"label": "Location Groups", "group": "Locations"},
    "group_members": {"label": "Group Members", "group": "Locations"},
    "budget": {"label": "Budgets", "group": "Inventory & Budget", "readonly": ["remaining_budget"]},
    "item": {"label": "Item Catalog", "group": "Inventory & Budget"},
    "inventory_list": {"label": "Inventory", "group": "Inventory & Budget"},
    "purchase_request": {"label": "Purchase Requests", "group": "Inventory & Budget"},
    "inventory_transaction": {"label": "Check In / Out", "group": "Inventory & Budget"},
    "garden_bed": {"label": "Garden Beds", "group": "Gardens"},
    "irrigation_setup": {"label": "Irrigation", "group": "Gardens"},
    "compost_unit": {"label": "Compost Units", "group": "Gardens"},
    "plant": {"label": "Plants", "group": "Gardens"},
    "crop_rotation": {"label": "Crop Rotations", "group": "Gardens"},
}
VIEWS = {
    "CropCalendar": "Crop Calendar", "CurrentBedPlantings": "Current Bed Plantings",
    "GardenAssets": "Garden Assets", "RestockList": "Restock List",
    "PendingRequests": "Pending Requests", "SchoolSupply": "School Supply",
    "BudgetPurchases": "Budget Purchases", "FundingSourceSpending": "Funding Source Spending",
    "YearlyPurchase": "Yearly Purchases",
}
ENUMS = {
    "condition": ["Good", "Require Maintenance", "In Maintenance"],
    "lifecycle_status": ["Active", "Planned", "Inactive"],
    "rotation_status": ["Planned", "In-ground", "Removed", "Harvested"],
    "soil_health_status": ["Good", "Fair", "Needs Replacement"],
    "inventory_transaction_status": ["Checked Out", "Checked In"],
}

# Describe which related table supplies a field's dropdown options.
def ref(table, column, depends=None):
    return {"ref_table": table, "ref_column": column, "depends_on": depends or {}}

# Describe a field's type, default value, choices, and editing rules for the form.
def column(name, kind, nullable=True, default=None, length=None, domain=None, enum=None, fk=None, readonly=False):
    return {
        "name": name, "data_type": kind, "udt_schema": "public",
        "udt_name": enum or kind.replace(" ", "_"), "domain_name": domain,
        "nullable": nullable, "default_value": default, "max_length": length,
        "readonly": readonly, "enum": ENUMS.get(enum) if enum else None,
        "foreign_key": fk, "required": not nullable and default is None and not readonly,
    }

# Describe an ID that the database creates automatically and users cannot edit.
def serial(name):
    return column(name, "integer", False, "nextval(...)", readonly=True)

# Describe a short text field with a maximum number of characters.
def varchar(name, length, nullable=True, default=None, fk=None):
    return column(name, "character varying", nullable, default, length, fk=fk)

# Describe a longer text field, such as notes or comments.
def text(name, nullable=True):
    return column(name, "text", nullable)

# Describe a yes-or-no field and its default value.
def boolean(name, nullable=True, default=None):
    return column(name, "boolean", nullable, default)

# Describe a whole-number field, such as an item quantity.
def integer(name, nullable=True, default=None, domain=None):
    return column(name, "integer", nullable, default, domain=domain)

# Describe a number field that can include decimals, such as a price.
def numeric(name, nullable=True, default=None, domain=None):
    return column(name, "numeric", nullable, default, domain=domain)

# Describe a date field and any default date the database supplies.
def date(name, nullable=True, default=None):
    return column(name, "date", nullable, default)

# Describe a field with a fixed list of choices, such as a status.
def enum(name, type_name, nullable=True, default=None):
    return column(name, "USER-DEFINED", nullable, default, enum=type_name)

# Combine a table's field descriptions and mark calculated fields as read-only.
def table(name, pk, columns):
    readonly_names = set(TABLES[name].get("readonly", []))
    for item in columns:
        if item["name"] in readonly_names:
            item["readonly"] = True
            item["required"] = False
    return {"name": name, **TABLES[name], "pk": pk, "columns": columns}

SCHEMAS = {
    "location": table("location", ["location_id"], [
        serial("location_id"), varchar("location_name", 200, False), varchar("contact", 100),
        varchar("email", 200), boolean("is_hlc", False, "false"), enum("garden_status", "lifecycle_status"),
        enum("garden_condition", "condition"), integer("bed_count", domain="nonnegative_count"), text("notes"),
    ]),
    "location_group": table("location_group", ["location_group_id"], [
        serial("location_group_id"), varchar("location_group_name", 200, False),
    ]),
    "group_members": table("group_members", ["location_group_name", "location_name"], [
        varchar("location_group_name", 200, False, fk=ref("location_group", "location_group_name")),
        varchar("location_name", 200, False, fk=ref("location", "location_name")),
    ]),
    "budget": table("budget", ["budget_id"], [
        serial("budget_id"), varchar("budget_name", 100, False), numeric("budget_amount", False, domain="dollar"),
        numeric("remaining_budget", domain="dollar"), text("notes"),
    ]),
    "item": table("item", ["item_id"], [
        serial("item_id"), varchar("item_name", 200, False), varchar("category", 50),
        varchar("vendor_name", 50), text("link"), numeric("unit_cost", domain="dollar"), text("notes"),
    ]),
    "inventory_list": table("inventory_list", ["inventory_id"], [
        serial("inventory_id"), varchar("item_name", 200, False, fk=ref("item", "item_name")),
        integer("cumulative_asset", False, "0", "nonnegative_count"),
        integer("instock_total", False, "0", "nonnegative_count"),
        integer("reorder_point", domain="nonnegative_count"), boolean("counted", False, "false"),
        varchar("storage_location", 200), text("notes"),
    ]),
    "purchase_request": table("purchase_request", ["request_id"], [
        serial("request_id"), date("request_date", default="CURRENT_DATE"), varchar("requested_by", 50, False),
        varchar("requesting_school", 200, fk=ref("location", "location_name")),
        varchar("requesting_school_group", 200, fk=ref("location_group", "location_group_name")),
        varchar("item_name", 200, False, fk=ref("item", "item_name")),
        numeric("unit_cost_at_request", domain="dollar"), integer("quantity_requested", domain="nonnegative_count"),
        numeric("total_cost", False, "0", "dollar"), boolean("delivered_to_fns", False, "false"),
        text("review_status"), boolean("ordered", False, "false"),
        varchar("budget_name", 100, fk=ref("budget", "budget_name")),
        varchar("funding_source", 100), varchar("school_year", 9), text("notes"),
    ]),
    "inventory_transaction": table("inventory_transaction", ["transaction_id"], [
        serial("transaction_id"), date("transaction_date", default="CURRENT_DATE"),
        enum("status", "inventory_transaction_status", False), varchar("taken_by", 50, False),
        varchar("for_school", 200, fk=ref("location", "location_name")),
        varchar("for_school_group", 200, fk=ref("location_group", "location_group_name")),
        varchar("item_name", 200, False, fk=ref("inventory_list", "item_name")),
        integer("quantity", False, domain="nonnegative_count"), text("notes"),
    ]),
    "garden_bed": table("garden_bed", ["bed_id"], [
        serial("bed_id"), varchar("location_name", 200, False, fk=ref("location", "location_name")),
        varchar("bed_name", 100, False), varchar("bed_type", 50), numeric("bed_size_sq_ft"),
        enum("lifecycle_status", "lifecycle_status"), enum("condition", "condition"),
        boolean("is_full", False, "false"), text("notes"),
    ]),
    "irrigation_setup": table("irrigation_setup", ["irrigation_id"], [
        serial("irrigation_id"), varchar("location_name", 200, False, fk=ref("location", "location_name")),
        varchar("irrigation_name", 100, False), varchar("irrigation_type", 100),
        enum("lifecycle_status", "lifecycle_status"), enum("condition", "condition"), text("notes"),
    ]),
    "compost_unit": table("compost_unit", ["compost_unit_id"], [
        serial("compost_unit_id"), varchar("location_name", 200, False, fk=ref("location", "location_name")),
        varchar("unit_name", 100, False), varchar("compost_type", 100),
        enum("lifecycle_status", "lifecycle_status"), enum("condition", "condition"), text("notes"),
    ]),
    "plant": table("plant", ["plant_id"], [
        serial("plant_id"), varchar("plant_name", 100, False), varchar("plant_type", 50),
        varchar("growing_period", 100), integer("days_to_harvest", domain="nonnegative_count"), text("notes"),
    ]),
    "crop_rotation": table("crop_rotation", ["rotation_id"], [
        serial("rotation_id"), enum("status", "rotation_status", default="'Planned'::rotation_status"),
        varchar("location_name", 200, False, fk=ref("location", "location_name")),
        varchar("bed_name", 100, False, fk=ref("garden_bed", "bed_name", {"location_name": "location_name"})),
        varchar("plant_name", 100, False, fk=ref("plant", "plant_name")),
        integer("quantity", domain="nonnegative_count"), varchar("season", 20), date("sow_date"),
        enum("soil_health", "soil_health_status"), text("notes"),
    ]),
}

STAFF_PURCHASE_COLUMNS = [
    "request_id", "request_date", "requested_by", "requesting_school", "requesting_school_group",
    "item_name", "quantity_requested", "unit_cost_at_request", "total_cost", "delivered_to_fns",
    "review_status", "ordered", "school_year", "notes",
]
STAFF_VIEWS = {"CropCalendar", "CurrentBedPlantings", "GardenAssets", "RestockList", "PendingRequests", "SchoolSupply"}
STAFF_VIEW_COLUMNS = {
    "PendingRequests": ["request_date", "request_status", "item_name", "requested_by", "assigned_locations",
                        "quantity_requested", "total_cost", "review_status", "notes"],
    "SchoolSupply": ["assignment_type", "location_name", "items_currently_checked_out", "purchase_items_pending"],
}

class ApiError(Exception):
    # Store an app error message, its response status, and any extra details.
    def __init__(self, message, status=400, detail=None):
        super().__init__(message)
        self.message, self.status, self.detail = message, status, detail

app = Flask(__name__, static_folder="static", static_url_path="")

# Send app errors back to the browser in a consistent, readable format.
@app.errorhandler(ApiError)
def handle_api_error(err):
    return jsonify({"error": err.message, "detail": err.detail}), err.status

# Read the token details; Supabase checks the token before these details are trusted.
def decode_claims(token):
    try:
        part = token.split(".")[1]
        part += "=" * (-len(part) % 4)
        return json.loads(base64.urlsafe_b64decode(part.encode("ascii")))
    except Exception:
        raise ApiError("Your sign-in session is invalid. Please sign in again.", 401)

# Ask Supabase to validate the user's token, then remember their account and assigned role.
def authenticate_request():
    authorization = request.headers.get("Authorization", "")
    if not authorization.startswith("Bearer "):
        raise ApiError("Please sign in to continue.", 401)
    token = authorization[7:].strip()
    try:
        response = requests.get(
            f"{SUPABASE_URL}/auth/v1/user",
            headers={"apikey": SUPABASE_PUBLISHABLE_KEY, "Authorization": f"Bearer {token}"},
            timeout=15,
        )
    except requests.RequestException:
        raise ApiError("Could not reach Supabase Auth. Check your internet connection.", 503)
    if response.status_code != 200:
        raise ApiError("Your sign-in session has expired. Please sign in again.", 401)
    role = decode_claims(token).get("role")
    if role not in ROLES:
        raise ApiError("This account has no Garden Program role assigned yet.", 403)
    g.access_token, g.auth_user, g.role = token, response.json(), role

# Require a valid sign-in before handling any app data request.
@app.before_request
def require_auth():
    if request.path.startswith("/api/"):
        authenticate_request()

# Tell the browser not to save copies of app responses in its cache.
@app.after_request
def disable_caching(response):
    response.headers["Cache-Control"] = "no-store"
    return response

# Send a data request to Supabase using the signed-in user's token and report any errors.
def rest_request(method, resource, params=None, body=None, range_header=None, prefer=None):
    headers = {
        "apikey": SUPABASE_PUBLISHABLE_KEY,
        "Authorization": f"Bearer {g.access_token}",
        "Accept-Profile": "public", "Content-Profile": "public",
    }
    if range_header:
        headers["Range-Unit"], headers["Range"] = "items", range_header
    if prefer:
        headers["Prefer"] = prefer
    try:
        response = requests.request(
            method, f"{SUPABASE_URL}/rest/v1/{quote(resource, safe='/')}",
            headers=headers, params=params, json=body, timeout=30,
        )
    except requests.RequestException:
        raise ApiError("Could not reach the Supabase Data API. Check your internet connection.", 503)
    if not response.ok:
        try:
            error = response.json()
        except ValueError:
            error = {}
        message = error.get("message") or error.get("error") or f"Supabase request failed ({response.status_code})"
        detail = error.get("details") or error.get("hint")
        raise ApiError(message, response.status_code if response.status_code < 500 else 502, detail)
    if not response.content:
        return []
    try:
        return response.json()
    except ValueError:
        return []

# Load records from Supabase in batches so large results can span multiple responses.
def fetch_rows(resource, select="*", order=None, extra_params=None):
    params = list(extra_params or []) + [("select", select)]
    if order:
        params.append(("order", ",".join(f"{field}.asc" for field in order)))
    results, offset, page_size = [], 0, 1000
    while True:
        rows = rest_request("GET", resource, params, range_header=f"{offset}-{offset + page_size - 1}")
        if not isinstance(rows, list):
            raise ApiError("Unexpected response from Supabase.", 502)
        results.extend(rows)
        if len(rows) < page_size:
            return results
        offset += page_size

# Check that the requested table exists in the app and block staff from budgets.
def ensure_table(name):
    if name not in TABLES:
        raise ApiError(f"Unknown table: {name}", 404)
    if g.role == "staff" and name == "budget":
        raise ApiError("Your role cannot access this table.", 403)

# Return the table's field descriptions with fields hidden when the user's role requires it.
def schema_for_role(name):
    ensure_table(name)
    info = copy.deepcopy(SCHEMAS[name])
    if g.role == "staff" and name == "purchase_request":
        info["columns"] = [item for item in info["columns"] if item["name"] in STAFF_PURCHASE_COLUMNS]
    return info

# Choose which table columns to request so staff do not receive hidden budget fields.
def table_select(name):
    if g.role == "staff" and name == "purchase_request":
        return ",".join(STAFF_PURCHASE_COLUMNS)
    return "*"

# Check that the requested report exists and that the user's role can access it.
def ensure_view(name):
    if name not in VIEWS:
        raise ApiError(f"Unknown view: {name}", 404)
    if g.role == "staff" and name not in STAFF_VIEWS:
        raise ApiError("Your role cannot access this report.", 403)

# Choose report columns while leaving out financial information hidden from staff.
def view_select(name):
    if g.role == "staff" and name in STAFF_VIEW_COLUMNS:
        return ",".join(STAFF_VIEW_COLUMNS[name])
    return "*"

# Format a value as an exact-match filter that the Supabase Data API understands.
def postgrest_equal(value):
    if value is None:
        return "is.null"
    if isinstance(value, bool):
        return f"eq.{str(value).lower()}"
    if isinstance(value, (int, float)):
        return f"eq.{value}"
    escaped = str(value).replace("\\", "\\\\").replace('"', '\\"')
    return f'eq."{escaped}"'

# Build the filters that identify one record by its primary key.
def key_params(pk, key):
    if not isinstance(key, dict) or any(field not in key for field in pk):
        raise ApiError("Missing record key")
    return [(field, postgrest_equal(key[field])) for field in pk]

# Keep editable fields, letting blank fields use database defaults when adding a record.
def editable_values(info, values, for_insert=False):
    editable = {item["name"] for item in info["columns"] if not item["readonly"]}
    defaulted = {item["name"] for item in info["columns"] if item["default_value"] is not None}
    return {
        key: (None if isinstance(value, str) and value.strip() == "" else value)
        for key, value in (values or {}).items()
        if key in editable and not (
            for_insert and key in defaulted and isinstance(value, str) and value.strip() == ""
        )
    }

# Serve the main page containing the sign-in screen and app.
@app.get("/")
def index():
    return send_from_directory(app.static_folder, "index.html")

# Give the browser the public Supabase URL and publishable key needed for sign-in.
@app.get("/supabase-config.js")
def public_config():
    payload = json.dumps({"url": SUPABASE_URL, "publishableKey": SUPABASE_PUBLISHABLE_KEY})
    return app.response_class(f"window.GARDEN_SUPABASE_CONFIG = {payload};", mimetype="application/javascript")

# Tell the browser which tables and reports the signed-in user can see.
@app.get("/api/meta")
def meta():
    tables = [{"name": name, "label": cfg["label"], "group": cfg["group"]}
              for name, cfg in TABLES.items() if not (g.role == "staff" and name == "budget")]
    views = [{"name": name, "label": label} for name, label in VIEWS.items()
             if not (g.role == "staff" and name not in STAFF_VIEWS)]
    return jsonify({"role": g.role, "user": {"id": g.auth_user.get("id"), "email": g.auth_user.get("email")}, "tables": tables, "views": views})

# Give the browser the field descriptions needed to display a table and build its forms.
@app.get("/api/tables/<name>/schema")
def get_table_schema(name):
    return jsonify(schema_for_role(name))

# Load related records to fill the form's dropdown choices.
@app.get("/api/tables/<name>/options")
def get_table_options(name):
    info, options = schema_for_role(name), {}
    for item in info["columns"]:
        foreign_key = item["foreign_key"]
        if not foreign_key:
            continue
        fields = list(dict.fromkeys([foreign_key["ref_column"], *foreign_key["depends_on"].values()]))
        options[item["name"]] = fetch_rows(
            foreign_key["ref_table"], ",".join(fields), [foreign_key["ref_column"]],
        )
    return jsonify(options)

# Return the records and columns the user is allowed to read from a table.
@app.get("/api/tables/<name>")
def list_rows(name):
    ensure_table(name)
    return jsonify(fetch_rows(name, table_select(name), SCHEMAS[name]["pk"]))

# Return one referenced record using exact foreign-key values and the caller's normal table access.
@app.post("/api/tables/<name>/reference")
def get_referenced_row(name):
    ensure_table(name)
    info = schema_for_role(name)
    body = request.get_json(silent=True) or {}
    key = body.get("key")
    allowed = {item["name"] for item in info["columns"]}
    if not isinstance(key, dict) or not key or any(field not in allowed for field in key):
        raise ApiError("A valid reference key is required.")
    filters = [(field, postgrest_equal(value)) for field, value in key.items()]
    rows = fetch_rows(name, table_select(name), extra_params=filters)
    if not rows:
        # Check visible rows as a fallback for PostgREST filter edge cases with text keys.
        visible_rows = fetch_rows(name, table_select(name))
        rows = [row for row in visible_rows if all(row.get(field) == value for field, value in key.items())]
    if not rows:
        raise ApiError("The referenced record could not be found or is not available to your role.", 404)
    return jsonify(rows[0])

# Send a new record to Supabase, where database permissions and rules decide whether to save it.
@app.post("/api/tables/<name>")
def create_row(name):
    ensure_table(name)
    info = schema_for_role(name)
    values = editable_values(info, (request.get_json(silent=True) or {}).get("values"), for_insert=True)
    rows = rest_request("POST", name, [("select", table_select(name))], values, prefer="return=representation")
    return jsonify(rows[0] if rows else {}), 201

# Send changes for one record to Supabase and report if it cannot be edited.
@app.put("/api/tables/<name>")
def update_row(name):
    ensure_table(name)
    info, body = schema_for_role(name), request.get_json(silent=True) or {}
    values = editable_values(info, body.get("values"))
    if not values:
        raise ApiError("Nothing to update")
    params = key_params(info["pk"], body.get("key")) + [("select", table_select(name))]
    rows = rest_request("PATCH", name, params, values, prefer="return=representation")
    if not rows:
        raise ApiError("Record not found or your role cannot edit it.", 404)
    return jsonify(rows[0])

# Ask Supabase to delete one record and report if it cannot be deleted.
@app.delete("/api/tables/<name>")
def delete_row(name):
    ensure_table(name)
    info = SCHEMAS[name]
    params = key_params(info["pk"], (request.get_json(silent=True) or {}).get("key"))
    params.append(("select", ",".join(info["pk"])))
    rows = rest_request("DELETE", name, params, prefer="return=representation")
    if not rows:
        raise ApiError("Record not found or your role cannot delete it.", 404)
    return jsonify({"deleted": len(rows)})

# Return the rows of a report the user is allowed to view.
@app.get("/api/views/<name>")
def get_view(name):
    ensure_view(name)
    return jsonify(fetch_rows(name, view_select(name)))

# Gather counts, restock alerts, upcoming plantings, and any budgets the user may view.
@app.get("/api/dashboard")
def dashboard():
    locations = fetch_rows("location", "location_name,garden_status")
    active_beds = fetch_rows("garden_bed", "bed_id", extra_params=[("lifecycle_status", "eq.Active")])
    inventory = fetch_rows("inventory_list", "inventory_id")
    restock = fetch_rows("RestockList", view_select("RestockList"), ["item_name"])
    pending = fetch_rows("PendingRequests", view_select("PendingRequests"))
    crop_rows = fetch_rows("CropCalendar", view_select("CropCalendar"))
    today = datetime.date.today().isoformat()
    rotations = [row for row in crop_rows if
                 (row.get("sow_date") and row["sow_date"] >= today) or row.get("rotation_status") == "Planned"]
    rotations.sort(key=lambda row: row.get("sow_date") or "9999-12-31")
    budgets = [] if g.role == "staff" else fetch_rows(
        "budget", "budget_name,budget_amount,remaining_budget", ["budget_name"])
    return jsonify({
        "counts": {
            "locations": len(locations),
            "gardens": sum(1 for row in locations if row.get("garden_status") is not None),
            "active_beds": len(active_beds), "inventory_items": len(inventory),
            "restock_needed": len(restock), "pending_requests": len(pending),
        },
        "budgets": budgets, "restock": restock[:10], "rotations": rotations[:10],
    })

# Keep account management restricted to managers, including direct API requests.
def ensure_manager():
    if g.role != "database_manager":
        raise ApiError("Only a database manager can manage users.", 403)

# Show managers the existing Auth accounts and their assigned app roles.
@app.get("/api/users")
def list_app_users():
    ensure_manager()
    try:
        users = fetch_rows("rpc/list_app_users", "user_id,email,database_role", ["user_id"])
    except ApiError as error:
        if error.status == 404:
            raise ApiError("User management needs a database setup update. Contact the project administrator.", 503)
        raise
    return jsonify(users)

# Change another user's app role; Supabase also checks the manager's current assignment.
@app.put("/api/users/<uuid:user_id>/role")
def assign_app_role(user_id):
    ensure_manager()
    if str(user_id) == g.auth_user.get("id"):
        raise ApiError("You cannot change your own manager role.", 403)
    body = request.get_json(silent=True)
    role = body.get("role") if isinstance(body, dict) else None
    if not isinstance(role, str) or role not in ROLES:
        raise ApiError("Choose a valid app role.")
    rest_request("POST", "rpc/set_user_database_role", body={
        "p_user_id": str(user_id), "p_database_role": role,
    })
    return jsonify({"saved": True})

# Remove another user's role without deleting their sign-in account or records.
@app.delete("/api/users/<uuid:user_id>/role")
def remove_app_role(user_id):
    ensure_manager()
    if str(user_id) == g.auth_user.get("id"):
        raise ApiError("You cannot remove your own manager access.", 403)
    rest_request("POST", "rpc/remove_user_database_role", body={"p_user_id": str(user_id)})
    return jsonify({"removed": True})

# Email a reset link for an existing account without revealing or changing its password.
@app.post("/api/users/<uuid:user_id>/password-reset")
def request_user_password_reset(user_id):
    ensure_manager()
    # The directory function checks that this manager still has their assigned role.
    users = fetch_rows("rpc/list_app_users", "user_id,email", extra_params=[
        ("user_id", postgrest_equal(str(user_id))),
    ])
    if not users:
        raise ApiError("This account no longer exists.", 404)
    email = users[0].get("email")
    if not email:
        raise ApiError("This account has no email address for password recovery.")
    try:
        response = requests.post(
            f"{SUPABASE_URL}/auth/v1/recover",
            headers={"apikey": SUPABASE_PUBLISHABLE_KEY},
            params={"redirect_to": "http://localhost:8000/"},
            json={"email": email}, timeout=15,
        )
    except requests.RequestException:
        raise ApiError("Could not reach Supabase Auth. Check your internet connection and try again.", 503)
    if response.status_code == 429:
        raise ApiError("Too many reset emails have been requested. Wait a while before trying again.", 429)
    if not response.ok:
        try:
            error = response.json()
        except ValueError:
            error = {}
        detail = error.get("msg") or error.get("message") or error.get("error_description")
        raise ApiError("Supabase could not request the reset email. Please try again later.", 502, detail)
    return jsonify({"requested": True})

if __name__ == "__main__":
    app.run(debug=False, port=int(os.environ.get("PORT", 8000)))
