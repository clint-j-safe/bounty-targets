/**
 * ============================================================
 *  Bounty Targets -> Google Sheet  (create + populate + refresh)
 * ============================================================
 *  FEED: https://raw.githubusercontent.com/clint-j-safe/bounty-targets/main/data/programs.json
 *        (regenerated every 6 h by the repo's Crawl workflow)
 *
 *  FIRST RUN
 *    1. Open https://script.google.com  ->  New project
 *    2. Delete the stub code, paste this whole file, press Save
 *    3. Run the function: setup     (top toolbar -> Run)
 *    4. Approve the permission prompt (Advanced -> Go to ... -> Allow)
 *    5. View -> Logs shows the spreadsheet URL -> open it
 *
 *  WHAT YOU GET
 *    "Bounty Targets" spreadsheet with tabs:
 *      Programs (948 rows), Targets (~50,787 rows), Meta (counts + timestamps)
 *    A 6-hour time-driven trigger keeps it in sync automatically.
 *
 *    IMPORTANT: Programs / Targets / Meta are machine-generated. They are
 *    deleted and re-created on every refresh, so stale data-validation
 *    rules, formats, or protections can never block machine writes.
 *    Keep your own filters / pivots / notes on separate tabs.
 *
 *  OTHER ENTRY POINTS
 *    refreshAll()      - rebuild the tabs right now (script editor or menu)
 *    installTrigger()  - (re)install the 6-hour refresh trigger
 *    removeTrigger()   - stop automatic refreshes
 *    showSheetUrl()    - log the linked spreadsheet URL
 */

const PROGRAMS_URL = 'https://raw.githubusercontent.com/clint-j-safe/bounty-targets/main/data/programs.json';
const SHEET_NAME = 'Bounty Targets';
const MAX_INSTRUCTION = 500; // target instruction text truncated to this many characters
const CHUNK = 5000;          // rows per setValues() call
const PROP_KEY = 'BOUNTY_SHEET_ID';

/* ---------------- entry points ---------------- */

/** One-time setup: create/link the spreadsheet, populate it, install the trigger. */
function setup() {
  const ss = resolveSpreadsheet(true);
  PropertiesService.getScriptProperties().setProperty(PROP_KEY, ss.getId());
  refreshAll();
  installTrigger();

  // Remove the empty default "Sheet1" of freshly created spreadsheets.
  const def = ss.getSheetByName('Sheet1');
  if (def && ss.getSheets().length > 1 && def.getLastRow() === 0) ss.deleteSheet(def);

  Logger.log('Done. Sheet: ' + ss.getUrl());
  Logger.log('Auto-refresh installed: every 6 hours.');
}

/** Rebuild the Programs / Targets / Meta tabs from the live feed. */
function refreshAll() {
  const data = fetchJson(PROGRAMS_URL);
  writeProgramsTab(data);
  writeTargetsTab(data);
  writeMetaTab(data);
  Logger.log('Refreshed ' + data.programs.length + ' programs from ' + PROGRAMS_URL);
}

/** (Re)install the 6-hourly time-driven trigger. */
function installTrigger() {
  removeTrigger();
  ScriptApp.newTrigger('refreshAll').timeBased().everyHours(6).create();
  Logger.log('Trigger installed: refreshAll every 6 hours.');
}

/** Remove every trigger belonging to this script. */
function removeTrigger() {
  ScriptApp.getProjectTriggers().forEach(function (t) { ScriptApp.deleteTrigger(t); });
}

/** Log the linked spreadsheet URL (handy when running from the editor). */
function showSheetUrl() {
  Logger.log(resolveSpreadsheet(false).getUrl());
}

/** Optional menu when the script is bound to a spreadsheet. */
function onOpen() {
  try {
    SpreadsheetApp.getUi()
      .createMenu('Bounty Targets')
      .addItem('Refresh now', 'refreshAll')
      .addToUi();
  } catch (e) {
    // standalone script - no sheet UI to attach the menu to; safe to ignore
  }
}

/* ---------------- internals ---------------- */

/** active spreadsheet (if bound) -> remembered spreadsheet -> create new. */
function resolveSpreadsheet(createIfMissing) {
  let ss = null;
  try { ss = SpreadsheetApp.getActiveSpreadsheet(); } catch (e) { ss = null; }
  if (ss) return ss;

  const id = PropertiesService.getScriptProperties().getProperty(PROP_KEY);
  if (id) {
    try {
      return SpreadsheetApp.openById(id);
    } catch (e) {
      if (!createIfMissing) throw new Error('Linked spreadsheet not found. Run setup() again.');
    }
  }
  if (createIfMissing) return SpreadsheetApp.create(SHEET_NAME);
  throw new Error('No spreadsheet linked yet. Run setup() once from the Apps Script editor.');
}

function fetchJson(url) {
  const res = UrlFetchApp.fetch(url, { muteHttpExceptions: true });
  if (res.getResponseCode() !== 200) {
    throw new Error('Fetch failed (' + res.getResponseCode() + '): ' + url);
  }
  return JSON.parse(res.getContentText());
}

