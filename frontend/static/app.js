const state = { meta: null, schema: null, rows: [], options: {}, sort: null, search: "" };

const $ = (sel) => document.querySelector(sel);
const content = $("#content");

const LABELS = {
  instock_total: "In Stock",
  bed_size_sq_ft: "Bed Size (sq ft)",
  delivered_to_fns: "Delivered to FNS",
  is_hlc: "HLC",
  is_full: "Full",
  location_group_name: "Location Group",
  unit_cost_at_request: "Unit Cost at Request",
};

function label(name) {
  if (LABELS[name]) return LABELS[name];
  return name
    .replace(/_/g, " ")
    .replace(/([a-z])([A-Z])/g, "$1 $2")
    .replace(/\b\w/g, (c) => c.toUpperCase());
}

function escapeHtml(value) {
  return String(value ?? "").replace(/[&<>"']/g, (c) => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;",
  })[c]);
}

const money = new Intl.NumberFormat("en-US", { style: "currency", currency: "USD" });
const isMoneyColumn = (name) => /cost|budget|spent|spending/.test(name) && !/quantity|items_/.test(name);

function formatCell(name, value) {
  if (value === null || value === undefined || value === "") return '<span class="muted">—</span>';
  if (typeof value === "boolean") return `<span class="pill ${value ? "yes" : "no"}">${value ? "Yes" : "No"}</span>`;
  if (typeof value === "number" && isMoneyColumn(name)) return money.format(value);
  if (name === "link" && /^https?:\/\//.test(value)) {
    return `<a href="${escapeHtml(value)}" target="_blank" rel="noopener">Link</a>`;
  }
  return escapeHtml(value);
}

