const state = { meta: null, schema: null, rows: [], options: {}, sort: null, search: "", role: null };

const $ = (sel) => document.querySelector(sel);
const content = $("#content");
const notePreview = $("#note-preview");
const referencePreview = $("#reference-preview");
let previewedNote = null;
let noteHideTimer = null;
let previewedReference = null;
let referenceHideTimer = null;
let referenceRequestId = 0;
let previewedReferenceKey = null;

function hideNotePreview() {
  clearTimeout(noteHideTimer);
  if (previewedNote) previewedNote.removeAttribute("aria-describedby");
  previewedNote = null;
  if (typeof notePreview.hidePopover === "function" && notePreview.matches(":popover-open")) notePreview.hidePopover();
  notePreview.hidden = true;
  $("#note-preview-text").textContent = "";
}

function hideReferencePreview() {
  clearTimeout(referenceHideTimer);
  referenceRequestId += 1;
  if (previewedReference) previewedReference.removeAttribute("aria-describedby");
  previewedReference = null;
  previewedReferenceKey = null;
  if (typeof referencePreview.hidePopover === "function" && referencePreview.matches(":popover-open")) referencePreview.hidePopover();
  referencePreview.hidden = true;
  $("#reference-preview-text").innerHTML = "";
}

function positionPreview(popup, anchor) {
  popup.hidden = false;
  if (typeof popup.showPopover === "function" && !popup.matches(":popover-open")) popup.showPopover();
  const anchorBox = anchor.getBoundingClientRect();
  const popupBox = popup.getBoundingClientRect();
  const left = Math.max(12, Math.min(anchorBox.left + anchorBox.width / 2 - popupBox.width / 2, window.innerWidth - popupBox.width - 12));
  let top = anchorBox.bottom + 8;
  if (top + popupBox.height > window.innerHeight - 12) top = anchorBox.top - popupBox.height - 8;
  top = Math.max(12, Math.min(top, window.innerHeight - popupBox.height - 12));
  popup.style.left = `${left}px`;
  popup.style.top = `${top}px`;
}

// Place the full text above the scrolling table without resizing its columns.
function showNotePreview(cell) {
  hideReferencePreview();
  clearTimeout(noteHideTimer);
  if (previewedNote && previewedNote !== cell) previewedNote.removeAttribute("aria-describedby");
  previewedNote = cell;
  $("#note-preview-text").textContent = cell.dataset.note;
  cell.setAttribute("aria-describedby", "note-preview");
  positionPreview(notePreview, cell);
}

function scheduleNoteHide() {
  clearTimeout(noteHideTimer);
  noteHideTimer = setTimeout(() => {
    if (document.activeElement !== previewedNote) hideNotePreview();
  }, 180);
}

content.addEventListener("pointerover", event => {
  if (event.pointerType === "touch") return;
  const cell = event.target.closest("td[data-note]");
  if (cell) showNotePreview(cell);
});
content.addEventListener("pointerout", event => {
  const cell = event.target.closest("td[data-note]");
  if (cell && !cell.contains(event.relatedTarget) && !notePreview.contains(event.relatedTarget)) scheduleNoteHide();
});
content.addEventListener("focusin", event => {
  const cell = event.target.closest("td[data-note]");
  if (cell) showNotePreview(cell);
});
content.addEventListener("focusout", event => {
  if (event.target === previewedNote && !notePreview.contains(event.relatedTarget)) scheduleNoteHide();
});
content.addEventListener("click", event => {
  const cell = event.target.closest("td[data-note]");
  if (cell) showNotePreview(cell);
});
notePreview.addEventListener("pointerenter", () => clearTimeout(noteHideTimer));
notePreview.addEventListener("pointerleave", scheduleNoteHide);
notePreview.addEventListener("toggle", event => {
  if (event.newState === "closed" && !notePreview.matches(":popover-open")) hideNotePreview();
});
document.addEventListener("pointerdown", event => {
  if (previewedNote && !previewedNote.contains(event.target) && !notePreview.contains(event.target)) hideNotePreview();
});
document.addEventListener("keydown", event => {
  if (event.key === "Escape") {
    hideNotePreview();
    hideReferencePreview();
  }
});
content.addEventListener("scroll", hideNotePreview, true);
window.addEventListener("resize", hideNotePreview);
window.addEventListener("resize", hideReferencePreview);
referencePreview.addEventListener("pointerenter", () => clearTimeout(referenceHideTimer));
referencePreview.addEventListener("pointerleave", scheduleReferenceHide);
referencePreview.addEventListener("toggle", event => {
  if (event.newState === "closed" && !referencePreview.matches(":popover-open")) hideReferencePreview();
});
document.addEventListener("pointerdown", event => {
  if (previewedReference && !previewedReference.contains(event.target) && !referencePreview.contains(event.target)) hideReferencePreview();
});
content.addEventListener("scroll", hideReferencePreview, true);
// Capture the email-link type before the SDK consumes its sign-in tokens.
const authRedirect = new URLSearchParams(location.hash.slice(1));
const authRedirectError = authRedirect.get("error_description");
const linkFlow = authRedirect.get("type");
const storedFlow = sessionStorage.getItem("garden-password-setup") ||
  (sessionStorage.getItem("garden-password-recovery") === "true" ? "recovery" : null);
let passwordSetupFlow = ["invite", "recovery"].includes(linkFlow) ? linkFlow :
  ["invite", "recovery"].includes(storedFlow) ? storedFlow : null;
let settingPassword = Boolean(passwordSetupFlow);
let passwordSaving = false;
if (settingPassword) sessionStorage.setItem("garden-password-setup", passwordSetupFlow);
const supabaseClient = window.supabase.createClient(
  window.GARDEN_SUPABASE_CONFIG.url,
  window.GARDEN_SUPABASE_CONFIG.publishableKey
);

const ROLE_LABELS = { staff: "Staff", finance_staff: "Finance Staff", database_manager: "Database Manager" };
let appStarted = false;
let initializingSession = true;
let recordBaseline = null;
let recordSaving = false;
let currentRouteHash = null;
const pendingRoleEdits = new Map();
let dashboardCalendarMonth = new Date(new Date().getFullYear(), new Date().getMonth(), 1);
let cropRotationMode = "table";
let cropRotationMonth = new Date(new Date().getFullYear(), new Date().getMonth(), 1);

// Compare current field values with the values shown when the record form opened.
function recordSnapshot() {
  return JSON.stringify(Array.from($("#form").elements)
    .filter(el => ["INPUT", "SELECT", "TEXTAREA"].includes(el.tagName))
    .map(el => [el.name || el.id, el.type === "checkbox" ? el.checked : el.value]));
}

function hasUnsavedRecord() {
  return $("#dialog").open && recordBaseline !== null && recordSnapshot() !== recordBaseline;
}

function hasUnsavedChanges() {
  return hasUnsavedRecord() || pendingRoleEdits.size > 0 ||
    (settingPassword && Boolean($("#reset-password").value || $("#reset-confirm").value));
}

function confirmDiscardChanges() {
  if (recordSaving || passwordSaving || ($("#role-dialog").open && $("#role-confirm").disabled)) {
    toast("Wait for the current request to finish.");
    return false;
  }
  return !hasUnsavedChanges() || window.confirm("Discard your unsaved changes?");
}

function discardRecordDraft() {
  recordBaseline = null;
  if ($("#dialog").open) $("#dialog").close();
}

function closeRecordForm() {
  if (recordSaving) return;
  if (hasUnsavedRecord() && !window.confirm("Discard your unsaved changes?")) return;
  discardRecordDraft();
}

