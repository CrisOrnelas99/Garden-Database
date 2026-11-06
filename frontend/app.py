"""Web frontend + JSON API for the LCSD Garden Program database.

Reads table structure (columns, types, keys, foreign keys, enums) from the live
database, so it works against the existing schema without modifying it.

Configure the connection with DATABASE_URL, e.g.
    postgresql://user:password@host:5432/dbname
"""

import datetime
import decimal
import os
import time

import psycopg2
import psycopg2.extras
from flask import Flask, g, jsonify, request, send_from_directory
from psycopg2 import sql

DATABASE_URL = os.environ.get("DATABASE_URL", "postgresql://postgres@localhost:5432/postgres")

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
    "CropCalendar": "Crop Calendar",
    "BedPlanting": "Bed Plantings",
    "GardenAssets": "Garden Assets",
    "RestockList": "Restock List",
    "PendingRequests": "Pending Requests",
    "SchoolSupply": "School Supply",
    "BudgetPurchases": "Budget Purchases",
    "FundingSourceSpending": "Funding Source Spending",
    "YearlyPurchase": "Yearly Purchases",
}

app = Flask(__name__, static_folder="static", static_url_path="")


class ApiError(Exception):
    def __init__(self, message, status=400):
        super().__init__(message)
        self.message = message
        self.status = status


@app.errorhandler(ApiError)
def handle_api_error(err):
    return jsonify({"error": err.message}), err.status


@app.errorhandler(psycopg2.Error)
def handle_db_error(err):
    message = (err.diag.message_primary if err.diag and err.diag.message_primary else str(err)).strip()
    detail = err.diag.message_detail if err.diag else None
    return jsonify({"error": message, "detail": detail}), 400


def connect():
    if "db" not in g:
        try:
            g.db = psycopg2.connect(DATABASE_URL, connect_timeout=10)
        except psycopg2.OperationalError as err:
            raise ApiError(f"Could not connect to the database: {err}".strip(), 503)
    return g.db


@app.teardown_appcontext
def close_connection(_exc):
    conn = g.pop("db", None)
    if conn is not None:
        conn.close()


def query(statement, params=None, commit=False):
    conn = connect()
    try:
        with conn.cursor(cursor_factory=psycopg2.extras.RealDictCursor) as cur:
            cur.execute(statement, params)
            rows = cur.fetchall() if cur.description else []
        if commit:
            conn.commit()
        else:
            conn.rollback()
        return [serialize(r) for r in rows]
    except Exception:
        conn.rollback()
        raise


def serialize(row):
    out = {}
    for key, value in row.items():
        if isinstance(value, decimal.Decimal):
            value = float(value)
        elif isinstance(value, (datetime.date, datetime.datetime)):
            value = value.isoformat()
        out[key] = value
    return out


def table_config(name):
    if name not in TABLES:
        raise ApiError(f"Unknown table: {name}", 404)
    return TABLES[name]


def table_columns(name):
    return query(
        """
        SELECT c.column_name AS name,
               c.data_type,
               c.udt_schema,
               c.udt_name,
               c.domain_name,
               c.is_nullable = 'YES' AS nullable,
               c.column_default AS default_value,
               c.character_maximum_length AS max_length
        FROM information_schema.columns c
        WHERE c.table_schema = 'public' AND c.table_name = %s
        ORDER BY c.ordinal_position
        """,
        (name,),
    )


def table_constraints(name):
    return query(
        """
        SELECT con.contype AS type,
               ARRAY(SELECT a.attname::text FROM unnest(con.conkey) WITH ORDINALITY k(n, i)
                     JOIN pg_attribute a ON a.attrelid = con.conrelid AND a.attnum = k.n
                     ORDER BY k.i) AS columns,
               ref.relname AS ref_table,
               ARRAY(SELECT a.attname::text FROM unnest(con.confkey) WITH ORDINALITY k(n, i)
                     JOIN pg_attribute a ON a.attrelid = con.confrelid AND a.attnum = k.n
                     ORDER BY k.i) AS ref_columns
        FROM pg_constraint con
        JOIN pg_class rel ON rel.oid = con.conrelid
        JOIN pg_namespace ns ON ns.oid = rel.relnamespace
        LEFT JOIN pg_class ref ON ref.oid = con.confrelid
        WHERE con.contype IN ('p', 'f') AND ns.nspname = 'public' AND rel.relname = %s
        """,
        (name,),
    )


