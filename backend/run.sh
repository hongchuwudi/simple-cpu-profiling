#!/usr/bin/env bash
#
# run.sh — 启动火焰图后端 API 服务
#
# 用法: bash run.sh
# 按 Ctrl+C 停止服务
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Starting FlameGraph backend API server..."
exec python3 "${SCRIPT_DIR}/server.py"
