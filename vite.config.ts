import { fileURLToPath, URL } from 'node:url'

import { defineConfig } from 'vite'
import vue from '@vitejs/plugin-vue'
import vueDevTools from 'vite-plugin-vue-devtools'
import tailwindcss from '@tailwindcss/vite'
import { VitePWA } from 'vite-plugin-pwa'

// https://vite.dev/config/
export default defineConfig({
  base: '/lider-camp/',
  build: {
    chunkSizeWarningLimit: 1000,
  },
  plugins: [
    tailwindcss(),
    vue(),
    vueDevTools(),
    VitePWA({
      registerType: 'autoUpdate',
      // Service worker con scope correcto para el sub-path /lider-camp/
      scope: '/lider-camp/',
      base: '/lider-camp/',
      workbox: {
        // Cachea todos los assets del build (videos excluidos — demasiado grandes)
        globPatterns: ['**/*.{js,css,html,ico,png,svg,jpg,jpeg,webp,woff,woff2,otf,ttf}'],
        globIgnores: ['**/videos/**'],
        // Cuando el usuario navega a cualquier ruta, sirve el index.html cacheado
        navigateFallback: '/lider-camp/index.html',
        // No interceptar llamadas a Supabase (van a la red o fallan offline)
        navigateFallbackDenylist: [/^\/lider-camp\/api/, /^https:\/\/.*\.supabase\.co/],
        runtimeCaching: [
          {
            // Assets estáticos: sirve desde caché primero (funciona offline)
            urlPattern: /\/lider-camp\/assets\//,
            handler: 'CacheFirst',
            options: {
              cacheName: 'lider-camp-assets',
              expiration: { maxEntries: 200, maxAgeSeconds: 60 * 60 * 24 * 30 },
            },
          },
        ],
      },
      manifest: {
        name: 'LiderCamp 2026-II',
        short_name: 'LiderCamp',
        description: 'Sistema de evaluación del campamento universitario LiderCamp',
        theme_color: '#059669',
        background_color: '#f8fafc',
        display: 'standalone',
        start_url: '/lider-camp/',
        scope: '/lider-camp/',
        icons: [
          {
            src: '/lider-camp/images/logo-upeu.svg',
            sizes: 'any',
            type: 'image/svg+xml',
            purpose: 'any maskable',
          },
        ],
      },
    }),
  ],
  resolve: {
    alias: {
      '@': fileURLToPath(new URL('./src', import.meta.url)),
    },
  },
})
