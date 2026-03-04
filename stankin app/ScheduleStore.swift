import Combine
import Foundation

@MainActor
final class ScheduleStore: ObservableObject {
    @Published private(set) var schedule: GroupSchedule?
    @Published var selectedSubgroup: Subgroup = .all
    @Published var errorMessage: String?
    @Published var isLoading = false
    @Published var isLoadingGroups = false
    @Published var availableGroups: [String] = []

    var hasSchedule: Bool { schedule != nil }

    var navigationTitle: String {
        schedule?.groupName ?? "Расписание"
    }

    var savedGroupName: String? {
        UserDefaults.standard.string(forKey: "selectedGroup")
    }

    init() {
        loadCachedSchedule()
    }

    func entries(for date: Date) -> [ScheduleEntry] {
        schedule?.forDate(date, subgroup: selectedSubgroup) ?? []
    }

    // MARK: - Загрузка списка групп

    func fetchGroups() {
        guard availableGroups.isEmpty else { return }
        isLoadingGroups = true

        Task {
            do {
                let groups = try await ScheduleAPI.fetchGroups()
                availableGroups = groups.sorted()
            } catch {
                errorMessage = "Не удалось загрузить список групп"
            }
            isLoadingGroups = false
        }
    }

    // MARK: - Выбор группы → загрузка расписания

    func loadSchedule(group: String) {
        isLoading = true
        errorMessage = nil

        Task {
            do {
                let result = try await ScheduleAPI.fetchSchedule(group: group)
                schedule = result
                UserDefaults.standard.set(group, forKey: "selectedGroup")
                cacheSchedule(result)
            } catch {
                errorMessage =
                    "Не удалось загрузить расписание: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }

    // MARK: - Обновить текущее расписание

    func refreshSchedule() {
        guard let group = savedGroupName else { return }
        loadSchedule(group: group)
    }

    // MARK: - Удаление

    func removeSchedule() {
        schedule = nil
        selectedSubgroup = .all
        errorMessage = nil
        UserDefaults.standard.removeObject(forKey: "selectedGroup")

        if let url = cacheURL() {
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - Кэш

    private func cacheURL() -> URL? {
        guard
            let folder = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first
        else { return nil }

        try? FileManager.default.createDirectory(
            at: folder, withIntermediateDirectories: true)
        return folder.appendingPathComponent("schedule_cache.json")
    }

    private func cacheSchedule(_ parsed: GroupSchedule) {
        guard let url = cacheURL(),
            let data = GroupSchedule.toJSON(parsed)
        else { return }
        try? data.write(to: url, options: .atomic)
    }

    private func loadCachedSchedule() {
        guard let url = cacheURL(),
            FileManager.default.fileExists(atPath: url.path)
        else { return }

        if let data = try? Data(contentsOf: url),
            let cached = GroupSchedule.fromJSON(data)
        {
            schedule = cached
        }
    }
}
