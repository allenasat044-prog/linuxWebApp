#!/usr/bin/env bash
# ============================================================
# generate-report.sh
# Produces a single self-contained HTML report of current
# disk/inode status and recent growth trends. No server or
# login required - just open the file in a browser.
#
# Usage: ./generate-report.sh
# ============================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/common.sh"

TS="$(date '+%Y-%m-%d_%H%M%S')"
OUT_FILE="${REPORT_DIR}/storage-report_${TS}.html"
JSON_DATA="$("${SCRIPT_DIR}/storage-monitor.sh" --quiet --json)"

# Build table rows from the JSON (lightweight parse, no jq dependency required)
ROWS_HTML=""
STATUS_COUNT_OK=0
STATUS_COUNT_WARN=0
STATUS_COUNT_CRIT=0

# crude JSON object splitter (fine for our flat, controlled schema)
IFS=$'\n'
for obj in $(grep -oE '\{[^}]*\}' <<< "${JSON_DATA}"); do
    mount=$(grep -oE '"mount":"[^"]*"' <<< "$obj" | cut -d'"' -f4)
    fs=$(grep -oE '"filesystem":"[^"]*"' <<< "$obj" | cut -d'"' -f4)
    disk=$(grep -oE '"disk_used_pct":[0-9]+' <<< "$obj" | cut -d':' -f2)
    inode=$(grep -oE '"inode_used_pct":"[^"]*"' <<< "$obj" | cut -d'"' -f4)
    status=$(grep -oE '"status":"[^"]*"' <<< "$obj" | cut -d'"' -f4)

    case "$status" in
        OK)   badge_class="ok"; ((STATUS_COUNT_OK++)) ;;
        WARN) badge_class="warn"; ((STATUS_COUNT_WARN++)) ;;
        CRIT) badge_class="crit"; ((STATUS_COUNT_CRIT++)) ;;
        *)    badge_class="ok" ;;
    esac

    ROWS_HTML+="<tr><td>${mount}</td><td>${fs}</td><td>${disk}%</td><td>${inode}</td><td><span class=\"badge ${badge_class}\">${status}</span></td></tr>"
done
unset IFS

# Growth trend rows (last 15 entries)
GROWTH_ROWS_HTML=""
if [[ -f "${SNAPSHOT_FILE}" ]]; then
    while IFS=, read -r ts dir size; do
        [[ "$ts" == "timestamp" ]] && continue
        human=$(human_bytes $((size*1024)))
        GROWTH_ROWS_HTML+="<tr><td>${ts}</td><td>${dir}</td><td>${human}</td></tr>"
    done < <(tail -n 15 "${SNAPSHOT_FILE}")
fi

cat > "${OUT_FILE}" <<HTML
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Storage Monitoring Report - ${TS}</title>
<link rel="preconnect" href="https://fonts.googleapis.com">
<link href="https://fonts.googleapis.com/css2?family=Anton&family=IBM+Plex+Mono:wght@400;500;600;700&display=swap" rel="stylesheet">
<style>
  :root { color-scheme: dark; --orange:#FF4D00; --black:#0B0B0B; --dim:#8A8A85; }
  * { box-sizing: border-box; }
  body { font-family: 'IBM Plex Mono', monospace; max-width: 1000px; margin: 0 auto; padding: 0 24px 60px; background:var(--black); color:#F5F3EE; }
  .bar { height:6px; background:var(--orange); margin: 0 -24px 40px; }
  h1 { font-family:'Anton', sans-serif; text-transform:uppercase; font-size: 2.6rem; letter-spacing:-0.01em; margin-bottom: 6px; }
  .meta { color: var(--dim); margin-bottom: 32px; font-size: .82rem; letter-spacing:.02em; }
  .summary { display:flex; gap:1px; margin-bottom: 40px; background:#232323; border:1px solid #232323; }
  .card { background:var(--black); padding:20px 24px; flex:1; text-align:left; }
  .card .num { font-family:'Anton', sans-serif; font-size:2.2rem; }
  .card .label { font-size:.72rem; letter-spacing:.06em; color:var(--dim); text-transform:uppercase; }
  .card.ok .num { color:#34D399; }
  .card.warn .num { color:#FBBF24; }
  .card.crit .num { color:#F87171; }
  table { width:100%; border-collapse: collapse; margin-bottom: 48px; }
  th, td { text-align:left; padding:12px 14px; border-bottom:1px solid #232323; font-size:.85rem; }
  th { color:var(--dim); font-weight:600; text-transform:uppercase; font-size:.7rem; letter-spacing:.06em; }
  .badge { padding:3px 10px; font-size:.72rem; font-weight:700; letter-spacing:.03em; }
  .badge.ok   { background:#0d2818; color:#34D399; }
  .badge.warn { background:#2e2107; color:#FBBF24; }
  .badge.crit { background:#2e0d0d; color:#F87171; }
  h2 { font-family:'Anton', sans-serif; text-transform:uppercase; font-size:1.4rem; margin-top: 8px; border-left:4px solid var(--orange); padding-left:14px; margin-bottom:20px; }
</style>
</head>
<body>
  <div class="bar"></div>
  <h1>Storage Monitoring Report</h1>
  <div class="meta">Generated ${TS} on host $(hostname) ($(detect_os))</div>

  <div class="summary">
    <div class="card ok"><div class="num">${STATUS_COUNT_OK}</div><div class="label">OK</div></div>
    <div class="card warn"><div class="num">${STATUS_COUNT_WARN}</div><div class="label">Warning</div></div>
    <div class="card crit"><div class="num">${STATUS_COUNT_CRIT}</div><div class="label">Critical</div></div>
  </div>

  <h2>Filesystem Usage</h2>
  <table>
    <thead><tr><th>Mount</th><th>Filesystem</th><th>Disk Used</th><th>Inode Used</th><th>Status</th></tr></thead>
    <tbody>${ROWS_HTML:-"<tr><td colspan=5>No data</td></tr>"}</tbody>
  </table>

  <h2>Recent Growth Snapshots</h2>

  <table>
    <thead><tr><th>Timestamp</th><th>Directory</th><th>Size</th></tr></thead>
    <tbody>${GROWTH_ROWS_HTML:-"<tr><td colspan=3>No snapshot history yet - run growth-tracker.sh snapshot</td></tr>"}</tbody>
  </table>
</body>
</html>
HTML

log_info "Report generated: ${OUT_FILE}"
echo "${OUT_FILE}"
