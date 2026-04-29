---
name: cpu-profiling
description: Use this skill whenever the user wants to do anything with the continuous CPU profiling system. This includes starting/stopping/checking the profiler daemon, generating flamegraphs from perf data, modifying profiling parameters, troubleshooting perf issues, and understanding profiling results. Triggers include: mentions of "profiler", "CPU profiling", "flamegraph", "perf record", "start profiler", "stop profiler", "profiler status", "generate flamegraph", or any question about the profiling system at /home/hongchu/code/simple-cpu-profiling.
---

## Overview

A 7x24 continuous CPU profiling system at `/home/hongchu/code/simple-cpu-profiling` based on Linux `perf`. The daemon records system-wide call-chain samples in fixed 10-second slices (~1.4 MB each, ~6 slices/min) and auto-cleans data older than 24 hours. Flamegraphs can be generated from any recorded time slice. A Vue 3 Web Viewer (Python backend + frontend) provides file browsing, SVG zoom/pan, and function search highlighting.

## Project Structure

```
simple-cpu-profiling/
├── config/
│   ├── profiler.conf              # Shared configuration
│   └── profiler.service           # systemd unit file
├── scripts/
│   ├── profiler_daemon.sh         # Daemon: {start|stop|status}
│   └── generate_flamegraph.sh     # Flamegraph generator [HH:MM | HH:MM:SS]
├── backend/
│   ├── server.py                  # Python HTTP API (zero deps, port 5174)
│   └── run.sh                     # Start backend script
├── front/
│   ├── src/
│   │   ├── App.vue                # Root component
│   │   ├── main.js                # Entry point
│   │   ├── api/files.js           # API client
│   │   └── components/
│   │       ├── FileList.vue       # Left sidebar file list
│   │       ├── FlameGraphViewer.vue # SVG viewer (zoom/pan/search)
│   │       └── SearchBar.vue      # Search bar (debounced)
│   ├── dist/                      # Build output
│   ├── package.json
│   └── vite.config.js             # Vite config (with /api proxy)
├── log/profiler/
│   ├── perf_*.data                # Raw perf data slices (YYYYMMDD_HHMMSS)
│   ├── flamegraph_*.svg           # Generated flamegraphs
│   └── profiler.log               # Daemon log
├── run/profiler.pid               # Daemon PID
```

## Commands

### Check daemon status

```bash
./scripts/profiler_daemon.sh status
```

### Start / Stop / Restart

```bash
./scripts/profiler_daemon.sh start
./scripts/profiler_daemon.sh stop
# restart = stop then start
```

### Generate flamegraph from latest slice

```bash
./scripts/generate_flamegraph.sh
```

Output: `log/profiler/flamegraph_HH-MM.svg` (time derived from filename).

### Generate flamegraph from specific time

```bash
./scripts/generate_flamegraph.sh 14:30      # HH:MM
./scripts/generate_flamegraph.sh 14:30:25   # HH:MM:SS
```

Finds the nearest `.data` file to the requested time and generates `flamegraph_HH-MM.svg` (or `flamegraph_HH-MM-SS.svg`).

### Change configuration

Edit `config/profiler.conf`:

```bash
SAMPLE_FREQ=99              # Hz sampling frequency
SLICE_INTERVAL=10           # seconds per slice
OUTPUT_DIR=...              # data output directory
RETENTION_MINUTES=1440      # 24-hour retention
CLEANUP_INTERVAL=600        # cleanup check interval
```

Apply changes: restart the daemon (`stop` then `start`).

### Web Viewer

```bash
# Start backend API server (127.0.0.1:5174)
bash backend/run.sh

# Start frontend dev server (5173, proxies /api → backend)
cd front && npm run dev

# Build production static files
cd front && npm run build
# Output in front/dist/
```

**API endpoints** (backend/server.py):
- `GET /api/files` → list of flamegraph SVG files (JSON: name, size, modified)
- `GET /api/files/:name` → SVG file content

**Frontend features**: file list (sorted by time), SVG zoom/pan via mouse, function search with text highlighting.

## Architecture

**profiler_daemon.sh** — infinite loop:

```
perf record -a -g -F 99 -o perf_YYYYMMDD_HHMMSS.data -- sleep 10
    → cleanup every 10 slices (delete .data older than 24h)
```

**generate_flamegraph.sh** — pipeline:

```
perf script -i <data> | stackcollapse-perf.pl | flamegraph.pl > flamegraph.svg
```

**Web Viewer** — backend + frontend:

```
backend/server.py (Python http.server, port 5174)
  GET /api/files        → JSON list of flamegraph_*.svg
  GET /api/files/:name  → SVG content
  Path traversal protection (rejects ../  and /)

front (Vue 3 + Vite, port 5173)
  FileList          → fetch /api/files, display sorted list
  FlameGraphViewer  → fetch /api/files/:name, render SVG with zoom/pan
  SearchBar         → debounce 300ms, highlight matching SVG text elements
```

## Troubleshooting

### "perf is not installed"

```bash
sudo apt install linux-tools-generic  # Debian/Ubuntu
sudo yum install kernel-tools         # RHEL/CentOS
```

### "perf_event_paranoid >= 2"

```bash
sudo sysctl -w kernel.perf_event_paranoid=1
```

### "FlameGraph toolkit not found"

```bash
git clone https://github.com/brendangregg/FlameGraph.git /opt/FlameGraph
```

### Stale PID file (daemon shows running but isn't)

```bash
rm run/profiler.pid
./scripts/profiler_daemon.sh start
```

### No data files found

Wait ~20 seconds for at least one slice to complete, or check the daemon log:

```bash
tail -20 log/profiler/profiler.log
```

### Web Viewer shows "获取文件列表失败"

Ensure the backend server is running:

```bash
bash backend/run.sh
# Should print: FlameGraph API server running at http://127.0.0.1:5174
```

Also verify SVG files exist:

```bash
ls log/profiler/flamegraph_*.svg
```

### Flamegraph filename contains colons

All SVG filenames use hyphens (e.g. `flamegraph_23-09-14.svg`). When specifying times as arguments, the script handles colon-to-hyphen conversion automatically.

## Key parameters

| Parameter | Default | Notes |
|---|---|---|
| `SAMPLE_FREQ` | 99 Hz | Prime number to avoid aliasing with 100 Hz timer interrupts |
| `SLICE_INTERVAL` | 10 s | Each slice ~1.4 MB |
| `RETENTION_MINUTES` | 1440 | 24 hours; prevents ~120 GB/day disk usage |
| `--no-buildid` | used | Reduces per-slice overhead; not needed for hot-path identification |
