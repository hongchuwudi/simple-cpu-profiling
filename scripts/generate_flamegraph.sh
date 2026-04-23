#!/usr/bin/env bash
#
# generate_flamegraph.sh — Generate a CPU flamegraph from the nearest perf slice
#
# Usage: generate_flamegraph.sh [HH:MM | HH:MM:SS]
#        If no time is given, uses the most recent completed data slice.
#
# Author: hongchuwudi
# Date:   2026-04-23

set -euo pipefail

# ── Hard-coded defaults ──────────────────────────────────────────────────────
OUTPUT_DIR="/home/hongchu/code/simple-cpu-profiling/log/profiler"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONF_FILE="${SCRIPT_DIR}/../config/profiler.conf"

# ── Configuration ─────────────────────────────────────────────────────────────
load_config() {
    if [[ -f "$CONF_FILE" ]]; then
        # shellcheck source=/dev/null
        source "$CONF_FILE"
    fi
}

# ── Find newest completed .data file ─────────────────────────────────────────
find_newest_completed() {
    local slice_interval="${1:-10}"

    local candidates=()
    while IFS= read -r -d '' f; do
        candidates+=("$f")
    done < <(find "${OUTPUT_DIR}" -name "perf_*.data" -printf '%T@ %p\0' 2>/dev/null | sort -zrn | sed -z 's/^[^ ]* //')

    if [[ ${#candidates[@]} -eq 0 ]]; then
        echo "ERROR: no perf_*.data files found in ${OUTPUT_DIR}" >&2
        exit 1
    fi

    local now
    now="$(date +%s)"
    for f in "${candidates[@]}"; do
        local mtime
        mtime="$(stat -c %Y "$f")"
        if (( now - mtime >= slice_interval )); then
            echo "$f"
            return
        fi
    done

    # All files still being recorded — return the second-newest if available
    if [[ ${#candidates[@]} -ge 2 ]]; then
        echo "${candidates[1]}"
    else
        echo "${candidates[0]}"
    fi
}

# ── Find nearest .data file ──────────────────────────────────────────────────
find_data_file() {
    local target_epoch="$1"

    local candidates=()
    while IFS= read -r -d '' f; do
        candidates+=("$f")
    done < <(find "${OUTPUT_DIR}" -name "perf_*.data" -printf '%T@ %p\0' 2>/dev/null | sort -zn | sed -z 's/^[^ ]* //')

    if [[ ${#candidates[@]} -eq 0 ]]; then
        echo "ERROR: no perf_*.data files found in ${OUTPUT_DIR}" >&2
        exit 1
    fi

    local best=""
    local best_diff=""
    for f in "${candidates[@]}"; do
        local ts
        ts="$(stat -c %Y "$f")"
        local diff=$(( target_epoch > ts ? target_epoch - ts : ts - target_epoch ))
        if [[ -z "$best_diff" ]] || [[ $diff -lt $best_diff ]]; then
            best_diff=$diff
            best="$f"
        fi
    done

    echo "$best"
}

# ── Generate flamegraph ──────────────────────────────────────────────────────
generate_flamegraph() {
    local data_file="$1"
    local time_label="$2"

    # Sanitize time_label: colons are invalid/unsafe in filenames on some systems
    time_label="${time_label//:/-}"

    local svg_file="flamegraph_${time_label}.svg"
    local output_path="${OUTPUT_DIR}/${svg_file}"

    local flamegraph_dir="/opt/FlameGraph"
    if [[ ! -d "$flamegraph_dir" ]]; then
        echo "ERROR: FlameGraph toolkit not found at ${flamegraph_dir}" >&2
        echo "Install it with:" >&2
        echo "  git clone https://github.com/brendangregg/FlameGraph.git ${flamegraph_dir}" >&2
        exit 1
    fi

    echo "Generating flamegraph from: $(basename "$data_file")"
    echo "  slice time : ${time_label}"
    echo "  output     : ${output_path}"

    perf script -i "$data_file" \
        | "${flamegraph_dir}/stackcollapse-perf.pl" \
        | "${flamegraph_dir}/flamegraph.pl" \
        > "$output_path"

    echo "Done: ${output_path}"
}

# ── Main ──────────────────────────────────────────────────────────────────────
load_config

# Parse target time
time_input="${1:-}"
if [[ -n "$time_input" ]]; then
    # Try to parse HH:MM or HH:MM:SS against today
    target_epoch="$(date -d "today ${time_input}" +%s 2>/dev/null)" || {
        echo "ERROR: cannot parse time '${time_input}', use HH:MM or HH:MM:SS" >&2
        exit 1
    }
else
    # No argument: use the most recent completed data file
    data_file="$(find_newest_completed "${SLICE_INTERVAL:-10}")"
    if [[ -z "$data_file" ]]; then
        echo "ERROR: no completed .data file found" >&2
        exit 1
    fi

    # Extract the time label from filename (e.g. perf_20260423_230841.data → 23:08:41)
    base="$(basename "$data_file" .data)"
    ts_part="${base##*_}"
    time_label="$(echo "$ts_part" | sed 's/\(..\)\(..\)/\1-\2/;s/\(..\)$/-\1/')"

    generate_flamegraph "$data_file" "$time_label"
    exit 0
fi

# Validate output directory
if [[ ! -d "$OUTPUT_DIR" ]]; then
    echo "ERROR: output directory does not exist: ${OUTPUT_DIR}" >&2
    exit 1
fi

# Find the nearest data file
data_file="$(find_data_file "$target_epoch")"
if [[ -z "$data_file" ]]; then
    echo "ERROR: no suitable .data file found near ${time_input}" >&2
    exit 1
fi

# Sanitize time label for filename
time_label="$(echo "$time_input" | tr ':' '-')"

generate_flamegraph "$data_file" "$time_label"
