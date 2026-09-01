<script lang="ts">
	import '../app.css';
	import { dev } from '$app/environment';
	import { onMount } from 'svelte';
	import { injectSpeedInsights } from '@vercel/speed-insights';
	import { injectAnalytics } from '@vercel/analytics/sveltekit';

	let { children } = $props();

	injectSpeedInsights();
	injectAnalytics({ mode: dev ? 'development' : 'production' });

	onMount(() => {
		let updateInterval: ReturnType<typeof window.setInterval> | undefined;

		void import('virtual:pwa-register').then(({ registerSW }) => {
			registerSW({
				immediate: true,
				onRegisteredSW(_scriptUrl, registration) {
					if (!registration) return;
					updateInterval = window.setInterval(() => void registration.update(), 60 * 60 * 1000);
				},
				onRegisterError(error) {
					console.error('Service worker registration failed', error);
				}
			});
		});

		return () => {
			if (updateInterval !== undefined) window.clearInterval(updateInterval);
		};
	});
</script>

{@render children?.()}
