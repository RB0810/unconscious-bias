import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';

// https://vitejs.dev/config/
export default defineConfig({
  plugins: [react()],
  optimizeDeps: {
    exclude: ['lucide-react'],
  },
  // Add cache busting
  build: {
    sourcemap: true,
  },
  server: {
    // Clear module cache on restart
    force: true,
    // Ensure HMR works correctly
    hmr: {
      overlay: true,
    },
  },
});