// Browsers supply their own warning text for refreshes and closing the tab.
window.addEventListener("beforeunload", event => {
  if (!recordSaving && !passwordSaving && !hasUnsavedChanges()) return;
  event.preventDefault();
  event.returnValue = "";
});

function showLogin(message = "") {
  hideNotePreview();
  hideReferencePreview();
  discardRecordDraft();
  pendingRoleEdits.clear();
  currentRouteHash = null;
  if ($("#role-dialog").open) $("#role-dialog").close();
  $("#app-shell").hidden = true;
  $("#login-screen").hidden = false;
  $("#login-form").hidden = false;
  $("#reset-form").hidden = true;
  $("#forgot-form").hidden = true;
  $("#login-access-note").hidden = false;
  $("#login-heading").textContent = "Sign in";
  $("#login-intro").textContent = "Enter your account email and password.";
  $("#login-message").textContent = message;
  $("#login-submit").disabled = false;
  $("#login-submit").textContent = "Sign in";
  appStarted = false;
}

function showPasswordSetup(flow = passwordSetupFlow || "recovery") {
  passwordSetupFlow = flow;
  settingPassword = true;
  sessionStorage.setItem("garden-password-setup", flow);
  appStarted = false;
  $("#app-shell").hidden = true;
  $("#login-screen").hidden = false;
  $("#login-form").hidden = true;
  $("#forgot-form").hidden = true;
  $("#reset-form").hidden = false;
  $("#login-access-note").hidden = true;
  $("#login-heading").textContent = flow === "invite" ? "Set your password" : "Set a new password";
  $("#login-intro").textContent = flow === "invite"
    ? "Choose a password for your Garden Program account."
    : "Enter and confirm your new account password.";
  $("#reset-submit").textContent = flow === "invite" ? "Save password" : "Save new password";
}

function clearPasswordSetup() {
  settingPassword = false;
  passwordSetupFlow = null;
  sessionStorage.removeItem("garden-password-setup");
  sessionStorage.removeItem("garden-password-recovery");
  history.replaceState(null, "", location.pathname);
  $("#reset-form").reset();
  $("#login-password").value = "";
}

async function openApp(session) {
  if (settingPassword) return showPasswordSetup();
  if (!session?.access_token) return showLogin();
  if (appStarted) return;
  appStarted = true;
  $("#login-screen").hidden = true;
  $("#app-shell").hidden = false;
  $("#account-email").textContent = session.user?.email || "Signed in";
  content.innerHTML = '<div class="empty">Loading your access…</div>';
  try {
    state.meta = await api("/meta");
    state.role = state.meta.role;
    $("#account-role").textContent = ROLE_LABELS[state.role] || state.role;
    window.addEventListener("hashchange", route);
    if (!location.hash) location.hash = "#/dashboard";
    await route();
  } catch (err) {
    appStarted = false;
    state.meta = null;
    state.role = null;
    if (err.message.includes("no Garden Program role")) {
      await supabaseClient.auth.signOut();
      showLogin("Your account is signed in but has no Garden Program role yet. Ask a manager to assign one.");
      return;
    }
    content.innerHTML = `<div class="banner"><strong>Could not load the app.</strong> ${escapeHtml(err.message)}</div>
      <button class="btn primary" id="retry-startup">Try again</button>`;
    $("#retry-startup").onclick = () => openApp(session);
  }
}

const LABELS = {
  instock_total: "In Stock",
  bed_size_sq_ft: "Bed Size (sq ft)",
  delivered_to_fns: "Delivered to FNS",
  is_hlc: "HLC",
  is_full: "Full",
  location_group_name: "Location Group",
  associated_schools: "Associated Schools",
  unit_cost_at_request: "Unit Cost at Request",
};

// Keep report columns in a predictable order even if the database view's
// physical column order differs between Supabase projects.
const VIEW_COLUMNS = {
  CropCalendar: [
    "rotation_status", "location_name", "bed_name", "plant_name", "quantity",
    "season", "sow_date", "expected_harvest_date", "soil_health", "notes",
  ],
  CurrentBedPlantings: [
    "location_name", "bed_name", "plant_name", "quantity", "bed_condition",
    "is_full", "season", "rotation_status", "sow_date", "expected_harvest_date",
    "soil_health", "rotation_notes",
  ],
  GardenAssets: [
    "location_name", "item_type", "item_name", "lifecycle_status", "condition", "notes",
  ],
  RestockList: [
    "inventory_id", "item_name", "instock_total", "reorder_point", "counted", "storage_location",
  ],
  PendingRequests: [
    "request_date", "request_status", "item_name", "requested_by", "assigned_locations",
    "quantity_requested", "total_cost", "review_status", "notes",
  ],
  SchoolSupply: [
    "assignment_type", "location_name", "items_currently_checked_out",
    "purchase_items_pending", "total_spent",
  ],
  BudgetPurchases: [
    "budget_name", "item_name", "total_quantity_ordered", "total_spent", "total_budget",
    "total_budget_spent", "remaining_budget",
  ],
  FundingSourceSpending: [
    "funding_source", "item_name", "total_quantity_ordered", "total_spent",
    "total_funding_source_spent",
  ],
  YearlyPurchase: ["school_year", "total_spent", "pending_spending"],
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
  if (/(status|condition)/i.test(name)) {
    const status = String(value).trim().toLowerCase();
    let tone = "neutral";
    if (["good", "active", "in-ground", "checked in", "approved", "harvested", "complete", "completed", "delivered", "ordered"].includes(status)) tone = "green";
    else if (["planned", "pending", "awaiting", "fair", "scheduled", "needs review"].includes(status)) tone = "yellow";
    else if (["in maintenance", "require maintenance", "checked out", "in progress"].includes(status)) tone = status === "require maintenance" ? "red" : "orange";
    else if (["inactive", "removed", "rejected", "denied", "cancelled", "canceled", "overdue", "needs replacement"].includes(status)) tone = "red";
    return `<span class="pill status-pill status-${tone}">${escapeHtml(value)}</span>`;
  }
  if (typeof value === "number" && isMoneyColumn(name)) return money.format(value);
  if (name === "link" && /^https?:\/\//.test(value)) {
    return `<a href="${escapeHtml(value)}" target="_blank" rel="noopener">Link</a>`;
  }
  return escapeHtml(value);
}

// Show the member locations as an escaped list in location-group previews.
function formatReferenceCell(name, value) {
  if (name === "associated_schools" && Array.isArray(value)) {
    if (!value.length) return '<span class="muted">No schools are assigned to this group.</span>';
    return `<ul class="reference-list">${value.map((school) => `<li>${escapeHtml(school)}</li>`).join("")}</ul>`;
  }
  return formatCell(name, value);
}

