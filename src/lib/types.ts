export type Subgroup = 'a' | 'b' | 'all';
export type ThemeMode = 'light' | 'dark' | 'system';

export type ClassType = 'Лекция' | 'Семинар' | 'Лабораторная';

export interface ScheduleEntry {
  id: string;
  subject: string;
  teacher?: string;
  classType: ClassType;
  subgroup: Subgroup;
  room?: string;
  weekday: number;
  slotStart: number;
  slotEnd: number;
  dates: string[];
  timeString: string;
}

export interface GroupSchedule {
  groupName: string;
  entries: ScheduleEntry[];
}

interface ApiEntry {
  name: string;
  type_: string;
  sub_group?: string;
  teacher?: string[];
  office?: string;
  time: { start: string; end: string }[];
  dates: string[];
  weekday: string;
}

export type { ApiEntry };
