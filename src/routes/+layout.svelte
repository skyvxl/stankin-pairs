<script lang="ts">
  import '../app.css';
	import { dev } from '$app/environment';
  import { injectSpeedInsights } from '@vercel/speed-insights';
	import { injectAnalytics } from '@vercel/analytics/sveltekit';

  let { children } = $props();
  
  injectSpeedInsights();
  injectAnalytics({ mode: dev? 'development' : 'production' });
</script>

{@render children?.()}
