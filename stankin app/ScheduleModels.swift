//
//  PDFScheduleParser.swift → ScheduleModels + ScheduleAPI
//  stankin app
//
//  Created by Дмитрий Нилов on 01.03.2026.
//

import Foundation

// MARK: - 1. Модели данных ═══════════════════════════════════════

enum Weekday: Int, Codable, CaseIterable, Comparable {
    case monday = 0
    case tuesday, wednesday, thursday, friday, saturday

    var name: String {
        switch self {
        case .monday: return "Понедельник"
        case .tuesday: return "Вторник"
        case .wednesday: return "Среда"
        case .thursday: return "Четверг"
        case .friday: return "Пятница"
        case .saturday: return "Суббота"
        }
    }

    static func from(calendarWeekday: Int) -> Weekday? {
        let mapped = (calendarWeekday + 5) % 7
        return Weekday(rawValue: mapped)
    }

    static func < (lhs: Weekday, rhs: Weekday) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

enum ClassType: String, Codable {
    case lecture = "Лекция"
    case seminar = "Семинар"
    case lab = "Лабораторная"
}

enum Subgroup: String, Codable {
    case a = "А"
    case b = "Б"
    case all = "all"
}

struct TimeSlot: Codable, Equatable, Hashable {
    let index: Int
    let start: String
    let end: String

    static let slots: [TimeSlot] = [
        .init(index: 0, start: "8:30", end: "10:10"),
        .init(index: 1, start: "10:20", end: "12:00"),
        .init(index: 2, start: "12:20", end: "14:00"),
        .init(index: 3, start: "14:10", end: "15:50"),
        .init(index: 4, start: "16:00", end: "17:40"),
        .init(index: 5, start: "18:00", end: "19:30"),
        .init(index: 6, start: "19:40", end: "21:10"),
        .init(index: 7, start: "21:20", end: "22:50"),
    ]

    /// Находит индекс слота по времени начала (e.g. "8:30" → 0).
    static func index(forStart start: String) -> Int? {
        slots.firstIndex { $0.start == start }
    }
}

struct ScheduleEntry: Codable, Identifiable {
    let id: String
    let subject: String
    let teacher: String?
    let classType: ClassType
    let subgroup: Subgroup
    let room: String?
    let weekday: Weekday
    let slotStart: Int
    let slotEnd: Int
    /// Конкретные даты занятий в формате "yyyy-MM-dd".
    let dates: [String]

    var isRemote: Bool { room == nil }

    var timeString: String {
        let s = TimeSlot.slots[slotStart]
        let e = TimeSlot.slots[slotEnd]
        return "\(s.start) – \(e.end)"
    }

    func progress(
        on date: Date,
        calendar: Calendar = Calendar(identifier: .gregorian)
    )
        -> (completed: Int, total: Int)?
    {
        let targetDate = Self.progressDateFormatter.string(
            from: calendar.startOfDay(for: date)
        )
        var seenDates: Set<String> = []
        var total = 0
        var completed = 0

        for day in dates {
            guard seenDates.insert(day).inserted else { continue }
            total += 1

            if day <= targetDate {
                completed += 1
            }
        }

        guard total > 0 else { return nil }

        return (
            completed: min(completed, total),
            total: total
        )
    }

    private static let progressDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}

struct GroupSchedule: Codable {
    let groupName: String
    let entries: [ScheduleEntry]

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    func forDate(
        _ date: Date,
        subgroup: Subgroup = .all
    ) -> [ScheduleEntry] {
        let cal = Calendar(identifier: .gregorian)
        let cw = cal.component(.weekday, from: date)
        guard let weekday = Weekday.from(calendarWeekday: cw) else { return [] }

        let target = Self.dateFmt.string(from: date)

        var result: [ScheduleEntry] = []
        result.reserveCapacity(entries.count / 6)

        for entry in entries {
            guard entry.weekday == weekday else { continue }
            guard subgroup == .all || entry.subgroup == .all || entry.subgroup == subgroup
            else { continue }
            guard entry.dates.contains(target) else { continue }

            result.append(entry)
        }

        result.sort { $0.slotStart < $1.slotStart }
        return result
    }

