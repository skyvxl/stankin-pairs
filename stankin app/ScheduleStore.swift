import Foundation
import Observation

@MainActor
@Observable
final class ScheduleStore {
    private(set) var schedule: GroupSchedule? {
        didSet {
            dayEntriesCache.removeAll(keepingCapacity: true)
        }
    }
    var selectedSubgroup: Subgroup = .all {
        didSet {
            guard oldValue != selectedSubgroup else { return }
            dayEntriesCache.removeAll(keepingCapacity: true)
        }
    }
    var errorMessage: String?
    var isLoading = false
    var isLoadingGroups = false
    private(set) var availableGroups: [String] = []
    // @ObservationIgnored prevents cache writes from triggering view re-renders.
    // Without it, every cache-miss write notifies @Observable observers, causing
    // cascading re-renders that accumulate after settings changes.
    @ObservationIgnored
    private var dayEntriesCache: [DayEntriesCacheKey: [ScheduleEntry]] = [:]

    var hasSchedule: Bool {
        schedule != nil
    }

    var navigationTitle: String {
        schedule?.groupName ?? "Расписание"
    }

    var savedGroupName: String? {
        UserDefaults.standard.string(forKey: "selectedGroup")
    }

    init() {
        if AppLaunchContext.shouldResetPersistentState {
            clearPersistedState()
        }

        if let fixtureMode = AppLaunchContext.fixtureMode {
            applyFixture(mode: fixtureMode)
        } else {
            // Load cache off the main thread so file I/O + JSON decode
            // don't block the UI on launch.
            Task { await loadCachedScheduleAsync() }
        }
    }

    func entries(for date: Date) -> [ScheduleEntry] {
        guard let schedule else { return [] }

        let normalizedDate = ScheduleCalendar.russian.startOfDay(for: date)
        let cacheKey = DayEntriesCacheKey(
            day: normalizedDate,
            subgroup: selectedSubgroup
        )

        if let cached = dayEntriesCache[cacheKey] {
            return cached
        }

        let resolved = schedule.forDate(normalizedDate, subgroup: selectedSubgroup)
        dayEntriesCache[cacheKey] = resolved
        return resolved
    }

    func fetchGroupsIfNeeded() async {
        if AppLaunchContext.fixtureMode != nil {
            availableGroups = ScheduleFixtures.availableGroups
            return
        }

        guard availableGroups.isEmpty, !isLoadingGroups else { return }

        isLoadingGroups = true
        defer { isLoadingGroups = false }

        do {
            availableGroups = try await ScheduleAPI.fetchGroups().sorted()
        } catch {
            errorMessage = "Не удалось загрузить список групп"
        }
    }

    func loadSchedule(group: String) async {
        if AppLaunchContext.fixtureMode != nil {
            let result = ScheduleFixtures.schedule(named: group)
            schedule = result
            availableGroups = ScheduleFixtures.availableGroups
            UserDefaults.standard.set(group, forKey: "selectedGroup")
            cacheSchedule(result)
            return
        }

        guard !isLoading else { return }

        isLoading = true
        errorMessage = nil

        defer { isLoading = false }

        do {
            let result = try await ScheduleAPI.fetchSchedule(group: group)
            schedule = result
            UserDefaults.standard.set(group, forKey: "selectedGroup")
            cacheSchedule(result)
        } catch {
            errorMessage =
                "Не удалось загрузить расписание: \(error.localizedDescription)"
        }
    }

    func refreshSchedule() async {
        guard let group = savedGroupName else { return }
        await loadSchedule(group: group)
    }

    func removeSchedule() {
        schedule = nil
        selectedSubgroup = .all
        errorMessage = nil
        UserDefaults.standard.removeObject(forKey: "selectedGroup")

        if let url = cacheURL() {
            try? FileManager.default.removeItem(at: url)
        }

        if AppLaunchContext.fixtureMode != nil {
            availableGroups = ScheduleFixtures.availableGroups
        }
    }
}

private struct DayEntriesCacheKey: Hashable {
    let day: Date
    let subgroup: Subgroup
}

private extension ScheduleStore {
    func applyFixture(mode: LaunchFixtureMode) {
        availableGroups = ScheduleFixtures.availableGroups
        selectedSubgroup = .all
        errorMessage = nil

        switch mode {
        case .empty:
            schedule = nil

        case .schedule:
            let group = savedGroupName ?? "ИДБ-23-02"
            let fixtureSchedule = ScheduleFixtures.schedule(named: group)
            schedule = fixtureSchedule
            UserDefaults.standard.set(group, forKey: "selectedGroup")
        }
    }

    func clearPersistedState() {
        UserDefaults.standard.removeObject(forKey: "selectedGroup")

        if let url = cacheURL() {
            try? FileManager.default.removeItem(at: url)
        }
    }

    func cacheURL() -> URL? {
        guard
            let folder = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first
        else {
            return nil
        }

        try? FileManager.default.createDirectory(
            at: folder,
            withIntermediateDirectories: true
        )

        return folder.appendingPathComponent("schedule_cache.json")
    }

    func cacheSchedule(_ parsed: GroupSchedule) {
        guard let url = cacheURL(),
            let data = GroupSchedule.toJSON(parsed)
        else {
            return
        }

        try? data.write(to: url, options: .atomic)
    }

    func loadCachedScheduleAsync() async {
        guard let url = cacheURL(),
            FileManager.default.fileExists(atPath: url.path)
        else { return }

        // File I/O is the bottleneck — read bytes off the main actor,
        // then decode on main (Codable conformance requires it here).
        let data: Data? = await Task.detached(priority: .userInitiated) {
            try? Data(contentsOf: url)
        }.value

        guard let data, let cached = GroupSchedule.fromJSON(data) else { return }
        schedule = cached
    }
}
