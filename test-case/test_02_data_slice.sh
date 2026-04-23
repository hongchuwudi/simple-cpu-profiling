#!/usr/bin/env bash
#
# Test 2: Perf data slice creation and validation
#
# Verifies:
#   - perf_*.data files are created with non-zero size
#   - Files contain valid perf data (readable header)
#   - At least 2 slices are produced in 25 seconds
#

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE="/home/hongchu/code/simple-cpu-profiling"
DAEMON="${BASE}/scripts/profiler_daemon.sh"
OUTPUT_DIR="${BASE}/log/profiler"
PID_FILE="${BASE}/run/profiler.pid"

echo "=== Test 2: Perf Data Slice Creation ==="
echo "Date: $(date)"
echo ""

# Pre-clean
pkill -f "profiler_daemon.sh start" 2>/dev/null || true
sleep 1
rm -f "$PID_FILE"

# Start daemon and collect for 25 seconds
echo "[setup] Starting daemon for 25 seconds..."
"$DAEMON" start &
DAEMON_PID=$!
disown "$DAEMON_PID" 2>/dev/null || true
sleep 25

# Stop daemon
echo "[setup] Stopping daemon..."
kill -TERM "$DAEMON_PID" 2>/dev/null || true
sleep 2

# Count data files
data_count=$(find "$OUTPUT_DIR" -name "perf_*.data" 2>/dev/null | wc -l)
echo "[test] Number of perf_*.data files: ${data_count}"

if [[ "$data_count" -lt 2 ]]; then
    echo "  FAIL: expected at least 2 data files, found ${data_count}"
else
    echo "  PASS: at least 2 slices collected"
fi

# Validate each data file
echo ""
echo "[test] Data file details:"
total_pass=0
total_fail=0
for f in "$OUTPUT_DIR"/perf_*.data; do
    size=$(stat -c %s "$f" 2>/dev/null || echo 0)
    fname=$(basename "$f")
    if [[ "$size" -gt 0 ]]; then
        echo "  PASS: ${fname} (${size} bytes)"
        total_pass=$((total_pass + 1))
    else
        echo "  FAIL: ${fname} is empty (0 bytes)"
        total_fail=$((total_fail + 1))
    fi
done
echo "  Summary: ${total_pass} passed, ${total_fail} failed"

# Verify perf data format
echo ""
echo "[test] Verifying perf data format:"
newest=$(find "$OUTPUT_DIR" -name "perf_*.data" -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | awk '{print $2}')
if [[ -n "$newest" ]]; then
    echo "  File: $(basename "$newest")"
    header=$(perf report -i "$newest" --header-only 2>/dev/null | head -5)
    if [[ -n "$header" ]]; then
        echo "  PASS: perf report header is readable"
        echo "  Header preview:"
        echo "$header" | sed 's/^/    /'
    else
        echo "  FAIL: perf report header is empty"
    fi
else
    echo "  SKIP: no data file found"
fi

# Final cleanup
pkill -f "profiler_daemon.sh start" 2>/dev/null || true
rm -f "$PID_FILE"

echo ""
echo "=== Test 2 Complete ==="
