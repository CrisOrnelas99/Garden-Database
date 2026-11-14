const state = { meta: null, schema: null, rows: [], options: {}, sort: null, search: "", role: null };
const financialReportModes = { BudgetPurchases: "summary", FundingSourceSpending: "summary", YearlyPurchase: "summary" };
let cropRotationMode = "table";
let dataExportReminderDismissed = false;

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
let expandedNavGroup = null;
let formReadonlyNames = new Set();

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
let weeklySignOutTimer = null;
let signOutNotice = "";
let recordBaseline = null;
let recordSaving = false;
let currentRouteHash = null;
const pendingRoleEdits = new Map();
const pendingDisplayNameEdits = new Map();
let dashboardCalendarMonth = new Date(new Date().getFullYear(), new Date().getMonth(), 1);
let cropCalendarReportMode = "table";
let cropCalendarReportMonth = new Date(new Date().getFullYear(), new Date().getMonth(), 1);
let schoolSupplyMode = "overview";

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
  return hasUnsavedRecord() || pendingRoleEdits.size > 0 || pendingDisplayNameEdits.size > 0 ||
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

function startWeeklySignOutTimer(deadlineTimestamp) {
  clearTimeout(weeklySignOutTimer);
  const delay = Number(deadlineTimestamp) * 1000 - Date.now();
  weeklySignOutTimer = setTimeout(() => {
    void expireLocalSignIn("Weekly sign-in ended Monday at 12:01 a.m. Please sign in again.");
  }, Math.max(0, Math.min(delay, 2147483647)));
}

async function expireLocalSignIn(message) {
  clearTimeout(weeklySignOutTimer);
  signOutNotice = message;
  try {
    const { error } = await supabaseClient.auth.signOut({ scope: "local" });
    if (error) signOutNotice = "";
  } catch {
    signOutNotice = "";
  }
  showLogin(message, "info");
}

