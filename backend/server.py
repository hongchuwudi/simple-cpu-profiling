#!/usr/bin/env python3
"""
火焰图后端 API 服务

功能：
- GET /api/files          → 返回 log/profiler/ 目录下的 SVG 文件列表 (JSON)
- GET /api/files/:name    → 返回指定 SVG 文件的内容

使用 Python 标准库实现，零外部依赖。
默认监听 0.0.0.0:10101。
"""

import os
import json
import subprocess
import datetime
from http.server import HTTPServer, BaseHTTPRequestHandler

# 火焰图 SVG 文件存放目录
# server.py 位于 backend/，向上一级到项目根目录
PROJECT_ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PROFILER_DIR = os.path.join(PROJECT_ROOT, 'log', 'profiler')
SCRIPTS_DIR = os.path.join(PROJECT_ROOT, 'scripts')
DAEMON_SCRIPT = os.path.join(SCRIPTS_DIR, 'profiler_daemon.sh')
GENERATE_SCRIPT = os.path.join(SCRIPTS_DIR, 'generate_flamegraph.sh')

PORT = 10101


class FlameGraphHandler(BaseHTTPRequestHandler):
    """处理 HTTP 请求的处理器"""

    def do_GET(self):
        """
        处理 GET 请求，根据路径路由到不同处理逻辑：
        - /api/files          → 返回 SVG 文件列表
        - /api/files/:name    → 返回指定 SVG 文件内容
        - /api/daemon/status  → 返回 profiler daemon 状态
        """
        path = self.path.rstrip('/')

        if path == '/api/files':
            self._handle_file_list()
        elif path.startswith('/api/files/'):
            self._handle_file_content(path)
        elif path == '/api/daemon/status':
            self._handle_daemon_status()
        else:
            self._send_error(404, 'Not Found')

    def do_POST(self):
        """
        处理 POST 请求：
        - /api/generate       → 生成火焰图 (可选 ?time=HH:MM)
        - /api/daemon/start   → 启动 profiler daemon
        - /api/daemon/stop    → 停止 profiler daemon
        """
        path = self.path.rstrip('/')

        if path == '/api/generate':
            self._handle_generate()
        elif path == '/api/daemon/start':
            self._handle_daemon_start()
        elif path == '/api/daemon/stop':
            self._handle_daemon_stop()
        else:
            self._send_error(404, 'Not Found')

    def _handle_file_list(self):
        """
        扫描 PROFILER_DIR 目录，返回所有 flamegraph_*.svg 文件的信息列表
        按文件修改时间倒序排列（最新的在前）
        """
        try:
            entries = []
            if not os.path.isdir(PROFILER_DIR):
                self._send_json([])
                return

            for name in os.listdir(PROFILER_DIR):
                if name.startswith('flamegraph_') and name.endswith('.svg'):
                    full_path = os.path.join(PROFILER_DIR, name)
                    stat = os.stat(full_path)
                    entries.append({
                        'name': name,
                        'size': stat.st_size,
                        'modified': datetime.datetime.fromtimestamp(
                            stat.st_mtime
                        ).strftime('%Y-%m-%d %H:%M:%S'),
                    })

            # 按修改时间倒序排列
            entries.sort(key=lambda x: x['modified'], reverse=True)
            self._send_json(entries)

        except Exception as e:
            self._send_error(500, str(e))

    def _handle_file_content(self, path):
        """
        提取文件名，读取并返回 SVG 文件内容
        路径格式：/api/files/flamegraph_xxx.svg
        """
        # 从路径中提取文件名（去掉 /api/files/ 前缀）
        filename = path[len('/api/files/'):]

        # 安全检查：防止路径遍历攻击（不允许 ../ 等）
        if '..' in filename or '/' in filename:
            self._send_error(403, 'Forbidden')
            return

        filepath = os.path.join(PROFILER_DIR, filename)

        if not os.path.isfile(filepath):
            self._send_error(404, 'File not found')
            return

        try:
            with open(filepath, 'r', encoding='utf-8') as f:
                content = f.read()

            self.send_response(200)
            self.send_header('Content-Type', 'image/svg+xml; charset=utf-8')
            self.send_header('Content-Length', str(len(content)))
            self.end_headers()
            self.wfile.write(content.encode('utf-8'))

        except Exception as e:
            self._send_error(500, str(e))

    def _send_json(self, data):
        """辅助方法：将数据以 JSON 格式返回"""
        body = json.dumps(data, ensure_ascii=False).encode('utf-8')
        self.send_response(200)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _send_error(self, code, message):
        """辅助方法：返回错误响应"""
        self.send_response(code)
        self.send_header('Content-Type', 'application/json; charset=utf-8')
        body = json.dumps({'error': message}).encode('utf-8')
        self.send_header('Content-Length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    # ── Flamegraph generation ─────────────────────────────────────────────
    def _handle_generate(self):
        """调用 generate_flamegraph.sh 生成火焰图"""
        import urllib.parse
        parsed = urllib.parse.urlparse(self.path)
        params = urllib.parse.parse_qs(parsed.query)
        time_param = params.get('time', [None])[0]

        try:
            cmd = [GENERATE_SCRIPT]
            if time_param:
                cmd.append(time_param)
            result = subprocess.run(
                cmd, capture_output=True, text=True, timeout=120
            )
            if result.returncode == 0:
                self._send_json({'success': True, 'output': result.stdout.strip()})
            else:
                self._send_error(500, result.stderr.strip())
        except subprocess.TimeoutExpired:
            self._send_error(500, 'Flamegraph generation timed out (120s)')
        except Exception as e:
            self._send_error(500, str(e))

    # ── Daemon control ────────────────────────────────────────────────────
    def _handle_daemon_status(self):
        """查询 profiler daemon 状态"""
        try:
            result = subprocess.run(
                [DAEMON_SCRIPT, 'status'], capture_output=True, text=True, timeout=5
            )
            output = result.stdout.strip()
            running = 'is running' in output
            self._send_json({
                'running': running,
                'output': output,
            })
        except Exception as e:
            self._send_error(500, str(e))

    def _handle_daemon_start(self):
        """启动 profiler daemon (非阻塞)"""
        try:
            subprocess.Popen(
                [DAEMON_SCRIPT, 'start'],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.PIPE,
                start_new_session=True,
            )
            self._send_json({'success': True, 'output': 'profiler daemon starting...'})
        except Exception as e:
            self._send_error(500, str(e))

    def _handle_daemon_stop(self):
        """停止 profiler daemon"""
        try:
            result = subprocess.run(
                [DAEMON_SCRIPT, 'stop'], capture_output=True, text=True, timeout=10
            )
            if result.returncode == 0:
                self._send_json({'success': True, 'output': result.stdout.strip()})
            else:
                self._send_error(500, result.stderr.strip())
        except Exception as e:
            self._send_error(500, str(e))

    def log_message(self, format, *args):
        """重写日志方法，打印到控制台"""
        print(f"[{self.log_date_time_string()}] {format % args}")


def main():
    """启动 HTTP 服务器"""
    server = HTTPServer(('0.0.0.0', PORT), FlameGraphHandler)
    print(f"FlameGraph API server running at http://0.0.0.0:{PORT}")
    print(f"Serving files from: {PROFILER_DIR}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down...")
        server.server_close()


if __name__ == '__main__':
    main()
