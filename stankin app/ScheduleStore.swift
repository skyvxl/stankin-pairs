import Foundation
import Combine

@MainActor
final class ScheduleStore: ObservableObject {
    @Published private(set) var schedule: GroupSchedule?
    @Published var selectedSubgroup: Subgroup = .all
    @Published var errorMessage: String?
    @Published var isImporting = false
    @Published private(set) var timelineRange: ClosedRange<Int>

    private let calendar = Calendar(identifier: .gregorian)
    private let initialTimelinePaddingDays = 7
    private let maxTimelinePaddingDays = 1460
    private let timelineChunk = 28
    private let timelinePrefetchThreshold = 4
    private let expansionCooldown: TimeInterval = 0.35
    private var lastExpansionAt = Date.distantPast

    var hasSchedule: Bool {
        schedule != nil
    }

    var navigationTitle: String {
        schedule?.groupName ?? "Нет расписания"
    }

    init() {
        timelineRange = ScheduleStore.initialRange(
            calendar: calendar,
            padding: initialTimelinePaddingDays
        )
        loadCachedSchedule()
    }

    var timelineOffsets: ClosedRange<Int> {
        timelineRange
    }

    func entries(for date: Date) -> [ScheduleEntry] {
        schedule?.forDate(date, subgroup: selectedSubgroup) ?? []
    }

    func date(forOffset offset: Int, anchor: Date = Date()) -> Date {
        let center = calendar.startOfDay(for: anchor)
        return calendar.date(byAdding: .day, value: offset, to: center) ?? center
    }

    func bootstrapTimeline(anchor: Date = Date()) {
        _ = anchor
        timelineRange = Self.initialRange(
            calendar: calendar,
            padding: initialTimelinePaddingDays
        )
        lastExpansionAt = .distantPast
    }

    func prefetchAround(offset: Int) {
        if Date().timeIntervalSince(lastExpansionAt) < expansionCooldown {
            return
        }

        let lower = timelineRange.lowerBound
        let upper = timelineRange.upperBound

        var olderBy = 0
        var newerBy = 0

        if offset <= lower + timelinePrefetchThreshold {
            olderBy = timelineChunk
        }
        if offset >= upper - timelinePrefetchThreshold {
            newerBy = timelineChunk
        }

        if olderBy > 0 || newerBy > 0 {
            lastExpansionAt = Date()
            extendTimeline(olderBy: olderBy, newerBy: newerBy)
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
        selectedSubgroup = .all
        errorMessage = nil
        bootstrapTimeline()

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
        Task { @MainActor in
            let result = await Task.detached(priority: .utility) { () -> Result<GroupSchedule?, Error> in
                guard
                    let url = Self.cachedScheduleURL(),
                    FileManager.default.fileExists(atPath: url.path)
                else {
                    return .success(nil)
                }

                do {
                    let data = try Data(contentsOf: url)
                    return .success(PDFScheduleParser.fromJSON(data))
                } catch {
                    return .failure(error)
                }
            }.value

            switch result {
            case .success(let decoded):
                if let decoded {
                    schedule = decoded
                }
            case .failure(let error):
                errorMessage = "Не удалось загрузить кэш: \(error.localizedDescription)"
            }
        }
    }

    private func extendTimeline(olderBy: Int, newerBy: Int) {
        guard olderBy > 0 || newerBy > 0 else { return }

        let newLower = max(-maxTimelinePaddingDays, timelineRange.lowerBound - olderBy)
        let newUpper = min(maxTimelinePaddingDays, timelineRange.upperBound + newerBy)
        guard newLower != timelineRange.lowerBound || newUpper != timelineRange.upperBound else {
            return
        }
        timelineRange = newLower...newUpper
    }

    private static func initialRange(
        calendar: Calendar,
        padding: Int
    ) -> ClosedRange<Int> {
        _ = calendar
        return (-padding)...padding
    }

    private nonisolated static func cachedScheduleURL() -> URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("schedule_cache.json")
    }
}