async function api(path, options = {}) {
  const res = await fetch(`/api${path}`, {
    headers: { "Content-Type": "application/json" },
    ...options,
    body: options.body ? JSON.stringify(options.body) : undefined,
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    const err = new Error(data.error || `Request failed (${res.status})`);
    err.detail = data.detail;
    throw err;
  }
  return data;
}

function toast(message) {
  const el = $("#toast");
  el.textContent = message;
  el.hidden = false;
  clearTimeout(toast.timer);
  toast.timer = setTimeout(() => (el.hidden = true), 2600);
}

function showError(err) {
  content.innerHTML = `<div class="banner"><strong>Something went wrong.</strong> ${escapeHtml(err.message)}</div>`;
}

function setHeader(title, sub = "", actions = "") {
  $("#page-title").textContent = title;
  $("#page-sub").textContent = sub;
  $("#page-actions").innerHTML = actions;
  document.title = `${title} · LCSD Garden`;
}

function renderNav() {
  const groups = {};
  for (const t of state.meta.tables) (groups[t.group] ||= []).push({ ...t, href: `#/table/${t.name}` });
  groups.Reports = state.meta.views.map((v) => ({ ...v, href: `#/view/${v.name}` }));

  const current = location.hash || "#/dashboard";
  let html = `<a class="nav-link ${current === "#/dashboard" ? "active" : ""}" href="#/dashboard">Dashboard</a>`;
  for (const [group, links] of Object.entries(groups)) {
    html += `<div class="nav-group"><div class="nav-group-title">${escapeHtml(group)}</div>`;
    for (const link of links) {
      html += `<a class="nav-link ${current === link.href ? "active" : ""}" href="${link.href}">${escapeHtml(link.label)}</a>`;
    }
    html += "</div>";
  }
  $("#nav").innerHTML = html;
}

function dataTable(rows, { columns, actions = false } = {}) {
  if (!rows.length) return '<div class="empty">No records yet.</div>';
  const cols = columns || Object.keys(rows[0]);
  const head = cols
    .map((c) => {
      const sorted = state.sort && state.sort.col === c;
      return `<th data-sort="${escapeHtml(c)}" class="${sorted ? "sorted" : ""} ${sorted && state.sort.desc ? "desc" : ""}">${escapeHtml(label(c))}</th>`;
    })
    .join("");
  const body = rows
    .map((row, index) => {
      const cells = cols
        .map((c) => {
          const cls = c === "notes" ? "notes" : typeof row[c] === "number" ? "num" : "";
          return `<td class="${cls}" title="${c === "notes" ? escapeHtml(row[c]) : ""}">${formatCell(c, row[c])}</td>`;
        })
        .join("");
      const buttons = actions
        ? `<td class="actions"><button class="btn small" data-edit="${index}">Edit</button><button class="btn small danger" data-delete="${index}">Delete</button></td>`
        : "";
      return `<tr>${cells}${buttons}</tr>`;
    })
    .join("");
  return `<div class="table-wrap"><table><thead><tr>${head}${actions ? "<th></th>" : ""}</tr></thead><tbody>${body}</tbody></table></div>`;
}

function filterAndSort(rows) {
  let out = rows;
  if (state.search) {
    const q = state.search.toLowerCase();
    out = out.filter((r) => Object.values(r).some((v) => String(v ?? "").toLowerCase().includes(q)));
  }
  if (state.sort) {
    const { col, desc } = state.sort;
    out = [...out].sort((a, b) => {
      const x = a[col], y = b[col];
      if (x === y) return 0;
      if (x === null || x === undefined) return 1;
      if (y === null || y === undefined) return -1;
      const cmp = typeof x === "number" && typeof y === "number" ? x - y : String(x).localeCompare(String(y), undefined, { numeric: true });
      return desc ? -cmp : cmp;
    });
  }
  return out;
}

function bindTableControls(rerender) {
  const search = $("#search");
  if (search) {
    search.value = state.search;
    search.oninput = () => {
      state.search = search.value;
      rerender();
    };
  }
  content.querySelectorAll("th[data-sort]").forEach((th) => {
    th.onclick = () => {
      const col = th.dataset.sort;
      state.sort = state.sort && state.sort.col === col ? { col, desc: !state.sort.desc } : { col, desc: false };
      rerender();
    };
  });
}

/* ---------- Dashboard ---------- */

async function showDashboard() {
  setHeader("Dashboard", "Overview of inventory, budgets, and upcoming plantings");
  content.innerHTML = '<div class="empty">Loading…</div>';
  const data = await api("/dashboard");
  const c = data.counts;
  const stat = (value, text, warn = false) =>
    `<div class="card stat ${warn && value > 0 ? "alert-stat" : ""}"><div class="stat-value">${value}</div><div class="stat-label">${text}</div></div>`;

  const budgets = data.budgets.length
    ? data.budgets
        .map((b) => {
          const pct = b.budget_amount ? Math.max(0, Math.min(100, (b.remaining_budget / b.budget_amount) * 100)) : 0;
          return `<div class="budget-row">
            <div class="budget-top"><span><strong>${escapeHtml(b.budget_name)}</strong></span>
            <span>${money.format(b.remaining_budget ?? 0)} <span class="muted">of ${money.format(b.budget_amount)}</span></span></div>
            <div class="bar ${pct < 20 ? "low" : ""}"><span style="width:${pct}%"></span></div>
          </div>`;
        })
        .join("")
    : '<div class="muted">No budgets yet.</div>';

  content.innerHTML = `
    <div class="stats">
      ${stat(c.locations, "Locations")}
      ${stat(c.gardens, "Locations with gardens")}
      ${stat(c.active_beds, "Active beds")}
      ${stat(c.inventory_items, "Inventory items")}
      ${stat(c.restock_needed, "Items to restock", true)}
      ${stat(c.pending_requests, "Pending requests", true)}
    </div>
    <div class="grid-2">
      <div class="card"><div class="card-header">Budgets remaining <a href="#/table/budget" class="muted">Manage</a></div><div class="card-body">${budgets}</div></div>
      <div class="card"><div class="card-header">Restock needed <a href="#/view/RestockList" class="muted">View all</a></div>
        ${dataTable(data.restock, { columns: ["item_name", "instock_total", "reorder_point", "storage_location"] })}</div>
    </div>
    <div class="card"><div class="card-header">Upcoming plantings <a href="#/view/CropCalendar" class="muted">Crop calendar</a></div>
      ${dataTable(data.rotations, { columns: ["sow_date", "location_name", "bed_name", "plant_name", "season", "rotation_status"] })}</div>
  `;
}

/* ---------- Report views ---------- */

async function showView(name) {
  const view = state.meta.views.find((v) => v.name === name);
  if (!view) return showError(new Error(`Unknown report: ${name}`));
  setHeader(view.label, "Read-only report", '<input id="search" class="search" type="search" placeholder="Search…">');
  content.innerHTML = '<div class="empty">Loading…</div>';
  state.rows = await api(`/views/${name}`);
  const render = () => {
    content.innerHTML = `<div class="card">${dataTable(filterAndSort(state.rows))}</div>`;
    bindTableControls(render);
  };
  render();
}

/* ---------- Editable tables ---------- */

async function showTable(name) {
  const table = state.meta.tables.find((t) => t.name === name);
  if (!table) return showError(new Error(`Unknown table: ${name}`));
  setHeader(
    table.label,
    table.group,
    '<input id="search" class="search" type="search" placeholder="Search…"><button class="btn primary" id="add-btn">+ Add</button>'
  );
  content.innerHTML = '<div class="empty">Loading…</div>';
  const [schema, rows] = await Promise.all([api(`/tables/${name}/schema`), api(`/tables/${name}`)]);
  state.schema = schema;
  state.rows = rows;

  const render = () => {
    const visible = filterAndSort(state.rows);
    content.innerHTML = `<div class="card">${dataTable(visible, {
      columns: schema.columns.map((c) => c.name),
      actions: true,
    })}</div><p class="muted">${visible.length} of ${state.rows.length} records</p>`;
    bindTableControls(render);
    content.querySelectorAll("[data-edit]").forEach((b) => (b.onclick = () => openForm(visible[b.dataset.edit])));
    content.querySelectorAll("[data-delete]").forEach((b) => (b.onclick = () => deleteRow(visible[b.dataset.delete])));
  };
  render();
  $("#add-btn").onclick = () => openForm(null);
}

async function reloadTable() {
  await showTable(state.schema.name);
}

function rowKey(row) {
  return Object.fromEntries(state.schema.pk.map((k) => [k, row[k]]));
}

async function deleteRow(row) {
  const label = state.meta.tables.find((t) => t.name === state.schema.name).label;
  if (!confirm(`Delete this record from ${label}? Related records may also be removed.`)) return;
  try {
    await api(`/tables/${state.schema.name}`, { method: "DELETE", body: { key: rowKey(row) } });
    toast("Record deleted");
    await reloadTable();
  } catch (err) {
    alert(err.message);
  }
}

function inputFor(col, value) {
  const id = `f_${col.name}`;
  const required = col.required ? "required" : "";
  const v = value ?? "";

  if (col.data_type === "boolean") {
    const checked = value === null || value === undefined ? /true/i.test(col.default_value || "") : value;
    return `<div class="field checkbox"><input type="checkbox" id="${id}" name="${col.name}" ${checked ? "checked" : ""}><label for="${id}">${escapeHtml(label(col.name))}</label></div>`;
  }

  let control;
  if (col.foreign_key) {
    control = `<select id="${id}" name="${col.name}" ${required}></select>`;
  } else if (col.enum) {
    const opts = col.enum.map((e) => `<option ${e === v ? "selected" : ""}>${escapeHtml(e)}</option>`).join("");
    control = `<select id="${id}" name="${col.name}" ${required}><option value="">Select…</option>${opts}</select>`;
  } else if (col.data_type === "text") {
    control = `<textarea id="${id}" name="${col.name}" rows="3" ${required}>${escapeHtml(v)}</textarea>`;
  } else if (col.data_type === "date") {
    control = `<input type="date" id="${id}" name="${col.name}" value="${escapeHtml(String(v).slice(0, 10))}" ${required}>`;
  } else if (["integer", "numeric", "smallint", "bigint", "real", "double precision"].includes(col.data_type)) {
    const step = col.data_type === "numeric" ? "0.01" : "1";
    const min = col.domain_name ? 'min="0"' : "";
    control = `<input type="number" step="${step}" ${min} id="${id}" name="${col.name}" value="${escapeHtml(v)}" ${required}>`;
  } else {
    const max = col.max_length ? `maxlength="${col.max_length}"` : "";
    const type = col.name.includes("email") ? "email" : "text";
    control = `<input type="${type}" id="${id}" name="${col.name}" value="${escapeHtml(v)}" ${max} ${required}>`;
  }

  const hint = col.foreign_key ? `<span class="hint">From ${escapeHtml(label(col.foreign_key.ref_table))}</span>` : "";
  const wide = col.data_type === "text" ? "wide" : "";
  return `<div class="field ${wide}"><label for="${id}">${escapeHtml(label(col.name))}${col.required ? ' <span class="req">*</span>' : ""}</label>${control}${hint}</div>`;
}

function fillForeignKeySelects(record) {
  for (const col of state.schema.columns) {
    const fk = col.foreign_key;
    if (!fk || col.readonly) continue;
    const select = $(`#f_${col.name}`);
    const current = select.value || (record ? record[col.name] : "") || "";
    let options = state.options[col.name] || [];
    for (const [localCol, refCol] of Object.entries(fk.depends_on)) {
      const parent = $(`#f_${localCol}`);
      if (parent && parent.value) options = options.filter((o) => String(o[refCol]) === parent.value);
    }
    const values = [...new Set(options.map((o) => o[fk.ref_column]))];
    select.innerHTML =
      `<option value="">${col.required ? "Select…" : "None"}</option>` +
      values.map((val) => `<option value="${escapeHtml(val)}" ${String(val) === String(current) ? "selected" : ""}>${escapeHtml(val)}</option>`).join("");
  }
}

async function openForm(record) {
  const schema = state.schema;
  const tableLabel = state.meta.tables.find((t) => t.name === schema.name).label;
  $("#dialog-title").textContent = record ? `Edit ${tableLabel}` : `Add to ${tableLabel}`;
  $("#form-error").hidden = true;

  const editable = schema.columns.filter((c) => !c.readonly);
  $("#form-fields").innerHTML = editable.map((c) => inputFor(c, record ? record[c.name] : null)).join("");

  try {
    state.options = await api(`/tables/${schema.name}/options`);
  } catch (err) {
    state.options = {};
  }
  fillForeignKeySelects(record);

  for (const col of editable) {
    for (const localCol of Object.keys(col.foreign_key?.depends_on || {})) {
      const parent = $(`#f_${localCol}`);
      if (parent) parent.addEventListener("change", () => fillForeignKeySelects(null));
    }
  }

  const form = $("#form");
  form.onsubmit = async (event) => {
    event.preventDefault();
    const payload = {};
    for (const col of editable) {
      const el = $(`#f_${col.name}`);
      payload[col.name] = col.data_type === "boolean" ? el.checked : el.value;
    }
    const submit = $("#form-submit");
    submit.disabled = true;
    try {
      if (record) {
        await api(`/tables/${schema.name}`, { method: "PUT", body: { key: rowKey(record), values: payload } });
        toast("Changes saved");
      } else {
        await api(`/tables/${schema.name}`, { method: "POST", body: { values: payload } });
        toast("Record added");
      }
      $("#dialog").close();
      await reloadTable();
    } catch (err) {
      const box = $("#form-error");
      box.textContent = err.detail ? `${err.message} — ${err.detail}` : err.message;
      box.hidden = false;
    } finally {
      submit.disabled = false;
    }
  };
  $("#dialog").showModal();
}

document.querySelectorAll("[data-close]").forEach((b) => (b.onclick = () => $("#dialog").close()));

/* ---------- Router ---------- */

async function route() {
  state.search = "";
  state.sort = null;
  renderNav();
  const [, kind, name] = (location.hash || "#/dashboard").split("/");
  try {
    if (kind === "table") await showTable(decodeURIComponent(name));
    else if (kind === "view") await showView(decodeURIComponent(name));
    else await showDashboard();
  } catch (err) {
    showError(err);
  }
}

(async function init() {
  try {
    state.meta = await api("/meta");
  } catch (err) {
    return showError(err);
  }
  window.addEventListener("hashchange", route);
  route();
})();