// Show the related row above its foreign-key value using the signed-in user's permissions.
async function showReferencePreview(anchor, column, row, foreignKey) {
  hideNotePreview();
  clearTimeout(referenceHideTimer);
  const target = foreignKey.ref_table;
  const key = { [foreignKey.ref_column]: row[foreignKey.value_column || column] };
  for (const [localColumn, referencedColumn] of Object.entries(foreignKey.depends_on || {})) {
    key[referencedColumn] = row[localColumn];
  }
  const lookupKey = `${target}:${JSON.stringify(key)}`;
  if (previewedReference === anchor && previewedReferenceKey === lookupKey && referencePreview.matches(":popover-open")) return;
  if (previewedReference && previewedReference !== anchor) previewedReference.removeAttribute("aria-describedby");
  previewedReference = anchor;
  previewedReferenceKey = lookupKey;
  anchor.setAttribute("aria-describedby", "reference-preview");
  const targetLabel = state.meta.tables.find((item) => item.name === target)?.label || label(target);
  $("#reference-preview-heading").textContent = `${targetLabel} details`;
  $("#reference-preview-text").innerHTML = '<p class="muted">Loading related record…</p>';
  positionPreview(referencePreview, anchor);
  const requestId = ++referenceRequestId;
  try {
    const related = await api(`/tables/${encodeURIComponent(target)}/reference`, { method: "POST", body: { key } });
    if (requestId !== referenceRequestId || previewedReference !== anchor) return;
    $("#reference-preview-text").innerHTML = `<dl>${Object.entries(related).map(([name, value]) =>
      `<div class="reference-field"><dt>${escapeHtml(label(name))}</dt><dd>${formatReferenceCell(name, value)}</dd></div>`
    ).join("")}</dl>`;
    positionPreview(referencePreview, anchor);
  } catch (error) {
    if (requestId !== referenceRequestId || previewedReference !== anchor) return;
    $("#reference-preview-text").innerHTML = `<p class="banner">${escapeHtml(error.message)}</p>`;
    positionPreview(referencePreview, anchor);
  }
}

function scheduleReferenceHide() {
  clearTimeout(referenceHideTimer);
  referenceHideTimer = setTimeout(() => {
    if (document.activeElement !== previewedReference) hideReferencePreview();
  }, 180);
}