def enum_values():
    rows = query(
        """
        SELECT ns.nspname AS schema, t.typname AS type_name, e.enumlabel AS value
        FROM pg_type t
        JOIN pg_enum e ON e.enumtypid = t.oid
        JOIN pg_namespace ns ON ns.oid = t.typnamespace
        ORDER BY t.typname, e.enumsortorder
        """
    )
    enums = {}
    for row in rows:
        enums.setdefault((row["schema"], row["type_name"]), []).append(row["value"])
    return enums


SCHEMA_CACHE_SECONDS = 300
_schema_cache = {}


def describe_table(name):
    table_config(name)
    cached = _schema_cache.get(name)
    if cached and time.time() - cached[0] < SCHEMA_CACHE_SECONDS:
        return cached[1]
    info = load_table_description(name)
    _schema_cache[name] = (time.time(), info)
    return info


def load_table_description(name):
    config = table_config(name)
    columns = table_columns(name)
    if not columns:
        raise ApiError(f'Table "{name}" was not found in the database', 404)
    enums = enum_values()
    constraints = table_constraints(name)

    pk = next((c["columns"] for c in constraints if c["type"] == "p"), None)
    if not pk:
        raise ApiError(f'Table "{name}" has no primary key', 500)

    # Single-column FKs become dropdowns; composite FKs (e.g. location + bed)
    # make the trailing column depend on the leading ones.
    fk_by_column = {}
    foreign_keys = sorted((c for c in constraints if c["type"] == "f"), key=lambda c: len(c["columns"]))
    for fk in foreign_keys:
        cols, ref_cols = fk["columns"], fk["ref_columns"]
        fk_by_column[cols[-1]] = {
            "ref_table": fk["ref_table"],
            "ref_column": ref_cols[-1],
            "depends_on": dict(zip(cols[:-1], ref_cols[:-1])),
        }

    readonly = set(config.get("readonly", []))
    for col in columns:
        auto = (col["default_value"] or "").startswith("nextval(")
        col["readonly"] = auto or col["name"] in readonly
        col["enum"] = (
            enums.get((col["udt_schema"], col["udt_name"])) if col["data_type"] == "USER-DEFINED" else None
        )
        col["foreign_key"] = fk_by_column.get(col["name"])
        col["required"] = not col["nullable"] and col["default_value"] is None and not col["readonly"]
    return {"name": name, **config, "pk": pk, "columns": columns}


def key_clause(pk, key):
    if not isinstance(key, dict) or any(k not in key for k in pk):
        raise ApiError("Missing record key")
    clause = sql.SQL(" AND ").join(sql.SQL("{} = %s").format(sql.Identifier(k)) for k in pk)
    return clause, [key[k] for k in pk]


def clean_values(info, values):
    editable = {c["name"] for c in info["columns"] if not c["readonly"]}
    out = {}
    for key, value in (values or {}).items():
        if key not in editable:
            continue
        if isinstance(value, str) and value.strip() == "":
            value = None
        out[key] = value
    return out


@app.after_request
def disable_caching(response):
    response.headers["Cache-Control"] = "no-cache"
    return response


@app.get("/")
def index():
    return send_from_directory(app.static_folder, "index.html")


@app.get("/api/meta")
def meta():
    return jsonify(
        {
            "tables": [{"name": n, "label": c["label"], "group": c["group"]} for n, c in TABLES.items()],
            "views": [{"name": n, "label": label} for n, label in VIEWS.items()],
        }
    )


@app.get("/api/tables/<name>/schema")
def get_table_schema(name):
    return jsonify(describe_table(name))


@app.get("/api/tables/<name>/options")
def get_table_options(name):
    info = describe_table(name)
    options = {}
    for col in info["columns"]:
        fk = col["foreign_key"]
        if not fk:
            continue
        fields = [fk["ref_column"], *fk["depends_on"].values()]
        options[col["name"]] = query(
            sql.SQL("SELECT DISTINCT {fields} FROM {table} ORDER BY {order}").format(
                fields=sql.SQL(", ").join(sql.Identifier(f) for f in fields),
                table=sql.Identifier(fk["ref_table"]),
                order=sql.Identifier(fk["ref_column"]),
            )
        )
    return jsonify(options)


