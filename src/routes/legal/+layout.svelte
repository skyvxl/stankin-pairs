<script lang="ts">
  import { goto } from '$app/navigation';
  let { children } = $props();
</script>

<main class="mx-auto min-h-dvh w-full max-w-md px-4 pb-10 pt-4">
  <button
    class="mb-4 flex items-center gap-1.5 text-sm text-zinc-500 dark:text-zinc-400"
    onclick={() => history.length > 1 ? history.back() : goto('/')}
  >
    <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m15 18-6-6 6-6"/></svg>
    Назад
  </button>
  {@render children()}
</main>
