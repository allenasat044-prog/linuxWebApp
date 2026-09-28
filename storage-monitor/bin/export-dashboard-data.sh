#!/usr/bin/env bash
# ============================================================
# export-dashboard-data.sh
# Exports real disk usage, category breakdown, and growth
# history as a single JSON file the interactive dashboard
# (docs/dashboard.html) can load via its "Load your report"
# file picker - so the dashboard shows YOUR numbers instead
# of the built-in sample data.
#
# Usage: ./export-dashboard-data.sh [root_mount]
#   root_mount defaults to "/"
#
# Output: reports/dashboard-data.json
#
# Note on the category breakdown: df/du don't natively split
# disk usage into "system/logs/user data/cache" buckets - this
# is a best-effort heuristic built from MONITORED_DIRS in the
# config, not an authoritative OS-level breakdown. It's real
# measured data (du -sk on real directories), just approximate
# in how it's categorized.
# ============================================================

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/../lib/common.sh"

ROOT_MOUNT="${1:-/}"
OUT_JSON="${REPORT_DIR}/dashboard-data.json"

if [[ ! -d "$ROOT_MOUNT" ]]; then
    log_error "Mount point not found: $ROOT_MOUNT"
    exit 1
fi

# ---------- capacity (forced KB blocks - see storage-monitor.sh for why) ----------
line=$(df -Pk "$ROOT_MOUNT" 2>/dev/null | tail -n +2)
total_kb=$(awk '{print $2}' <<< "$line")
used_kb=$(awk '{print $3}' <<< "$line")
avail_kb=$(awk '{print $4}' <<< "$line")
use_pct=$(awk '{gsub("%","",$5); print $5}' <<< "$line")

if [[ -z "$total_kb" || "$total_kb" -eq 0 ]]; then
    log_error "Could not read disk stats for $ROOT_MOUNT"
    exit 1
fi

total_gb=$(awk -v k="$total_kb" 'BEGIN{printf "%.1f", k/1024/1024}')
used_gb=$(awk -v k="$used_kb"  'BEGIN{printf "%.1f", k/1024/1024}')
free_gb=$(awk -v k="$avail_kb" 'BEGIN{printf "%.1f", k/1024/1024}')

inode_pct="null"
if [[ "$(detect_os)" == "linux" ]]; then
    iline=$(df -iP "$ROOT_MOUNT" 2>/dev/null | tail -n +2)
    ip=$(awk '{gsub("%","",$5); print $5}' <<< "$iline")
    [[ "$ip" =~ ^[0-9]+$ ]] && inode_pct="$ip"
fi

# ---------- category breakdown (heuristic, from MONITORED_DIRS) ----------
logs_kb=0; user_kb=0; cache_kb=0
for dir in "${MONITORED_DIRS[@]}"; do
    [[ ! -d "$dir" ]] && continue
    sz=$(du -sk "$dir" 2>/dev/null | awk '{print $1}')
    [[ -z "$sz" ]] && continue
    case "$dir" in
        *log*)                    logs_kb=$((logs_kb + sz)) ;;
        /tmp*|*/private/var*)     cache_kb=$((cache_kb + sz)) ;;
        /home*|/Users*|/root*)    user_kb=$((user_kb + sz)) ;;
        *)                        user_kb=$((user_kb + sz)) ;;
    esac
done

pct_of_total() { awk -v a="$1" -v t="$total_kb" 'BEGIN{printf "%.1f", (t>0)?a/t*100:0}'; }
logs_pct=$(pct_of_total "$logs_kb")
user_pct=$(pct_of_total "$user_kb")
cache_pct=$(pct_of_total "$cache_kb")
free_pct=$(pct_of_total "$avail_kb")
system_pct=$(awk -v u="$use_pct" -v l="$logs_pct" -v us="$user_pct" -v c="$cache_pct" \
    'BEGIN{v=u-l-us-c; if(v<0)v=0; printf "%.1f", v}')

# ---------- status vs configured thresholds ----------
status="OK"
if (( $(awk -v u="$use_pct" -v t="$DISK_CRIT_THRESHOLD" 'BEGIN{print (u>=t)}') )); then
    status="CRITICAL"
elif (( $(awk -v u="$use_pct" -v t="$DISK_WARN_THRESHOLD" 'BEGIN{print (u>=t)}') )); then
    status="WARNING"
fi

# ---------- growth history (real snapshots, if any exist) ----------
primary_dir="${MONITORED_DIRS[0]}"
growth_json="[]"
if [[ -f "${SNAPSHOT_FILE}" ]]; then
    rows=()
    while IFS=, read -r ts dir size_kb_row; do
        [[ "$ts" == "timestamp" ]] && continue
        [[ "$dir" != "$primary_dir" ]] && continue
        gb=$(awk -v k="$size_kb_row" 'BEGIN{printf "%.3f", k/1024/1024}')
        short_ts=$(echo "$ts" | cut -c6-16 | tr 'T' ' ')
        rows+=("{\"label\":\"${short_ts}\",\"gb\":${gb}}")
    done < <(tail -n 50 "${SNAPSHOT_FILE}")
    # keep only the most recent 7
    total_rows=${#rows[@]}
    start=$(( total_rows > 7 ? total_rows - 7 : 0 ))
    recent=("${rows[@]:$start}")
    growth_json="[$(IFS=,; echo "${recent[*]:-}")]"
fi

cat > "${OUT_JSON}" <<JSON
{
  "generated": "$(date -Iseconds)",
  "host": "$(hostname)",
  "os": "$(detect_os)",
  "root_mount": "${ROOT_MOUNT}",
  "capacity_gb": ${total_gb},
  "used_gb": ${used_gb},
  "free_gb": ${free_gb},
  "used_pct": ${use_pct},
  "inode_pct": ${inode_pct},
  "status": "${status}",
  "breakdown": [
    {"label":"User Data","pct":${user_pct},"color":"#FA4B42"},
    {"label":"System","pct":${system_pct},"color":"#111111"},
    {"label":"Logs","pct":${logs_pct},"color":"#837E76"},
    {"label":"Cache / Temp","pct":${cache_pct},"color":"#C9C2B6"},
    {"label":"Free Space","pct":${free_pct},"color":"#F5F1EC"}
  ],
  "growth_history": ${growth_json},
  "growth_dir": "${primary_dir}",
  "growth_note": "Breakdown categories are a best-effort heuristic from configured MONITORED_DIRS, not an OS-level accounting."
}
JSON

log_info "Dashboard data exported: ${OUT_JSON}"
echo "${OUT_JSON}"
