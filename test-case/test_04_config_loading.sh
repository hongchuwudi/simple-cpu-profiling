#!/usr/bin/env bash
#
# Test 4: Config loading and parameter validation
#
# Verifies:
#   - Config file exists with all required keys
#   - Default values match expectations
#   - Daemon respects config values in perf command
#   - Built-in defaults in daemon match config values
#

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE="/home/hongchu/code/simple-cpu-profiling"
DAEMON="${BASE}/scripts/profiler_daemon.sh"
CONF="${BASE}/config/profiler.conf"
PID_FILE="${BASE}/run/profiler.pid"

echo "=== Test 4: Config Loading & Parameter Validation ==="
echo "Date: $(date)"
echo ""

# ── Test 4.1: Config file existence and key validation ──
echo "[test] 4.1: Config file existence and key validation"
if [[ -f "$CONF" ]]; then
    echo "  PASS: config file exists at ${CONF}"
else
    echo "  FAIL: config file not found"
    echo "=== Test 4 Complete (FAIL) ==="
    exit 1
fi

expected_keys=("SAMPLE_FREQ" "SLICE_INTERVAL" "OUTPUT_DIR" "RETENTION_MINUTES" "CLEANUP_INTERVAL" "PID_FILE" "LOG_FILE")
for key in "${expected_keys[@]}"; do
    if grep -q "^${key}=" "$CONF"; then
        value=$(grep "^${key}=" "$CONF" | head -1 | cut -d'=' -f2-)
        echo "  PASS: ${key}=${value}"
    else
        echo "  FAIL: ${key} not found in config"
    fi
done

# ── Test 4.2: Default value validation ──
echo ""
echo "[test] 4.2: Default value validation"

check_value() {
    local key="$1"
    local expected="$2"
    local actual
    actual=$(grep "^${key}=" "$CONF" | head -1 | cut -d'=' -f2- | tr -d ' ')
    if [[ "$actual" == "$expected" ]]; then
        echo "  PASS: ${key} = ${actual} (expected ${expected})"
    else
        echo "  FAIL: ${key} = ${actual} (expected ${expected})"
    fi
}

check_value "SAMPLE_FREQ" "99"
check_value "SLICE_INTERVAL" "10"
check_value "RETENTION_MINUTES" "1440"
check_value "CLEANUP_INTERVAL" "600"

# ── Test 4.3: Daemon respects config values ──
echo ""
echo "[test] 4.3: Daemon respects config values"

# Pre-clean
pkill -f "profiler_daemon.sh start" 2>/dev/null || true
sleep 1
rm -f "$PID_FILE"

"$DAEMON" start &
DAEMON_PID=$!
disown "$DAEMON_PID" 2>/dev/null || true
sleep 3

if [[ -f "$PID_FILE" ]]; then
    pid=$(cat "$PID_FILE")
    if kill -0 "$pid" 2>/dev/null; then
        echo "  PASS: daemon running with config (PID: ${pid})"

        # Check the perf child process
        perf_children=$(pgrep -P "$pid" 2>/dev/null || true)
        if [[ -n "$perf_children" ]]; then
            for child_pid in $perf_children; do
                cmdline=$(tr '\0' ' ' < /proc/$child_pid/cmdline 2>/dev/null || true)
                if [[ "$cmdline" == *"perf record"* ]]; then
                    echo "  perf command: ${cmdline}"
                    if [[ "$cmdline" == *"-F 99"* ]]; then
                        echo "  PASS: SAMPLE_FREQ=99 applied"
                    else
                        echo "  FAIL: SAMPLE_FREQ not found"
                    fi
                    if [[ "$cmdline" == *"sleep 10"* ]]; then
                        echo "  PASS: SLICE_INTERVAL=10 applied"
                    else
                        echo "  FAIL: SLICE_INTERVAL not found"
                    fi
                fi
            done
        else
            echo "  INFO: perf child not yet spawned (between slices)"
        fi
    else
        echo "  FAIL: daemon process not alive"
    fi
else
    echo "  FAIL: PID file not created"
fi

# Stop daemon
kill -TERM "$DAEMON_PID" 2>/dev/null || true
sleep 2

# ── Test 4.4: Consistency between config and daemon defaults ──
echo ""
echo "[test] 4.4: Config vs daemon default consistency"

compare_defaults() {
    local key="$1"
    local conf_val daemon_val
    conf_val=$(grep "^${key}=" "$CONF" | cut -d'=' -f2- | tr -d ' ')
    daemon_val=$(grep "^${key}=" "${BASE}/scripts/profiler_daemon.sh" | head -1 | cut -d'=' -f2- | tr -d ' ')
    if [[ "$conf_val" == "$daemon_val" ]]; then
        echo "  PASS: ${key} config(${conf_val}) == daemon(${daemon_val})"
    else
        echo "  FAIL: ${key} config(${conf_val}) != daemon(${daemon_val})"
    fi
}

compare_defaults "SAMPLE_FREQ"
compare_defaults "SLICE_INTERVAL"
compare_defaults "RETENTION_MINUTES"
compare_defaults "CLEANUP_INTERVAL"

# Final cleanup
pkill -f "profiler_daemon.sh start" 2>/dev/null || true
rm -f "$PID_FILE"

echo ""
echo "=== Test 4 Complete ==="
