import { defineConfig } from 'vitest/config'
import { sveltekit } from '@sveltejs/kit/vite'

export default defineConfig({
  plugins: [sveltekit()],
  test: {
    include: ['src/**/*.test.ts'],
    sequence: {
      concurrent: true,
    },
    maxConcurrency: 10,
  },
  worker: {
    format: 'es' as const,
  },
  server: {
    allowedHosts: ['host.docker.internal'],
  },
})
