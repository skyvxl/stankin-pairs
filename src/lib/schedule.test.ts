import { describe, expect, test } from 'vitest';
import type { ApiEntry } from './types';
import { mapScheduleEntries } from './schedule';

const baseEntry: ApiEntry = {
	name: 'Защита информации',
	type_: 'Лекция',
	sub_group: null,
	teacher: ['Симонов М.Ф.'],
	office: null,
	time: [{ start: '14:05', end: '15:40' }],
	dates: ['2026-09-02'],
	weekday: 'freak'
};

describe('schedule mapping', () => {
	test('uses explicit PDF column indexes for the new timetable', () => {
		const entries = mapScheduleEntries([
			{
				...baseEntry,
				slot_start: 3,
				slot_end: 3
			}
		]);

		expect(entries).toHaveLength(1);
		expect(entries[0]).toMatchObject({
			subject: 'Защита информации',
			slotStart: 3,
			slotEnd: 3,
			timeString: '14:05 – 15:40'
		});
	});

	test('keeps current JSON without slot metadata during rollout', () => {
		const entries = mapScheduleEntries([
			{
				...baseEntry,
				name: 'Операционные системы',
				time: [
					{ start: '15:50', end: '17:25' },
					{ start: '18:00', end: '19:30' }
				]
			}
		]);

		expect(entries).toHaveLength(1);
		expect(entries[0]).toMatchObject({
			slotStart: 4,
			slotEnd: 5,
			timeString: '15:50 – 19:30'
		});
	});

	test('does not discard a valid lesson when its time changes again', () => {
		const entries = mapScheduleEntries([
			{
				...baseEntry,
				time: [{ start: '14:00', end: '15:35' }]
			}
		]);

		expect(entries).toHaveLength(1);
		expect(entries[0]).toMatchObject({
			slotStart: 3,
			slotEnd: 3,
			timeString: '14:00 – 15:35'
		});
	});
});
