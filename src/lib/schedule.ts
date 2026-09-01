import type { ApiEntry, ScheduleEntry } from './types';

const SLOT_START_MINUTES = [
	8 * 60 + 30,
	10 * 60 + 15,
	12 * 60 + 20,
	14 * 60 + 5,
	15 * 60 + 50,
	18 * 60,
	19 * 60 + 40,
	21 * 60 + 20
];
const SLOT_END_MINUTES = [
	10 * 60 + 5,
	11 * 60 + 50,
	13 * 60 + 55,
	15 * 60 + 40,
	17 * 60 + 25,
	19 * 60 + 30,
	21 * 60 + 10,
	22 * 60 + 50
];

const weekdayMap: Record<string, number> = {
	monday: 0,
	tuesday: 1,
	wednesday: 2,
	thursday: 3,
	friday: 4,
	saturday: 5
};

function timeToMinutes(value: string): number | null {
	const match = /^(\d{1,2}):(\d{2})$/.exec(value);
	if (!match) return null;

	const hours = Number(match[1]);
	const minutes = Number(match[2]);
	if (hours > 23 || minutes > 59) return null;

	return hours * 60 + minutes;
}

function nearestSlot(value: string, timetable: number[]): number | null {
	const minutes = timeToMinutes(value);
	if (minutes === null) return null;

	let nearestIndex = 0;
	let nearestDistance = Number.POSITIVE_INFINITY;

	for (const [index, target] of timetable.entries()) {
		const distance = Math.abs(minutes - target);
		if (distance < nearestDistance) {
			nearestIndex = index;
			nearestDistance = distance;
		}
	}

	return nearestIndex;
}

function explicitSlot(value: number | undefined): number | null {
	return typeof value === 'number' && Number.isInteger(value) && value >= 0 ? value : null;
}

export function mapScheduleEntries(json: ApiEntry[]): ScheduleEntry[] {
	return json
		.map((entry): ScheduleEntry | null => {
			const start = entry.time[0]?.start;
			const end = entry.time[entry.time.length - 1]?.end;
			if (!start || !end) return null;

			const slotStart = explicitSlot(entry.slot_start) ?? nearestSlot(start, SLOT_START_MINUTES);
			const inferredSlotEnd = explicitSlot(entry.slot_end) ?? nearestSlot(end, SLOT_END_MINUTES);
			if (slotStart === null || inferredSlotEnd === null) return null;
			const slotEnd = Math.max(slotStart, inferredSlotEnd);

			const sg = entry.sub_group ?? '';
			const subgroup = /А/i.test(sg) ? 'a' : /Б/i.test(sg) ? 'b' : 'all';
			const classType =
				entry.type_ === 'Лабораторная работа'
					? 'Лабораторная'
					: (entry.type_ as ScheduleEntry['classType']);

			const mapped: ScheduleEntry = {
				id: `${entry.name}-${subgroup}-${slotStart}-${entry.dates[0] ?? ''}`,
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
}
