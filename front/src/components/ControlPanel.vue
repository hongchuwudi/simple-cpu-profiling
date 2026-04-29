<template>
  <div class="control-panel">
    <h3>控制面板</h3>

    <!-- 火焰图生成 -->
    <div class="section">
      <h4>火焰图生成</h4>
      <div class="row">
        <input
          v-model="generateTime"
          type="text"
          placeholder="可选  HH:MM"
          class="time-input"
        />
        <button
          class="btn btn-generate"
          :disabled="generating"
          @click="handleGenerate"
        >
          {{ generating ? '生成中...' : '生成火焰图' }}
        </button>
      </div>
      <p v-if="generateMsg" :class="generateOk ? 'msg-ok' : 'msg-err'">
        {{ generateMsg }}
      </p>
    </div>

    <!-- Profiler 守护进程控制 -->
    <div class="section">
      <h4>Profiler 守护进程</h4>
      <div class="status-line">
        <span class="status-dot" :class="daemonRunning ? 'on' : 'off'" />
        <span class="status-text">{{ daemonRunning ? '运行中' : '已停止' }}</span>
      </div>
      <div class="row">
        <button
          class="btn btn-start"
          :disabled="daemonBusy"
          @click="handleStart"
        >
          {{ daemonBusy ? '操作中...' : '启动' }}
        </button>
        <button
          class="btn btn-stop"
          :disabled="daemonBusy"
          @click="handleStop"
        >
          {{ daemonBusy ? '操作中...' : '停止' }}
        </button>
        <button class="btn btn-refresh" @click="refreshStatus">刷新</button>
      </div>
      <p v-if="daemonMsg" :class="daemonOk ? 'msg-ok' : 'msg-err'">
        {{ daemonMsg }}
      </p>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { generateFlamegraph, getDaemonStatus, startDaemon, stopDaemon } from '../api/files.js'

const emit = defineEmits(['regenerated'])

// ── 火焰图生成 ──────────────────────────
const generateTime = ref('')
const generating = ref(false)
const generateMsg = ref('')
const generateOk = ref(true)

async function handleGenerate() {
  generating.value = true
  generateMsg.value = ''
  try {
    const result = await generateFlamegraph(generateTime.value || undefined)
    generateMsg.value = result.output || '生成成功'
    generateOk.value = true
    generateTime.value = ''
    emit('regenerated')
  } catch (e) {
    generateMsg.value = e.message
    generateOk.value = false
  } finally {
    generating.value = false
  }
}

// ── 守护进程控制 ──────────────────────────
const daemonRunning = ref(false)
const daemonBusy = ref(false)
const daemonMsg = ref('')
const daemonOk = ref(true)

async function refreshStatus() {
  try {
    const status = await getDaemonStatus()
    daemonRunning.value = status.running
  } catch { /* ignore */ }
}

async function handleStart() {
  daemonBusy.value = true
  daemonMsg.value = ''
  try {
    const result = await startDaemon()
    daemonMsg.value = result.output || '已启动'
    daemonOk.value = true
    daemonRunning.value = true
  } catch (e) {
    daemonMsg.value = e.message
    daemonOk.value = false
  } finally {
    daemonBusy.value = false
  }
}

async function handleStop() {
  daemonBusy.value = true
  daemonMsg.value = ''
  try {
    const result = await stopDaemon()
    daemonMsg.value = result.output || '已停止'
    daemonOk.value = true
    daemonRunning.value = false
  } catch (e) {
    daemonMsg.value = e.message
    daemonOk.value = false
  } finally {
    daemonBusy.value = false
  }
}

onMounted(refreshStatus)
</script>

<style scoped>
.control-panel {
  padding: 12px;
  border-bottom: 1px solid #ddd;
}

.control-panel h3 {
  font-size: 14px;
  color: #333;
  margin-bottom: 10px;
}

.section {
  margin-bottom: 14px;
}

.section h4 {
  font-size: 12px;
  color: #666;
  margin-bottom: 6px;
}

.row {
  display: flex;
  gap: 6px;
  align-items: center;
}

.time-input {
  flex: 1;
  padding: 5px 8px;
  border: 1px solid #ccc;
  border-radius: 4px;
  font-size: 13px;
}

.btn {
  padding: 5px 10px;
  border: none;
  border-radius: 4px;
  font-size: 13px;
  cursor: pointer;
  white-space: nowrap;
}

.btn:disabled {
  opacity: 0.5;
  cursor: not-allowed;
}

.btn-generate {
  background: #3498db;
  color: white;
}
.btn-generate:hover:not(:disabled) {
  background: #2980b9;
}

.btn-start {
  background: #27ae60;
  color: white;
}
.btn-start:hover:not(:disabled) {
  background: #219a52;
}

.btn-stop {
  background: #e74c3c;
  color: white;
}
.btn-stop:hover:not(:disabled) {
  background: #c0392b;
}

.btn-refresh {
  background: #95a5a6;
  color: white;
}
.btn-refresh:hover:not(:disabled) {
  background: #7f8c8d;
}

.status-line {
  display: flex;
  align-items: center;
  gap: 6px;
  margin-bottom: 6px;
}

.status-dot {
  width: 10px;
  height: 10px;
  border-radius: 50%;
}

.status-dot.on {
  background: #27ae60;
  box-shadow: 0 0 4px #27ae60;
}

.status-dot.off {
  background: #e74c3c;
}

.status-text {
  font-size: 13px;
  color: #333;
}

.msg-ok {
  font-size: 12px;
  color: #27ae60;
  margin-top: 4px;
}

.msg-err {
  font-size: 12px;
  color: #e74c3c;
  margin-top: 4px;
}
</style>
