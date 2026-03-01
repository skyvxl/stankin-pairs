import Foundation
import Testing
@testable import stankin_app

struct stankin_appTests {

    @Test
    func alternatingSubgroupLabsAreResolvedBiweekly() throws {
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
            dates: [
                DateRange(start: "15.10", end: "10.12", isEveryWeek: true, isBiweekly: false)
            ]
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
            dates: [
                DateRange(start: "22.10", end: "17.12", isEveryWeek: true, isBiweekly: false)
            ]
        )

        let schedule = GroupSchedule(groupName: "ИДБ-23-02", entries: [entryA, entryB])

        let calendar = Calendar(identifier: .gregorian)
        let dateA = try #require(calendar.date(from: DateComponents(year: 2025, month: 10, day: 29)))
        let dateB = try #require(calendar.date(from: DateComponents(year: 2025, month: 10, day: 22)))

        #expect(schedule.forDate(dateB, subgroup: .a).isEmpty)
        #expect(schedule.forDate(dateB, subgroup: .b).count == 1)

        #expect(schedule.forDate(dateA, subgroup: .a).count == 1)
        #expect(schedule.forDate(dateA, subgroup: .b).isEmpty)
    }

    @Test
    func emptyRoomInJsonBecomesRemote() throws {
        let json = """
        {
          "groupName": "ИДБ-23-02",
          "entries": [
            {
              "id": "1",
              "subject": "Технологии",
              "teacher": "Иванов И.И.",
              "classType": "Лекция",
              "subgroup": "all",
              "room": "\\n",
              "weekday": 0,
              "slotStart": 1,
              "slotEnd": 1,
              "dates": [
                { "start": "01.09", "end": "29.12" }
              ]
            }
          ]
        }
        """.data(using: .utf8)!

        let schedule = try #require(PDFScheduleParser.fromJSON(json))
        let entry = try #require(schedule.entries.first)

        #expect(entry.room == nil)
        #expect(entry.isRemote)
    }
}
