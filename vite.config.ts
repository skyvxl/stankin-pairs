import tailwindcss from '@tailwindcss/vite';
import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';
import { SvelteKitPWA } from '@vite-pwa/sveltekit';

export default defineConfig({
  plugins: [
    tailwindcss(),
    sveltekit(),
    SvelteKitPWA({
      registerType: 'autoUpdate',
      // Registration is handled manually in app.html
      injectRegister: null,
      manifest: {
        name: 'СТАНКИН Расписание',
        short_name: 'Расписание',
        description: 'Неофициальное расписание занятий МГТУ СТАНКИН',
        theme_color: '#ffffff',
        background_color: '#18181b',
        display: 'standalone',
        start_url: '/',
        scope: '/',
        lang: 'ru',
        icons: [
          { src: 'pwa-64x64.png', sizes: '64x64', type: 'image/png' },
          { src: 'pwa-192x192.png', sizes: '192x192', type: 'image/png' },
          { src: 'pwa-512x512.png', sizes: '512x512', type: 'image/png', purpose: 'any' },
          { src: 'maskable-icon-512x512.png', sizes: '512x512', type: 'image/png', purpose: 'maskable' }
        ]
      },
      workbox: {
        // Precache the SvelteKit client build
        globPatterns: ['client/**/*.{js,css,ico,png,svg,webp,woff,woff2}'],
        // Cache schedule JSON from GitHub Raw — stale-while-revalidate:
        // serves from cache instantly, updates in background when online
        runtimeCaching: [
          {
            urlPattern: /^https:\/\/raw\.githubusercontent\.com\/.+\.json$/i,
            handler: 'StaleWhileRevalidate',
            options: {
              cacheName: 'schedule-data',
              expiration: {
                maxEntries: 100,
                maxAgeSeconds: 60 * 60 * 24 * 7 // 7 days
              },
              cacheableResponse: { statuses: [0, 200] }
            }
          }
        ]
      },
      devOptions: {
        // Enable SW in dev mode for testing
        enabled: false
      }
    })
  ]
});
