#!/usr/bin/env bash
#
# start.sh — 一键启动火焰图系统（后端 API + 前端 dev 服务器）
#
# 用法: bash start.sh
# 按 Ctrl+C 停止所有服务
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# 确保前端依赖已安装
if [[ ! -d "${SCRIPT_DIR}/front/node_modules" ]]; then
  echo "Installing frontend dependencies..."
  cd "${SCRIPT_DIR}/front" && npm install
fi

cleanup() {
  echo ""
  echo "Stopping services..."
  [[ -n "${BACKEND_PID:-}" ]] && kill "$BACKEND_PID" 2>/dev/null || true
  [[ -n "${FRONTEND_PID:-}" ]] && kill "$FRONTEND_PID" 2>/dev/null || true
  wait 2>/dev/null || true
  echo "All services stopped."
  exit 0
}
trap cleanup INT TERM

echo "=== CPU FlameGraph Profiler ==="

# 启动后端
echo "[1/2] Starting backend API server on :5174 ..."
python3 "${SCRIPT_DIR}/backend/server.py" &
BACKEND_PID=$!

# 等待后端就绪
sleep 1
if ! kill -0 "$BACKEND_PID" 2>/dev/null; then
  echo "ERROR: Backend failed to start."
  exit 1
fi

# 启动前端
echo "[2/2] Starting frontend dev server on :5173 ..."
cd "${SCRIPT_DIR}/front"
npm run dev &
FRONTEND_PID=$!

echo ""
echo "Done! Services running:"
echo "  Frontend: http://localhost:5173"
echo "  Backend:  http://127.0.0.1:5174"
echo "  Press Ctrl+C to stop."
echo ""

# 等待任意子进程退出
wait
