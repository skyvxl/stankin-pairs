import Foundation

enum LaunchFixtureMode: String {
    case empty
    case schedule
}

enum AppLaunchContext {
    static var fixtureMode: LaunchFixtureMode? {
        let arguments = ProcessInfo.processInfo.arguments

        if arguments.contains("UITEST_EMPTY_STATE") {
            return .empty
        }

        if arguments.contains("UITEST_SCHEDULE_STATE") {
            return .schedule
        }

        return nil
    }

    static var shouldResetPersistentState: Bool {
        ProcessInfo.processInfo.arguments.contains("UITEST_RESET_STATE")
    }

    static var initialSelectedDate: Date? {
        if let overrideSelectedDate {
            return overrideSelectedDate
        }

        guard fixtureMode == .schedule else { return nil }

        return ScheduleFixtures.focusDate
    }

    private static var overrideSelectedDate: Date? {
        let prefix = "UITEST_SELECTED_DATE="

        guard
            let argument = ProcessInfo.processInfo.arguments.first(where: {
                $0.hasPrefix(prefix)
            })
        else {
            return nil
        }

        let rawValue = String(argument.dropFirst(prefix.count))
        return ScheduleFormatters.dayID.date(from: rawValue)
    }
}

enum ScheduleFixtures {
    static let availableGroups = [
        "ИДБ-23-02",
        "АДБ-22-01",
        "АДБ-22-03",
        "АДБ-22-04",
        "АДБ-22-06",
        "АДБ-22-07",
        "АДБ-22-08",
        "АДБ-22-09",
    ]

    static let focusDate = ScheduleCalendar.russian.date(
        from: DateComponents(year: 2026, month: 4, day: 4)
    ) ?? Date()

    static func schedule(named groupName: String = "ИДБ-23-02") -> GroupSchedule {
        GroupSchedule(
            groupName: groupName,
            entries: [
                ScheduleEntry(
                    id: "fixture-1",
                    subject: "Системы цифровой обработки изображений",
                    teacher: "Ахунов Т.Е.",
                    classType: .lab,
                    subgroup: .a,
                    room: "313",
                    weekday: .saturday,
                    slotStart: 0,
                    slotEnd: 1,
                    dates: ["2026-04-04", "2026-04-18", "2026-05-02", "2026-05-16", "2026-05-30"]
                ),
                ScheduleEntry(
                    id: "fixture-2",
                    subject: "Организация и управление предприятием",
                    teacher: "Лукина С.В.",
                    classType: .seminar,
                    subgroup: .all,
                    room: "509",
                    weekday: .saturday,
                    slotStart: 2,
                    slotEnd: 2,
                    dates: ["2026-04-04", "2026-04-11", "2026-04-18", "2026-04-25", "2026-05-02", "2026-05-09"]
                ),
            ]
        )
    }
}

enum ScheduleCalendar {
    static let russian: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "ru_RU")
        calendar.firstWeekday = 2
        return calendar
    }()

    /// ±2 years — used by the date picker sheet.
    static let pagerDateRange: ClosedRange<Date> = {
        let today = russian.startOfDay(for: Date())
        let start = russian.date(byAdding: .year, value: -2, to: today) ?? today
        let end = russian.date(byAdding: .year, value: 2, to: today) ?? today
        return start...end
    }()

    /// Number of days on each side of today for the horizontal pager (±2 years).
    static let pagerRadius: Int = 365 * 2
}

enum ScheduleFormatters {
    static let monthYear: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "LLLL yyyy"
        return formatter
    }()

    static let shortWeekday: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "EE"
        return formatter
    }()

    static let fullDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateStyle = .full
        return formatter
    }()

    static let weekdayTitle: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "EEEE"
        return formatter
    }()

    static let dayID: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

extension Subgroup {
    static var pickerValues: [Subgroup] {
        [.all, .a, .b]
    }

    var title: String {
        switch self {
        case .all: return "Все"
        case .a: return "А"
        case .b: return "Б"
        }
    }
}

extension Date {
    var dayID: String {
        ScheduleFormatters.dayID.string(from: self)
    }

    func dayHeadline(calendar: Calendar = ScheduleCalendar.russian) -> String {
        if calendar.isDateInToday(self) {
            return "Сегодня"
        }

        if calendar.isDateInTomorrow(self) {
            return "Завтра"
        }

        if calendar.isDateInYesterday(self) {
            return "Вчера"
        }

        return ScheduleFormatters.weekdayTitle
            .string(from: self)
            .capitalized
    }

    func relativeCaption(calendar: Calendar = ScheduleCalendar.russian) -> String {
        if calendar.isDateInToday(self) {
            return "Сегодня"
        }

        if calendar.isDateInTomorrow(self) {
            return "Завтра"
        }

        if calendar.isDateInYesterday(self) {
            return "Вчера"
        }

        return ScheduleFormatters.shortWeekday
            .string(from: self)
            .capitalized
    }
}

extension ScheduleEntry {
    func interval(
        on date: Date,
        calendar: Calendar = ScheduleCalendar.russian
    ) -> DateInterval? {
        let startSlot = TimeSlot.slots[slotStart]
        let endSlot = TimeSlot.slots[slotEnd]

        guard
            let start = calendar.date(
                bySettingHour: startSlot.start.hourComponent,
                minute: startSlot.start.minuteComponent,
                second: 0,
                of: date
            ),
            let end = calendar.date(
                bySettingHour: endSlot.end.hourComponent,
                minute: endSlot.end.minuteComponent,
                second: 0,
                of: date
            )
        else {
            return nil
        }

        return DateInterval(start: start, end: end)
    }
}

private extension String {
    var hourComponent: Int {
        Int(split(separator: ":").first ?? "0") ?? 0
    }

    var minuteComponent: Int {
        Int(split(separator: ":").last ?? "0") ?? 0
    }
}
