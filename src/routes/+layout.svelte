<script lang="ts">
  import { injectSpeedInsights } from '@vercel/speed-insights';
  import '../app.css';
  let { children } = $props();
  injectSpeedInsights();
</script>

{@render children?.()}
