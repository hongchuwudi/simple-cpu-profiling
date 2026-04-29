<template>
  <div class="flamegraph-viewer" ref="viewerRef">
    <!-- 加载状态 -->
    <div v-if="loading" class="center-msg">加载中...</div>

    <!-- 错误状态 -->
    <div v-else-if="error" class="center-msg error">{{ error }}</div>

    <!-- 未选择文件提示 -->
    <div v-else-if="!filename" class="center-msg">
      请从左侧列表选择一个火焰图
    </div>

    <!-- SVG 展示区域 -->
    <div
      v-else
      class="svg-container"
      :style="{ transform: `scale(${scale}) translate(${panX}px, ${panY}px)` }"
      @mousedown="startPan"
      @wheel.prevent="handleWheel"
    >
      <!-- 通过 v-html 内联渲染 SVG -->
      <div v-html="svgContent" ref="svgRef" class="svg-content"></div>
    </div>
  </div>
</template>

<script setup>
import { ref, watch, nextTick } from 'vue'
import { fetchFileContent } from '../api/files.js'

const props = defineProps({
  filename: { type: String, default: '' },
  searchQuery: { type: String, default: '' },
})

const svgContent = ref('')
const loading = ref(false)
const error = ref('')

// 缩放和平移状态
const scale = ref(1)
const panX = ref(0)
const panY = ref(0)

// DOM 引用
const viewerRef = ref(null)
const svgRef = ref(null)

// 拖拽状态
let isPanning = false
let startX = 0
let startY = 0

/**
 * 加载 SVG 文件内容
 */
async function loadSvg() {
  if (!props.filename) {
    svgContent.value = ''
    return
  }

  loading.value = true
  error.value = ''
  scale.value = 1
  panX.value = 0
  panY.value = 0

  try {
    svgContent.value = await fetchFileContent(props.filename)
    // SVG 加载后，等待 DOM 更新再应用搜索高亮
    await nextTick()
    applySearchHighlight()
  } catch (e) {
    error.value = e.message
  } finally {
    loading.value = false
  }
}

/**
 * 根据搜索关键词高亮 SVG 中的文本
 * 遍历 SVG 中的所有 text 元素，匹配关键词并改变样式
 */
function applySearchHighlight() {
  if (!props.searchQuery || !svgRef.value) return

  const textElements = svgRef.value.querySelectorAll('text')
  textElements.forEach((el) => {
    const text = el.textContent || ''
    if (text.toLowerCase().includes(props.searchQuery.toLowerCase())) {
      el.setAttribute('fill', '#ff0')
      el.setAttribute('font-weight', 'bold')
    }
  })
}

// 监听文件名变化，自动重新加载
watch(() => props.filename, loadSvg, { immediate: true })

// 监听搜索关键词变化，重新应用高亮
watch(() => props.searchQuery, () => {
  applySearchHighlight()
})

/**
 * 鼠标滚轮缩放
 */
function handleWheel(e) {
  const delta = e.deltaY > 0 ? 0.9 : 1.1
  scale.value = Math.max(0.2, Math.min(10, scale.value * delta))
}

/**
 * 开始拖拽平移
 */
function startPan(e) {
  // 仅鼠标左键触发拖拽
  if (e.button !== 0) return
  isPanning = true
  startX = e.clientX - panX.value
  startY = e.clientY - panY.value

  const onMove = (ev) => {
    if (!isPanning) return
    panX.value = ev.clientX - startX
    panY.value = ev.clientY - startY
  }

  const onUp = () => {
    isPanning = false
    document.removeEventListener('mousemove', onMove)
    document.removeEventListener('mouseup', onUp)
  }

  document.addEventListener('mousemove', onMove)
  document.addEventListener('mouseup', onUp)
}
</script>

<style scoped>
.flamegraph-viewer {
  flex: 1;
  position: relative;
  overflow: hidden;
  background: #1e1e1e;
}

.center-msg {
  display: flex;
  align-items: center;
  justify-content: center;
  height: 100%;
  color: #999;
  font-size: 16px;
}

.center-msg.error {
  color: #e74c3c;
}

/* SVG 容器：支持缩放和平移 */
.svg-container {
  width: 100%;
  height: 100%;
  display: flex;
  align-items: flex-start;
  justify-content: flex-start;
  padding: 20px;
  cursor: grab;
  transition: transform 0.1s ease-out;
}

.svg-container:active {
  cursor: grabbing;
}

/* 内联 SVG 样式 */
.svg-content :deep(svg) {
  max-width: 100%;
  height: auto;
}
</style>