async function api(path, options = {}) {
  const { data: { session } } = await supabaseClient.auth.getSession();
  const headers = new Headers(options.headers || {});
  headers.set("Content-Type", "application/json");
  if (session?.access_token) headers.set("Authorization", `Bearer ${session.access_token}`);
  const res = await fetch(`/api${path}`, {
    ...options,
    headers,
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
  hideNotePreview();
  hideReferencePreview();
  content.innerHTML = `<div class="banner"><strong>Something went wrong.</strong> ${escapeHtml(err.message)}</div>`;
}

function setHeader(title, sub = "", actions = "", scrollTable = false) {
  hideNotePreview();
  hideReferencePreview();
  content.scrollTop = 0;
  content.classList.toggle("records-page", scrollTable);
  $("#page-title").textContent = title;
  $("#page-sub").textContent = sub;
  $("#page-actions").innerHTML = actions;
  $("#print-page")?.addEventListener("click", downloadTablePdf);
  document.title = `${title} · LCSD Garden`;
}

const printButton = '<button type="button" class="btn print-btn" id="print-page" aria-label="Download PDF" title="Download as PDF">' +
  '<svg viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M12 3v12m0 0 4-4m-4 4-4-4M5 17v4h14v-4"/></svg></button>';

// Print a lightweight copy of the table so the browser does not reflow the whole app.
function downloadTablePdf() {
  const table = content.querySelector(".data-table");
  if (!table) {
    toast("Switch to Table mode before downloading this report.");
    return;
  }
  const printWindow = window.open("", "_blank");
  if (!printWindow) {
    toast("Allow pop-ups to download this table as a PDF.");
    return;
  }
  const printableTable = table.cloneNode(true);
  printableTable.querySelectorAll("th.notes, td.notes, td.actions, th:last-child:empty").forEach((cell) => cell.remove());
  printableTable.querySelectorAll(".reference-link").forEach((link) => link.replaceWith(document.createTextNode(link.textContent)));
  const title = $("#page-title").textContent;
  const count = content.querySelector(":scope > p")?.textContent || `${table.tBodies[0]?.rows.length || 0} records`;
  printWindow.addEventListener("load", () => {
    printWindow.focus();
    printWindow.print();
  }, { once: true });
  printWindow.document.open();
  printWindow.document.write(`<!doctype html><html><head><meta charset="utf-8"><title>${escapeHtml(title)}</title>
    <style>
      @page { size: landscape; margin: 12mm; }
      body { color: #111; font: 11px Arial, sans-serif; }
      h1 { margin: 0 0 4px; font-size: 20px; }
      p { margin: 0 0 12px; color: #555; font-size: 11px; }
      table { width: 100%; border-collapse: collapse; }
      thead { display: table-header-group; }
      tr { break-inside: avoid; }
      th, td { padding: 5px 7px; border: 1px solid #bbb; text-align: left; vertical-align: top; white-space: normal; overflow-wrap: anywhere; }
      th { color: #222; background: #eee; font-size: 9px; }
      td { font-size: 9px; }
    </style></head><body><h1>${escapeHtml(title)}</h1><p>${escapeHtml(count)}</p>${printableTable.outerHTML}</body></html>`);
  printWindow.document.close();
}

function renderNav() {
  const groups = {};
  for (const t of state.meta.tables) (groups[t.group] ||= []).push({ ...t, href: `#/table/${t.name}` });
  groups.Reports = state.meta.views.map((v) => ({ ...v, href: `#/view/${v.name}` }));
  if (state.role === "database_manager") groups.Manage = [{label: "Users", href: "#/users"}];

  const current = location.hash || "#/dashboard";
  let html = `<a class="nav-link ${current === "#/dashboard" ? "active" : ""}" ${current === "#/dashboard" ? 'aria-current="page"' : ""} href="#/dashboard">Dashboard</a>`;
  const preferredOrder = ["Locations", "Gardens", "Inventory & Budget", "Reports", "Manage"];
  const orderedGroups = [...preferredOrder.filter(name => groups[name]), ...Object.keys(groups).filter(name => !preferredOrder.includes(name))];
  let sectionIndex = 0;
  for (const group of orderedGroups) {
    const links = groups[group];
    if (!links.length) continue;
    const active = links.some(link => link.href === current);
    const headingId = `nav-section-${sectionIndex++}`;
    html += `<section class="nav-group ${active ? "has-active" : ""}" aria-labelledby="${headingId}">
      <h2 class="nav-group-heading" id="${headingId}">${escapeHtml(group)}</h2>
      <div class="nav-group-links">`;
    for (const link of links) {
      html += `<a class="nav-link ${current === link.href ? "active" : ""}" ${current === link.href ? 'aria-current="page"' : ""} href="${link.href}">${escapeHtml(link.label)}</a>`;
    }
    html += "</div></section>";
  }
  $("#nav").innerHTML = html;
}

function dataTable(rows, { columns, actions = false, foreignKeys = {} } = {}) {
  if (!rows.length) return `<div class="empty">${actions ? "No records yet." : "No records to show."}</div>`;
  const cols = columns || Object.keys(rows[0]);
  const head = cols
    .map((c) => {
      const sorted = state.sort && state.sort.col === c;
      const isNote = c === "notes" || c.endsWith("_notes");
      return `<th data-sort="${escapeHtml(c)}" class="${isNote ? "notes" : ""} ${sorted ? "sorted" : ""} ${sorted && state.sort.desc ? "desc" : ""}">${escapeHtml(label(c))}</th>`;
    })
    .join("");
  const body = rows
    .map((row, index) => {
      const cells = cols
        .map((c) => {
          const isNote = c === "notes" || c.endsWith("_notes");
          const cls = isNote ? "notes" : typeof row[c] === "number" ? "num" : "";
          const noteAttributes = isNote && row[c] != null && String(row[c]) !== ""
            ? ` data-note="${escapeHtml(row[c])}" tabindex="0"` : "";
          const foreignKey = foreignKeys[c];
          const referenceValue = foreignKey && row[c] != null && row[c] !== ""
            ? `<button type="button" class="reference-link" data-reference="${index}" data-reference-column="${escapeHtml(c)}">${formatCell(c, row[c])}</button>`
            : formatCell(c, row[c]);
          return `<td class="${cls}${foreignKey && row[c] != null && row[c] !== "" ? " has-reference" : ""}"${noteAttributes}>${referenceValue}</td>`;
        })
        .join("");
      const rowActions = typeof actions === "function" ? actions(row) : { edit: actions, delete: actions };
      const actionButtons = [
        rowActions.edit ? `<button class="btn small" data-edit="${index}">Edit</button>` : "",
        rowActions.delete ? `<button class="btn small danger" data-delete="${index}">Delete</button>` : "",
      ].join("");
      const buttons = actionButtons ? `<td class="actions">${actionButtons}</td>` : "";
      return `<tr>${cells}${buttons}</tr>`;
    })
    .join("");
  return `<div class="table-wrap"><table class="data-table"><thead><tr>${head}${actions ? "<th></th>" : ""}</tr></thead><tbody>${body}</tbody></table></div>`;
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

function parseCalendarDate(value) {
  const match = String(value || "").slice(0, 10).match(/^(\d{4})-(\d{2})-(\d{2})$/);
  return match ? new Date(Number(match[1]), Number(match[2]) - 1, Number(match[3])) : null;
}

function calendarDateKey(date) {
  return date.getFullYear() + "-" + String(date.getMonth() + 1).padStart(2, "0") + "-" +
    String(date.getDate()).padStart(2, "0");
}

function buildDashboardCalendar(rows, month) {
  const events = [];
  const byDate = new Map();
  const undated = [];
  for (const row of rows) {
    let hasDate = false;
    for (const [kind, field] of [["Sowing", "sow_date"], ["Expected harvest", "expected_harvest_date"]]) {
      const date = parseCalendarDate(row[field]);
      if (!date) continue;
      hasDate = true;
      const event = { row, kind, date: calendarDateKey(date) };
      const index = events.push(event) - 1;
      const entries = byDate.get(event.date) || [];
      entries.push(index);
      byDate.set(event.date, entries);
    }
    if (!hasDate) undated.push(events.push({ row, kind: "Undated planting", date: null }) - 1);
  }

  const monthStart = new Date(month.getFullYear(), month.getMonth(), 1);
  const gridStart = new Date(month.getFullYear(), month.getMonth(), 1 - monthStart.getDay());
  const today = calendarDateKey(new Date());
  const weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    .map(day => '<div class="crop-calendar-weekday">' + day + "</div>").join("");
  const days = Array.from({ length: 42 }, (_, index) => {
    const date = new Date(gridStart.getFullYear(), gridStart.getMonth(), gridStart.getDate() + index);
    const key = calendarDateKey(date);
    const inMonth = date.getMonth() === month.getMonth();
    const classes = ["crop-calendar-day", inMonth ? "" : "outside-month", key === today ? "today" : ""].filter(Boolean).join(" ");
    const dayEvents = (byDate.get(key) || []).map(eventIndex => {
      const event = events[eventIndex];
      const plant = event.row.plant_name || "Planting";
      const place = [event.row.location_name, event.row.bed_name].filter(Boolean).join(" · ");
      const kind = event.kind === "Sowing" ? "sowing" : "harvest";
      const aria = event.kind + ": " + plant + (place ? " at " + place : "") + " on " + key;
      return '<button type="button" class="crop-calendar-event ' + kind + '" data-crop-event="' + eventIndex +
        '" aria-label="' + escapeHtml(aria) + '"><strong>' + (event.kind === "Sowing" ? "Sow" : "Harvest") +
        " · " + escapeHtml(plant) + "</strong>" + (place ? "<span>" + escapeHtml(place) + "</span>" : "") + "</button>";
    }).join("");
    return '<div class="' + classes + '" data-date="' + key + '"><span class="crop-calendar-day-number">' +
      date.getDate() + '</span><div class="crop-calendar-day-events">' + dayEvents + "</div></div>";
  }).join("");
  const undatedMarkup = undated.length
    ? '<section class="crop-calendar-undated"><strong>Undated plantings</strong><div>' + undated.map(index => {
      const row = events[index].row;
      const place = [row.location_name, row.bed_name].filter(Boolean).join(" · ");
      return '<button type="button" class="crop-calendar-event sowing" data-crop-event="' + index + '">' +
        "<strong>" + escapeHtml(row.plant_name || "Planting") + "</strong>" +
        (place ? "<span>" + escapeHtml(place) + "</span>" : "") + "</button>";
    }).join("") + "</div></section>"
    : "";
  return {
    events,
    markup: '<div class="crop-calendar-weekdays">' + weekdays + '</div><div class="crop-calendar-grid">' +
      days + "</div>" + undatedMarkup,
  };
}

function showCropCalendarEvent(event) {
  if (!event) return;
  const dialog = $("#crop-event-dialog");
  const row = event.row;
  $("#crop-event-title").textContent = event.kind + " · " + (row.plant_name || "Planting");
  const fields = [
    ["Calendar event", escapeHtml(event.kind)],
    ["Date", escapeHtml(event.date ? formatCalendarDate(event.date) : "Not scheduled")],
  ];
  for (const name of VIEW_COLUMNS.CropCalendar) {
    if (Object.hasOwn(row, name)) fields.push([label(name), formatCell(name, row[name])]);
  }
  $("#crop-event-fields").innerHTML = "<dl>" + fields.map(([name, value]) =>
    '<div class="reference-field"><dt>' + escapeHtml(name) + "</dt><dd>" + value + "</dd></div>"
  ).join("") + "</dl>";
  if (!dialog.open) dialog.showModal();
}

// Show every field from a crop-rotation row in the shared read-only hover popup.
function showCropRotationPreview(anchor, row) {
  hideNotePreview();
  clearTimeout(referenceHideTimer);
  if (previewedReference && previewedReference !== anchor) previewedReference.removeAttribute("aria-describedby");
  previewedReference = anchor;
  previewedReferenceKey = `crop_rotation:${row.rotation_id}`;
  anchor.setAttribute("aria-describedby", "reference-preview");
  $("#reference-preview-heading").textContent = "Crop Rotation Details";
  $("#reference-preview-text").innerHTML = `<dl>${Object.entries(row).map(([name, value]) =>
    `<div class="reference-field"><dt>${escapeHtml(label(name))}</dt><dd>${formatCell(name, value)}</dd></div>`
  ).join("")}</dl>`;
  positionPreview(referencePreview, anchor);
}

function formatCalendarDate(value) {
  const date = parseCalendarDate(value);
  return date ? new Intl.DateTimeFormat(undefined, { month: "long", day: "numeric", year: "numeric" }).format(date) : String(value || "");
}

function renderDashboardCalendar(rows) {
  const calendar = buildDashboardCalendar(rows, dashboardCalendarMonth);
  $("#dashboard-calendar-month").textContent = new Intl.DateTimeFormat(undefined, {
    month: "long", year: "numeric",
  }).format(dashboardCalendarMonth);
  $("#dashboard-calendar-content").innerHTML = calendar.markup;
  $("#dashboard-calendar-content").querySelectorAll("[data-crop-event]").forEach(button => {
    button.onclick = () => showCropCalendarEvent(calendar.events[Number(button.dataset.cropEvent)]);
  });
}

function buildCropRotationCalendar(rows, month) {
  const byDate = new Map();
  const undated = [];
  rows.forEach((row, index) => {
    const date = parseCalendarDate(row.sow_date);
    if (!date) {
      undated.push(index);
      return;
    }
    const key = calendarDateKey(date);
    const entries = byDate.get(key) || [];
    entries.push(index);
    byDate.set(key, entries);
  });

  const monthStart = new Date(month.getFullYear(), month.getMonth(), 1);
  const gridStart = new Date(month.getFullYear(), month.getMonth(), 1 - monthStart.getDay());
  const today = calendarDateKey(new Date());
  const weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
    .map(day => '<div class="crop-calendar-weekday">' + day + "</div>").join("");
  const days = Array.from({ length: 42 }, (_, index) => {
    const date = new Date(gridStart.getFullYear(), gridStart.getMonth(), gridStart.getDate() + index);
    const key = calendarDateKey(date);
    const classes = [
      "crop-calendar-day", date.getMonth() === month.getMonth() ? "" : "outside-month",
      key === today ? "today" : "",
    ].filter(Boolean).join(" ");
    const entries = (byDate.get(key) || []).map(rowIndex => {
      const row = rows[rowIndex];
      const place = [row.location_name, row.bed_name].filter(Boolean).join(" · ");
      return '<button type="button" class="crop-calendar-event sowing" data-rotation-index="' + rowIndex +
        '" aria-label="Edit ' + escapeHtml(row.plant_name || "planting") + (place ? " at " + escapeHtml(place) : "") + '">' +
        "<strong>" + escapeHtml(row.plant_name || "Planting") + "</strong>" +
        (place ? "<span>" + escapeHtml(place) + "</span>" : "") + "</button>";
    }).join("");
    return '<div class="' + classes + '"><button type="button" class="rotation-day-add" data-rotation-date="' + key +
      '" aria-label="Add crop rotation for ' + escapeHtml(formatCalendarDate(key)) + '"><span class="crop-calendar-day-number">' +
      date.getDate() + '</span><span class="rotation-add-mark" aria-hidden="true">+</span></button>' +
      '<div class="crop-calendar-day-events">' + entries + "</div></div>";
  }).join("");
  const undatedMarkup = undated.length
    ? '<section class="crop-calendar-undated"><strong>Undated rotations</strong><div>' + undated.map(index => {
      const row = rows[index];
      const place = [row.location_name, row.bed_name].filter(Boolean).join(" · ");
      return '<button type="button" class="crop-calendar-event sowing" data-rotation-index="' + index +
        '"><strong>' + escapeHtml(row.plant_name || "Planting") + "</strong>" +
        (place ? "<span>" + escapeHtml(place) + "</span>" : "") + "</button>";
    }).join("") + "</div></section>"
    : "";
  return '<div class="crop-calendar-weekdays">' + weekdays + '</div><div class="crop-calendar-grid">' +
    days + "</div>" + undatedMarkup;
}

/* ---------- Dashboard ---------- */

async function showDashboard() {
  setHeader("Dashboard", "Garden program overview");
  content.innerHTML = '<div class="empty">Loading…</div>';
  const data = await api("/dashboard");
  const c = data.counts;
  const stat = (value, text, href, warn = false) =>
    `<div class="card stat ${warn && value > 0 ? "alert-stat" : ""}"><a class="stat-value stat-link" href="${href}" aria-label="View ${text}">${value}</a><div class="stat-label">${text}</div></div>`;

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
      ${stat(c.hlc_locations, "HLC locations", "#/table/location")}
      ${stat(c.inventory_items, "Inventory items", "#/table/inventory_list")}
      ${stat(c.maintenance_items, "Garden items needing maintenance", "#/view/GardenAssets", true)}
      ${stat(c.restock_needed, "Items to restock", "#/view/RestockList", true)}
      ${stat(c.pending_requests, "Pending requests", "#/view/PendingRequests", true)}
    </div>
    <div class="grid-2">
      ${state.role === "staff" ? "" : `<div class="card"><div class="card-header">Budgets remaining <a href="#/table/budget" class="muted">Manage</a></div><div class="card-body">${budgets}</div></div>`}
      <div class="card"><div class="card-header">Restock needed <a href="#/view/RestockList" class="muted">View all</a></div>
        ${dataTable(data.restock, { columns: ["item_name", "instock_total", "reorder_point", "storage_location"] })}</div>
    </div>
    <section class="card crop-calendar-card" aria-label="Upcoming crop calendar">
      <div class="card-header crop-calendar-heading">
        <strong>Upcoming plantings</strong>
        <div class="crop-calendar-controls">
          <button type="button" class="btn small" id="dashboard-calendar-prev" aria-label="Previous month">‹</button>
          <strong id="dashboard-calendar-month"></strong>
          <button type="button" class="btn small" id="dashboard-calendar-next" aria-label="Next month">›</button>
          <button type="button" class="btn small" id="dashboard-calendar-today">Today</button>
          <a href="#/view/CropCalendar" class="muted">Table</a>
        </div>
      </div>
      <div id="dashboard-calendar-content"></div>
    </section>
  `;
  const shiftCalendarMonth = amount => {
    dashboardCalendarMonth = new Date(dashboardCalendarMonth.getFullYear(), dashboardCalendarMonth.getMonth() + amount, 1);
    renderDashboardCalendar(data.rotations);
  };
  $("#dashboard-calendar-prev").onclick = () => shiftCalendarMonth(-1);
  $("#dashboard-calendar-next").onclick = () => shiftCalendarMonth(1);
  $("#dashboard-calendar-today").onclick = () => {
    dashboardCalendarMonth = new Date(new Date().getFullYear(), new Date().getMonth(), 1);
    renderDashboardCalendar(data.rotations);
  };
  $("#crop-event-close").onclick = () => $("#crop-event-dialog").close();
  renderDashboardCalendar(data.rotations);
}

/* ---------- Report views ---------- */

// Keep the same columns in view when sorting or searching a wide table.
function renderRecordContent(html) {
  hideNotePreview();
  hideReferencePreview();
  const left = content.querySelector(".table-wrap")?.scrollLeft || 0;
  content.innerHTML = html;
  const wrapper = content.querySelector(".table-wrap");
  if (wrapper) wrapper.scrollLeft = left;
}

async function showView(name) {
  const view = state.meta.views.find((v) => v.name === name);
  if (!view) return showError(new Error(`Unknown report: ${name}`));
  setHeader(view.label, view.description || "", printButton + '<input id="search" class="search" type="search" placeholder="Search…">', true);
  content.innerHTML = '<div class="empty">Loading…</div>';
  state.rows = await api(`/views/${name}`);
  const render = () => {
    const rowColumns = state.rows.length ? Object.keys(state.rows[0]) : [];
    const preferredColumns = VIEW_COLUMNS[name] || rowColumns;
    const columns = [
      ...preferredColumns.filter((c) => rowColumns.includes(c)),
      ...rowColumns.filter((c) => !preferredColumns.includes(c)),
    ];
    const visible = filterAndSort(state.rows);
    renderRecordContent(`<div class="card">${dataTable(visible, { columns })}</div><p class="muted">${visible.length} of ${state.rows.length} records</p>`);
    bindTableControls(render);
  };
  render();
}

/* ---------- Editable tables ---------- */

async function showTable(name) {
  const table = state.meta.tables.find((t) => t.name === name);
  if (!table) return showError(new Error(`Unknown table: ${name}`));
  const cropModeControls = name === "crop_rotation"
    ? '<div class="view-mode-toggle" role="group" aria-label="Crop rotation display">' +
      '<button type="button" class="btn small" id="crop-rotation-table-mode">Table</button>' +
      '<button type="button" class="btn small" id="crop-rotation-calendar-mode">Calendar</button></div>'
    : "";
  setHeader(
    table.label,
    table.description || "",
    printButton + cropModeControls + '<input id="search" class="search" type="search" placeholder="Search…"><button class="btn primary" id="add-btn">+ Add</button>',
    true
  );
  content.innerHTML = '<div class="empty">Loading…</div>';
  const [schema, rows] = await Promise.all([api(`/tables/${name}/schema`), api(`/tables/${name}`)]);
  state.schema = schema;
  state.rows = rows;

  const render = () => {
    const visible = filterAndSort(state.rows);
    const foreignKeys = Object.fromEntries(schema.columns.filter((c) => c.foreign_key).map((c) => [c.name, c.foreign_key]));
    if (name === "location_group") {
      foreignKeys.location_group_name = {
        ref_table: "location_group", ref_column: "location_group_id", value_column: "location_group_id",
      };
    }
    const page = name === "crop_rotation" && cropRotationMode === "calendar"
      ? '<div class="card crop-rotation-calendar-card"><div class="card-header crop-rotation-calendar-heading">' +
        '<div><strong>Sow dates</strong><div class="muted">Click a day to add a rotation; click a planting to edit it.</div></div>' +
        '<div class="crop-calendar-controls"><button type="button" class="btn small" id="crop-rotation-prev" aria-label="Previous month">‹</button>' +
        '<strong id="crop-rotation-month"></strong><button type="button" class="btn small" id="crop-rotation-next" aria-label="Next month">›</button>' +
        '<button type="button" class="btn small" id="crop-rotation-today">Today</button></div></div>' +
        buildCropRotationCalendar(visible, cropRotationMonth) + '</div><p class="muted">' +
        visible.length + " of " + state.rows.length + " rotations</p>"
      : '<div class="card">' + dataTable(visible, {
        columns: schema.columns.map((c) => c.name),
        foreignKeys,
        actions: (row) => ({ edit: canEdit(name, row), delete: canDelete(name, row) }),
      }) + '</div><p class="muted">' + visible.length + " of " + state.rows.length + " records</p>";
    renderRecordContent(page);
    bindTableControls(render);
    if (name === "crop_rotation" && cropRotationMode === "calendar") {
      $("#crop-rotation-month").textContent = new Intl.DateTimeFormat(undefined, {
        month: "long", year: "numeric",
      }).format(cropRotationMonth);
      $("#crop-rotation-prev").onclick = () => {
        cropRotationMonth = new Date(cropRotationMonth.getFullYear(), cropRotationMonth.getMonth() - 1, 1);
        render();
      };
      $("#crop-rotation-next").onclick = () => {
        cropRotationMonth = new Date(cropRotationMonth.getFullYear(), cropRotationMonth.getMonth() + 1, 1);
        render();
      };
      $("#crop-rotation-today").onclick = () => {
        cropRotationMonth = new Date(new Date().getFullYear(), new Date().getMonth(), 1);
        render();
      };
      content.querySelectorAll("[data-rotation-index]").forEach(button => {
        const row = visible[Number(button.dataset.rotationIndex)];
        button.onpointerenter = event => { if (event.pointerType !== "touch" && row) showCropRotationPreview(button, row); };
        button.onpointerleave = event => {
          if (!referencePreview.contains(event.relatedTarget)) scheduleReferenceHide();
        };
        button.onfocus = () => { if (row) showCropRotationPreview(button, row); };
        button.onblur = event => { if (!referencePreview.contains(event.relatedTarget)) scheduleReferenceHide(); };
        button.onclick = () => openForm(visible[Number(button.dataset.rotationIndex)]);
      });
      content.querySelectorAll("[data-rotation-date]").forEach(button => {
        button.onclick = () => openForm(null, { sow_date: button.dataset.rotationDate });
      });
    }
    content.querySelectorAll("[data-reference]").forEach((button) => {
      const showPreview = () => {
        const row = visible[Number(button.dataset.reference)];
        const column = button.dataset.referenceColumn;
        const foreignKey = schema.columns.find((item) => item.name === column)?.foreign_key;
        if (row && foreignKey) showReferencePreview(button, column, row, foreignKey);
      };
      button.onpointerenter = (event) => { if (event.pointerType !== "touch") showPreview(); };
      button.onpointerleave = (event) => {
        if (!referencePreview.contains(event.relatedTarget)) scheduleReferenceHide();
      };
      button.onfocus = showPreview;
      button.onblur = (event) => { if (!referencePreview.contains(event.relatedTarget)) scheduleReferenceHide(); };
      button.onclick = showPreview;
    });
    content.querySelectorAll("[data-edit]").forEach((b) => (b.onclick = () => openForm(visible[b.dataset.edit])));
    content.querySelectorAll("[data-delete]").forEach((b) => (b.onclick = () => deleteRow(visible[b.dataset.delete])));
  };
  render();
  if (name === "crop_rotation") {
    const setMode = mode => {
      cropRotationMode = mode;
      for (const [id, selected] of [
        ["crop-rotation-table-mode", mode === "table"],
        ["crop-rotation-calendar-mode", mode === "calendar"],
      ]) {
        const button = $("#" + id);
        button.classList.toggle("active", selected);
        button.setAttribute("aria-pressed", String(selected));
      }
      render();
    };
    $("#crop-rotation-table-mode").onclick = () => setMode("table");
    $("#crop-rotation-calendar-mode").onclick = () => setMode("calendar");
    setMode(cropRotationMode);
  }
  const addButton = $("#add-btn");
  if (addButton) addButton.onclick = () => openForm(null);
}

function rowDate(name, row) {
  if (name === "purchase_request") return row.request_date;
  if (name === "inventory_transaction") return row.transaction_date;
  return null;
}

function sameDayRow(name, row) {
  const date = rowDate(name, row);
  return Boolean(date) && String(date).slice(0, 10) === new Date().toISOString().slice(0, 10);
}

function canEdit(name, row) {
  if (state.role === "database_manager") return true;
  if (["purchase_request", "inventory_transaction"].includes(name)) return sameDayRow(name, row);
  return true;
}

function canDelete(name, row) {
  if (state.role === "database_manager") return true;
  if (state.role === "finance_staff" && name === "budget") return true;
  if (["purchase_request", "inventory_transaction"].includes(name)) return sameDayRow(name, row);
  return false;
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

function inputFor(col, value, isNew = false) {
  const id = `f_${col.name}`;
  const required = col.required ? "required" : "";
  let v = value ?? "";
  // Fill simple database defaults only for new records; preserve existing NULLs on edits.
  if (isNew && value == null && col.default_value != null) {
    const defaultValue = String(col.default_value);
    if (col.data_type === "date" && defaultValue === "CURRENT_DATE") {
      v = new Date().toISOString().slice(0, 10);
    } else if (["integer", "numeric"].includes(col.data_type) && /^-?\d+(\.\d+)?$/.test(defaultValue)) {
      v = defaultValue;
    } else if (col.enum) {
      const match = defaultValue.match(/^'((?:[^']|'')*)'(?:::.*)?$/);
      if (match) v = match[1].replace(/''/g, "'");
    }
  }

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

async function openForm(record, initialValues = {}) {
  hideNotePreview();
  hideReferencePreview();
  const schema = state.schema;
  const tableLabel = state.meta.tables.find((t) => t.name === schema.name).label;
  $("#dialog-title").textContent = record ? `Edit ${tableLabel}` : `Add to ${tableLabel}`;
  $("#form-error").hidden = true;

  const editable = schema.columns.filter((c) => !c.readonly);
  $("#form-fields").innerHTML = editable
    .map((c) => inputFor(c, record ? record[c.name] : (initialValues[c.name] ?? null), !record))
    .join("");

  try {
    state.options = await api(`/tables/${schema.name}/options`);
  } catch (err) {
    state.options = {};
  }
  fillForeignKeySelects(record || initialValues);
  recordBaseline = recordSnapshot();

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
    if (recordSaving) return;
    recordSaving = true;
    submit.disabled = true;
    try {
      if (record) {
        await api(`/tables/${schema.name}`, { method: "PUT", body: { key: rowKey(record), values: payload } });
        toast("Changes saved");
      } else {
        await api(`/tables/${schema.name}`, { method: "POST", body: { values: payload } });
        toast("Record added");
      }
      recordBaseline = null;
      $("#dialog").close();
      await reloadTable();
    } catch (err) {
      const box = $("#form-error");
      box.textContent = err.detail ? `${err.message} — ${err.detail}` : err.message;
      box.hidden = false;
    } finally {
      recordSaving = false;
      submit.disabled = false;
    }
  };
  $("#dialog").showModal();
}

document.querySelectorAll("[data-close]").forEach((b) => (b.onclick = closeRecordForm));
$("#dialog").oncancel = event => {
  event.preventDefault();
  closeRecordForm();
};

/* ---------- Manager user access ---------- */

async function showUsers() {
  if (state.role !== "database_manager") throw new Error("Only a database manager can manage users.");
  setHeader("Users", "Manage who can access the Garden Program app.", '<button class="btn" id="refresh-users">Refresh</button>');
  content.innerHTML = '<div class="empty">Loading accounts…</div>';
  let users = await api("/users");
  content.innerHTML = `
    <div class="user-notice" id="users-notice" role="status" hidden></div>
    <section class="user-summary" aria-label="Account summary">
      <div class="card"><strong id="user-count"></strong><span>Accounts</span></div>
      <div class="card"><strong id="assigned-count"></strong><span>With app access</span></div>
      <div class="card"><strong id="unassigned-count"></strong><span>Without app access</span></div>
    </section>
    <section class="card">
      <div class="users-heading"><div><h2>People &amp; roles</h2><p>Choose a role, then save your change.</p></div>
        <input class="search" id="search-users" type="search" placeholder="Search accounts…" aria-label="Search accounts"></div>
      <div class="table-wrap"><table><thead><tr><th>Account</th><th>Current access</th><th>Role</th><th class="user-actions-heading">Actions</th></tr></thead><tbody id="users-body"></tbody></table></div>
      <div class="empty" id="users-empty" hidden>No matching accounts.</div>
    </section>
    <p class="access-note"><strong>Your own role is protected</strong> so you cannot accidentally remove your manager access.<br>
      Removing access keeps the person's account. They can be assigned a role again later.</p>
    <p class="access-note">Account invitations are still sent through Supabase by the project administrator.</p>`;

  const renderUsers = () => {
    users.sort((a, b) => (a.email || a.user_id).localeCompare(b.email || b.user_id));
    const query = $("#search-users").value.toLowerCase();
    $("#user-count").textContent = users.length;
    $("#assigned-count").textContent = users.filter(user => user.database_role).length;
    $("#unassigned-count").textContent = users.filter(user => !user.database_role).length;
    const rows = users.map((user, index) => {
      if (!`${user.email || ""} ${user.user_id}`.toLowerCase().includes(query)) return "";
      const self = user.user_id === state.meta.user.id;
      const role = user.database_role;
      const selectedRole = pendingRoleEdits.get(user.user_id) ?? role;
      const email = user.email || "Account without email";
      return `<tr><td><div class="user-name"><span class="user-avatar" aria-hidden="true">${escapeHtml(email.slice(0, 2).toUpperCase())}</span>
        <div><strong>${escapeHtml(email)}${self ? ' <span class="muted">(you)</span>' : ""}</strong><small>${escapeHtml(user.user_id)}</small></div></div></td>
        <td><span class="role-pill ${role ? "" : "none"}">${escapeHtml(ROLE_LABELS[role] || "No app access")}</span></td>
        <td><select class="role-select" aria-label="Role for ${escapeHtml(email)}" data-user-role="${index}" ${self ? "disabled" : ""}>
          <option value="" ${!selectedRole ? "selected" : ""} disabled>Choose a role</option>
          ${Object.entries(ROLE_LABELS).map(([key, name]) => `<option value="${key}" ${key === selectedRole ? "selected" : ""}>${name}</option>`).join("")}</select></td>
        <td><div class="user-actions"><button class="btn small primary" data-user-save="${index}" ${self || !pendingRoleEdits.has(user.user_id) ? "disabled" : ""}>Save</button>
          <button class="btn small" data-user-reset="${index}" ${!user.email ? 'disabled title="This account has no email address"' : ""}>Send password reset email</button>
          <button class="btn small danger" data-user-remove="${index}" ${self || !role ? "disabled" : ""}>Remove access</button></div></td></tr>`;
    }).join("");
    $("#users-body").innerHTML = rows;
    $("#users-empty").hidden = Boolean(rows);
    content.querySelectorAll("[data-user-role]").forEach(select => {
      select.onchange = () => {
        const user = users[select.dataset.userRole];
        if (select.value && select.value !== user.database_role) pendingRoleEdits.set(user.user_id, select.value);
        else pendingRoleEdits.delete(user.user_id);
        content.querySelector(`[data-user-save="${select.dataset.userRole}"]`).disabled = !select.value || select.value === user.database_role;
      };
    });
    content.querySelectorAll("[data-user-save]").forEach(button => {
      button.onclick = () => confirmUserAction(users[button.dataset.userSave], {role: content.querySelector(`[data-user-role="${button.dataset.userSave}"]`).value});
    });
    content.querySelectorAll("[data-user-remove]").forEach(button => {
      button.onclick = () => confirmUserAction(users[button.dataset.userRemove]);
    });
    content.querySelectorAll("[data-user-reset]").forEach(button => {
      button.onclick = () => confirmUserAction(users[button.dataset.userReset], {resetPassword: true});
    });
  };

  const confirmUserAction = (user, {role = null, resetPassword = false} = {}) => {
    if (resetPassword ? !user.email : user.user_id === state.meta.user.id) return;
    const dialog = $("#role-dialog");
    const confirm = $("#role-confirm");
    const confirmLabel = resetPassword ? "Send reset email" : "Confirm";
    $("#role-dialog-title").textContent = resetPassword ? "Send password reset email?" : role ? "Change app role?" : "Remove app access?";
    $("#role-description").textContent = resetPassword ? `Request a password reset email for ${user.email}.` : role
      ? `${user.email || user.user_id} will have the ${ROLE_LABELS[role]} role.`
      : `${user.email || user.user_id} will no longer have an assigned app role.`;
    $("#role-detail").textContent = resetPassword
      ? "They choose their own new password. They must have the Garden Program app running on their computer when opening the email link."
      : role === "database_manager"
      ? "Database managers can manage all records and assign roles to other users."
      : role ? "Their access will follow the permissions of the selected role." : "Their sign-in account and existing records will be kept.";
    $("#role-error").hidden = true;
    $("#role-session-note").hidden = resetPassword;
    confirm.disabled = false;
    confirm.textContent = confirmLabel;
    $("#role-close").onclick = $("#role-cancel").onclick = () => { if (!confirm.disabled) dialog.close(); };
    dialog.oncancel = event => { if (confirm.disabled) event.preventDefault(); };
    $("#role-form").onsubmit = async event => {
      event.preventDefault();
      if (confirm.disabled) return;
      confirm.disabled = true;
      confirm.textContent = resetPassword ? "Requesting email…" : "Saving…";
      $("#role-error").hidden = true;
      try {
        if (resetPassword) {
          await api(`/users/${encodeURIComponent(user.user_id)}/password-reset`, {method: "POST"});
        } else {
          await api(`/users/${encodeURIComponent(user.user_id)}/role`, role
            ? { method: "PUT", body: { role } }
            : { method: "DELETE" });
        }
      } catch (error) {
        $("#role-error").textContent = error.detail ? `${error.message} ${error.detail}` : error.message;
        $("#role-error").hidden = false;
        confirm.disabled = false;
        confirm.textContent = confirmLabel;
        return;
      }
      dialog.close();
      if (resetPassword) {
        if ($("#users-notice")) {
          $("#users-notice").textContent = `Password reset email requested for ${user.email}. Ask them to check their inbox and spam folder, and start the app before opening the link.`;
          $("#users-notice").hidden = false;
        }
        toast("Password reset email requested");
        return;
      }
      toast(role ? "App role saved" : "App access removed");
      pendingRoleEdits.delete(user.user_id);
      try {
        users = await api("/users");
        if ((location.hash || "").split("/")[1] === "users" && $("#users-body")) renderUsers();
      } catch (error) {
        if ((location.hash || "").split("/")[1] === "users") showError(error);
      }
    };
    dialog.showModal();
  };

  $("#search-users").oninput = renderUsers;
  $("#refresh-users").onclick = () => {
    if (!confirmDiscardChanges()) return;
    pendingRoleEdits.clear();
    showUsers().catch(showError);
  };

  renderUsers();
}

/* ---------- Router ---------- */

async function route() {
  if (!appStarted || !state.meta) return;
  const nextHash = location.hash || "#/dashboard";
  if (currentRouteHash !== null && nextHash !== currentRouteHash) {
    if (!confirmDiscardChanges()) {
      history.replaceState(null, "", `${location.pathname}${location.search}${currentRouteHash}`);
      return;
    }
    discardRecordDraft();
    pendingRoleEdits.clear();
  }
  currentRouteHash = nextHash;
  state.search = "";
  state.sort = null;
  renderNav();
  const [, kind, name] = (location.hash || "#/dashboard").split("/");
  try {
    if (kind === "table") await showTable(decodeURIComponent(name));
    else if (kind === "view") await showView(decodeURIComponent(name));
    else if (kind === "users") await showUsers();
    else await showDashboard();
  } catch (err) {
    showError(err);
  }
}

$("#login-form").onsubmit = async (event) => {
  event.preventDefault();
  const submit = $("#login-submit");
  const message = $("#login-message");
  submit.disabled = true;
  submit.textContent = "Signing in…";
  message.textContent = "";
  const { data, error } = await supabaseClient.auth.signInWithPassword({
    email: $("#login-email").value.trim(),
    password: $("#login-password").value,
  });
  if (error) return showLogin(error.message);
  await openApp(data.session);
};

$("#forgot-password").onclick = () => {
  showLogin();
  $("#login-form").hidden = true;
  $("#forgot-form").hidden = false;
  $("#login-access-note").hidden = true;
  $("#login-heading").textContent = "Reset your password";
  $("#login-intro").textContent = "Enter your account email to request a reset link.";
  $("#forgot-email").value = $("#login-email").value.trim();
  $("#forgot-message").textContent = "";
  $("#forgot-message").classList.remove("success");
};

$("#forgot-cancel").onclick = () => showLogin();

$("#forgot-form").onsubmit = async event => {
  event.preventDefault();
  const submit = $("#forgot-submit");
  if (submit.disabled) return;
  const email = $("#forgot-email").value.trim();
  if (!email) return;
  submit.disabled = true;
  submit.textContent = "Requesting email…";
  const message = $("#forgot-message");
  message.textContent = "";
  message.classList.remove("success");
  try {
    const { error } = await supabaseClient.auth.resetPasswordForEmail(email, {redirectTo: `${location.origin}/`});
    if (error) throw error;
    message.textContent = "If an account exists for this email, you will receive a reset link. Check your inbox and spam folder. Keep the app running when you open the link.";
    message.classList.add("success");
  } catch (error) {
    message.textContent = error.status === 429
      ? "Too many reset email requests. Wait a while before trying again."
      : "Could not request the reset email. Please try again later or contact your manager.";
  } finally {
    submit.disabled = false;
    submit.textContent = "Send reset email";
  }
};

$("#toggle-password").onclick = () => {
  const input = $("#login-password");
  const reveal = input.type === "password";
  input.type = reveal ? "text" : "password";
  $("#toggle-password").textContent = reveal ? "Hide" : "Show";
  $("#toggle-password").setAttribute("aria-pressed", String(reveal));
};

$("#sign-out").onclick = async () => {
  if (!confirmDiscardChanges()) return;
  await supabaseClient.auth.signOut();
  showLogin("You have been signed out.");
};

$("#reset-form").onsubmit = async (event) => {
  event.preventDefault();
  if (passwordSaving) return;
  const isInvite = passwordSetupFlow === "invite";
  const password = $("#reset-password").value;
  const message = $("#reset-message");
  if (password !== $("#reset-confirm").value) {
    message.textContent = "The passwords do not match.";
    return;
  }
  const submit = $("#reset-submit");
  passwordSaving = true;
  submit.disabled = true;
  submit.textContent = "Saving…";
  message.textContent = "";
  try {
    const { data: { session }, error: sessionError } = await supabaseClient.auth.getSession();
    if (sessionError || !session) throw new Error("This email link has expired. Use Forgot password? to request a new reset email.");
    const { error } = await supabaseClient.auth.updateUser({ password });
    if (error) throw error;
    const { error: signOutError } = await supabaseClient.auth.signOut({ scope: "local" });
    if (signOutError) throw new Error("Your password was saved. Please reload the app to sign in.");
    clearPasswordSetup();
    showLogin(isInvite ? "Your password is saved. Sign in to your Garden Program account." : "Password updated. Sign in with your new password.");
  } catch (err) {
    message.textContent = err.message;
  } finally {
    passwordSaving = false;
    submit.disabled = false;
    submit.textContent = isInvite ? "Save password" : "Save new password";
  }
};

$("#reset-cancel").onclick = async () => {
  if (!confirmDiscardChanges()) return;
  const { error } = await supabaseClient.auth.signOut({ scope: "local" });
  if (error) {
    $("#reset-message").textContent = error.message;
    return;
  }
  clearPasswordSetup();
  showLogin();
};

supabaseClient.auth.onAuthStateChange((event, session) => {
  if (event === "PASSWORD_RECOVERY") return showPasswordSetup("recovery");
  if (settingPassword) return;
  if (event === "SIGNED_OUT") showLogin();
  if (event === "SIGNED_IN" && !appStarted && !initializingSession) setTimeout(() => openApp(session), 0);
});

(async function init() {
  try {
    const { data: { session }, error } = await supabaseClient.auth.getSession();
    if (authRedirectError || error) {
      clearPasswordSetup();
      return showLogin("Your session or email link could not be used. Sign in again, or use Forgot password? if needed.");
    }
    if (settingPassword) {
      if (session) return showPasswordSetup();
      clearPasswordSetup();
      return showLogin("This email link has expired or is invalid. Use Forgot password? to request a new reset email.");
    }
    if (!session) return showLogin();

    // A saved session can contain yesterday's role. Issue a new token so the
    // existing Supabase hook picks up the manager's latest role assignment.
    const { data, error: refreshError } = await supabaseClient.auth.refreshSession();
    if (refreshError || !data.session) {
      return showLogin("Could not refresh your sign-in permissions. Check your connection and sign in again.");
    }
    await openApp(data.session);
  } catch {
    showLogin("Could not refresh your sign-in permissions. Check your connection and sign in again.");
  } finally {
    initializingSession = false;
  }
})();
