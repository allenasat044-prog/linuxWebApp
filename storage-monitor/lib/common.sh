#!/usr/bin/env bash
# ============================================================
# common.sh - shared functions for the storage monitor toolkit
# ============================================================

# Resolve project root regardless of where this is sourced from
LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${LIB_DIR}/.." && pwd)"
CONF_FILE="${PROJECT_ROOT}/conf/storage-monitor.conf"

if [[ -f "${CONF_FILE}" ]]; then
    # shellcheck disable=SC1090
    source "${CONF_FILE}"
else
    echo "FATAL: config file not found at ${CONF_FILE}" >&2
    exit 1
fi

mkdir -p "${DATA_DIR}" "${LOG_DIR}" "${REPORT_DIR}"

# ---------- logging ----------
log() {
    local level="$1"; shift
    local msg="$*"
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[${ts}] [${level}] ${msg}" | tee -a "${LOG_FILE}" >/dev/null
    if [[ "${level}" != "INFO" ]]; then
        echo "[${ts}] [${level}] ${msg}"
    fi
}

log_info()  { log "INFO"  "$@"; }
log_warn()  { log "WARN"  "$@"; }
log_crit()  { log "CRIT"  "$@"; }
log_error() { log "ERROR" "$@"; }

# ---------- OS detection ----------
detect_os() {
    case "$(uname -s)" in
        Linux*)  echo "linux" ;;
        Darwin*) echo "macos" ;;
        *)       echo "unsupported" ;;
    esac
}

# ---------- alerting ----------
send_alert() {
    local severity="$1"   # WARN | CRIT
    local subject="$2"
    local body="$3"

    log_"${severity,,}" "${subject} :: ${body}"

    if [[ "${ALERT_SYSLOG_ENABLED}" == "true" ]] && command -v logger >/dev/null 2>&1; then
        logger -t storage-monitor -p "user.${severity,,}" "${subject}: ${body}"
    fi

    if [[ "${ALERT_EMAIL_ENABLED}" == "true" ]] && command -v mail >/dev/null 2>&1; then
        echo "${body}" | mail -s "[${severity}] Storage Monitor: ${subject}" "${ALERT_EMAIL_TO}"
    fi

    if [[ "${ALERT_WEBHOOK_ENABLED}" == "true" ]] && command -v curl >/dev/null 2>&1; then
        local payload
        payload=$(printf '{"text":"*[%s] Storage Monitor*\\n%s\\n%s"}' "${severity}" "${subject}" "${body}")
        curl -s -X POST -H 'Content-type: application/json' \
            --data "${payload}" "${ALERT_WEBHOOK_URL}" >/dev/null 2>&1
    fi
}

# ---------- helpers ----------
# Convert a df size like "10G" / "512M" / "1024K" to MB (integer).
# Pure awk, no numfmt dependency (numfmt is GNU-only; macOS doesn't ship
# it, and Homebrew's coreutils installs it as "gnumfmt", not "numfmt",
# unless the user manually adds its gnubin dir to PATH - relying on it
# silently produced wrong/raw numbers on every Mac).
to_mb() {
    local val="$1"
    awk -v v="$val" 'BEGIN{
        unit=substr(v,length(v),1);
        num=substr(v,1,length(v)-1);
        if (unit !~ /^[0-9]$/) {
            if (unit=="K") mb=num/1024;
            else if (unit=="M") mb=num;
            else if (unit=="G") mb=num*1024;
            else if (unit=="T") mb=num*1024*1024;
            else mb=0;
        } else {
            mb=v/1024/1024; # assume raw bytes if no unit suffix
        }
        printf "%d", mb;
    }'
}

# Format a raw byte count as human-readable (B/KB/MB/GB/TB), pure awk.
# Always available - no external dependency, identical output on
# Linux, macOS, and WSL regardless of what's installed.
human_bytes() {
    local bytes="${1:-0}"
    awk -v b="$bytes" 'BEGIN{
        split("B KB MB GB TB PB", units, " ");
        u = 1;
        sign = (b < 0) ? "-" : "";
        if (b < 0) b = -b;
        while (b >= 1024 && u < 6) { b /= 1024; u++ }
        if (u == 1) printf "%s%d%s", sign, b, units[u];
        else        printf "%s%.1f%s", sign, b, units[u];
    }'
}
