import Foundation
import Testing
@testable import stankin_app

@MainActor
struct stankin_appTests {

    @Test
    func forDateFiltersEntriesByDayAndSubgroup() throws {
        let entryA = ScheduleEntry(
            id: "A",
            subject: "Лаба 1",
            teacher: "Тестов Т.Т.",
            classType: .lab,
            subgroup: .a,
            room: "302",
            weekday: .wednesday,
            slotStart: 2,
            slotEnd: 3,
            dates: ["2025-10-29"]
        )

        let entryB = ScheduleEntry(
            id: "B",
            subject: "Лаба 2",
            teacher: "Тестов Т.Т.",
            classType: .lab,
            subgroup: .b,
            room: "303",
            weekday: .wednesday,
            slotStart: 2,
            slotEnd: 3,
            dates: ["2025-10-22"]
        )

        let schedule = GroupSchedule(groupName: "ИДБ-23-02", entries: [entryA, entryB])
        let calendar = Calendar(identifier: .gregorian)
        let dateA = try #require(calendar.date(from: DateComponents(year: 2025, month: 10, day: 29)))
        let dateB = try #require(calendar.date(from: DateComponents(year: 2025, month: 10, day: 22)))

        #expect(schedule.forDate(dateB, subgroup: Subgroup.a).isEmpty)
        #expect(schedule.forDate(dateB, subgroup: Subgroup.b).count == 1)
        #expect(schedule.forDate(dateA, subgroup: Subgroup.a).count == 1)
        #expect(schedule.forDate(dateA, subgroup: Subgroup.b).isEmpty)
    }

    @Test
    func progressCountsCompletedSessionsUpToSelectedDate() throws {
        let entry = ScheduleEntry(
            id: "progress",
            subject: "Технологии",
            teacher: "Иванов И.И.",
            classType: .lecture,
            subgroup: .all,
            room: "405",
            weekday: .saturday,
            slotStart: 1,
            slotEnd: 1,
            dates: ["2026-04-05", "2026-04-12", "2026-04-19"]
        )

        let calendar = Calendar(identifier: .gregorian)
        let selectedDate = try #require(calendar.date(from: DateComponents(year: 2026, month: 4, day: 12)))
        let progress = try #require(entry.progress(on: selectedDate))

        #expect(progress.completed == 2)
        #expect(progress.total == 3)
    }

    @Test
    func scheduleRoundTripsThroughJSON() throws {
        let schedule = GroupSchedule(
            groupName: "ИДБ-23-02",
            entries: [
                ScheduleEntry(
                    id: "1",
                    subject: "Системы цифровой обработки изображений",
                    teacher: "Ахунов Т.Е.",
                    classType: .lab,
                    subgroup: .a,
                    room: "313",
                    weekday: .saturday,
                    slotStart: 0,
                    slotEnd: 1,
                    dates: ["2026-04-04"]
                )
            ]
        )

        let data = try #require(GroupSchedule.toJSON(schedule))
        let decoded = try #require(GroupSchedule.fromJSON(data))
        let entry = try #require(decoded.entries.first)

        #expect(decoded.groupName == "ИДБ-23-02")
        #expect(decoded.entries.count == 1)
        #expect(entry.subject == "Системы цифровой обработки изображений")
        #expect(entry.subgroup == .a)
        #expect(entry.room == "313")
    }

    @Test
    func forDateSortsLessonsByTimeSlot() throws {
        let early = ScheduleEntry(
            id: "early",
            subject: "Раннее занятие",
            teacher: nil,
            classType: .lecture,
            subgroup: .all,
            room: "101",
            weekday: .saturday,
            slotStart: 0,
            slotEnd: 0,
            dates: ["2026-04-04"]
        )

        let late = ScheduleEntry(
            id: "late",
            subject: "Позднее занятие",
            teacher: nil,
            classType: .seminar,
            subgroup: .all,
            room: "202",
            weekday: .saturday,
            slotStart: 3,
            slotEnd: 3,
            dates: ["2026-04-04"]
        )

        let schedule = GroupSchedule(groupName: "ИДБ-23-02", entries: [late, early])
        let date = try #require(ScheduleCalendar.russian.date(from: DateComponents(year: 2026, month: 4, day: 4)))
        let entries = schedule.forDate(date)

        #expect(entries.map(\.id) == ["early", "late"])
    }

    @Test
    func dayHeadlineUsesRelativeCaptions() throws {
        let today = ScheduleCalendar.russian.startOfDay(for: Date())
        let tomorrow = try #require(ScheduleCalendar.russian.date(byAdding: .day, value: 1, to: today))
        let yesterday = try #require(ScheduleCalendar.russian.date(byAdding: .day, value: -1, to: today))

        #expect(today.dayHeadline() == "Сегодня")
        #expect(tomorrow.dayHeadline() == "Завтра")
        #expect(yesterday.dayHeadline() == "Вчера")
    }
}
