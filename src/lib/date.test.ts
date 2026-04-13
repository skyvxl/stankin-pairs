import { describe, expect, it } from 'vitest';
import { toISODate, weekDates } from '$lib/date';

describe('date helpers', () => {
  it('formats iso date', () => {
    expect(toISODate(new Date('2026-04-13T00:00:00Z'))).toBe('2026-04-13');
  });

  it('builds full week', () => {
    expect(weekDates(new Date('2026-04-13')).length).toBe(7);
  });
});
