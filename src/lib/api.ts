import { mapScheduleEntries } from './schedule';
import type { ApiEntry, GroupSchedule } from './types';

const BASE_URL = 'https://raw.githubusercontent.com/skyvxl/schedule-parser/refs/heads/schedules';

export async function fetchGroups(): Promise<string[]> {
	const res = await fetch(`${BASE_URL}/groups.json`, { cache: 'no-cache' });
	if (!res.ok) throw new Error('groups fetch failed');
	const json = (await res.json()) as { group_name: string }[];
	return json.map((item) => item.group_name).sort();
}

export async function fetchSchedule(group: string): Promise<GroupSchedule> {
	const res = await fetch(`${BASE_URL}/${encodeURIComponent(group)}.json`, { cache: 'no-cache' });
	if (!res.ok) throw new Error('schedule fetch failed');
	const json = (await res.json()) as ApiEntry[];

	const entries = mapScheduleEntries(json);

	return { groupName: group, entries };
}
