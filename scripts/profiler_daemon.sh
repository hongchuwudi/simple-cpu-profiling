#!/usr/bin/env bash
#
# profiler_daemon.sh — 7x24 continuous CPU profiling daemon
# Uses Linux perf to collect call-chain samples in fixed-length slices.
#
# Usage: profiler_daemon.sh {start|stop|status}
# Author: hongchuwudi
# Date:   2026-04-23

set -euo pipefail

# ── Hard-coded defaults (fallback if config is missing) ──────────────────────
SAMPLE_FREQ=99
SLICE_INTERVAL=10
OUTPUT_DIR="/home/hongchu/code/simple-cpu-profiling/log/profiler"
RETENTION_MINUTES=1440
CLEANUP_INTERVAL=600
PID_FILE="/home/hongchu/code/simple-cpu-profiling/run/profiler.pid"
LOG_FILE="/home/hongchu/code/simple-cpu-profiling/log/profiler/profiler.log"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF_FILE="${SCRIPT_DIR}/../config/profiler.conf"

# ── Signal trap ───────────────────────────────────────────────────────────────
cleanup() {
    # Kill any lingering perf child processes
    pkill -P $$ 2>/dev/null || true
    rm -f "$PID_FILE"
    log "INFO" "profiler daemon exiting"
}
trap cleanup EXIT INT TERM

# ── Logging ───────────────────────────────────────────────────────────────────
log() {
    local level="${1:-INFO}"
    local msg="${2:-}"
    local ts
    ts="$(date '+%Y-%m-%d %H:%M:%S')"
    echo "[${ts}] [${level}] ${msg}" | tee -a "$LOG_FILE"
}

# ── Configuration ─────────────────────────────────────────────────────────────
load_config() {
    if [[ -f "$CONF_FILE" ]]; then
        # shellcheck source=/dev/null
        source "$CONF_FILE"
    else
        log "WARN" "Config file not found at ${CONF_FILE}, using built-in defaults"
    fi
}

# ── Start ─────────────────────────────────────────────────────────────────────
do_start() {
    load_config

    # Verify perf is available
    if ! command -v perf &>/dev/null; then
        log "ERROR" "perf is not installed or not in PATH"
        exit 1
    fi

    # Check perf_event_paranoid
    local paranoid
    paranoid="$(cat /proc/sys/kernel/perf_event_paranoid 2>/dev/null || echo '-1')"
    if [[ "$paranoid" -ge 2 ]]; then
        log "ERROR" "perf_event_paranoid=${paranoid} (>=2), perf requires less restrictive setting.
  Fix: sudo sysctl -w kernel.perf_event_paranoid=1 (or run as root)"
        exit 1
    fi

    # Create directories
    mkdir -p "$OUTPUT_DIR"
    mkdir -p "$(dirname "$PID_FILE")"
    mkdir -p "$(dirname "$LOG_FILE")"

    # Clean stale PID file
    if [[ -f "$PID_FILE" ]]; then
        local old_pid
        old_pid="$(cat "$PID_FILE" 2>/dev/null || true)"
        if [[ -n "$old_pid" ]] && kill -0 "$old_pid" 2>/dev/null; then
            log "ERROR" "profiler is already running, PID: ${old_pid}"
            exit 1
        else
            log "WARN" "Removing stale PID file (old PID=${old_pid} no longer exists)"
            rm -f "$PID_FILE"
        fi
    fi

    # Write PID so external tools can identify the daemon
    echo "$$" > "$PID_FILE"
    log "INFO" "profiler daemon started, PID: $$"

    # Run the sampling loop in the foreground (so systemd tracks this process)
    cleanup_counter=0
    while true; do
        local slice_tag
        slice_tag="$(date +%Y%m%d_%H%M%S)"
        local slice_file="${OUTPUT_DIR}/perf_${slice_tag}.data"

        perf record -a -g -F "${SAMPLE_FREQ}" -o "${slice_file}" --no-buildid -- sleep "${SLICE_INTERVAL}" &>>"$LOG_FILE" || true

        log "INFO" "slice completed: perf_${slice_tag}.data"

        cleanup_counter=$((cleanup_counter + 1))
        if [ $((cleanup_counter % 10)) -eq 0 ]; then
            find "${OUTPUT_DIR}" -name "perf_*.data" -mmin +"${RETENTION_MINUTES}" -delete &>>"$LOG_FILE" || true
            log "INFO" "cleanup executed"
        fi
    done
}

# ── Stop ──────────────────────────────────────────────────────────────────────
do_stop() {
    load_config

    if [[ ! -f "$PID_FILE" ]]; then
        log "WARN" "profiler is not running (no PID file)"
        exit 0
    fi

    local pid
    pid="$(cat "$PID_FILE" 2>/dev/null || true)"

    if [[ -z "$pid" ]] || ! kill -0 "$pid" 2>/dev/null; then
        log "WARN" "PID file exists but process ${pid:-<empty>} is dead — cleaning up"
        rm -f "$PID_FILE"
        exit 0
    fi

    log "INFO" "stopping profiler, PID: ${pid}"
    kill -TERM "$pid" 2>/dev/null || true

    # Grace period: wait up to 2 seconds
    local waited=0
    while [[ $waited -lt 20 ]]; do
        if ! kill -0 "$pid" 2>/dev/null; then
            break
        fi
        sleep 0.1
        waited=$((waited + 1))
    done

    # Force kill if still alive
    if kill -0 "$pid" 2>/dev/null; then
        log "WARN" "process did not exit after 2s, sending SIGKILL"
        kill -KILL "$pid" 2>/dev/null || true
        wait "$pid" 2>/dev/null || true
    fi

    rm -f "$PID_FILE"
    log "INFO" "profiler stopped"
}

# ── Status ────────────────────────────────────────────────────────────────────
do_status() {
    load_config

    if [[ ! -f "$PID_FILE" ]]; then
        echo "profiler is not running"
        return 0
    fi

    local pid
    pid="$(cat "$PID_FILE" 2>/dev/null || true)"

    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
        echo "profiler is running, PID: ${pid}"
    else
        echo "stale PID file found, profiler may have crashed"
        rm -f "$PID_FILE"
        log "WARN" "removed stale PID file"
    fi
}

# ── Main ──────────────────────────────────────────────────────────────────────
case "${1:-}" in
    start)  do_start  ;;
    stop)   do_stop   ;;
    status) do_status ;;
    *)
        echo "Usage: $0 {start|stop|status}"
        exit 1
        ;;
esac
