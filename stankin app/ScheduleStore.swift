import Foundation
import Combine

@MainActor
final class ScheduleStore: ObservableObject {
    enum Scope: String, CaseIterable, Identifiable {
        case day = "День"
        case week = "Неделя"

        var id: String { rawValue }
    }

    @Published private(set) var schedule: GroupSchedule?
    @Published var selectedDate: Date = Date()
    @Published var selectedSubgroup: Subgroup = .all
    @Published var scope: Scope = .day
    @Published var errorMessage: String?
    @Published var isImporting = false

    private let calendar = Calendar(identifier: .gregorian)

    var entriesForSelectedDate: [ScheduleEntry] {
        entries(for: selectedDate)
    }

    var selectedDateTitle: String {
        if calendar.isDateInToday(selectedDate) {
            return "Сегодня"
        }
        if calendar.isDateInTomorrow(selectedDate) {
            return "Завтра"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM, EEEE"
        return formatter.string(from: selectedDate)
    }

    init() {
        loadCachedSchedule()
    }

    func entries(for date: Date) -> [ScheduleEntry] {
        schedule?.forDate(date, subgroup: selectedSubgroup) ?? []
    }

    func weekdayPills() -> [Date] {
        guard let monday = mondayDate(for: selectedDate) else { return [] }
        return (0..<6).compactMap {
            calendar.date(byAdding: .day, value: $0, to: monday)
        }
    }

    func importSchedule(from fileURL: URL) {
        let canAccess = fileURL.startAccessingSecurityScopedResource()
        defer {
            if canAccess {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: fileURL)
            importSchedule(fromPDFData: data)
        } catch {
            errorMessage = "Ошибка чтения файла: \(error.localizedDescription)"
        }
    }

    func removeSchedule() {
        schedule = nil
        selectedDate = Date()
        selectedSubgroup = .all
        scope = .day
        errorMessage = nil

        guard let url = cacheURL() else { return }
        try? FileManager.default.removeItem(at: url)
    }

    private func importSchedule(fromPDFData data: Data) {
        isImporting = true
        errorMessage = nil

        Task {
            let parsed = await Task.detached(priority: .userInitiated) {
                PDFScheduleParser.parse(pdfData: data)
            }.value

            if let parsed {
                schedule = parsed
                cacheSchedule(parsed)
            } else {
                errorMessage = "Не удалось распознать расписание из PDF"
            }

            isImporting = false
        }
    }

    private func mondayDate(for date: Date) -> Date? {
        let weekday = calendar.component(.weekday, from: date)
        let normalized = (weekday + 5) % 7
        return calendar.date(byAdding: .day, value: -normalized, to: calendar.startOfDay(for: date))
    }

    private func cacheURL() -> URL? {
        guard let folder = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        } catch {
            return nil
        }
        return folder.appendingPathComponent("schedule_cache.json")
    }

    private func cacheSchedule(_ parsed: GroupSchedule) {
        guard let url = cacheURL() else { return }
        guard let data = PDFScheduleParser.toJSON(parsed) else { return }
        do {
            try data.write(to: url, options: .atomic)
        } catch {
            errorMessage = "Не удалось сохранить кэш: \(error.localizedDescription)"
        }
    }

    private func loadCachedSchedule() {
        guard let url = cacheURL(), FileManager.default.fileExists(atPath: url.path) else {
            return
        }

        do {
            let data = try Data(contentsOf: url)
            if let decoded = PDFScheduleParser.fromJSON(data) {
                schedule = decoded
            }
        } catch {
            errorMessage = "Не удалось загрузить кэш: \(error.localizedDescription)"
        }
    }
}
