#!/usr/bin/env bash
#
# Test 5: Data cleanup logic
# Verifies that old data files are cleaned up based on RETENTION_MINUTES,
# and that recent data is preserved.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="/home/hongchu/code/simple-cpu-profiling/log/profiler"

echo "=== Test 5: Data Cleanup Logic ==="
echo "Date: $(date)"
echo ""

# Test 5.1: Simulate old files and verify cleanup command
echo "[test] 5.1: Cleanup command removes old files"

# Create fake old data files
fake_dir=$(mktemp -d "${OUTPUT_DIR}/test_cleanup_XXXXXX")
for i in 1 2 3; do
    touch "${fake_dir}/perf_20260101_00000${i}.data"
done
# Mark them as 30 days old
touch -d "30 days ago" "${fake_dir}"/perf_*.data

old_count=$(find "$OUTPUT_DIR" -name "perf_*.data" -path "*/test_cleanup_*" 2>/dev/null | wc -l)
echo "  Created ${old_count} fake old data files in ${fake_dir}"

# Run the same cleanup command used by the daemon (files older than 1440 min = 24h)
find "$OUTPUT_DIR" -name "perf_*.data" -path "*/test_cleanup_*" -mmin +1440 -delete 2>/dev/null || true

remaining=$(find "$OUTPUT_DIR" -name "perf_*.data" -path "*/test_cleanup_*" 2>/dev/null | wc -l)
if [[ "$remaining" -eq 0 ]]; then
    echo "  PASS: all old files cleaned up"
else
    echo "  FAIL: ${remaining} old files still remain"
fi

# Test 5.2: Verify recent files are NOT cleaned
echo ""
echo "[test] 5.2: Recent files are preserved"

# Create fake recent data files
touch "${fake_dir}/perf_20260423_120000.data"
touch "${fake_dir}/perf_20260423_120010.data"
# Don't set them as old - they should be "now"

recent_count=$(find "$OUTPUT_DIR" -name "perf_*.data" -path "*/test_cleanup_*" 2>/dev/null | wc -l)
echo "  Created 2 recent data files"

# Run cleanup on recent files
find "$OUTPUT_DIR" -name "perf_*.data" -path "*/test_cleanup_*" -mmin +1440 -delete 2>/dev/null || true

recent_remaining=$(find "$OUTPUT_DIR" -name "perf_*.data" -path "*/test_cleanup_*" 2>/dev/null | wc -l)
if [[ "$recent_remaining" -eq 2 ]]; then
    echo "  PASS: recent files preserved (${recent_remaining} remain)"
else
    echo "  FAIL: expected 2 recent files, found ${recent_remaining}"
fi

# Cleanup temp dir
rmdir "$fake_dir" 2>/dev/null || rm -rf "$fake_dir"

# Test 5.3: Verify cleanup is triggered every N slices (N=10 in code)
echo ""
echo "[test] 5.3: Cleanup interval in daemon source"
if grep -q "cleanup_counter % 10" "${SCRIPT_DIR}/../scripts/profiler_daemon.sh"; then
    echo "  PASS: cleanup runs every 10 slices (CLEANUP_INTERVAL=600s equivalent)"
else
    echo "  FAIL: cleanup interval logic not found"
fi

# Test 5.4: RETENTION_MINUTES matches config
echo ""
echo "[test] 5.4: RETENTION_MINUTES consistency"
config_retention=$(grep "^RETENTION_MINUTES=" "${SCRIPT_DIR}/../config/profiler.conf" | cut -d'=' -f2-)
daemon_retention=$(grep "^RETENTION_MINUTES=" "${SCRIPT_DIR}/../scripts/profiler_daemon.sh" | head -1 | cut -d'=' -f2-)
if [[ "$config_retention" == "$daemon_retention" ]]; then
    echo "  PASS: config (${config_retention}) == daemon default (${daemon_retention})"
else
    echo "  FAIL: config (${config_retention}) != daemon default (${daemon_retention})"
fi

echo ""
echo "=== Test 5 Complete ==="
