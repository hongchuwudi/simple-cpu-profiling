import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'

export default defineConfig({
  plugins: [vue()],
  server: {
    host: '0.0.0.0',
    port: 10100,
    // 开发模式下将 /api 请求代理到 Python 后端
    proxy: {
      '/api': {
        target: 'http://127.0.0.1:10101',
        changeOrigin: true,
      },
    },
  },
})
