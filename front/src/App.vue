<template>
  <div class="app">
    <!-- 顶部标题栏 -->
    <header class="header">
      <h1>CPU Flame Graph Viewer</h1>
    </header>

    <!-- 主体区域：左侧文件列表 + 右侧内容 -->
    <div class="body">
      <!-- 左侧：控制面板 + 文件列表 -->
      <div class="sidebar">
        <ControlPanel @regenerated="onRegenerated" />
        <FileList
          ref="fileListRef"
          :selected="selectedFile"
          @select="onFileSelect"
        />
      </div>

      <!-- 右侧：搜索栏 + 火焰图展示 -->
      <div class="main">
        <div class="toolbar">
          <SearchBar @search="onSearch" />
        </div>
        <FlameGraphViewer
          :filename="selectedFile"
          :search-query="searchQuery"
        />
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref } from 'vue'
import FileList from './components/FileList.vue'
import FlameGraphViewer from './components/FlameGraphViewer.vue'
import SearchBar from './components/SearchBar.vue'
import ControlPanel from './components/ControlPanel.vue'

// 当前选中的文件名
const selectedFile = ref('')

// 搜索关键词
const searchQuery = ref('')

// FileList 组件引用
const fileListRef = ref(null)

/**
 * 文件选择回调
 * @param {string} name - 选中的文件名
 */
function onFileSelect(name) {
  selectedFile.value = name
}

/**
 * 搜索回调
 * @param {string} query - 搜索关键词
 */
function onSearch(query) {
  searchQuery.value = query
}

/**
 * 火焰图重新生成后刷新列表
 */
function onRegenerated() {
  // 通知 FileList 刷新（通过 ref 调用或 event）
  fileListRef.value?.refresh()
}
</script>

<style>
/* 全局样式：去除默认边距，设置字体 */
* {
  margin: 0;
  padding: 0;
  box-sizing: border-box;
}

html, body, #app {
  width: 100%;
  height: 100%;
  font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
}

.app {
  display: flex;
  flex-direction: column;
  height: 100%;
}

/* 顶部标题栏 */
.header {
  height: 48px;
  background: #2c3e50;
  color: white;
  display: flex;
  align-items: center;
  padding: 0 16px;
  flex-shrink: 0;
}

.header h1 {
  font-size: 16px;
  font-weight: 500;
}

/* 主体区域 */
.body {
  display: flex;
  flex: 1;
  overflow: hidden;
}

/* 左侧栏容器 */
.sidebar {
  display: flex;
  flex-direction: column;
  width: 240px;
  min-width: 200px;
  height: 100%;
  background: #f5f5f5;
  border-right: 1px solid #ddd;
  overflow-y: auto;
}

/* 右侧主内容区 */
.main {
  flex: 1;
  display: flex;
  flex-direction: column;
  overflow: hidden;
}

/* 工具栏 */
.toolbar {
  height: 48px;
  padding: 0 16px;
  display: flex;
  align-items: center;
  background: #fff;
  border-bottom: 1px solid #ddd;
  flex-shrink: 0;
}
</style>