    // MARK: JSON

    static func toJSON(_ schedule: GroupSchedule) -> Data? {
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? enc.encode(schedule)
    }

    static func fromJSON(_ data: Data) -> GroupSchedule? {
        try? JSONDecoder().decode(GroupSchedule.self, from: data)
    }
}

// MARK: - 2. API Response Models ══════════════════════════════════

private struct APITimeSlot: Codable {
    let start: String
    let end: String
}

private struct APIEntry: Codable {
    let name: String
    let type_: String
    let sub_group: String?
    let teacher: [String]?
    let office: String?
    let time: [APITimeSlot]
    let dates: [String]
    let weekday: String
}

// MARK: - 3. Schedule API Client ══════════════════════════════════

private struct APIGroup: Codable {
    let group_name: String
    let group_link: String
}

enum ScheduleAPI {
    private static let baseURL =
        "https://raw.githubusercontent.com/skyvxl/schedule-parser/refs/heads/schedules"

    /// Список всех доступных групп.
    static func fetchGroups() async throws -> [String] {
        let url = URL(string: "\(baseURL)/groups.json")!
        let (data, _) = try await URLSession.shared.data(
            for: URLRequest(url: url, timeoutInterval: 15)
        )
        let groups = try JSONDecoder().decode([APIGroup].self, from: data)
        return groups.map(\.group_name)
    }

    /// Расписание для конкретной группы.
    static func fetchSchedule(group: String) async throws -> GroupSchedule {
        let fileName = "\(group).json"
        guard
            let encoded = fileName.addingPercentEncoding(
                withAllowedCharacters: .urlPathAllowed
            ),
            let url = URL(string: "\(baseURL)/\(encoded)")
        else {
            throw URLError(.badURL)
        }

        let (data, _) = try await URLSession.shared.data(
            for: URLRequest(url: url, timeoutInterval: 15)
        )
        let apiEntries = try JSONDecoder().decode([APIEntry].self, from: data)
        return convert(apiEntries, groupName: group)
    }

    // MARK: - Converter

    private static func convert(
        _ apiEntries: [APIEntry],
        groupName: String
    ) -> GroupSchedule {
        let cal = Calendar(identifier: .gregorian)
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.locale = Locale(identifier: "en_US_POSIX")

        var entries: [ScheduleEntry] = []

        for api in apiEntries {
            // Тип занятия
            let classType: ClassType
            switch api.type_ {
            case "Лекция": classType = .lecture
            case "Семинар": classType = .seminar
            case "Лабораторная работа": classType = .lab
            default: continue
            }

            // Подгруппа
            let subgroup: Subgroup
            switch api.sub_group {
            case "(А)": subgroup = .a
            case "(Б)": subgroup = .b
            default: subgroup = .all
            }

            // Тайм-слоты
            guard let firstTime = api.time.first else { continue }
            let lastTime = api.time.last ?? firstTime
            let slotStart = TimeSlot.index(forStart: firstTime.start) ?? 0
            let slotEnd = TimeSlot.index(forStart: lastTime.start) ?? slotStart

            // День недели — из первой даты
            guard let firstDateStr = api.dates.first,
                let firstDate = fmt.date(from: firstDateStr),
                let weekday = Weekday.from(
                    calendarWeekday: cal.component(.weekday, from: firstDate)
                )
            else { continue }

            let teacher = api.teacher?.joined(separator: ", ")

            entries.append(
                ScheduleEntry(
                    id: UUID().uuidString,
                    subject: api.name,
                    teacher: teacher,
                    classType: classType,
                    subgroup: subgroup,
                    room: api.office,
                    weekday: weekday,
                    slotStart: slotStart,
                    slotEnd: slotEnd,
                    dates: api.dates
                )
            )
        }

        return GroupSchedule(groupName: groupName, entries: entries)
    }
}
