"""Local Flask app; authenticated data requests are enforced by Supabase Postgres roles."""

import base64
import copy
import datetime
import io
import json
import os
import sys
import threading
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
from urllib.parse import quote

import bleach
import markdown
import requests
from flask import Flask, g, jsonify, request, send_file, send_from_directory

# These are the public Supabase project URL and publishable key. They identify
# the project and are safe to include in the public GitHub repository. Access
# is protected by Supabase Auth and the database role/RLS policies below; never
# put a database password, secret key, or service-role key in this app.
SUPABASE_URL = os.environ.get("SUPABASE_URL", "https://ecpxuuzqumtdhlewbmdt.supabase.co").rstrip("/")
SUPABASE_PUBLISHABLE_KEY = os.environ.get("SUPABASE_PUBLISHABLE_KEY", "sb_publishable_eBf3BZwPQvO9nHC1eD64Fg_Uit1YMGg")
ROLES = {"staff", "finance_staff", "database_manager"}

TABLES = {
    "location": {"label": "Locations", "group": "Locations", "description": "Stores schools and program locations. Garden fields are optional, so an office or a school without a tracked garden can leave them empty.", "readonly": ["bed_count"]},
    "location_group": {"label": "Location Groups", "group": "Locations", "description": "Stores one readable row for each location group."},
    "group_members": {"label": "Group Members", "group": "Locations", "description": "Connects groups to their member locations. Each row represents one location in one group."},
    "budget": {"label": "Budgets", "group": "Inventory & Budget", "description": "Stores the available and remaining amount for each budget.", "readonly": ["remaining_budget"]},
    "item": {"label": "Item Catalog", "group": "Inventory & Budget", "description": "Catalog of supplies that can be purchased or tracked in inventory."},
    "inventory_list": {"label": "Inventory", "group": "Inventory & Budget", "description": "Tracks current stock for catalog items. Each catalog item can have at most one inventory-list row."},
    "purchase_request": {"label": "Purchase Requests", "group": "Inventory & Budget", "description": "Records requested items, ordering and delivery state, and optional budget and funding-source details.", "readonly": ["unit_cost_at_request", "total_cost"], "readonly_display": ["unit_cost_at_request", "total_cost"]},
    "inventory_transaction": {"label": "Check In / Out", "group": "Inventory & Budget", "description": "Records inventory check-ins and check-outs. A row may be assigned to one school, one location group, or neither for personal use."},
    "garden_bed": {"label": "Garden Beds", "group": "Gardens", "description": "Stores individual beds for locations. Adding the first bed automatically starts the bed count for that location."},
    "irrigation_setup": {"label": "Irrigation", "group": "Gardens", "description": "Stores zero or more irrigation systems for each location with garden details."},
    "compost_unit": {"label": "Compost Units", "group": "Gardens", "description": "Stores zero or more composting units for each location with garden details."},
    "plant": {"label": "Plants", "group": "Gardens", "description": "Catalog of general information about plants. Planting-specific details are stored in crop rotations."},
    "crop_rotation": {"label": "Crop Rotations", "group": "Gardens", "description": "Tracks plantings by bed within a location's garden."},
}
VIEWS = {
    "CropCalendar": "Crop Calendar", "CurrentBedPlantings": "Current Bed Plantings",
    "GardenAssets": "Garden Assets", "RestockList": "Restock List",
    "PendingRequests": "Pending Requests", "SchoolSupply": "School Supply",
    "BudgetPurchases": "Budget Purchases", "FundingSourceSpending": "Funding Source Spending",
    "YearlyPurchase": "Yearly Purchases",
}
VIEW_DESCRIPTIONS = {
    "RestockList": "Identifies inventory items at or below their reorder point.",
    "PendingRequests": "Lists purchase requests that are unordered or not yet delivered, showing the saved school or group assignment by name.",
    "SchoolSupply": "Summarizes inventory and purchasing activity in separate rows for each school and each named group. Group totals stay on the group row.",
    "BudgetPurchases": "Groups ordered quantities and item spending by budget and item, with budget-level totals.",
    "FundingSourceSpending": "Groups ordered quantities and spending by funding source and item, with funding-source totals.",
    "YearlyPurchase": "Summarizes ordered and unordered request spending by school year.",
    "CurrentBedPlantings": "Shows in-ground and harvested plantings with the associated bed details and estimated harvest date.",
    "CropCalendar": "Shows planned, current, and past crop rotations with an estimated harvest date.",
    "GardenAssets": "Lists each bed, irrigation system, and compost unit with its location and lifecycle and condition statuses.",
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
    display_names = set(TABLES[name].get("readonly_display", []))
    for item in columns:
        if item["name"] in readonly_names:
            item["readonly"] = True
            item["required"] = False
        item["show_readonly"] = item["name"] in display_names
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
WEEKLY_SIGN_OUT_LOCK = threading.Lock()
WEEKLY_SIGN_OUT_MESSAGE = "Weekly sign-in expired. Please sign in again."
HELP_ALLOWED_TAGS = {
    "a", "blockquote", "br", "code", "em", "h1", "h2", "h3", "h4", "h5", "h6",
    "hr", "li", "ol", "p", "pre", "strong", "table", "tbody", "td", "th", "thead",
    "tr", "ul",
}
HELP_ALLOWED_ATTRIBUTES = {"a": ["href", "title"], "code": ["class"]}

def render_help_markdown(source):
    # Render the repository guides as Markdown while allowing only safe HTML output.
    rendered = markdown.markdown(source, extensions=["fenced_code", "sane_lists", "tables"])
    return bleach.clean(
        rendered,
        tags=HELP_ALLOWED_TAGS,
        attributes=HELP_ALLOWED_ATTRIBUTES,
        protocols=["http", "https", "mailto"],
        strip=True,
    )

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

# Keep each Supabase session's weekly sign-out deadline on this computer so it
# survives browser reloads and local server restarts without storing tokens.
def weekly_sign_out_deadline(session_id):
    if not isinstance(session_id, str) or not session_id:
        raise ApiError("Your sign-in session is invalid. Please sign in again.", 401)

    if os.name == "nt":
        state_root = Path(os.environ.get("LOCALAPPDATA") or Path.home() / "AppData" / "Local")
    elif os.environ.get("XDG_STATE_HOME"):
        state_root = Path(os.environ["XDG_STATE_HOME"])
    elif os.name == "posix" and sys.platform == "darwin":
        state_root = Path.home() / "Library" / "Application Support"
    else:
        state_root = Path.home() / ".local" / "state"
    state_dir = state_root / "GardenDatabase"
    state_file = state_dir / "weekly-sign-ins.json"

    now = datetime.datetime.now()
    now_timestamp = now.timestamp()
    with WEEKLY_SIGN_OUT_LOCK:
        try:
            records = json.loads(state_file.read_text(encoding="utf-8")) if state_file.exists() else {}
            if not isinstance(records, dict):
                raise ValueError("Invalid weekly sign-in state")
        except (OSError, ValueError, json.JSONDecodeError):
            if state_file.exists():
                raise ApiError("Could not read the local sign-in schedule. Contact the app manager.", 503)
            records = {}

        stored_deadline = records.get(session_id)
        if isinstance(stored_deadline, (int, float)):
            deadline_timestamp = float(stored_deadline)
        else:
            days_until_monday = (7 - now.weekday()) % 7
            deadline = datetime.datetime.combine(
                now.date() + datetime.timedelta(days=days_until_monday),
                datetime.time(0, 1),
            )
            if deadline <= now:
                deadline += datetime.timedelta(days=7)
            deadline_timestamp = deadline.timestamp()

        # Prune old session entries while retaining expired deadlines long
        # enough to keep a stale session from receiving a fresh week.
        records = {
            key: value for key, value in records.items()
            if isinstance(value, (int, float)) and float(value) >= now_timestamp - 30 * 24 * 60 * 60
        }
        records[session_id] = deadline_timestamp
        try:
            state_dir.mkdir(parents=True, exist_ok=True)
            temporary_file = state_file.with_suffix(".tmp")
            temporary_file.write_text(json.dumps(records), encoding="utf-8")
            temporary_file.replace(state_file)
        except OSError:
            raise ApiError("Could not save the local sign-in schedule. Check this computer's storage permissions.", 503)

    return deadline_timestamp

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
    claims = decode_claims(token)
    role = claims.get("role")
    if role not in ROLES:
        raise ApiError("This account has no Garden Program role assigned yet.", 403)
    deadline_timestamp = weekly_sign_out_deadline(claims.get("session_id"))
    if datetime.datetime.now().timestamp() >= deadline_timestamp:
        raise ApiError(WEEKLY_SIGN_OUT_MESSAGE, 401)
    g.weekly_sign_out_at = deadline_timestamp
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
def rest_request(method, resource, params=None, body=None, range_header=None, prefer=None, token=None):
    headers = {
        "apikey": SUPABASE_PUBLISHABLE_KEY,
        "Authorization": f"Bearer {token or g.access_token}",
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
def fetch_rows(resource, select="*", order=None, extra_params=None, token=None):
    params = list(extra_params or []) + [("select", select)]
    if order:
        params.append(("order", ",".join(f"{field}.asc" for field in order)))
    results, offset, page_size = [], 0, 1000
    while True:
        rows = rest_request(
            "GET", resource, params, range_header=f"{offset}-{offset + page_size - 1}", token=token,
        )
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
    tables = [{"name": name, "label": cfg["label"], "group": cfg["group"], "description": cfg["description"]}
              for name, cfg in TABLES.items() if not (g.role == "staff" and name == "budget")]
    views = [{"name": name, "label": label, "description": VIEW_DESCRIPTIONS[name]} for name, label in VIEWS.items()
             if not (g.role == "staff" and name not in STAFF_VIEWS)]
    return jsonify({
        "role": g.role,
        "user": {"id": g.auth_user.get("id"), "email": g.auth_user.get("email")},
        "tables": tables,
        "views": views,
        "weekly_sign_out_at": g.weekly_sign_out_at,
    })

# Provide the frontend guide to signed-in users and the Supabase guide only to managers.
@app.get("/api/help")
def get_help_guides():
    repository_root = Path(__file__).resolve().parent.parent
    try:
        frontend_source = (repository_root / "frontend" / "README.md").read_text(encoding="utf-8-sig")
        manager_start = frontend_source.find("\n## Manager pages")
        troubleshooting_start = frontend_source.find("\n## Troubleshooting", manager_start)
        if manager_start < 0 or troubleshooting_start < 0:
            raise ApiError("The frontend guide is missing its expected sections.", 500)

        reference_source = (repository_root / "docs" / "db_design.md").read_text(encoding="utf-8-sig")
        reference_start = reference_source.find("## Reusable types")
        if reference_start < 0:
            raise ApiError("The database reference section could not be found.", 500)

        manager_source = frontend_source[manager_start:troubleshooting_start]
        troubleshooting_source = frontend_source[troubleshooting_start:]
        guides = {
            "frontend": render_help_markdown(frontend_source[:manager_start]),
            "reference": render_help_markdown(reference_source[reference_start:]),
            "troubleshooting": render_help_markdown(troubleshooting_source),
        }
        if g.role == "database_manager":
            guides["manager"] = render_help_markdown(manager_source)
            supabase_source = (repository_root / "docs" / "supabase_user_guide.md").read_text(encoding="utf-8-sig")
            guides["supabase"] = render_help_markdown(supabase_source)
    except OSError:
        raise ApiError("The help guides could not be loaded from this installation.", 500)
    return jsonify(guides)

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
        # Include the selected catalog item's current price for the
        # purchase-request read-only price and total preview.
        if name == "purchase_request" and item["name"] == "item_name":
            fields.append("unit_cost")
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
    related = rows[0]
    if name == "location_group":
        group_name = related.get("location_group_name")
        members = fetch_rows(
            "group_members", "location_name",
            extra_params=[("location_group_name", postgrest_equal(group_name))],
        )
        if not members:
            visible_members = fetch_rows("group_members")
            members = [member for member in visible_members if member.get("location_group_name") == group_name]
        related["associated_schools"] = sorted({
            member["location_name"] for member in members if member.get("location_name")
        }, key=str.casefold)
    return jsonify(related)

# Send a new record to Supabase, where database permissions and rules decide whether to save it.
@app.post("/api/tables/<name>")
def create_row(name):
    ensure_table(name)
    info = schema_for_role(name)
    submitted = (request.get_json(silent=True) or {}).get("values")
    if name in {"purchase_request", "inventory_transaction"} and isinstance(submitted, dict):
        display_name = rest_request("GET", "rpc/get_my_display_name")
        actor_field = "requested_by" if name == "purchase_request" else "taken_by"
        submitted = {**submitted, actor_field: display_name or g.auth_user.get("email")}
    values = editable_values(info, submitted, for_insert=True)
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
    token = g.access_token
    queries = {
        "locations": ("location", "is_hlc,garden_condition", None),
        "inventory": ("inventory_list", "inventory_id", None),
        "beds": ("garden_bed", "condition", None),
        "irrigation": ("irrigation_setup", "condition", None),
        "compost": ("compost_unit", "condition", None),
        "restock": ("RestockList", view_select("RestockList"), ["item_name"]),
        "pending": ("PendingRequests", view_select("PendingRequests"), None),
        "crop_rows": ("CropCalendar", view_select("CropCalendar"), None),
    }
    if g.role != "staff":
        queries["budgets"] = ("budget", "budget_name,budget_amount,remaining_budget", ["budget_name"])
    with ThreadPoolExecutor(max_workers=len(queries)) as executor:
        futures = {
            name: executor.submit(fetch_rows, resource, select, order, token=token)
            for name, (resource, select, order) in queries.items()
        }
        results = {name: future.result() for name, future in futures.items()}
    locations = results["locations"]
    inventory = results["inventory"]
    maintenance_conditions = {"Require Maintenance", "In Maintenance"}
    maintenance_items = sum(
        1 for row in locations if row.get("garden_condition") in maintenance_conditions
    ) + sum(
        sum(1 for row in results[key] if row.get("condition") in maintenance_conditions)
        for key in ("beds", "irrigation", "compost")
    )
    restock = results["restock"]
    pending = results["pending"]
    crop_rows = results["crop_rows"]
    today = datetime.date.today().isoformat()
    rotations = [row for row in crop_rows if
                 (row.get("sow_date") and row["sow_date"] >= today)
                 or (row.get("expected_harvest_date") and row["expected_harvest_date"] >= today)
                 or row.get("rotation_status") == "Planned"]
    rotations.sort(key=lambda row: row.get("sow_date") or "9999-12-31")
    budgets = results.get("budgets", [])
    return jsonify({
        "counts": {
            "hlc_locations": sum(1 for row in locations if row.get("is_hlc") is True),
            "inventory_items": len(inventory),
            "maintenance_items": maintenance_items,
            "restock_needed": len(restock), "pending_requests": len(pending),
        },
        "budgets": budgets, "restock": restock[:10], "rotations": rotations,
    })

# Keep account management restricted to managers, including direct API requests.
def ensure_manager():
    if g.role != "database_manager":
        raise ApiError("Only a database manager can access this feature.", 403)

# Export every app-managed public table as insertable SQL, following the root seed file's format.
@app.get("/api/manage-data/export")
def export_all_table_data():
    ensure_manager()
    sql_lines = [
        "-- Copy of the table row data in the database.",
        "-- Generated by Garden Database. Review before running in Supabase SQL Editor.",
        "BEGIN;",
        "",
        "-- Match the root seed file: historical check-in/out rows must not replay stock movement.",
        "ALTER TABLE public.purchase_request DISABLE TRIGGER trg_update_inventory_when_received;",
        "ALTER TABLE public.inventory_transaction DISABLE TRIGGER trg_inventory_transaction;",
        "",
    ]
    for table_name, table_info in SCHEMAS.items():
        rows = fetch_rows(table_name)
        columns = [column["name"] for column in table_info["columns"]]
        columns.extend(sorted({key for row in rows for key in row if key not in columns}))
        primary_key = table_info["pk"]
        sql_lines.append(f"-- {table_name}")
        for row in rows:
            present_columns = [column for column in columns if column in row]
            names = ", ".join(sql_identifier(column) for column in present_columns)
            values = ", ".join(sql_literal(row[column]) for column in present_columns)
            conflict = ", ".join(sql_identifier(column) for column in primary_key)
            updates = [column for column in present_columns if column not in primary_key]
            action = (
                "DO UPDATE SET " + ", ".join(f"{sql_identifier(column)} = EXCLUDED.{sql_identifier(column)}" for column in updates)
                if updates else "DO NOTHING"
            )
            sql_lines.append(
                f"INSERT INTO public.{sql_identifier(table_name)} ({names}) VALUES ({values}) "
                f"ON CONFLICT ({conflict}) {action};"
            )
        sql_lines.append("")
    sql_lines.extend([
        "COMMIT;",
        "",
        "-- Restore the live stock movement triggers after the snapshot rows are loaded.",
        "ALTER TABLE public.purchase_request ENABLE TRIGGER trg_update_inventory_when_received;",
        "ALTER TABLE public.inventory_transaction ENABLE TRIGGER trg_inventory_transaction;",
        "",
    ])
    sql_buffer = io.BytesIO("\n".join(sql_lines).encode("utf-8"))
    filename = f"garden-program-data-{datetime.date.today().isoformat()}.sql"
    rest_request("POST", "rpc/record_app_event", body={"p_event_type": "BACKUP_DOWNLOAD", "p_details": {"filename": filename}})
    return send_file(
        sql_buffer, mimetype="application/sql", as_attachment=True,
        download_name=filename, max_age=0,
    )

# Quote a PostgreSQL identifier so exported SQL safely handles mixed-case or unusual column names.
def sql_identifier(value):
    return '"' + str(value).replace('"', '""') + '"'


# Format API values as SQL literals for the downloadable insert script.
def sql_literal(value):
    if value is None:
        return "NULL"
    if isinstance(value, (dict, list)):
        value = json.dumps(value, ensure_ascii=False)
    if isinstance(value, bool):
        return "TRUE" if value else "FALSE"
    if isinstance(value, (int, float)):
        return str(value)
    return "'" + str(value).replace("'", "''") + "'"

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
    profiles = fetch_rows("rpc/list_user_profiles", "user_id,display_name", ["user_id"])
    names = {profile["user_id"]: profile.get("display_name") for profile in profiles}
    for user in users:
        user["display_name"] = names.get(user["user_id"])
    return jsonify(users)

# Save a manager-controlled name; the database function also updates exact email matches.
@app.put("/api/users/<uuid:user_id>/display-name")
def set_user_display_name(user_id):
    ensure_manager()
    body = request.get_json(silent=True) or {}
    display_name = body.get("display_name")
    if display_name is not None and not isinstance(display_name, str):
        raise ApiError("Display name must be text.")
    if display_name is not None and len(display_name.strip()) > 100:
        raise ApiError("Display name must be 100 characters or fewer.")
    users = fetch_rows("rpc/list_app_users", "user_id,email,database_role")
    target_user = next((user for user in users if user.get("user_id") == str(user_id)), None)
    if not target_user:
        raise ApiError("This account no longer exists.", 404)
    profiles = fetch_rows("rpc/list_user_profiles", "user_id,display_name")
    old_profile = next((profile for profile in profiles if profile.get("user_id") == str(user_id)), None)
    old_name = old_profile.get("display_name") if old_profile else None
    rest_request("POST", "rpc/set_user_display_name", body={
        "p_user_id": str(user_id), "p_display_name": display_name,
    })
    rest_request("POST", "rpc/record_app_event", body={"p_event_type": "DISPLAY_NAME_CHANGED", "p_details": {
        "target_user_id": str(user_id), "target_email": target_user.get("email"),
        "old_display_name": old_name, "new_display_name": display_name.strip() if display_name else None,
    }})
    return jsonify({"saved": True})

# Return recent row-change history; database policy is checked again in SQL.
@app.get("/api/audit-log")
def get_audit_log():
    ensure_manager()
    return jsonify(fetch_rows("rpc/list_audit_log", "audit_id,changed_at,actor_user_id,actor_email,action,table_name,row_key,old_data,new_data", extra_params=[("limit", "500")]))

@app.get("/api/app-events")
def get_app_events():
    ensure_manager()
    return jsonify(fetch_rows("rpc/list_application_events", "event_id,occurred_at,actor_user_id,actor_email,event_type,details", extra_params=[("limit", "500")]))

# Record a small allow-listed account/app event; the database validates manager-only events too.
@app.post("/api/events")
def record_app_event():
    body = request.get_json(silent=True) or {}
    event_type = body.get("event_type")
    allowed = {"BACKUP_DOWNLOAD", "PASSWORD_RESET_REQUEST", "ROLE_CHANGED", "ROLE_REMOVED", "DISPLAY_NAME_CHANGED"}
    if event_type not in allowed:
        raise ApiError("Unsupported app event.")
    rest_request("POST", "rpc/record_app_event", body={
        "p_event_type": event_type,
        "p_details": body.get("details") if isinstance(body.get("details"), dict) else {},
    })
    return jsonify({"recorded": True})

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
    users = fetch_rows("rpc/list_app_users", "user_id,email,database_role")
    target_user = next((user for user in users if user.get("user_id") == str(user_id)), None)
    if not target_user:
        raise ApiError("This account no longer exists.", 404)
    old_role = target_user.get("database_role")
    rest_request("POST", "rpc/set_user_database_role", body={
        "p_user_id": str(user_id), "p_database_role": role,
    })
    rest_request("POST", "rpc/record_app_event", body={"p_event_type": "ROLE_CHANGED", "p_details": {
        "target_user_id": str(user_id), "target_email": target_user.get("email"), "old_role": old_role, "new_role": role,
    }})
    return jsonify({"saved": True})

# Remove another user's role without deleting their sign-in account or records.
@app.delete("/api/users/<uuid:user_id>/role")
def remove_app_role(user_id):
    ensure_manager()
    if str(user_id) == g.auth_user.get("id"):
        raise ApiError("You cannot remove your own manager access.", 403)
    users = fetch_rows("rpc/list_app_users", "user_id,email,database_role")
    target_user = next((user for user in users if user.get("user_id") == str(user_id)), None)
    if not target_user:
        raise ApiError("This account no longer exists.", 404)
    rest_request("POST", "rpc/remove_user_database_role", body={"p_user_id": str(user_id)})
    rest_request("POST", "rpc/record_app_event", body={"p_event_type": "ROLE_REMOVED", "p_details": {
        "target_user_id": str(user_id), "target_email": target_user.get("email"), "old_role": target_user.get("database_role"), "new_role": None,
    }})
    return jsonify({"removed": True})

# Email a reset link for an existing account without revealing or changing its password.
@app.post("/api/users/<uuid:user_id>/password-reset")
def request_user_password_reset(user_id):
    ensure_manager()
    # The directory function checks that this manager still has their assigned role.
    users = fetch_rows("rpc/list_app_users", "user_id,email")
    target_user = next((user for user in users if user.get("user_id") == str(user_id)), None)
    if not target_user:
        raise ApiError("This account no longer exists.", 404)
    email = target_user.get("email")
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
    rest_request("POST", "rpc/record_app_event", body={"p_event_type": "PASSWORD_RESET_REQUEST", "p_details": {
        "target_user_id": str(user_id), "target_email": email,
    }})
    return jsonify({"requested": True})

if __name__ == "__main__":
    app.run(debug=False, port=int(os.environ.get("PORT", 8000)))