@app.get("/api/tables/<name>")
def list_rows(name):
    info = describe_table(name)
    rows = query(
        sql.SQL("SELECT * FROM {table} ORDER BY {order}").format(
            table=sql.Identifier(name),
            order=sql.SQL(", ").join(sql.Identifier(k) for k in info["pk"]),
        )
    )
    return jsonify(rows)


@app.post("/api/tables/<name>")
def create_row(name):
    info = describe_table(name)
    values = clean_values(info, (request.get_json(silent=True) or {}).get("values"))
    if values:
        statement = sql.SQL("INSERT INTO {table} ({cols}) VALUES ({vals}) RETURNING *").format(
            table=sql.Identifier(name),
            cols=sql.SQL(", ").join(sql.Identifier(k) for k in values),
            vals=sql.SQL(", ").join(sql.Placeholder() for _ in values),
        )
    else:
        statement = sql.SQL("INSERT INTO {table} DEFAULT VALUES RETURNING *").format(table=sql.Identifier(name))
    rows = query(statement, list(values.values()), commit=True)
    return jsonify(rows[0]), 201


@app.put("/api/tables/<name>")
def update_row(name):
    info = describe_table(name)
    body = request.get_json(silent=True) or {}
    values = clean_values(info, body.get("values"))
    if not values:
        raise ApiError("Nothing to update")
    where, key_params = key_clause(info["pk"], body.get("key"))
    statement = sql.SQL("UPDATE {table} SET {assignments} WHERE {where} RETURNING *").format(
        table=sql.Identifier(name),
        assignments=sql.SQL(", ").join(sql.SQL("{} = %s").format(sql.Identifier(k)) for k in values),
        where=where,
    )
    rows = query(statement, [*values.values(), *key_params], commit=True)
    if not rows:
        raise ApiError("Record not found", 404)
    return jsonify(rows[0])


@app.delete("/api/tables/<name>")
def delete_row(name):
    info = describe_table(name)
    where, key_params = key_clause(info["pk"], (request.get_json(silent=True) or {}).get("key"))
    rows = query(
        sql.SQL("DELETE FROM {table} WHERE {where} RETURNING *").format(table=sql.Identifier(name), where=where),
        key_params,
        commit=True,
    )
    if not rows:
        raise ApiError("Record not found", 404)
    return jsonify({"deleted": len(rows)})


@app.get("/api/views/<name>")
def get_view(name):
    if name not in VIEWS:
        raise ApiError(f"Unknown view: {name}", 404)
    return jsonify(query(sql.SQL("SELECT * FROM {view}").format(view=sql.Identifier(name))))


@app.get("/api/dashboard")
def dashboard():
    counts = query(
        """
        SELECT
            (SELECT COUNT(*) FROM location) AS locations,
            (SELECT COUNT(*) FROM location WHERE garden_status IS NOT NULL) AS gardens,
            (SELECT COUNT(*) FROM garden_bed WHERE lifecycle_status = 'Active') AS active_beds,
            (SELECT COUNT(*) FROM inventory_list) AS inventory_items,
            (SELECT COUNT(*) FROM "RestockList") AS restock_needed,
            (SELECT COUNT(*) FROM "PendingRequests") AS pending_requests
        """
    )[0]
    budgets = query("SELECT budget_name, budget_amount, remaining_budget FROM budget ORDER BY budget_name")
    restock = query('SELECT * FROM "RestockList" ORDER BY item_name LIMIT 10')
    rotations = query(
        """
        SELECT * FROM "CropCalendar"
        WHERE sow_date >= CURRENT_DATE OR rotation_status = 'Planned'
        ORDER BY sow_date NULLS LAST
        LIMIT 10
        """
    )
    return jsonify({"counts": counts, "budgets": budgets, "restock": restock, "rotations": rotations})


if __name__ == "__main__":
    app.run(debug=True, port=int(os.environ.get("PORT", 8000)))
