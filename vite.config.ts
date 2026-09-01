import tailwindcss from '@tailwindcss/vite';
import { sveltekit } from '@sveltejs/kit/vite';
import { defineConfig } from 'vite';
import { SvelteKitPWA } from '@vite-pwa/sveltekit';

export default defineConfig({
	plugins: [
		tailwindcss(),
		sveltekit(),
		SvelteKitPWA({
			base: '/',
			scope: '/',
			registerType: 'autoUpdate',
			// Registration and update handling live in the root Svelte layout.
			injectRegister: 'auto',
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
					{
						src: 'maskable-icon-512x512.png',
						sizes: '512x512',
						type: 'image/png',
						purpose: 'maskable'
					}
				]
			},
			workbox: {
				// Precache the SvelteKit client build
				globPatterns: ['client/**/*.{js,css,ico,png,svg,webp,woff,woff2}'],
				// Prefer current schedule JSON online, then fall back to the cached copy offline.
				runtimeCaching: [
					{
						urlPattern: /^https:\/\/raw\.githubusercontent\.com\/.+\.json$/i,
						handler: 'NetworkFirst',
						options: {
							cacheName: 'schedule-data-v2',
							networkTimeoutSeconds: 5,
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
