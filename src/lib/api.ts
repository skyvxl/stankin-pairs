import type { ApiEntry, GroupSchedule, ScheduleEntry } from './types';

const BASE_URL = 'https://raw.githubusercontent.com/skyvxl/schedule-parser/refs/heads/schedules';

const SLOT_START: Record<string, number> = {
  '8:30': 0,
  '10:20': 1,
  '12:20': 2,
  '14:10': 3,
  '16:00': 4,
  '18:00': 5,
  '19:40': 6,
  '21:20': 7
};

const SLOT_END: Record<number, string> = {
  0: '10:10',
  1: '12:00',
  2: '14:00',
  3: '15:50',
  4: '17:40',
  5: '19:30',
  6: '21:10',
  7: '22:50'
};

const weekdayMap: Record<string, number> = {
  monday: 0,
  tuesday: 1,
  wednesday: 2,
  thursday: 3,
  friday: 4,
  saturday: 5
};

export async function fetchGroups(): Promise<string[]> {
  const res = await fetch(`${BASE_URL}/groups.json`, { cache: 'force-cache' });
  if (!res.ok) throw new Error('groups fetch failed');
  const json = (await res.json()) as { group_name: string }[];
  return json.map((item) => item.group_name).sort();
}

export async function fetchSchedule(group: string): Promise<GroupSchedule> {
  const res = await fetch(`${BASE_URL}/${encodeURIComponent(group)}.json`, { cache: 'no-cache' });
  if (!res.ok) throw new Error('schedule fetch failed');
  const json = (await res.json()) as ApiEntry[];

  const entries = json
    .map((entry): ScheduleEntry | null => {
      const start = entry.time[0]?.start;
      const end = entry.time[entry.time.length - 1]?.end;
      if (!start || !end) return null;
      const slotStart = SLOT_START[start];
      if (slotStart === undefined) return null;

      const slotEnd = Number(Object.keys(SLOT_END).find((key) => SLOT_END[Number(key)] === end) ?? slotStart);
      const subgroup = entry.sub_group === 'А' ? 'a' : entry.sub_group === 'Б' ? 'b' : 'all';
      const classType = entry.type_ === 'Лабораторная работа' ? 'Лабораторная' : (entry.type_ as ScheduleEntry['classType']);

      const mapped: ScheduleEntry = {
        id: `${entry.name}-${slotStart}-${entry.dates[0] ?? ''}`,
        subject: entry.name,
        classType,
        subgroup,
        weekday: weekdayMap[entry.weekday] ?? 0,
        slotStart,
        slotEnd,
        dates: entry.dates,
        timeString: `${start} – ${end}`
      };

      if (entry.teacher?.length) mapped.teacher = entry.teacher.join(', ');
      if (entry.office) mapped.room = entry.office;

      return mapped;
    })
    .filter((value): value is ScheduleEntry => Boolean(value));

  return { groupName: group, entries };
}