function showLogin(message = "", messageTone = "error") {
  clearTimeout(weeklySignOutTimer);
  hideNotePreview();
  hideReferencePreview();
  discardRecordDraft();
  pendingRoleEdits.clear();
  pendingDisplayNameEdits.clear();
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
  const loginMessage = $("#login-message");
  loginMessage.textContent = message;
  loginMessage.classList.toggle("success", messageTone === "success");
  loginMessage.classList.toggle("info", messageTone === "info");
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

// Ask an invited user to sign in after they finish setting their password.
function showInviteLogin() {
  $("#invite-login-password").value = "";
  const message = $("#invite-login-message");
  message.textContent = "";
  message.classList.remove("success", "info");
  const dialog = $("#invite-login-dialog");
  if (!dialog.open) dialog.showModal();
  requestAnimationFrame(() => $("#invite-login-password").focus());
}

async function openApp(session) {
  if (settingPassword) return showPasswordSetup();
  if (!session?.access_token) return showLogin();
  if (appStarted) return true;
  appStarted = true;
  $("#login-screen").hidden = true;
  $("#app-shell").hidden = false;
  $("#account-email").textContent = session.user?.email || "Signed in";
  content.innerHTML = '<div class="empty">Loading your access…</div>';
  try {
    state.meta = await api("/meta");
    startWeeklySignOutTimer(state.meta.weekly_sign_out_at);
    state.role = state.meta.role;
    $("#account-role").textContent = ROLE_LABELS[state.role] || state.role;
    updateDataExportReminder();
    window.addEventListener("hashchange", route);
    if (!location.hash) location.hash = "#/dashboard";
    await route();
    return true;
  } catch (err) {
    appStarted = false;
    state.meta = null;
    state.role = null;
    if (err.message.includes("no Garden Program role")) {
      await supabaseClient.auth.signOut();
      showLogin("Your account is signed in but has no Garden Program role yet. Ask a manager to assign one.");
      return false;
    }
    if (err.sessionExpired) return false;
    content.innerHTML = `<div class="banner"><strong>Could not load the app.</strong> ${escapeHtml(err.message)}</div>
      <button class="btn primary" id="retry-startup">Try again</button>`;
    $("#retry-startup").onclick = () => openApp(session);
    return false;
  }
}

const LABELS = {
  instock_total: "In Stock",
  bed_size_sq_ft: "Bed Size (sq ft)",
  is_hlc: "HLC",
  is_full: "Full",
  location_group_name: "Location Group",
  associated_schools: "Associated Schools",
  unit_cost_at_request: "Unit Cost at Request",
  current_location_count: "Current Location Count",
  current_total_quantity: "Current Total Quantity",
  planned_quantity: "Planned Quantity",
  in_ground_quantity: "In-Ground Quantity",
  harvested_quantity: "Harvested Quantity",
  removed_quantity: "Removed Quantity",
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
    "purchase_requests_pending", "total_spent",
  ],
  SchoolSupplyRequests: [
    "assignment_type", "location_name", "request_id", "request_date", "item_name",
    "requested_by", "quantity_requested", "status", "total_cost", "notes",
  ],
  SchoolSupplyCheckedOut: [
    "assignment_type", "location_name", "item_name", "current_quantity",
    "transaction_count", "last_transaction_date",
  ],
  BudgetPurchases: [
    "budget_name", "request_id", "item_name", "total_quantity_ordered", "total_spent",
  ],
  FundingSourceSpending: [
    "funding_source", "request_id", "item_name", "total_quantity_ordered",
  ],
  ItemSpending: [
    "item_name", "purchase_request_count", "total_quantity_ordered", "total_spent", "average_unit_cost",
  ],
  YearlyPurchase: ["school_year", "purchase_month", "purchase_request_count", "total_quantity_ordered", "total_spent", "pending_spending"],
  PlantCount: ["plant_name", "current_location_count", "planned_quantity", "current_total_quantity", "in_ground_quantity", "harvested_quantity", "removed_quantity"],
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
const isMoneyColumn = (name) => /cost|budget|spent|spending/.test(name) && !/quantity|items_|_id$/.test(name);

function formatCell(name, value) {
  if (value === null || value === undefined || value === "") return '<span class="muted">—</span>';
  if (typeof value === "boolean") return `<span class="pill ${value ? "yes" : "no"}">${value ? "Yes" : "No"}</span>`;
  if (/(status|condition)/i.test(name)) {
    const status = String(value).trim().toLowerCase();
    let tone = "neutral";
    if (["good", "active", "in-ground", "checked in", "approved", "harvested", "complete", "completed", "delivered", "delivered to fns", "ordered"].includes(status)) tone = "green";
    else if (["requested", "planned", "pending", "awaiting", "fair", "scheduled", "needs review"].includes(status)) tone = "yellow";
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
    if (res.status === 401 && data.error === "Weekly sign-in expired. Please sign in again.") {
      err.sessionExpired = true;
      await expireLocalSignIn("Weekly sign-in ended Monday at 12:01 a.m. Please sign in again.");
    }
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

// Keep each manager's reminder schedule and download acknowledgment in this browser only.
function dataExportReminderKey() {
  const userId = state.meta?.user?.id;
  return userId ? `garden-data-export-reminder:${userId}` : null;
}

// Load a validated local reminder schedule, falling back to reminders being off.
function readDataExportReminder() {
  const key = dataExportReminderKey();
  if (!key) return { intervalDays: 0, lastDownloadAt: null };
  try {
    const saved = JSON.parse(localStorage.getItem(key) || "{}");
    const intervalDays = [0, 7, 14, 30].includes(Number(saved.intervalDays)) ? Number(saved.intervalDays) : 0;
    const timestamp = Date.parse(saved.lastDownloadAt || "");
    return { intervalDays, lastDownloadAt: Number.isNaN(timestamp) ? null : new Date(timestamp).toISOString() };
  } catch {
    return { intervalDays: 0, lastDownloadAt: null };
  }
}

// Save reminder settings and the most recent download date on this computer.
function writeDataExportReminder(settings) {
  const key = dataExportReminderKey();
  if (!key) return false;
  try {
    localStorage.setItem(key, JSON.stringify(settings));
    return true;
  } catch {
    return false;
  }
}

// Display the reminder on every app page while an export is due.
function updateDataExportReminder() {
  const banner = $("#data-export-reminder");
  if (!banner) return;
  if (state.role !== "database_manager") {
    banner.hidden = true;
    return;
  }
  const settings = readDataExportReminder();
  if (!settings.intervalDays) {
    banner.hidden = true;
    return;
  }
  const lastDownload = settings.lastDownloadAt ? Date.parse(settings.lastDownloadAt) : NaN;
  const due = Number.isNaN(lastDownload) || Date.now() - lastDownload >= settings.intervalDays * 24 * 60 * 60 * 1000;
  if (!due || dataExportReminderDismissed) {
    banner.hidden = true;
    return;
  }
  $("#data-export-reminder-text").textContent = Number.isNaN(lastDownload)
    ? "No export has been downloaded yet. Download the latest table row data."
    : `Your scheduled export is due. The last download was ${new Intl.DateTimeFormat(undefined, {dateStyle: "medium"}).format(new Date(lastDownload))}.`;
  banner.hidden = false;
}

// Fetch the manager-only SQL data file, start a browser download, then acknowledge it locally.
async function downloadAllTableData(button) {
  if (state.role !== "database_manager") throw new Error("Only a database manager can download all table data.");
  const originalText = button?.textContent;
  if (button) {
    if (button.disabled) return;
    button.disabled = true;
    button.textContent = "Preparing download…";
  }
  try {
    const { data: { session } } = await supabaseClient.auth.getSession();
    if (!session?.access_token) throw new Error("Your session expired. Sign in again and retry the download.");
    const response = await fetch("/api/manage-data/export", {
      headers: {Authorization: `Bearer ${session.access_token}`},
    });
    if (!response.ok) {
      const error = await response.json().catch(() => ({}));
      throw new Error(error.error || `Download failed (${response.status}).`);
    }
    const blob = await response.blob();
    const objectUrl = URL.createObjectURL(blob);
    const link = document.createElement("a");
    link.href = objectUrl;
    link.download = `garden-program-data-${new Date().toISOString().slice(0, 10)}.sql`;
    document.body.append(link);
    link.click();
    link.remove();
    setTimeout(() => URL.revokeObjectURL(objectUrl), 60_000);

    const settings = readDataExportReminder();
    settings.lastDownloadAt = new Date().toISOString();
    if (!writeDataExportReminder(settings)) {
      toast("Download started. Reminder status could not be saved on this computer.");
      return;
    }
    dataExportReminderDismissed = false;
    updateDataExportReminder();
    const lastDownloadLabel = $("#data-export-last-download");
    if (lastDownloadLabel) {
      lastDownloadLabel.textContent = new Intl.DateTimeFormat(undefined, {dateStyle: "medium", timeStyle: "short"}).format(new Date(settings.lastDownloadAt));
    }
    const status = $("#data-export-status");
    if (status) {
      status.classList.remove("error");
      status.textContent = "Download started.";
    }
    toast("Data download started.");
  } catch (error) {
    const status = $("#data-export-status");
    if (status) {
      status.textContent = error.message;
      status.classList.add("error");
    } else {
      toast(error.message);
    }
  } finally {
    if (button) {
      button.disabled = false;
      button.textContent = originalText;
    }
  }
}

$("#data-export-reminder-settings").onclick = () => { location.hash = "#/manage-data"; };
window.setInterval(updateDataExportReminder, 60 * 60 * 1000);
document.addEventListener("visibilitychange", () => {
  if (!document.hidden) updateDataExportReminder();
});

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
  content.classList.toggle("log-page", title === "Log");
  $("#page-title").textContent = title;
  $("#page-sub").textContent = sub;
  $("#page-actions").innerHTML = actions;
  $("#print-page")?.addEventListener("click", downloadTablePdf);
  document.title = `${title} · LCSD Garden`;
}

const printButton = '<button type="button" class="btn print-btn" id="print-page" aria-label="Download PDF" title="Download as PDF">' +
  '<svg viewBox="0 0 24 24" aria-hidden="true" focusable="false"><path d="M12 3v12m0 0 4-4m-4 4-4-4M5 17v4h14v-4"/></svg></button>';

// Download the currently visible table as a PDF file.
function downloadTablePdf() {
  const table = content.querySelector(".data-table");
  if (!table) {
    toast("Switch to Table mode before downloading this report.");
    return;
  }
  const printableTable = table.cloneNode(true);
  printableTable.querySelectorAll("details").forEach(detail => { detail.open = true; });
  printableTable.querySelectorAll("th.notes, td.notes, td.actions, th:last-child:empty").forEach((cell) => cell.remove());
  printableTable.querySelectorAll(".reference-link").forEach((link) => link.replaceWith(document.createTextNode(link.textContent)));
  const title = $("#page-title").textContent;
  const count = content.querySelector(":scope > p")?.textContent || `${table.tBodies[0]?.rows.length || 0} records`;
  const headers = [...printableTable.querySelectorAll("thead th")].map(cell => cell.innerText.trim());
  const rows = [...printableTable.querySelectorAll("tbody tr")].map(row =>
    [...row.cells].map(cell => cell.innerText.replace(/\s+/g, " ").trim())
  );
  const clean = value => String(value ?? "").normalize("NFKD").replace(/[\u0300-\u036f]/g, "")
    .replace(/[“”]/g, '"').replace(/[‘’]/g, "'").replace(/[–—]/g, "-").replace(/[^\x20-\x7E]/g, " ");
  const pageW = 842, pageH = 595, margin = 28, font = 7;
  const colW = (pageW - margin * 2) / Math.max(headers.length, 1);
  const maxChars = Math.max(5, Math.floor((colW - 8) / (font * .52)));
  const wrap = value => {
    const result = [];
    let line = "";
    for (const word of clean(value).split(/\s+/).filter(Boolean)) {
      if (line && line.length + word.length + 1 > maxChars) { result.push(line); line = ""; }
      if (!line && word.length > maxChars) {
        for (let i = 0; i < word.length; i += maxChars) result.push(word.slice(i, i + maxChars));
      } else line += (line ? " " : "") + word;
    }
    if (line) result.push(line);
    return result.length ? result : [""];
  };
  const esc = value => value.replace(/\\/g, "\\\\").replace(/\(/g, "\\(").replace(/\)/g, "\\)");
  const pages = [];
  let ops, y;
  const cell = (x, top, height, lines, isHeader = false) => {
    const bottom = top - height;
    if (isHeader) ops.push(`0.91 g ${x} ${bottom} ${colW} ${height} re f 0 g`);
    ops.push(`0.65 G ${x} ${bottom} ${colW} ${height} re S 0 G`);
    lines.forEach((line, i) => ops.push(`BT /F1 ${isHeader ? 7 : font} Tf ${x + 4} ${top - 10 - i * 9} Td (${esc(line)}) Tj ET`));
  };
  const newPage = () => {
    if (ops) pages.push(ops.join("\n"));
    ops = [`BT /F1 15 Tf ${margin} ${pageH - margin - 15} Td (${esc(clean(title))}) Tj ET`,
      `BT /F1 8 Tf ${margin} ${pageH - margin - 30} Td (${esc(clean(count))}) Tj ET`];
    y = pageH - margin - 42;
    headers.forEach((header, i) => cell(margin + i * colW, y, 22, wrap(header), true));
    y -= 22;
  };
  newPage();
  for (const row of rows) {
    const lines = headers.map((_, i) => wrap(row[i] || ""));
    const height = Math.max(18, ...lines.map(cellLines => 7 + cellLines.length * 9));
    if (y - height < margin) newPage();
    lines.forEach((cellLines, i) => cell(margin + i * colW, y, height, cellLines));
    y -= height;
  }
  pages.push(ops.join("\n"));
  const objects = ["<< /Type /Catalog /Pages 2 0 R >>",
    `<< /Type /Pages /Kids [${pages.map((_, i) => `${4 + i * 2} 0 R`).join(" ")}] /Count ${pages.length} >>`,
    "<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>"];
  pages.forEach((page, i) => {
    const pageId = 4 + i * 2;
    objects.push(`<< /Type /Page /Parent 2 0 R /MediaBox [0 0 ${pageW} ${pageH}] /Resources << /Font << /F1 3 0 R >> >> /Contents ${pageId + 1} 0 R >>`);
    objects.push(`<< /Length ${page.length} >>\nstream\n${page}\nendstream`);
  });
  let pdf = "%PDF-1.4\n";
  const offsets = [0];
  objects.forEach((object, i) => { offsets.push(pdf.length); pdf += `${i + 1} 0 obj\n${object}\nendobj\n`; });
  const xref = pdf.length;
  pdf += `xref\n0 ${objects.length + 1}\n0000000000 65535 f \n`;
  offsets.slice(1).forEach(offset => { pdf += `${String(offset).padStart(10, "0")} 00000 n \n`; });
  pdf += `trailer\n<< /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n${xref}\n%%EOF`;
  const link = document.createElement("a");
  link.href = URL.createObjectURL(new Blob([pdf], { type: "application/pdf" }));
  link.download = `${clean(title).replace(/[^a-z0-9]+/gi, "-").replace(/^-|-$/g, "") || "garden-table"}.pdf`;
  document.body.append(link);
  link.click();
  link.remove();
  setTimeout(() => URL.revokeObjectURL(link.href), 1000);
}

function renderNav() {
  const groups = {};
  for (const t of state.meta.tables) (groups[t.group] ||= []).push({ ...t, href: `#/table/${t.name}` });
  groups.Reports = state.meta.views.map((v) => ({ ...v, href: `#/view/${v.name}` }));
  if (state.role === "database_manager") groups.Manage = [
    {label: "Users", href: "#/users"},
    {label: "Data", href: "#/manage-data"},
    {label: "Log", href: "#/audit-log"},
  ];

  const preferredOrder = ["Inventory & Budget", "Gardens", "Locations", "Reports", "Manage"];
  const orderedGroups = [...preferredOrder.filter(name => groups[name]), ...Object.keys(groups).filter(name => !preferredOrder.includes(name))];
  const current = location.hash || "#/dashboard";
  $("#help-link").classList.toggle("active", current === "#/help");
  const hoverGroups = new Set(["Locations", "Reports", "Manage"]);
  const currentGroup = orderedGroups.find(group => groups[group].some(link => link.href === current));
  expandedNavGroup = hoverGroups.has(currentGroup) ? currentGroup : null;
  let html = `<a class="nav-link ${current === "#/dashboard" ? "active" : ""}" ${current === "#/dashboard" ? 'aria-current="page"' : ""} href="#/dashboard">Dashboard</a>`;
  let sectionIndex = 0;
  for (const group of orderedGroups) {
    const links = groups[group];
    if (!links.length) continue;
    const active = links.some(link => link.href === current);
    const headingId = `nav-section-${sectionIndex++}`;
    const hoverGroup = hoverGroups.has(group);
    const heading = group === "Inventory & Budget" && state.role === "staff" ? "Inventory" : group;
    html += `<section class="nav-group ${active ? "has-active" : ""} ${hoverGroup ? "hover-nav-group" : ""} ${expandedNavGroup === group ? "expanded-nav-group" : ""}" data-nav-group="${escapeHtml(group)}" aria-labelledby="${headingId}">
      ${hoverGroup
        ? `<button type="button" class="nav-group-heading" id="${headingId}" aria-expanded="${expandedNavGroup === group}">${escapeHtml(heading)}</button>`
        : `<h2 class="nav-group-heading" id="${headingId}">${escapeHtml(heading)}</h2>`}
      <div class="nav-group-links">`;
    for (const link of links) {
      html += `<a class="nav-link ${current === link.href ? "active" : ""}" ${current === link.href ? 'aria-current="page"' : ""} href="${link.href}">${escapeHtml(link.label)}</a>`;
    }
    html += "</div></section>";
  }
  const nav = $("#nav");
  nav.innerHTML = html;
  nav.querySelectorAll(".hover-nav-group").forEach(section => {
    const headingButton = section.querySelector(".nav-group-heading");
    headingButton.onclick = () => {
      const shouldExpand = !section.classList.contains("expanded-nav-group");
      nav.querySelectorAll(".expanded-nav-group").forEach(item => {
        item.classList.remove("expanded-nav-group");
        item.querySelector(".nav-group-heading")?.setAttribute("aria-expanded", "false");
      });
      if (shouldExpand) {
        section.classList.add("expanded-nav-group");
        expandedNavGroup = section.dataset.navGroup;
        headingButton.setAttribute("aria-expanded", "true");
      } else {
        expandedNavGroup = null;
        headingButton.blur();
      }
    };
  });
}

function dataTable(rows, { columns, actions = false, foreignKeys = {}, actionsFirst = false } = {}) {
  if (!rows.length) return `<div class="empty">${actions ? "No records yet." : "No records to show."}</div>`;
  const cols = columns || Object.keys(rows[0]);
  const head = cols
    .map((c) => {
      const sorted = state.sort && state.sort.col === c;
      const isNote = c === "notes" || c.endsWith("_notes");
      const columnClass = `col-${c.replace(/[^a-zA-Z0-9_-]/g, "-")}`;
      const sortDirection = sorted ? (state.sort.desc ? "down" : "up") : "";
      return `<th data-sort="${escapeHtml(c)}" class="${columnClass} ${isNote ? "notes" : ""} ${sorted ? "sorted" : ""}">${escapeHtml(label(c))}<span class="sort-arrows" aria-hidden="true"><span class="sort-arrow-up ${sortDirection === "up" ? "active" : ""}">▲</span><span class="sort-arrow-down ${sortDirection === "down" ? "active" : ""}">▼</span></span></th>`;
    })
    .join("");
  const body = rows
    .map((row, index) => {
      const cells = cols
        .map((c) => {
          const isNote = c === "notes" || c.endsWith("_notes");
          const columnClass = `col-${c.replace(/[^a-zA-Z0-9_-]/g, "-")}`;
          const cls = `${columnClass} ${isNote ? "notes" : typeof row[c] === "number" ? "num" : ""}`.trim();
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
        rowActions.edit ? `<button class="btn small edit-btn" data-edit="${index}">Edit</button>` : "",
        rowActions.delete ? `<button class="btn small danger" data-delete="${index}">Delete</button>` : "",
      ].join("");
      const buttons = actionButtons ? `<td class="actions">${actionButtons}</td>` : "";
      return `<tr>${actionsFirst ? buttons : ""}${cells}${actionsFirst ? "" : buttons}</tr>`;
    })
    .join("");
  return `<div class="table-wrap"><table class="data-table"><thead><tr>${actions && actionsFirst ? "<th></th>" : ""}${head}${actions && !actionsFirst ? "<th></th>" : ""}</tr></thead><tbody>${body}</tbody></table></div>`;
}

function filterAndSort(rows) {
  let out = rows;
  const terms = [$("#search")?.value, ...[...document.querySelectorAll("[data-record-search]")].map(input => input.value)]
    .map(value => String(value || "").trim().toLowerCase()).filter(Boolean);
  if (terms.length) out = out.filter(row => {
    const text = Object.values(row).map(value => String(value ?? "")).join(" ").toLowerCase();
    return terms.every(term => text.includes(term));
  });
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
  const downloadButton = $("#print-page");
  if (downloadButton) downloadButton.onclick = downloadTablePdf;
  const extraContainer = $("#record-extra-searches");
  const addButton = $("#record-add-search");
  const updateAddButtons = () => {
    const rows = [...(extraContainer?.querySelectorAll(".record-extra-search") || [])];
    const buttons = [addButton, ...rows.map(row => row.querySelector(".record-add-search"))].filter(Boolean);
    buttons.forEach((button, index) => { button.hidden = rows.length >= 2 || index < rows.length; });
  };
  const addSearch = () => {
    if (!extraContainer || extraContainer.querySelectorAll("[data-record-search]").length >= 2) return;
    const row = document.createElement("div");
    row.className = "record-extra-search";
    row.innerHTML = '<button class="btn small audit-remove-filter" type="button" aria-label="Remove search box">×</button><input class="search" type="search" data-record-search placeholder="Search another term" aria-label="Additional search term"><button class="btn small audit-add-filter record-add-search" type="button" aria-label="Add another search box">+</button>';
    const input = row.querySelector("input");
    input.oninput = rerender;
    row.querySelector(".audit-remove-filter").onclick = () => { row.remove(); updateAddButtons(); rerender(); };
    row.querySelector(".record-add-search").onclick = addSearch;
    extraContainer.append(row);
    input.focus();
    updateAddButtons();
  };
  if (addButton) addButton.onclick = addSearch;
  updateAddButtons();
  content.querySelectorAll("th[data-sort]").forEach((th) => {
    th.onclick = () => {
      const col = th.dataset.sort;
      if (state.sort?.col !== col) state.sort = { col, desc: false };
      else if (!state.sort.desc) state.sort = { col, desc: true };
      else state.sort = null;
      rerender();
    };
  });
}

function multiSearchControls(includeAdd = false) {
  const addButton = includeAdd ? '<button class="btn primary" id="add-btn" type="button">+ Add</button>' : "";
  return '<div class="record-search-controls"><span class="record-search-inputs"><input id="search" class="search" type="search" placeholder="Search…" aria-label="Search records"><button class="btn small audit-add-filter" id="record-add-search" type="button" aria-label="Add another search box" title="Add another search box">+</button><span id="record-extra-searches" class="record-extra-searches"></span></span><span class="record-search-actions">' + printButton + addButton + '</span></div>';
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
  $("#crop-event-close").onclick = () => dialog.close();
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
  const currentMonth = new Date(new Date().getFullYear(), new Date().getMonth(), 1);
  const nextMonth = new Date(currentMonth.getFullYear(), currentMonth.getMonth() + 1, 1);
  const previousButton = $("#dashboard-calendar-prev");
  const nextButton = $("#dashboard-calendar-next");
  if (previousButton) previousButton.disabled = dashboardCalendarMonth <= currentMonth;
  if (nextButton) nextButton.disabled = dashboardCalendarMonth >= nextMonth;
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
      const deleteButton = canDelete("crop_rotation", row)
        ? '<button type="button" class="crop-calendar-delete" data-rotation-delete="' + rowIndex + '" aria-label="Delete ' + escapeHtml(row.plant_name || "crop rotation") + '">×</button>'
        : "";
      return '<div class="crop-calendar-entry"><button type="button" class="crop-calendar-event sowing" data-rotation-index="' + rowIndex +
        '" aria-label="Edit ' + escapeHtml(row.plant_name || "planting") + (place ? " at " + escapeHtml(place) : "") + '">' +
        "<strong>" + escapeHtml(row.plant_name || "Planting") + "</strong>" +
        (place ? "<span>" + escapeHtml(place) + "</span>" : "") + "</button>" + deleteButton + "</div>";
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
      const deleteButton = canDelete("crop_rotation", row)
        ? '<button type="button" class="crop-calendar-delete" data-rotation-delete="' + index + '" aria-label="Delete ' + escapeHtml(row.plant_name || "crop rotation") + '">×</button>'
        : "";
      return '<div class="crop-calendar-entry"><button type="button" class="crop-calendar-event sowing" data-rotation-index="' + index +
        '"><strong>' + escapeHtml(row.plant_name || "Planting") + "</strong>" +
        (place ? "<span>" + escapeHtml(place) + "</span>" : "") + "</button>" + deleteButton + "</div>";
    }).join("") + "</div></section>"
    : "";
  return '<div class="crop-calendar-weekdays">' + weekdays + '</div><div class="crop-calendar-grid">' +
    days + "</div>" + undatedMarkup;
}

/* ---------- Dashboard ---------- */

async function showDashboard() {
  dashboardCalendarMonth = new Date(new Date().getFullYear(), new Date().getMonth(), 1);
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
    const currentMonth = new Date(new Date().getFullYear(), new Date().getMonth(), 1);
    const nextMonth = new Date(currentMonth.getFullYear(), currentMonth.getMonth() + 1, 1);
    const requestedMonth = new Date(dashboardCalendarMonth.getFullYear(), dashboardCalendarMonth.getMonth() + amount, 1);
    dashboardCalendarMonth = requestedMonth < currentMonth ? currentMonth : requestedMonth > nextMonth ? nextMonth : requestedMonth;
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
  const searchControls = content.querySelector(".record-search-controls");
  const activeSearch = searchControls?.contains(document.activeElement) ? document.activeElement : null;
  const activeExtraIndex = activeSearch?.matches("[data-record-search]")
    ? [...searchControls.querySelectorAll("[data-record-search]")].indexOf(activeSearch)
    : -1;
  const selectionStart = activeSearch?.selectionStart;
  const selectionEnd = activeSearch?.selectionEnd;
  if (searchControls) {
    searchControls.remove();
    html = html.replace(/^<div class="record-search-controls">[\s\S]*?<\/div>/, "");
  }
  content.innerHTML = html;
  if (searchControls) {
    content.prepend(searchControls);
    const nextActive = activeExtraIndex >= 0
      ? searchControls.querySelectorAll("[data-record-search]")[activeExtraIndex]
      : activeSearch?.id === "search" ? searchControls.querySelector("#search") : null;
    if (nextActive) {
      nextActive.focus({ preventScroll: true });
      if (selectionStart !== null && selectionStart !== undefined) nextActive.setSelectionRange(selectionStart, selectionEnd);
    }
  }
  const wrapper = content.querySelector(".table-wrap");
  if (wrapper) wrapper.scrollLeft = left;
}

function financialReportConfig(name) {
  if (name === "BudgetPurchases") return {
    key: "budget_name", label: "Budget", summaryColumns: ["budget_name", "purchase_request_count", "total_budget", "total_spent", "remaining_budget"],
  };
  if (name === "FundingSourceSpending") return {
    key: "funding_source", label: "Funding source", summaryColumns: ["funding_source", "purchase_request_count", "total_spent"],
  };
  if (name === "YearlyPurchase") return {
    key: "school_year", label: "School year", summaryColumns: ["school_year", "purchase_request_count", "total_quantity_ordered", "total_spent", "pending_spending"],
    detailColumns: ["school_year", "purchase_month", "purchase_request_count", "total_quantity_ordered", "total_spent"],
    modeLabels: ["Yearly", "Monthly"],
  };
  return null;
}

function financialReportControls(name, rows) {
  const config = financialReportConfig(name);
  if (!config) return "";
  const labels = config.modeLabels || ["Summary", "Detail"];
  return '<div class="view-mode-toggle financial-report-controls" role="group" aria-label="Financial report display">' +
    '<button type="button" class="btn small" id="financial-summary-mode">' + labels[0] + '</button>' +
    '<button type="button" class="btn small" id="financial-detail-mode">' + labels[1] + '</button></div>';
}

function summarizeFinancialReport(name, rows) {
  const config = financialReportConfig(name);
  if (!config) return rows;
  const groups = new Map();
  rows.forEach(row => {
    const key = String(row[config.key] ?? "");
    if (!groups.has(key)) groups.set(key, {...row, item_name: undefined, request_id: undefined, purchase_request_count: 0, total_quantity_ordered: 0, total_spent: 0, pending_spending: 0});
    const summary = groups.get(key);
    summary.purchase_request_count += row.purchase_request_count === undefined ? 1 : Number(row.purchase_request_count) || 0;
    summary.total_quantity_ordered += Number(row.total_quantity_ordered) || 0;
    summary.total_spent += Number(row.total_spent) || 0;
    summary.pending_spending += Number(row.pending_spending) || 0;
  });
  return [...groups.values()].map(row => {
    const result = {...row};
    delete result.item_name;
    return result;
  });
}

async function showView(name) {
  const view = state.meta.views.find((v) => v.name === name);
  if (!view) return showError(new Error(`Unknown report: ${name}`));
  const cropCalendarControls = name === "CropCalendar"
    ? '<div class="view-mode-toggle" role="group" aria-label="Crop calendar display">' +
      '<button type="button" class="btn small" id="crop-calendar-report-table-mode">Table</button>' +
      '<button type="button" class="btn small" id="crop-calendar-report-calendar-mode">Calendar</button></div>'
    : "";
  const schoolSupplyControls = name === "SchoolSupply"
    ? '<div class="view-mode-toggle" role="group" aria-label="School Supply display">' +
      '<button type="button" class="btn small" id="school-supply-overview-mode">Overview</button>' +
      '<button type="button" class="btn small" id="school-supply-requests-mode">Purchase Requests</button>' +
      '<button type="button" class="btn small" id="school-supply-checked-out-mode">Checked Out Items</button></div>'
    : "";
  setHeader(view.label, view.description || "", schoolSupplyControls || cropCalendarControls, true);
  content.innerHTML = '<div class="empty">Loading…</div>';
  if (name === "SchoolSupply") state.sort = null;
  const modeQuery = name === "SchoolSupply" ? `?mode=${encodeURIComponent(schoolSupplyMode)}` : "";
  state.rows = await api(`/views/${name}${modeQuery}`);
  const financialConfig = financialReportConfig(name);
  if (financialConfig) setHeader(view.label, view.description || "", financialReportControls(name, state.rows), true);
  const render = () => {
    const rowColumns = state.rows.length ? Object.keys(state.rows[0]) : [];
    const modeColumns = name === "SchoolSupply"
      ? (schoolSupplyMode === "requests" ? VIEW_COLUMNS.SchoolSupplyRequests : schoolSupplyMode === "checked_out" ? VIEW_COLUMNS.SchoolSupplyCheckedOut : VIEW_COLUMNS.SchoolSupply)
      : null;
    const preferredColumns = modeColumns || VIEW_COLUMNS[name] || rowColumns;
    const columns = [
      ...preferredColumns.filter((c) => rowColumns.includes(c)),
      ...rowColumns.filter((c) => !preferredColumns.includes(c)),
    ];
    if (name === "FundingSourceSpending" && financialReportModes[name] === "detail") {
      const redundantIndex = columns.indexOf("total_funding_source_spent");
      if (redundantIndex >= 0) columns.splice(redundantIndex, 1);
    }
    if (name === "BudgetPurchases" && financialReportModes[name] === "detail") {
      ["total_budget", "total_budget_spent", "remaining_budget"].forEach(column => {
        const index = columns.indexOf(column);
        if (index >= 0) columns.splice(index, 1);
      });
    }
    const schoolSupplyRows = name === "SchoolSupply"
      ? [...state.rows].sort((a, b) => {
        const typeOrder = {School: 0, Group: 1};
        const typeComparison = (typeOrder[a.assignment_type] ?? 2) - (typeOrder[b.assignment_type] ?? 2);
        if (typeComparison) return typeComparison;
        return String(a.location_name ?? "").localeCompare(String(b.location_name ?? ""), undefined, {numeric: true});
      })
      : state.rows;
    const filteredRows = filterAndSort(schoolSupplyRows);
    const visible = financialConfig && financialReportModes[name] === "summary"
      ? summarizeFinancialReport(name, filteredRows)
      : filteredRows;
    const financialColumns = financialConfig && financialReportModes[name] === "summary"
      ? financialConfig.summaryColumns
      : financialConfig?.detailColumns || columns;
    const showingCalendar = name === "CropCalendar" && cropCalendarReportMode === "calendar";
    const reportContent = showingCalendar
      ? '<div class="card crop-rotation-calendar-card"><div class="card-header crop-rotation-calendar-heading">' +
        '<div><strong>Sowing and expected harvest dates</strong><div class="muted">Select a planting or harvest to view its report information.</div></div>' +
        '<div class="crop-calendar-controls"><button type="button" class="btn small" id="crop-calendar-report-prev" aria-label="Previous month">‹</button>' +
        '<strong id="crop-calendar-report-month"></strong><button type="button" class="btn small" id="crop-calendar-report-next" aria-label="Next month">›</button>' +
        '<button type="button" class="btn small" id="crop-calendar-report-today">Today</button></div></div>' +
        '<div id="crop-calendar-report-grid"></div></div>'
      : '<div class="card">' + dataTable(visible, { columns: financialColumns }) + '</div>';
    const totalReportRecords = financialConfig && financialReportModes[name] === "summary"
      ? summarizeFinancialReport(name, state.rows).length
      : state.rows.length;
    renderRecordContent(`${multiSearchControls()}${reportContent}<p class="muted">${visible.length} of ${totalReportRecords} records</p>`);
    bindTableControls(render);
    if (name === "SchoolSupply") {
      const modeButtons = {
        overview: $("#school-supply-overview-mode"),
        requests: $("#school-supply-requests-mode"),
        checked_out: $("#school-supply-checked-out-mode"),
      };
      Object.entries(modeButtons).forEach(([mode, button]) => {
        if (!button) return;
        button.classList.toggle("active", schoolSupplyMode === mode);
        button.setAttribute("aria-pressed", String(schoolSupplyMode === mode));
        button.onclick = async () => {
          schoolSupplyMode = mode;
          state.sort = null;
          state.rows = await api(`/views/SchoolSupply?mode=${encodeURIComponent(mode)}`);
          render();
        };
      });
    }
    if (financialConfig) {
      const summaryButton = $("#financial-summary-mode");
      const detailButton = $("#financial-detail-mode");
      summaryButton.classList.toggle("active", financialReportModes[name] === "summary");
      detailButton.classList.toggle("active", financialReportModes[name] === "detail");
      summaryButton.onclick = () => { financialReportModes[name] = "summary"; render(); };
      detailButton.onclick = () => { financialReportModes[name] = "detail"; render(); };
    }
    if (showingCalendar) {
      const calendar = buildDashboardCalendar(visible, cropCalendarReportMonth);
      $("#crop-calendar-report-month").textContent = new Intl.DateTimeFormat(undefined, {
        month: "long", year: "numeric",
      }).format(cropCalendarReportMonth);
      $("#crop-calendar-report-grid").innerHTML = calendar.markup;
      const shiftMonth = amount => {
        cropCalendarReportMonth = new Date(cropCalendarReportMonth.getFullYear(), cropCalendarReportMonth.getMonth() + amount, 1);
        render();
      };
      $("#crop-calendar-report-prev").onclick = () => shiftMonth(-1);
      $("#crop-calendar-report-next").onclick = () => shiftMonth(1);
      $("#crop-calendar-report-today").onclick = () => {
        cropCalendarReportMonth = new Date(new Date().getFullYear(), new Date().getMonth(), 1);
        render();
      };
      content.querySelectorAll("[data-crop-event]").forEach(button => {
        button.onclick = () => showCropCalendarEvent(calendar.events[Number(button.dataset.cropEvent)]);
      });
    }
  };
  render();
  if (name === "CropCalendar") {
    const setMode = mode => {
      cropCalendarReportMode = mode;
      for (const [id, selected] of [
        ["crop-calendar-report-table-mode", mode === "table"],
        ["crop-calendar-report-calendar-mode", mode === "calendar"],
      ]) {
        const button = $("#" + id);
        button.classList.toggle("active", selected);
        button.setAttribute("aria-pressed", String(selected));
      }
      render();
    };
    $("#crop-calendar-report-table-mode").onclick = () => setMode("table");
    $("#crop-calendar-report-calendar-mode").onclick = () => setMode("calendar");
    setMode(cropCalendarReportMode);
  }
}

// Load the guides appropriate to this signed-in user's app role.
async function showHelp(focusSection = "") {
  const searchControls = '<label class="help-search-control"><span>Search guides</span>' +
    '<input class="search" id="help-search" type="search" placeholder="Search guides" aria-label="Search help guides">' +
    '<span id="help-search-count" class="muted" role="status" aria-live="polite"></span>' +
    '<button type="button" class="btn small" id="help-search-prev" aria-label="Previous search match" title="Previous match">↑</button>' +
    '<button type="button" class="btn small" id="help-search-next" aria-label="Next search match" title="Next match">↓</button></label>';
  setHeader("Help", "Guides and instructions for using the Garden Database app.", searchControls);
  content.innerHTML = '<div class="empty">Loading help guides…</div>';
  const guides = await api("/help");
  const section = (id, title, html) => `<section class="card help-section" id="${id}"><div class="card-header"><h2>${title}</h2></div><article class="help-markdown">${html}</article></section>`;
  content.innerHTML = section("frontend-help", "Frontend User Guide", guides.frontend || "") +
    section("database-reference-help", "Program Data Reference", guides.reference || "") +
    (guides.manager ? section("manager-help", "Manager Pages", guides.manager) : "") +
    (guides.supabase ? section("supabase-help", "Supabase User Guide", guides.supabase) : "") +
    section("help-troubleshooting", "Troubleshooting", guides.troubleshooting || "");
  if (focusSection === "location-groups") {
    const heading = [...content.querySelectorAll("h2, h3")]
      .find(element => element.textContent.trim().toLowerCase() === "using location groups");
    heading?.scrollIntoView({ block: "start" });
  }
  const searchInput = $("#help-search");
  const searchCount = $("#help-search-count");
  const searchPrev = $("#help-search-prev");
  const searchNext = $("#help-search-next");
  let searchMatches = [];
  let searchIndex = -1;
  const updateSearchNavigation = () => {
    searchPrev.disabled = searchMatches.length === 0;
    searchNext.disabled = searchMatches.length === 0;
    searchMatches.forEach((match, index) => match.classList.toggle("help-search-current", index === searchIndex));
    searchCount.textContent = searchMatches.length
      ? `${searchIndex + 1} of ${searchMatches.length} matches`
      : (searchInput.value.trim() ? "No matches" : "");
  };
  const moveSearchMatch = (direction) => {
    if (!searchMatches.length) return;
    searchIndex = (searchIndex + direction + searchMatches.length) % searchMatches.length;
    updateSearchNavigation();
    searchMatches[searchIndex].scrollIntoView({ block: "center", behavior: "smooth" });
  };
  const searchGuides = () => {
    content.querySelectorAll("mark.help-search-match").forEach(mark => mark.replaceWith(document.createTextNode(mark.textContent)));
    content.querySelectorAll(".help-markdown").forEach(article => article.normalize());
    const term = searchInput.value.trim();
    if (!term) {
      searchMatches = [];
      searchIndex = -1;
      updateSearchNavigation();
      return;
    }
    const needle = term.toLocaleLowerCase();
    let matchCount = 0;
    content.querySelectorAll(".help-markdown").forEach(article => {
      const walker = document.createTreeWalker(article, NodeFilter.SHOW_TEXT);
      const textNodes = [];
      while (walker.nextNode()) textNodes.push(walker.currentNode);
      textNodes.forEach(node => {
        const original = node.nodeValue;
        const lower = original.toLocaleLowerCase();
        let cursor = 0;
        let index = lower.indexOf(needle, cursor);
        if (index < 0) return;
        const fragment = document.createDocumentFragment();
        while (index >= 0) {
          fragment.append(document.createTextNode(original.slice(cursor, index)));
          const mark = document.createElement("mark");
          mark.className = "help-search-match";
          mark.textContent = original.slice(index, index + term.length);
          fragment.append(mark);
          cursor = index + term.length;
          matchCount += 1;
          index = lower.indexOf(needle, cursor);
        }
        fragment.append(document.createTextNode(original.slice(cursor)));
        node.replaceWith(fragment);
      });
    });
    searchMatches = [...content.querySelectorAll("mark.help-search-match")];
    searchIndex = searchMatches.length ? 0 : -1;
    updateSearchNavigation();
  };
  searchInput.oninput = searchGuides;
  searchPrev.onclick = () => moveSearchMatch(-1);
  searchNext.onclick = () => moveSearchMatch(1);
  content.querySelectorAll("a[href^='http']").forEach(link => {
    link.target = "_blank";
    link.rel = "noopener noreferrer";
  });
}

/* ---------- Editable tables ---------- */

async function showTable(name) {
  const table = state.meta.tables.find((t) => t.name === name);
  if (!table) return showError(new Error(`Unknown table: ${name}`));
  setHeader(
    table.label,
    table.description || "",
    "",
    true
  );
  if (name === "location_group" || name === "group_members") {
    $("#page-sub").innerHTML = `${escapeHtml(table.description || "")} <a href="#/help/location-groups" class="inline-help-link">Open Help: Using location groups</a>`;
  }
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
    renderRecordContent(multiSearchControls(true) + page);
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
      content.querySelectorAll("[data-rotation-delete]").forEach(button => {
        button.onclick = event => {
          event.stopPropagation();
          const row = visible[Number(button.dataset.rotationDelete)];
          if (row && canDelete("crop_rotation", row)) deleteRow(row);
        };
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

function isDeliveredPurchaseRequest(row) {
  return Boolean(row && String(row.status || "").trim() === "Delivered to FNS");
}

function canEdit(name, row) {
  if (name === "purchase_request") {
    if (isDeliveredPurchaseRequest(row)) return false;
    return Boolean(row);
  }
  if (state.role === "database_manager") {
    if (name === "inventory_transaction") return sameDayRow(name, row);
    return true;
  }
  if (name === "inventory_transaction") return sameDayRow(name, row);
  return true;
}

function canDelete(name, row) {
  if (state.role === "database_manager") {
    if (["purchase_request", "inventory_transaction"].includes(name)) return sameDayRow(name, row);
    return true;
  }
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

  const effectiveReadonly = col.readonly || formReadonlyNames.has(col.name);
  if (col.data_type === "boolean") {
    const checked = value === null || value === undefined ? /true/i.test(col.default_value || "") : value;
    return `<div class="field checkbox"><input type="checkbox" id="${id}" name="${col.name}" ${checked ? "checked" : ""}><label for="${id}">${escapeHtml(label(col.name))}</label></div>`;
  }

  let control;
  const actorField = isNew && ((state.schema?.name === "purchase_request" && col.name === "requested_by")
    || (state.schema?.name === "inventory_transaction" && col.name === "taken_by"));
  if (actorField) {
    control = `<input type="text" id="${id}" name="${col.name}" value="${escapeHtml(v)}" readonly aria-readonly="true" title="Filled from your account">`;
  } else if (effectiveReadonly) {
    const displayValue = value == null || value === ""
      ? ""
      : isMoneyColumn(col.name) && Number.isFinite(Number(value))
        ? money.format(Number(value))
        : String(value);
    control = `<input type="text" id="${id}" name="${col.name}" value="${escapeHtml(displayValue)}" readonly aria-readonly="true">`;
  } else if (col.foreign_key) {
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

  let hint = col.foreign_key ? `<span class="hint">From ${escapeHtml(label(col.foreign_key.ref_table))}</span>` : "";
  if (col.name === "unit_cost_at_request") hint = '<span class="hint">Saved price snapshot; new requests use the item catalog price.</span>';
  if (col.name === "total_cost") hint = '<span class="hint">Calculated from the quantity and saved unit price.</span>';
  if (state.schema?.name === "purchase_request" && col.name === "status") hint = '<span class="hint">Requested → Ordered → Delivered to FNS. Once delivered, this table cannot be edited.</span>';
  const wide = col.data_type === "text" ? "wide" : "";
  return `<div class="field ${wide}"><label for="${id}">${escapeHtml(label(col.name))}${col.required ? ' <span class="req">*</span>' : ""}</label>${control}${hint}</div>`;
}

function fillForeignKeySelects(record) {
  for (const col of state.schema.columns) {
    const fk = col.foreign_key;
    if (!fk || col.readonly || formReadonlyNames.has(col.name)) continue;
    const select = $(`#f_${col.name}`);
    const current = select.value || (record ? record[col.name] : "") || "";
    let options = state.options[col.name] || [];
    for (const [localCol, refCol] of Object.entries(fk.depends_on)) {
      const parent = $(`#f_${localCol}`);
      if (parent && parent.value) options = options.filter((o) => String(o[refCol]) === parent.value);
    }
    const values = [...new Set(options.map((o) => o[fk.ref_column]))];
    const assignmentField = ["requesting_school", "requesting_school_group", "for_school", "for_school_group"].includes(col.name);
    select.innerHTML =
      `<option value="">${assignmentField ? "Unassigned" : (col.required ? "Select…" : "None")}</option>` +
      values.map((val) => `<option value="${escapeHtml(val)}" ${String(val) === String(current) ? "selected" : ""}>${escapeHtml(val)}</option>`).join("");
  }
}

function setupExclusiveLocationAssignment(tableName) {
  const pairs = {
    purchase_request: ["#f_requesting_school", "#f_requesting_school_group"],
    inventory_transaction: ["#f_for_school", "#f_for_school_group"],
  };
  const selectors = pairs[tableName];
  if (!selectors) return;
  const [school, group] = selectors.map((selector) => $(selector));
  if (!school || !group) return;

  const sync = () => {
    group.disabled = Boolean(school.value);
    school.disabled = Boolean(group.value);
  };
  school.addEventListener("change", sync);
  group.addEventListener("change", sync);
  sync();
}

function setupPurchaseRequestCostPreview(record) {
  const itemSelect = $("#f_item_name");
  const unitCost = $("#f_unit_cost_at_request");
  const quantity = $("#f_quantity_requested");
  const totalCost = $("#f_total_cost");
  if (!itemSelect || !unitCost || !quantity || !totalCost) return;

  const update = () => {
    const itemName = itemSelect.value;
    const selectedItem = (state.options.item_name || []).find((item) => String(item.item_name) === String(itemName));
    const sameRecordItem = Boolean(record && itemName === record.item_name);
    const price = sameRecordItem ? record.unit_cost_at_request : (selectedItem?.unit_cost ?? null);

    if (!itemName) {
      unitCost.value = "Select an item";
      totalCost.value = "Select an item";
      return;
    }
    if (price === null || price === undefined || price === "") {
      unitCost.value = sameRecordItem ? "No saved price snapshot" : "No catalog price set";
      totalCost.value = sameRecordItem
        ? (Number.isFinite(Number(record.total_cost)) ? money.format(Number(record.total_cost)) : "Not calculated")
        : "Price not available";
      return;
    }

    const priceNumber = Number(price);
    unitCost.value = Number.isFinite(priceNumber) ? money.format(priceNumber) : "No catalog price set";
    const quantityText = quantity.value.trim();
    if (!quantityText) {
      totalCost.value = record && itemName === record.item_name
        ? (Number.isFinite(Number(record.total_cost)) ? money.format(Number(record.total_cost)) : "Enter a quantity")
        : "Enter a quantity";
      return;
    }
    const quantityNumber = Number(quantityText);
    totalCost.value = Number.isFinite(quantityNumber) && quantityNumber > 0 && Number.isFinite(priceNumber)
      ? money.format(quantityNumber * priceNumber)
      : "Enter a quantity greater than zero";
  };

  itemSelect.addEventListener("change", update);
  quantity.addEventListener("input", update);
  update();
}

async function openForm(record, initialValues = {}) {
  hideNotePreview();
  hideReferencePreview();
  const schema = state.schema;
  formReadonlyNames = new Set();
  if (record && schema.name === "inventory_transaction") {
    formReadonlyNames.add("taken_by");
  }
  if (record && schema.name === "purchase_request" && !sameDayRow(schema.name, record)) {
    formReadonlyNames = new Set([
      "requested_by", "requesting_school", "requesting_school_group",
      "item_name", "unit_cost_at_request", "quantity_requested", "total_cost", "school_year",
    ]);
    if (record.request_date) formReadonlyNames.add("request_date");
  }
  if (!record && ["purchase_request", "inventory_transaction"].includes(schema.name)) {
    const { data: displayName, error } = await supabaseClient.rpc("get_my_display_name");
    if (error) console.warn("Could not load account display name; using email.", error.message);
    const actorField = schema.name === "purchase_request" ? "requested_by" : "taken_by";
    initialValues = { ...initialValues, [actorField]: displayName?.trim() || state.meta.user.email || "" };
  }
  const tableLabel = state.meta.tables.find((t) => t.name === schema.name).label;
  $("#dialog-title").textContent = record ? `Edit ${tableLabel}` : `Add to ${tableLabel}`;
  $("#form-error").hidden = true;

  const editable = schema.columns.filter((c) => !c.readonly && !formReadonlyNames.has(c.name));
  const visible = record
    ? editable
    : schema.columns.filter((c) => !c.readonly || c.show_readonly || formReadonlyNames.has(c.name));
  $("#form-fields").innerHTML = visible
    .map((c) => inputFor(c, record ? record[c.name] : (initialValues[c.name] ?? null), !record))
    .join("");

  try {
    state.options = await api(`/tables/${schema.name}/options`);
  } catch (err) {
    state.options = {};
  }
  fillForeignKeySelects(record || initialValues);
  setupExclusiveLocationAssignment(schema.name);
  if (schema.name === "purchase_request") setupPurchaseRequestCostPreview(record);
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
      <div class="card"><strong id="user-count"></strong><span>Total accounts</span></div>
    </section>
    <section class="card">
      <div class="users-heading"><div><h2>People &amp; roles</h2><p>Choose a role, then save your change.</p></div>
        <input class="search" id="search-users" type="search" placeholder="Search accounts…" aria-label="Search accounts"></div>
      <div class="table-wrap"><table><thead><tr><th>Account</th><th>Display name</th><th>Role</th><th class="user-actions-heading">Actions</th></tr></thead><tbody id="users-body"></tbody></table></div>
      <div class="empty" id="users-empty" hidden>No matching accounts.</div>
    </section>
    <p class="access-note"><strong>Your own role is protected</strong> so you cannot accidentally remove your manager access.<br>
      Removing access keeps the person's account. They can be assigned a role again later.</p>
    <p class="access-note invitation-note">A Supabase organization administrator sends account invitations through Supabase Auth.</p>`;

  const updateUserSaveButton = index => {
    const user = users[index];
    const button = content.querySelector(`[data-user-save="${index}"]`);
    if (button) button.disabled = !pendingRoleEdits.has(user.user_id) && !pendingDisplayNameEdits.has(user.user_id);
  };
  const saveDisplayName = async (user, value, button) => {
    if (!pendingDisplayNameEdits.has(user.user_id)) return;
    button.disabled = true;
    try {
      await api(`/users/${encodeURIComponent(user.user_id)}/display-name`, {method: "PUT", body: {display_name: value || null}});
      user.display_name = value || null;
      pendingDisplayNameEdits.delete(user.user_id);
      toast("User information saved");
      renderUsers();
    } catch (err) {
      toast(err.message);
      button.disabled = false;
    }
  };

  const renderUsers = () => {
    users.sort((a, b) => (a.email || a.user_id).localeCompare(b.email || b.user_id));
    const query = $("#search-users").value.toLowerCase();
    $("#user-count").textContent = users.length;
    const rows = users.map((user, index) => {
      if (!`${user.email || ""} ${user.user_id}`.toLowerCase().includes(query)) return "";
      const self = user.user_id === state.meta.user.id;
      const role = user.database_role;
      const selectedRole = pendingRoleEdits.get(user.user_id) ?? role;
      const email = user.email || "Account without email";
      return `<tr><td><div class="user-name"><span class="user-avatar" aria-hidden="true">${escapeHtml(email.slice(0, 2).toUpperCase())}</span>
        <div><strong>${escapeHtml(email)}${self ? ' <span class="muted">(you)</span>' : ""}</strong><small>${escapeHtml(user.user_id)}</small></div></div></td>
        <td><input class="display-name-input" maxlength="100" aria-label="Display name for ${escapeHtml(email)}" data-display-name="${index}" value="${escapeHtml(pendingDisplayNameEdits.get(user.user_id) ?? user.display_name ?? user.email ?? "")}" placeholder="Display name"></td>
        <td><select class="role-select" aria-label="Role for ${escapeHtml(email)}" data-user-role="${index}" ${self ? "disabled" : ""}>
          <option value="" ${!selectedRole ? "selected" : ""} disabled>Choose a role</option>
          ${Object.entries(ROLE_LABELS).map(([key, name]) => `<option value="${key}" ${key === selectedRole ? "selected" : ""}>${name}</option>`).join("")}</select></td>
        <td><div class="user-actions"><button class="btn small primary" data-user-save="${index}" disabled>Save</button>
          <button class="btn small reset-password-btn" data-user-reset="${index}" ${!user.email ? 'disabled title="This account has no email address"' : ""}>Reset password</button>
          <button class="btn small danger" data-user-remove="${index}" ${self || !role ? "disabled" : ""}>Remove access</button></div></td></tr>`;
    }).join("");
    $("#users-body").innerHTML = rows;
    $("#users-empty").hidden = Boolean(rows);
    content.querySelectorAll("[data-display-name]").forEach(input => {
      input.oninput = () => {
        const user = users[input.dataset.displayName];
        const value = input.value.trim();
        const baseline = user.display_name || user.email || "";
        if (value === baseline) pendingDisplayNameEdits.delete(user.user_id);
        else pendingDisplayNameEdits.set(user.user_id, value);
        updateUserSaveButton(input.dataset.displayName);
      };
    });
    content.querySelectorAll("[data-user-role]").forEach(select => {
      select.onchange = () => {
        const user = users[select.dataset.userRole];
        if (select.value && select.value !== user.database_role) pendingRoleEdits.set(user.user_id, select.value);
        else pendingRoleEdits.delete(user.user_id);
        updateUserSaveButton(select.dataset.userRole);
      };
    });
    content.querySelectorAll("[data-user-save]").forEach(button => {
      button.onclick = async () => {
        const user = users[button.dataset.userSave];
        const role = pendingRoleEdits.get(user.user_id);
        const displayName = pendingDisplayNameEdits.get(user.user_id);
        if (role) confirmUserAction(user, {role, displayName});
        else await saveDisplayName(user, displayName, button);
      };
      updateUserSaveButton(button.dataset.userSave);
    });
    content.querySelectorAll("[data-user-remove]").forEach(button => {
      button.onclick = () => confirmUserAction(users[button.dataset.userRemove]);
    });
    content.querySelectorAll("[data-user-reset]").forEach(button => {
      button.onclick = () => confirmUserAction(users[button.dataset.userReset], {resetPassword: true});
    });
  };

  const confirmUserAction = (user, {role = null, resetPassword = false, displayName = undefined} = {}) => {
    if (resetPassword ? !user.email : user.user_id === state.meta.user.id) return;
    const dialog = $("#role-dialog");
    const confirm = $("#role-confirm");
    const confirmLabel = resetPassword ? "Send reset email" : "Confirm";
    $("#role-dialog-title").textContent = resetPassword ? "Send password reset email?" : role ? "Save user changes?" : "Remove app access?";
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
          if (displayName !== undefined) {
            await api(`/users/${encodeURIComponent(user.user_id)}/display-name`, {method: "PUT", body: {display_name: displayName || null}});
            user.display_name = displayName || null;
            pendingDisplayNameEdits.delete(user.user_id);
          }
          await api(`/users/${encodeURIComponent(user.user_id)}/role`, role
            ? { method: "PUT", body: { role } }
            : { method: "DELETE" });
          user.database_role = role;
          pendingRoleEdits.delete(user.user_id);
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
      if (role) {
        renderUsers();
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

// Let database managers download an archive and configure this computer's reminder.
async function showManageData() {
  if (state.role !== "database_manager") throw new Error("Only a database manager can manage data downloads.");
  setHeader("Data", "Download a local snapshot of the Garden Program table rows.");
  const settings = readDataExportReminder();
  const lastDownload = settings.lastDownloadAt
    ? new Intl.DateTimeFormat(undefined, {dateStyle: "medium", timeStyle: "short"}).format(new Date(settings.lastDownloadAt))
    : "No export has been downloaded on this computer yet.";
  content.innerHTML = `
    <section class="card data-export-card">
      <div class="card-header">Download program data</div>
      <div class="card-body">
        <p>Download all Garden Program table rows as one insertable SQL file.</p>
        <p class="muted">This is a copy of the table row data in the database.</p>
        <p class="muted">Last download recorded on this computer: <strong id="data-export-last-download">${escapeHtml(lastDownload)}</strong></p>
        <button class="btn primary" type="button" id="data-export-download">Download all table data</button>
        <p class="data-export-status" id="data-export-status" role="status" aria-live="polite"></p>
      </div>
    </section>
    <section class="card data-export-card">
      <div class="card-header">Download reminder</div>
      <div class="card-body data-export-settings">
        <label for="data-export-frequency">Remind me to download</label>
        <select id="data-export-frequency">
          <option value="0">Off</option>
          <option value="7">Every week</option>
          <option value="14">Every two weeks</option>
          <option value="30">Every month</option>
        </select>
        <p class="muted">The reminder appears while the app is open. If dismissed without downloading, it returns the next time the app is opened.</p>
      </div>
    </section>`;
  $("#data-export-frequency").value = String(settings.intervalDays);
  $("#data-export-frequency").onchange = event => {
    const updated = {...readDataExportReminder(), intervalDays: Number(event.target.value)};
    const status = $("#data-export-status");
    status.classList.remove("error");
    if (!writeDataExportReminder(updated)) {
      status.textContent = "Could not save reminder settings in this browser.";
      status.classList.add("error");
      event.target.value = String(settings.intervalDays);
      return;
    }
    settings.intervalDays = updated.intervalDays;
    dataExportReminderDismissed = false;
    status.textContent = updated.intervalDays
      ? updated.lastDownloadAt ? "Reminder schedule saved on this computer." : "Reminder schedule saved. A download is due because no previous export is recorded."
      : "Reminders are off on this computer.";
    updateDataExportReminder();
  };
  $("#data-export-download").onclick = event => downloadAllTableData(event.currentTarget);
}

async function showAuditLog() {
  if (state.role !== "database_manager") throw new Error("Only a database manager can view the audit log.");
  setHeader("Log", "Recent data changes and account/app events.");
  content.innerHTML = '<div class="empty">Loading audit history…</div>';
  const [entries, appEvents, accounts] = await Promise.all([api("/audit-log"), api("/app-events"), api("/users")]);
  const emailByUserId = Object.fromEntries(accounts.map(account => [account.user_id, account.email]));
  const combined = [
    ...entries.map(entry => ({...entry, source: "data", timestamp: entry.changed_at, event: entry.action, area: String(entry.table_name || "").split(".").pop(), details: {row_key: entry.row_key, old: entry.old_data, new: entry.new_data}})),
    ...appEvents.map(entry => ({...entry, source: "app", timestamp: entry.occurred_at, event: entry.event_type.replaceAll("_", " "), area: "Account / App", details: entry.details || {}})),
  ].sort((a, b) => Date.parse(b.timestamp) - Date.parse(a.timestamp));
  content.innerHTML = `<div class="audit-toolbar"><div class="audit-search-row"><input id="audit-search" class="search" type="search" placeholder="Search…" aria-label="Search log"><button class="btn small audit-add-filter" id="audit-add-filter" type="button" aria-label="Add another search box" title="Add another search box">+</button><span id="audit-extra-filters" class="audit-filter-inline"></span></div><div class="audit-toolbar-actions">${printButton}<label class="audit-date-filter">From <input id="audit-from" type="datetime-local" aria-label="Filter from date and time"></label><label class="audit-date-filter">To <input id="audit-to" type="datetime-local" aria-label="Filter through date and time"></label></div></div><section class="card"><div class="table-wrap"><table class="data-table"><thead><tr><th>When</th><th>User</th><th>Event</th><th>Table / Area</th><th>Details</th></tr></thead><tbody id="audit-rows"></tbody></table></div><div class="empty" id="audit-empty" hidden>No matching entries.</div><p class="muted" id="audit-count"></p></section>`;
  $("#print-page").onclick = downloadTablePdf;
  let auditSort = null;
  const auditSortColumns = ["timestamp", "actor_email", "event", "area"];
  const auditHeaderLabels = ["When", "User", "Event", "Table / Area"];
  content.querySelectorAll(".data-table thead th").forEach((th, index) => {
    th.classList.add(["col-when", "col-user", "col-event", "col-area", "col-details"][index]);
    if (index >= auditSortColumns.length) return;
    th.dataset.auditSort = auditSortColumns[index];
    th.innerHTML = `${auditHeaderLabels[index]}<span class="sort-arrows" aria-hidden="true"><span class="sort-arrow-up">▲</span><span class="sort-arrow-down">▼</span></span>`;
  });
  let filteredEntries = [];
  const render = () => {
    const queries = [$("#audit-search").value, ...[...content.querySelectorAll("[data-audit-extra-filter]")].map(input => input.value)]
      .map(value => value.trim().toLowerCase()).filter(Boolean);
    const from = $("#audit-from").value ? new Date($("#audit-from").value).getTime() : -Infinity;
    const to = $("#audit-to").value ? new Date($("#audit-to").value).getTime() : Infinity;
    filteredEntries = combined.filter(entry => {
      const stamp = Date.parse(entry.timestamp);
      const when = new Intl.DateTimeFormat(undefined, {dateStyle:"medium",timeStyle:"short"}).format(new Date(stamp));
      const searchable = `${when} ${entry.timestamp} ${entry.actor_email || ""} ${entry.actor_user_id || ""} ${entry.event} ${entry.area} ${entry.details?.target_email || emailByUserId[entry.details?.target_user_id] || ""} ${JSON.stringify(entry.details)}`;
      const haystack = searchable.toLowerCase();
      return stamp >= from && stamp <= to && queries.every(query => haystack.includes(query));
    });
    if (auditSort) {
      const { col, desc } = auditSort;
      filteredEntries.sort((a, b) => {
        const x = col === "timestamp" ? Date.parse(a.timestamp) : String(a[col] || "");
        const y = col === "timestamp" ? Date.parse(b.timestamp) : String(b[col] || "");
        const comparison = typeof x === "number" && typeof y === "number"
          ? x - y
          : x.localeCompare(y, undefined, { numeric: true });
        return desc ? -comparison : comparison;
      });
    }
    content.querySelectorAll("th[data-audit-sort]").forEach(th => {
      const active = auditSort?.col === th.dataset.auditSort;
      th.querySelector(".sort-arrow-up")?.classList.toggle("active", active && !auditSort?.desc);
      th.querySelector(".sort-arrow-down")?.classList.toggle("active", active && Boolean(auditSort?.desc));
    });
    $("#audit-rows").innerHTML = filteredEntries.map(entry => {
      let details = entry.details;
      if (details?.target_user_id && !details.target_email && emailByUserId[details.target_user_id]) {
        details = {...details, target_email: emailByUserId[details.target_user_id]};
      }
      if (entry.source === "data") {
        if (entry.action === "UPDATE") {
          const before = entry.old_data || {};
          const after = entry.new_data || {};
          const changed = Object.keys(after).filter(key => JSON.stringify(before[key]) !== JSON.stringify(after[key]));
          details = {row_key: entry.row_key, changed: Object.fromEntries(changed.map(key => [key, {from: before[key] ?? null, to: after[key] ?? null}]))};
        } else if (entry.action === "INSERT") details = {row_key: entry.row_key, created: entry.new_data};
        else if (entry.action === "DELETE") details = {row_key: entry.row_key, deleted: entry.old_data};
      }
      return `<tr><td class="col-when">${escapeHtml(new Intl.DateTimeFormat(undefined, {dateStyle:"medium",timeStyle:"short"}).format(new Date(entry.timestamp)))}</td><td class="col-user">${escapeHtml(entry.actor_email || entry.actor_user_id || "System / SQL Editor")}</td><td class="col-event">${escapeHtml(entry.event)}</td><td class="col-area">${escapeHtml(entry.area)}</td><td class="col-details"><details><summary>View details</summary><pre>${escapeHtml(JSON.stringify(details,null,2))}</pre></details></td></tr>`;
    }).join("");
    $("#audit-empty").hidden = filteredEntries.length > 0;
    $("#audit-count").textContent = `${filteredEntries.length} of ${combined.length} log entries`;
  };
  $("#audit-search").oninput = render;
  const addExtraFilter = () => {
    if (document.querySelectorAll("[data-audit-extra-filter]").length >= 2) return;
    const row = document.createElement("div");
    row.className = "audit-filter-entry";
    row.innerHTML = `<button class="btn small audit-remove-filter" type="button" aria-label="Remove this search box" title="Remove this search box">×</button><input class="search" type="search" data-audit-extra-filter aria-label="Additional log search term" placeholder="Search another term"><button class="btn small audit-add-filter" type="button" aria-label="Add another search box" title="Add another search box">+</button>`;
    row.querySelector("input").oninput = render;
    $("#audit-extra-filters").append(row);
    row.querySelector(".audit-remove-filter").onclick = () => { row.remove(); updateAddFilterButtons(); render(); };
    row.querySelector(".audit-add-filter").onclick = addExtraFilter;
    row.querySelector("input").focus();
    updateAddFilterButtons();
  };
  const updateAddFilterButtons = () => {
    const extraButtons = [...document.querySelectorAll("#audit-extra-filters .audit-add-filter")];
    const extraCount = extraButtons.length;
    const buttons = [$("#audit-add-filter"), ...extraButtons];
    buttons.forEach((button, index) => { button.hidden = extraCount >= 2 || index < extraCount; });
  };
  $("#audit-add-filter").onclick = addExtraFilter;
  $("#audit-from").onchange = render;
  $("#audit-to").onchange = render;
  content.querySelectorAll("th[data-audit-sort]").forEach(th => {
    th.onclick = () => {
      const col = th.dataset.auditSort;
      if (auditSort?.col !== col) auditSort = { col, desc: false };
      else if (!auditSort.desc) auditSort = { col, desc: true };
      else auditSort = null;
      render();
    };
  });
  render();
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
  updateDataExportReminder();
  const [, kind, name] = (location.hash || "#/dashboard").split("/");
  try {
    if (kind === "table") await showTable(decodeURIComponent(name));
    else if (kind === "view") await showView(decodeURIComponent(name));
    else if (kind === "users") await showUsers();
    else if (kind === "manage-data") await showManageData();
    else if (kind === "audit-log") await showAuditLog();
    else if (kind === "help") await showHelp((location.hash || "").split("/")[2] || "");
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

$("#invite-login-form").onsubmit = async event => {
  event.preventDefault();
  const submit = $("#invite-login-submit");
  const message = $("#invite-login-message");
  submit.disabled = true;
  submit.textContent = "Signing in…";
  message.textContent = "";
  message.classList.remove("success", "info");
  try {
    const { data, error } = await supabaseClient.auth.signInWithPassword({
      email: $("#invite-login-email").value.trim(),
      password: $("#invite-login-password").value,
    });
    if (error) throw error;
    $("#invite-login-dialog").close();
    await openApp(data.session);
  } catch (error) {
    message.textContent = error.message || "Could not sign in. Check your email and password.";
  } finally {
    submit.disabled = false;
    submit.textContent = "Sign in";
  }
};

$("#invite-login-cancel").onclick = () => {
  $("#invite-login-dialog").close();
  showLogin();
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
  const hasSymbol = [...password].some((character) => "!@#$%^&*()_+-=[]{};':\"|<>?,./`~\\".includes(character));
  if (password.length < 8 || !/[a-z]/.test(password) || !/[A-Z]/.test(password) || !/[0-9]/.test(password) || !hasSymbol) {
    message.textContent = "Use at least 8 characters, including lowercase and uppercase letters, a number, and a symbol.";
    return;
  }
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
    if (isInvite) {
      showLogin();
      showInviteLogin();
    } else {
      showLogin("Password updated. Sign in with your new password.", "success");
    }
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
  if (event === "SIGNED_OUT") {
    const message = signOutNotice;
    signOutNotice = "";
    showLogin(message, message ? "info" : "error");
  }
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
