/**
 * API 调用封装模块
 *
 * 开发模式下，Vite 已将 /api 请求代理到 Python 后端 (5174 端口)。
 * 生产模式下，nginx 也将 /api 代理到后端服务。
 */

const BASE_URL = '/api'

/**
 * 获取所有 SVG 火焰图文件列表
 * @returns {Promise<Array<{name: string, size: number, modified: string}>>}
 */
export async function fetchFiles() {
  const res = await fetch(`${BASE_URL}/files`)
  if (!res.ok) throw new Error(`获取文件列表失败: ${res.status}`)
  return res.json()
}

/**
 * 获取指定 SVG 文件的内容
 * @param {string} filename - 文件名
 * @returns {Promise<string>} SVG 文本内容
 */
export async function fetchFileContent(filename) {
  const res = await fetch(`${BASE_URL}/files/${encodeURIComponent(filename)}`)
  if (!res.ok) throw new Error(`获取文件内容失败: ${res.status}`)
  return res.text()
}

/**
 * 生成火焰图
 * @param {string} [time] - 可选，时间参数 HH:MM 或 HH:MM:SS
 * @returns {Promise<{success: boolean, output: string}>}
 */
export async function generateFlamegraph(time) {
  const url = time ? `${BASE_URL}/generate?time=${encodeURIComponent(time)}` : `${BASE_URL}/generate`
  const res = await fetch(url, { method: 'POST' })
  if (!res.ok) {
    const data = await res.json().catch(() => ({}))
    throw new Error(data.error || `生成失败: ${res.status}`)
  }
  return res.json()
}

/**
 * 获取 profiler daemon 状态
 * @returns {Promise<{running: boolean, output: string}>}
 */
export async function getDaemonStatus() {
  const res = await fetch(`${BASE_URL}/daemon/status`)
  if (!res.ok) throw new Error(`获取状态失败: ${res.status}`)
  return res.json()
}

/**
 * 启动 profiler daemon
 * @returns {Promise<{success: boolean, output: string}>}
 */
export async function startDaemon() {
  const res = await fetch(`${BASE_URL}/daemon/start`, { method: 'POST' })
  if (!res.ok) {
    const data = await res.json().catch(() => ({}))
    throw new Error(data.error || `启动失败: ${res.status}`)
  }
  return res.json()
}

/**
 * 停止 profiler daemon
 * @returns {Promise<{success: boolean, output: string}>}
 */
export async function stopDaemon() {
  const res = await fetch(`${BASE_URL}/daemon/stop`, { method: 'POST' })
  if (!res.ok) {
    const data = await res.json().catch(() => ({}))
    throw new Error(data.error || `停止失败: ${res.status}`)
  }
  return res.json()
}
