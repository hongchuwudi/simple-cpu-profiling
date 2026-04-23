#!/usr/bin/env bash
#
# Test 3: Flamegraph generation (no args → latest slice)
#
# Verifies:
#   - generate_flamegraph.sh produces an SVG from the latest slice
#   - SVG has meaningful content (> 100 bytes)
#

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE="/home/hongchu/code/simple-cpu-profiling"
DAEMON="${BASE}/scripts/profiler_daemon.sh"
FLAME="${BASE}/scripts/generate_flamegraph.sh"
OUTPUT_DIR="${BASE}/log/profiler"
PID_FILE="${BASE}/run/profiler.pid"

echo "=== Test 3: Flamegraph Generation (Latest Slice) ==="
echo "Date: $(date)"
echo ""

# Pre-clean
pkill -f "profiler_daemon.sh start" 2>/dev/null || true
sleep 1
rm -f "$PID_FILE"

# Collect data
echo "[setup] Starting daemon for 22 seconds to collect data..."
"$DAEMON" start &
DAEMON_PID=$!
disown "$DAEMON_PID" 2>/dev/null || true
sleep 24

echo "[setup] Stopping daemon..."
kill -TERM "$DAEMON_PID" 2>/dev/null || true
sleep 3

# Count available slices
data_count=$(find "$OUTPUT_DIR" -name "perf_*.data" 2>/dev/null | wc -l)
echo "[setup] Available perf data slices: ${data_count}"

if [[ "$data_count" -eq 0 ]]; then
    echo "  SKIP: no data slices available, cannot generate flamegraph"
    pkill -f "profiler_daemon.sh start" 2>/dev/null || true
    rm -f "$PID_FILE"
    echo "=== Test 3 Complete (SKIP) ==="
    exit 0
fi

# Remove old SVG files
rm -f "$OUTPUT_DIR"/flamegraph_*.svg

# Generate flamegraph (no args)
echo ""
echo "[test] Running generate_flamegraph.sh (no args)..."
output=$("$FLAME" 2>&1) || true
echo "$output"

echo ""

# Verify SVG was created
svg_count=$(find "$OUTPUT_DIR" -name "flamegraph_*.svg" 2>/dev/null | wc -l)
echo "[test] Generated SVG files: ${svg_count}"

if [[ "$svg_count" -gt 0 ]]; then
    for svg in "$OUTPUT_DIR"/flamegraph_*.svg; do
        size=$(stat -c %s "$svg" 2>/dev/null || echo 0)
        echo "  File: $(basename "$svg") (${size} bytes)"
        if [[ "$size" -gt 100 ]]; then
            echo "  PASS: SVG has meaningful size"
        else
            echo "  FAIL: SVG is suspiciously small"
        fi
    done
else
    echo "  FAIL: no flamegraph SVG generated"
fi

# Verify SVG content
echo ""
echo "[test] Verifying SVG structure:"
for svg in "$OUTPUT_DIR"/flamegraph_*.svg 2>/dev/null; do
    if [[ -f "$svg" ]]; then
        if head -1 "$svg" | grep -q "<svg"; then
            echo "  PASS: $(basename "$svg") starts with <svg tag"
        else
            echo "  FAIL: $(basename "$svg") does not start with <svg tag"
        fi
        # Check for interactive elements (flamegraphs have JavaScript)
        if grep -q "function" "$svg" 2>/dev/null; then
            echo "  PASS: $(basename "$svg") contains interactive JavaScript"
        else
            echo "  WARN: $(basename "$svg") may lack interactivity"
        fi
    fi
done

# Final cleanup
pkill -f "profiler_daemon.sh start" 2>/dev/null || true
rm -f "$PID_FILE"

echo ""
echo "=== Test 3 Complete ==="
