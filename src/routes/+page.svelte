<script lang="ts">
  import { browser } from '$app/environment';
  import { onMount } from 'svelte';
  import type { GroupSchedule, ScheduleEntry, Subgroup, ThemeMode } from '$lib/types';
  import { fetchGroups, fetchSchedule } from '$lib/api';
  import { dayLabel, monthLabel, toISODate, weekDates } from '$lib/date';

  let schedule = $state<GroupSchedule | null>(null);
  let groups = $state<string[]>([]);
  let isLoading = $state(false);
  let isLoadingGroups = $state(false);
  let error = $state('');
  let selectedDate = $state(new Date());
  let selectedSubgroup = $state<Subgroup>('all');
  let selectedGroup = $state('');
  let search = $state('');
  let showGroupPicker = $state(false);
  let showSettings = $state(false);
  let theme = $state<ThemeMode>('system');

  const CACHE_KEY = 'pairs_schedule_cache_v1';
  const GROUP_KEY = 'pairs_group_v1';
  const SUBGROUP_KEY = 'pairs_subgroup_v1';
  const THEME_KEY = 'pairs_theme_v1';

  const filteredGroups = $derived.by(() => {
    const query = search.trim().toLowerCase();
    if (!query) return groups.filter((group) => group !== selectedGroup);
    return groups.filter((group) => group !== selectedGroup && group.toLowerCase().includes(query));
  });

  const entries = $derived.by(() => {
    if (!schedule) return [] as ScheduleEntry[];
    const date = toISODate(selectedDate);
    return schedule.entries
      .filter((entry) => entry.dates.includes(date))
      .filter((entry) => selectedSubgroup === 'all' || entry.subgroup === 'all' || entry.subgroup === selectedSubgroup)
      .sort((a, b) => a.slotStart - b.slotStart);
  });

  const week = $derived(weekDates(selectedDate));

  const todayISO = toISODate(new Date());
  const selectedISO = $derived(toISODate(selectedDate));

  const title = $derived(schedule?.groupName ?? 'Расписание');

  function applyTheme(mode: ThemeMode) {
    if (!browser) return;
    const root = document.documentElement;
    const shouldDark = mode === 'dark' || (mode === 'system' && window.matchMedia('(prefers-color-scheme: dark)').matches);
    root.classList.toggle('dark', shouldDark);
  }

  function shiftDay(days: number) {
    const next = new Date(selectedDate);
    next.setDate(next.getDate() + days);
    selectedDate = next;
  }

  async function loadGroups() {
    isLoadingGroups = true;
    error = '';
    try {
      groups = await fetchGroups();
    } catch {
      error = 'Не удалось загрузить список групп';
    } finally {
      isLoadingGroups = false;
    }
  }

  async function loadSchedule(group: string) {
    isLoading = true;
    error = '';
    try {
      const data = await fetchSchedule(group);
      schedule = data;
      selectedGroup = group;
      if (browser) {
        localStorage.setItem(CACHE_KEY, JSON.stringify(data));
        localStorage.setItem(GROUP_KEY, group);
      }
      showGroupPicker = false;
    } catch {
      error = 'Не удалось загрузить расписание';
    } finally {
      isLoading = false;
    }
  }

  function removeSchedule() {
    schedule = null;
    selectedGroup = '';
    selectedSubgroup = 'all';
    if (browser) {
      localStorage.removeItem(CACHE_KEY);
      localStorage.removeItem(GROUP_KEY);
      localStorage.setItem(SUBGROUP_KEY, 'all');
    }
    showSettings = false;
  }

  onMount(async () => {
    if (browser) {
      const cached = localStorage.getItem(CACHE_KEY);
      const savedGroup = localStorage.getItem(GROUP_KEY) ?? '';
      const savedSubgroup = (localStorage.getItem(SUBGROUP_KEY) as Subgroup | null) ?? 'all';
      const savedTheme = (localStorage.getItem(THEME_KEY) as ThemeMode | null) ?? 'system';

      if (cached) {
        try {
          schedule = JSON.parse(cached) as GroupSchedule;
        } catch {
          localStorage.removeItem(CACHE_KEY);
        }
      }

      selectedGroup = savedGroup;
      selectedSubgroup = savedSubgroup;
      theme = savedTheme;
      applyTheme(savedTheme);

      window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', () => applyTheme(theme));
    }

    await loadGroups();

    if (!schedule && selectedGroup) {
      await loadSchedule(selectedGroup);
    }
  });

  $effect(() => {
    if (!browser) return;
    localStorage.setItem(SUBGROUP_KEY, selectedSubgroup);
  });

  $effect(() => {
    if (!browser) return;
    localStorage.setItem(THEME_KEY, theme);
    applyTheme(theme);
  });
