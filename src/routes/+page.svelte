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

  function normalizeQuery(s: string): string {
    return s.toUpperCase().replace(/[^А-ЯA-Z0-9]/g, '');
  }

  const filteredGroups = $derived.by(() => {
    const raw = search.trim();
    if (!raw) return groups.filter((g) => g !== selectedGroup);
    const q = normalizeQuery(raw);
    return groups.filter((g) => g !== selectedGroup && normalizeQuery(g).includes(q));
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

  function classTypeBadgeClass(type: import('$lib/types').ClassType): string {
    const base = 'rounded-full px-2.5 py-1 text-xs font-medium';
    if (type === 'Семинар') return `${base} bg-orange-100 text-orange-700 dark:bg-orange-950/60 dark:text-orange-300`;
    if (type === 'Лабораторная') return `${base} bg-green-100 text-green-700 dark:bg-green-950/60 dark:text-green-300`;
    return `${base} bg-blue-100 text-blue-700 dark:bg-blue-950/60 dark:text-blue-300`;
  }

  function slotLabel(start: number, end: number): string {
    const s = start + 1;
    const e = end + 1;
    if (s === e) return `${s}-я пара`;
    return `${s}–${e}-я пары`;
  }

  function weekCounter(entry: ScheduleEntry, dateISO: string): string {
    const idx = entry.dates.indexOf(dateISO);
    if (idx === -1 || entry.dates.length < 2) return '';
    return `${idx + 1}/${entry.dates.length}`;
  }
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
        <button class="rounded-xl border border-zinc-300 px-3 py-2 dark:border-zinc-700" aria-label="Настройки" onclick={() => (showSettings = true)}>
          <svg xmlns="http://www.w3.org/2000/svg" width="16" height="16" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M12.22 2h-.44a2 2 0 0 0-2 2v.18a2 2 0 0 1-1 1.73l-.43.25a2 2 0 0 1-2 0l-.15-.08a2 2 0 0 0-2.73.73l-.22.38a2 2 0 0 0 .73 2.73l.15.1a2 2 0 0 1 1 1.72v.51a2 2 0 0 1-1 1.74l-.15.09a2 2 0 0 0-.73 2.73l.22.38a2 2 0 0 0 2.73.73l.15-.08a2 2 0 0 1 2 0l.43.25a2 2 0 0 1 1 1.73V20a2 2 0 0 0 2 2h.44a2 2 0 0 0 2-2v-.18a2 2 0 0 1 1-1.73l.43-.25a2 2 0 0 1 2 0l.15.08a2 2 0 0 0 2.73-.73l.22-.39a2 2 0 0 0-.73-2.73l-.15-.08a2 2 0 0 1-1-1.74v-.5a2 2 0 0 1 1-1.74l.15-.09a2 2 0 0 0 .73-2.73l-.22-.38a2 2 0 0 0-2.73-.73l-.15.08a2 2 0 0 1-2 0l-.43-.25a2 2 0 0 1-1-1.73V4a2 2 0 0 0-2-2z"/><circle cx="12" cy="12" r="3"/></svg>
        </button>
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
          {@const counter = weekCounter(entry, selectedISO)}
          <article class="rounded-2xl border border-zinc-200 bg-white p-4 dark:border-zinc-800 dark:bg-zinc-900">
            <!-- Header: time + badges -->
            <div class="flex items-start justify-between gap-2">
              <div>
                <p class="text-lg font-bold leading-tight">{entry.timeString}</p>
                <p class="mt-0.5 text-xs text-zinc-500 dark:text-zinc-400">{slotLabel(entry.slotStart, entry.slotEnd)}</p>
              </div>
              <div class="flex shrink-0 items-center gap-1.5">
                <span class={classTypeBadgeClass(entry.classType)}>{entry.classType}</span>
                {#if counter}
                  <span class="rounded-full bg-zinc-100 px-2.5 py-1 text-xs font-medium text-zinc-500 dark:bg-zinc-800 dark:text-zinc-400">{counter}</span>
                {/if}
              </div>
            </div>

            <!-- Subject -->
            <h3 class="mt-3 text-base font-bold leading-snug">{entry.subject}</h3>

            <!-- Teacher -->
            {#if entry.teacher}
              <p class="mt-1.5 text-sm text-zinc-500 dark:text-zinc-400">{entry.teacher}</p>
            {/if}

            <!-- Bottom meta badges -->
            <div class="mt-3 flex flex-wrap gap-1.5">
              {#if entry.room}
                <span class="flex items-center gap-1 rounded-full bg-zinc-100 px-2.5 py-1 text-xs text-zinc-600 dark:bg-zinc-800 dark:text-zinc-300">
                  <svg xmlns="http://www.w3.org/2000/svg" width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><rect x="4" y="2" width="16" height="20" rx="2"/><path d="M9 22V12h6v10"/><path d="M8 7h.01"/><path d="M12 7h.01"/><path d="M16 7h.01"/></svg>
                  {entry.room}
                </span>
              {:else}
                <span class="flex items-center gap-1 rounded-full bg-zinc-100 px-2.5 py-1 text-xs text-zinc-600 dark:bg-zinc-800 dark:text-zinc-300">
                  <svg xmlns="http://www.w3.org/2000/svg" width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="m22 8-6 4 6 4V8z"/><rect x="2" y="6" width="14" height="12" rx="2"/></svg>
                  Дистанционно
                </span>
              {/if}
              {#if entry.subgroup !== 'all'}
                <span class="flex items-center gap-1 rounded-full bg-blue-100 px-2.5 py-1 text-xs text-blue-700 dark:bg-blue-950/60 dark:text-blue-300">
                  <svg xmlns="http://www.w3.org/2000/svg" width="11" height="11" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M16 21v-2a4 4 0 0 0-4-4H6a4 4 0 0 0-4 4v2"/><circle cx="9" cy="7" r="4"/><path d="M22 21v-2a4 4 0 0 0-3-3.87"/><path d="M16 3.13a4 4 0 0 1 0 7.75"/></svg>
                  Подгруппа {entry.subgroup.toUpperCase()}
                </span>
              {/if}
            </div>
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

        <div class="mt-4 border-t border-zinc-200 pt-4 dark:border-zinc-800">
          <p class="mb-2 text-xs font-medium uppercase tracking-wide text-zinc-400 dark:text-zinc-500">Документы</p>
          <div class="overflow-hidden rounded-2xl border border-zinc-200 dark:border-zinc-800">
            <a href="/legal/privacy" onclick={() => (showSettings = false)} class="flex items-center justify-between px-4 py-3 text-sm hover:bg-zinc-50 dark:hover:bg-zinc-800">
              Политика конфиденциальности
              <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="text-zinc-400"><path d="m9 18 6-6-6-6"/></svg>
            </a>
            <div class="mx-4 h-px bg-zinc-100 dark:bg-zinc-800"></div>
            <a href="/legal/terms" onclick={() => (showSettings = false)} class="flex items-center justify-between px-4 py-3 text-sm hover:bg-zinc-50 dark:hover:bg-zinc-800">
              Условия использования
              <svg xmlns="http://www.w3.org/2000/svg" width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="text-zinc-400"><path d="m9 18 6-6-6-6"/></svg>
            </a>
          </div>
        </div>
      </div>
    </div>
  {/if}
</main>
