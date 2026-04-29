<template>
  <div class="search-bar">
    <input
      v-model="query"
      type="text"
      placeholder="搜索函数名..."
      @input="onInput"
    />
    <button v-if="query" @click="clear">清除</button>
  </div>
</template>

<script setup>
import { ref } from 'vue'

// 搜索关键词
const query = ref('')

// 触发搜索事件，传递给父组件
const emit = defineEmits(['search'])

// 防抖定时器
let timer = null

/**
 * 输入事件处理：使用防抖，避免频繁触发搜索
 */
function onInput() {
  clearTimeout(timer)
  timer = setTimeout(() => {
    emit('search', query.value)
  }, 300)
}

/** 清除搜索并通知父组件 */
function clear() {
  query.value = ''
  emit('search', '')
}
</script>

<style scoped>
.search-bar {
  display: flex;
  gap: 8px;
  align-items: center;
}

.search-bar input {
  flex: 1;
  padding: 6px 12px;
  border: 1px solid #ccc;
  border-radius: 4px;
  font-size: 14px;
}

.search-bar button {
  padding: 6px 12px;
  border: none;
  background: #e74c3c;
  color: white;
  border-radius: 4px;
  cursor: pointer;
}

.search-bar button:hover {
  background: #c0392b;
}
</style>