</script>

<main class="mx-auto flex min-h-dvh w-full max-w-md flex-col px-4 pb-6 pt-3">
  <header class="sticky top-0 z-10 rounded-2xl bg-zinc-100/95 p-3 backdrop-blur dark:bg-zinc-950/95">
    <div class="flex items-center justify-between gap-2">
      <div>
        <p class="text-xs text-zinc-500 dark:text-zinc-400">{monthLabel(selectedDate)}</p>
        <h1 class="text-xl font-bold">{title}</h1>
      </div>
      <div class="flex gap-2">
        <button class="rounded-xl border border-zinc-300 px-3 py-2 text-sm dark:border-zinc-700" onclick={() => (showGroupPicker = true)}>Группа</button>
        <button class="rounded-xl border border-zinc-300 px-3 py-2 text-sm dark:border-zinc-700" onclick={() => (showSettings = true)}>⚙️</button>
      </div>
    </div>
  </header>

  {#if !schedule}
    <section class="mt-8 rounded-3xl border border-zinc-200 bg-white p-5 text-center dark:border-zinc-800 dark:bg-zinc-900">
      <h2 class="text-xl font-semibold">Нет расписания</h2>
      <p class="mt-2 text-sm text-zinc-500 dark:text-zinc-400">Выберите группу и приложение сразу покажет пары.</p>
      <button class="mt-4 w-full rounded-2xl bg-zinc-900 px-4 py-3 text-white dark:bg-white dark:text-zinc-900" onclick={() => (showGroupPicker = true)}>Выбрать группу</button>
    </section>
  {:else}
    <section class="mt-3 flex items-center justify-between rounded-2xl border border-zinc-200 bg-white p-3 dark:border-zinc-800 dark:bg-zinc-900">
      <button class="rounded-xl border border-zinc-300 px-3 py-2 dark:border-zinc-700" onclick={() => shiftDay(-1)}>←</button>
      <div class="text-center">
        <p class="text-sm font-medium">{dayLabel(selectedDate)}</p>
        <p class="text-xs text-zinc-500 dark:text-zinc-400">{selectedISO === todayISO ? 'Сегодня' : 'Выбранный день'}</p>
      </div>
      <button class="rounded-xl border border-zinc-300 px-3 py-2 dark:border-zinc-700" onclick={() => shiftDay(1)}>→</button>
    </section>

    <div class="mt-2 grid grid-cols-7 gap-1 text-center text-xs">
      {#each week as day}
        <button
          class={`rounded-xl px-1 py-2 ${toISODate(day) === selectedISO ? 'bg-zinc-900 text-white dark:bg-white dark:text-zinc-900' : 'bg-zinc-200/70 dark:bg-zinc-800'}`}
          onclick={() => (selectedDate = day)}
        >
          {day.toLocaleDateString('ru-RU', { weekday: 'short' })}<br />{day.getDate()}
        </button>
      {/each}
    </div>

    <section class="mt-3 space-y-2">
      {#if entries.length === 0}
        <div class="rounded-2xl border border-dashed border-zinc-300 p-6 text-center text-sm text-zinc-500 dark:border-zinc-700 dark:text-zinc-400">В этот день пар нет.</div>
      {:else}
        {#each entries as entry}
          <article class="rounded-2xl border border-zinc-200 bg-white p-3 dark:border-zinc-800 dark:bg-zinc-900">
            <p class="text-sm text-zinc-500 dark:text-zinc-400">{entry.timeString}</p>
            <h3 class="mt-1 font-semibold">{entry.subject}</h3>
            <p class="mt-1 text-sm">{entry.classType} · {entry.subgroup === 'all' ? 'Все' : `Подгруппа ${entry.subgroup}`}</p>
            {#if entry.teacher}<p class="mt-1 text-sm text-zinc-600 dark:text-zinc-300">{entry.teacher}</p>{/if}
            <p class="mt-1 text-sm text-zinc-500 dark:text-zinc-400">{entry.room ?? 'Дистанционно'}</p>
          </article>
        {/each}
      {/if}
    </section>
  {/if}

  {#if error}
    <p class="mt-3 rounded-xl bg-red-100 p-3 text-sm text-red-700 dark:bg-red-950/50 dark:text-red-300">{error}</p>
  {/if}

  {#if isLoading}
    <div class="fixed inset-0 grid place-items-center bg-zinc-900/25 backdrop-blur-sm">
      <div class="rounded-xl bg-white px-4 py-3 text-sm dark:bg-zinc-900">Загрузка расписания…</div>
    </div>
  {/if}

  {#if showGroupPicker}
    <div class="fixed inset-0 z-20 bg-black/40 p-3" role="button" tabindex="0" aria-label="Закрыть выбор группы" onclick={(e) => e.currentTarget === e.target && (showGroupPicker = false)} onkeydown={(e) => e.key === "Escape" && (showGroupPicker = false)}>
      <div class="mx-auto mt-8 w-full max-w-md rounded-3xl bg-white p-3 dark:bg-zinc-900">
        <div class="mb-2 flex items-center justify-between">
          <h2 class="font-semibold">Выбор группы</h2>
          <button class="text-sm" onclick={() => (showGroupPicker = false)}>Закрыть</button>
        </div>
        <input class="mb-2 w-full rounded-xl border border-zinc-300 px-3 py-2 text-sm dark:border-zinc-700 dark:bg-zinc-800" bind:value={search} placeholder="Поиск группы" />
        <div class="max-h-[60dvh] overflow-auto">
          {#if isLoadingGroups}
            <p class="p-3 text-sm text-zinc-500">Загрузка групп…</p>
          {:else if filteredGroups.length === 0}
            <p class="p-3 text-sm text-zinc-500">Ничего не найдено.</p>
          {:else}
            {#each filteredGroups as group}
              <button class="mb-1 w-full rounded-xl px-3 py-2 text-left text-sm hover:bg-zinc-100 dark:hover:bg-zinc-800" onclick={() => loadSchedule(group)}>{group}</button>
            {/each}
          {/if}
        </div>
      </div>
    </div>
  {/if}

  {#if showSettings}
    <div class="fixed inset-0 z-20 bg-black/40 p-3" role="button" tabindex="0" aria-label="Закрыть настройки" onclick={(e) => e.currentTarget === e.target && (showSettings = false)} onkeydown={(e) => e.key === "Escape" && (showSettings = false)}>
      <div class="mx-auto mt-16 w-full max-w-md rounded-3xl bg-white p-4 dark:bg-zinc-900">
        <h2 class="mb-3 font-semibold">Настройки</h2>
        <label class="mb-3 block text-sm">Подгруппа
          <select class="mt-1 w-full rounded-xl border border-zinc-300 px-3 py-2 dark:border-zinc-700 dark:bg-zinc-800" bind:value={selectedSubgroup}>
            <option value="all">Все</option>
            <option value="a">А</option>
            <option value="b">Б</option>
          </select>
        </label>

        <label class="mb-3 block text-sm">Тема
          <select class="mt-1 w-full rounded-xl border border-zinc-300 px-3 py-2 dark:border-zinc-700 dark:bg-zinc-800" bind:value={theme}>
            <option value="system">Системная</option>
            <option value="light">Светлая</option>
            <option value="dark">Темная</option>
          </select>
        </label>

        <div class="flex gap-2">
          {#if selectedGroup}
            <button class="flex-1 rounded-xl border border-zinc-300 px-3 py-2 text-sm dark:border-zinc-700" onclick={() => loadSchedule(selectedGroup)}>Обновить</button>
          {/if}
          <button class="flex-1 rounded-xl bg-red-600 px-3 py-2 text-sm text-white" onclick={removeSchedule}>Удалить</button>
        </div>
      </div>
    </div>
  {/if}
</main>
