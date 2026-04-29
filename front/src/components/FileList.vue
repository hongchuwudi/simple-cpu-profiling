<template>
  <div class="file-list">
    <h3>火焰图列表</h3>

    <!-- 加载状态 -->
    <p v-if="loading" class="status">加载中...</p>

    <!-- 错误状态 -->
    <p v-else-if="error" class="error">{{ error }}</p>

    <!-- 空列表 -->
    <p v-else-if="files.length === 0" class="status">暂无火焰图文件</p>

    <!-- 文件列表 -->
    <ul v-else>
      <li
        v-for="file in files"
        :key="file.name"
        :class="{ active: file.name === selected }"
        @click="$emit('select', file.name)"
      >
        <!-- 文件名（去除 flamegraph_ 前缀和 .svg 后缀） -->
        <span class="file-name">{{ formatLabel(file.name) }}</span>
      </li>
    </ul>

    <!-- 手动刷新按钮 -->
    <button class="refresh-btn" @click="loadFiles">刷新</button>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue'
import { fetchFiles } from '../api/files.js'

// 选中的文件名（由父组件通过 props 传入）
const props = defineProps({
  selected: { type: String, default: '' },
})

// 触发事件：通知父组件选中了某个文件
defineEmits(['select'])

const files = ref([])
const loading = ref(false)
const error = ref('')

/** 从后端加载文件列表 */
async function loadFiles() {
  loading.value = true
  error.value = ''
  try {
    files.value = await fetchFiles()
  } catch (e) {
    error.value = e.message
  } finally {
    loading.value = false
  }
}

/**
 * 格式化文件名为更友好的显示名称
 * flamegraph_20260429_19-08-54.svg → 2026-04-29 19:08:54
 */
function formatLabel(name) {
  return name
    .replace(/^flamegraph_/, '')
    .replace(/\.svg$/, '')
    .replace(/(\d{4})(\d{2})(\d{2})_(\d{2})-(\d{2})-(\d{2})/, '$1-$2-$3 $4:$5:$6')
}

onMounted(loadFiles)

/** 暴露 refresh 方法供父组件调用 */
defineExpose({ refresh: loadFiles })
</script>

<style scoped>
.file-list {
  flex: 1;
  overflow-y: auto;
  padding: 12px;
}

.file-list h3 {
  margin: 0 0 12px;
  font-size: 14px;
  color: #333;
}

.file-list ul {
  list-style: none;
  padding: 0;
  margin: 0;
}

.file-list li {
  padding: 8px 10px;
  cursor: pointer;
  border-radius: 4px;
  margin-bottom: 2px;
  font-size: 13px;
}

.file-list li:hover {
  background: #e0e0e0;
}

.file-list li.active {
  background: #3498db;
  color: white;
}

.status {
  color: #666;
  font-size: 13px;
}

.error {
  color: #e74c3c;
  font-size: 13px;
}

.refresh-btn {
  margin-top: 12px;
  width: 100%;
  padding: 6px;
  border: 1px solid #ccc;
  background: white;
  border-radius: 4px;
  cursor: pointer;
  font-size: 13px;
}

.refresh-btn:hover {
  background: #eee;
}
</style>
