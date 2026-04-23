#!/usr/bin/env bash
#
# Test 1: Daemon start / stop / status lifecycle
# All logic in a single execution context to avoid EXIT trap issues with
# background daemons that survive parent process termination.
#

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE="/home/hongchu/code/simple-cpu-profiling"
DAEMON="${BASE}/scripts/profiler_daemon.sh"
PID_FILE="${BASE}/run/profiler.pid"
LOG_FILE="${BASE}/log/profiler/profiler.log"

echo "=== Test 1: Daemon Start / Stop / Status ==="
echo "Date: $(date)"
echo ""

# Pre-clean
pkill -f "profiler_daemon.sh start" 2>/dev/null || true
sleep 1
rm -f "$PID_FILE"

# ── Test 1.1: Status when not running ──
echo "[test] 1.1: status when not running"
result=$("$DAEMON" status 2>&1)
echo "  Output: $result"
if echo "$result" | grep -q "not running"; then
    echo "  PASS: correctly reports not running"
else
    echo "  FAIL: unexpected output"
fi
echo ""

# ── Test 1.2: Start daemon and verify running state ──
echo "[test] 1.2: start daemon and verify running"
"$DAEMON" start &
DAEMON_PID=$!
disown "$DAEMON_PID" 2>/dev/null || true
sleep 3

if kill -0 "$DAEMON_PID" 2>/dev/null; then
    echo "  PASS: daemon process $DAEMON_PID is alive"
else
    echo "  FAIL: daemon process $DAEMON_PID is dead"
fi

# Verify PID file
if [[ -f "$PID_FILE" ]]; then
    file_pid=$(cat "$PID_FILE")
    echo "  PID file contains: $file_pid"
    if [[ "$file_pid" == "$DAEMON_PID" ]]; then
        echo "  PASS: PID matches background process"
    else
        echo "  INFO: PID differs ($file_pid vs $DAEMON_PID) — may be due to $$ in daemon"
    fi
else
    echo "  FAIL: PID file not found"
fi

# Verify status command
status_out=$("$DAEMON" status 2>&1)
echo "  Status output: $status_out"
if echo "$status_out" | grep -q "running"; then
    echo "  PASS: status reports running"
else
    echo "  FAIL: status does not report running"
fi
echo ""

# ── Test 1.3: Stop daemon ──
echo "[test] 1.3: stop daemon"
kill -TERM "$DAEMON_PID" 2>/dev/null || true
sleep 2

if kill -0 "$DAEMON_PID" 2>/dev/null; then
    echo "  FAIL: daemon still alive after SIGTERM"
    kill -KILL "$DAEMON_PID" 2>/dev/null || true
else
    echo "  PASS: daemon terminated"
fi

if [[ ! -f "$PID_FILE" ]]; then
    echo "  PASS: PID file removed"
else
    echo "  FAIL: PID file still exists"
fi

status_out=$("$DAEMON" status 2>&1)
echo "  Status after stop: $status_out"
if echo "$status_out" | grep -q "not running"; then
    echo "  PASS: status reports not running after stop"
else
    echo "  FAIL: status unexpected after stop"
fi
echo ""

# Final cleanup
pkill -f "profiler_daemon.sh start" 2>/dev/null || true
rm -f "$PID_FILE"

echo "=== Test 1 Complete ==="