/** Intigriti sometimes returns {"value":123,"currency":"USD"}; flatten to the number. */
function money(v) {
  if (v && typeof v === 'object') return v.value !== undefined ? v.value : '';
  return v === null || v === undefined ? '' : v;
}

/** Currency companion for money() - blank when the feed has no currency. */
function currency(v) {
  return (v && typeof v === 'object' && v.currency) ? v.currency : '';
}

/** setValues() rejects undefined; turn it into an empty cell. */
function sanitize(row) {
  return row.map(function (v) { return v === undefined ? '' : v; });
}

function writeProgramsTab(data) {
  const rows = [[
    'platform', 'id', 'handle', 'name', 'url', 'offers_bounty', 'submission_state', 'managed',
    'first_started_at', 'last_updated_at', 'last_activity_at', 'reports_count', 'resolved_reports_count',
    'total_bounty_amount', 'total_bounty_currency', 'bounty_min', 'bounty_max',
    'targets_count', 'in_scope_targets_count', 'bounty_targets_count'
  ]];
  data.programs.forEach(function (p) {
    const t = p.targets || [];
    rows.push([
      p.platform, p.id, p.handle, p.name, p.url, p.offers_bounty, p.submission_state, p.managed,
      p.first_started_at, p.last_updated_at, p.last_activity_at, p.reports_count, p.resolved_reports_count,
      money(p.total_bounty_amount), currency(p.total_bounty_amount), money(p.bounty_min), money(p.bounty_max),
      t.length,
      t.filter(function (x) { return x.in_scope !== false; }).length,
      t.filter(function (x) { return x.bounty === true; }).length
    ]);
  });
  writeTab('Programs', rows);
}

function writeTargetsTab(data) {
  const rows = [[
    'platform', 'program_handle', 'program_name', 'program_url', 'type', 'target',
    'in_scope', 'bounty', 'updated_at', 'severity', 'instruction'
  ]];
  data.programs.forEach(function (p) {
    (p.targets || []).forEach(function (t) {
      let instr = t.instruction || '';
      if (instr.length > MAX_INSTRUCTION) instr = instr.substring(0, MAX_INSTRUCTION) + '...';
      rows.push([
        p.platform, p.handle, p.name, p.url, t.type, t.target,
        t.in_scope, t.bounty, t.updated_at, t.severity, instr
      ]);
    });
  });
  writeTab('Targets', rows);
}

function writeMetaTab(data) {
  let targets = 0, inScope = 0, bounty = 0;
  data.programs.forEach(function (p) {
    (p.targets || []).forEach(function (t) {
      targets++;
      if (t.in_scope !== false) inScope++;
      if (t.bounty === true) bounty++;
    });
  });
  writeTab('Meta', [
    ['key', 'value'],
    ['generated_at', data.generated_at],
    ['refreshed_at', new Date().toISOString()],
    ['programs', data.programs.length],
    ['targets', targets],
    ['in_scope_targets', inScope],
    ['bounty_targets', bounty],
    ['out_of_scope_targets', targets - inScope]
  ]);
}

/**
 * Replace a tab with a freshly created copy of it.
 * Deleting first is deliberate: some stale rules (e.g. ones enforced by a
 * Sheet "Table" column type) survive clearDataValidations() and would keep
 * rejecting machine-written values. A new tab always starts clean.
 */
function writeTab(name, rows) {
  const ss = resolveSpreadsheet(false);
  let sheet = ss.getSheetByName(name);
  if (sheet && ss.getSheets().length > 1) {
    ss.deleteSheet(sheet);
    sheet = null;
  }
  if (!sheet) {
    sheet = ss.insertSheet(name);
  } else {
    sheet.clear();
    sheet.getRange(1, 1, sheet.getMaxRows(), sheet.getMaxColumns()).clearDataValidations();
  }

  ensureGrid(sheet, rows.length, rows[0].length);

  for (let i = 0; i < rows.length; i += CHUNK) {
    const chunk = rows.slice(i, i + CHUNK).map(sanitize);
    const range = sheet.getRange(i + 1, 1, chunk.length, chunk[0].length);
    try {
      range.setValues(chunk);
    } catch (e) {
      range.clearDataValidations(); // last resort for exotic rules
      range.setValues(chunk);
    }
  }
  sheet.getRange(1, 1, 1, rows[0].length).setFontWeight('bold');
  sheet.setFrozenRows(1);
}

/** Grow the grid when the data is larger than the tab's current dimensions. */
function ensureGrid(sheet, neededRows, neededCols) {
  if (sheet.getMaxRows() < neededRows) {
    sheet.insertRowsAfter(sheet.getMaxRows(), neededRows - sheet.getMaxRows());
  }
  if (sheet.getMaxColumns() < neededCols) {
    sheet.insertColumnsAfter(sheet.getMaxColumns(), neededCols - sheet.getMaxColumns());
  }
}