import SwiftUI

struct ContentView: View {
    @StateObject private var store = ScheduleStore()
    @State private var selectedDate = Calendar(identifier: .gregorian)
        .startOfDay(for: Date())
    @State private var isGroupPickerPresented = false
    @State private var isSettingsPresented = false
    @State private var isDatePickerPresented = false
    @State private var scrolledDateID: String?
    @State private var settingsDetent: PresentationDetent = .medium
    @AppStorage("appTheme") private var appTheme: AppTheme = .system

    private static let russianCalendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "ru_RU")
        cal.firstWeekday = 2
        return cal
    }()

    /// ClosedRange для DatePicker и pager (±10 лет).
    private static let pagerDateRange: ClosedRange<Date> = {
        let cal = russianCalendar
        let today = cal.startOfDay(for: Date())
        let start = cal.date(byAdding: .year, value: -10, to: today)!
        let end = cal.date(byAdding: .year, value: 10, to: today)!
        return start...end
    }()

    /// Массив дат для pager.
    private static let pagerDates: [Date] = {
        let cal = russianCalendar
        let today = cal.startOfDay(for: Date())
        let totalDays = 365 * 10
        return (-totalDays...totalDays).compactMap {
            cal.date(byAdding: .day, value: $0, to: today)
        }
    }()

    private let calendar = ContentView.russianCalendar

    var body: some View {
        NavigationStack {
            Group {
                if store.hasSchedule {
                    scheduleView
                } else {
                    onboardingState
                }
            }
            .overlay {
                if store.isLoading {
                    loadingOverlay
                }
            }
            .navigationTitle(store.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if store.hasSchedule {
                    ToolbarItem(placement: .topBarTrailing) {
                        HStack(spacing: 2) {
                            Button {
                                isDatePickerPresented = true
                            } label: {
                                Image(systemName: "calendar")
                            }
                            Button {
                                isSettingsPresented = true
                            } label: {
                                Image(systemName: "gearshape")
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $isDatePickerPresented) {
                datePickerSheet
            }
            .sheet(isPresented: $isSettingsPresented, onDismiss: {
                settingsDetent = .medium
            }) {
                NavigationStack {
                    SettingsView(
                        groupName: store.schedule?.groupName,
                        hasSchedule: store.hasSchedule,
                        selectedSubgroup: $store.selectedSubgroup,
                        isExpanded: settingsDetent == .large,
                        appTheme: $appTheme,
                        onChangeGroup: {
                            isGroupPickerPresented = true
                        },
                        onRefresh: {
                            store.refreshSchedule()
                        },
                        onDeleteSchedule: {
                            store.removeSchedule()
                        }
                    )
                }
                .presentationDetents([.medium, .large], selection: $settingsDetent)
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $isGroupPickerPresented) {
                GroupPickerView(store: store)
            }
            .alert(
                "Ошибка",
                isPresented: Binding(
                    get: { store.errorMessage != nil },
                    set: { newValue in
                        if !newValue { store.errorMessage = nil }
                    }
                )
            ) {
                Button("Ок", role: .cancel) {}
            } message: {
                Text(store.errorMessage ?? "")
            }
        }
        .onAppear { applyTheme(appTheme) }
        .onChange(of: appTheme) { _, newTheme in applyTheme(newTheme) }
    }

    private func applyTheme(_ theme: AppTheme) {
        guard let scene = UIApplication.shared.connectedScenes.first
                as? UIWindowScene else { return }
        for window in scene.windows {
            window.overrideUserInterfaceStyle = theme.userInterfaceStyle
        }
    }

    // MARK: - Date Picker Sheet

    private var datePickerSheet: some View {
        NavigationStack {
            DatePicker(
                "Выберите дату",
                selection: Binding(
                    get: { selectedDate },
                    set: { newDate in
                        withAnimation(.snappy(duration: 0.25)) {
                            selectedDate = calendar.startOfDay(for: newDate)
                        }
                        isDatePickerPresented = false
                    }
                ),
                in: Self.pagerDateRange,
                displayedComponents: [.date]
            )
            .datePickerStyle(.graphical)
            .environment(\.locale, Locale(identifier: "ru_RU"))
            .padding(.horizontal)
            .navigationTitle("Выберите дату")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") {
                        isDatePickerPresented = false
                    }
                }
            }
        }
        .presentationDetents([.height(480)])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Schedule View

    private var scheduleView: some View {
        VStack(spacing: 0) {
            weekStrip
            Divider()
            dayPager
        }
    }

    // MARK: - Week Strip

    private var currentWeekDates: [Date] {
        let components = calendar.dateComponents(
            [.yearForWeekOfYear, .weekOfYear],
            from: selectedDate
        )
        guard let weekStart = calendar.date(from: components) else { return [] }
        return (0..<7).compactMap {
            calendar.date(byAdding: .day, value: $0, to: weekStart)
        }
    }

    private var monthYearTitle: String {
        WeekStripFormatters.monthYear
            .string(from: selectedDate)
            .capitalized
    }

    private var isOnToday: Bool {
        calendar.isDateInToday(selectedDate)
    }

    /// true — сегодня раньше (левее) выбранной даты → кнопка слева.
    private var isTodayBefore: Bool {
        calendar.startOfDay(for: Date()) < selectedDate
    }

    private var todayChip: some View {
        Button {
            goToToday()
        } label: {
            Text("Сегодня")
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    Color.accentColor.opacity(0.15),
                    in: Capsule()
                )
        }
    }

    private var weekStrip: some View {
        VStack(spacing: 10) {
            ZStack {
                Text(monthYearTitle)
                    .font(.subheadline.weight(.semibold))

                HStack {
                    Button {
                        moveWeek(by: -1)
                    } label: {
                        Image(systemName: "chevron.left")
                            .fontWeight(.semibold)
                            .contentShape(Rectangle())
                    }

                    todayChip
                        .opacity(!isOnToday && isTodayBefore ? 1 : 0)
                        .allowsHitTesting(!isOnToday && isTodayBefore)

                    Spacer()

                    todayChip
                        .opacity(!isOnToday && !isTodayBefore ? 1 : 0)
                        .allowsHitTesting(!isOnToday && !isTodayBefore)

                    Button {
                        moveWeek(by: 1)
                    } label: {
                        Image(systemName: "chevron.right")
                            .fontWeight(.semibold)
                            .contentShape(Rectangle())
                    }
                }
                .animation(.easeInOut(duration: 0.2), value: isOnToday)
                .animation(.easeInOut(duration: 0.2), value: isTodayBefore)
            }
            .padding(.horizontal, 20)

            HStack(spacing: 0) {
                ForEach(currentWeekDates, id: \.timeIntervalSince1970) { date in
                    dayButton(for: date)
                }
            }
            .padding(.horizontal, 8)
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private func dayButton(for date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(date)
        let dayNum = calendar.component(.day, from: date)
        let weekdayName = WeekStripFormatters.shortWeekday
            .string(from: date).lowercased()

        Button {
            withAnimation(.snappy(duration: 0.25)) {
                selectedDate = calendar.startOfDay(for: date)
            }
        } label: {
            VStack(spacing: 4) {
                Text(weekdayName)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(isSelected ? .white : .secondary)

                Text("\(dayNum)")
                    .font(
                        .callout
                            .weight(isSelected ? .bold : .semibold)
                            .monospacedDigit()
                    )
                    .foregroundStyle(
                        isSelected
                            ? .white
                            : (isToday ? Color.accentColor : .primary)
                    )
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.accentColor)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func moveWeek(by direction: Int) {
        guard
            let d = calendar.date(
                byAdding: .weekOfYear,
                value: direction,
                to: selectedDate
            )
        else { return }
        let clamped = max(
            Self.pagerDateRange.lowerBound,
            min(d, Self.pagerDateRange.upperBound))
        withAnimation(.snappy(duration: 0.25)) {
            selectedDate = clamped
        }
    }

    private func goToToday() {
        withAnimation(.snappy(duration: 0.25)) {
            selectedDate = calendar.startOfDay(for: Date())
        }
    }

    // MARK: - Day Pager

    private var dateRange: [Date] { Self.pagerDates }

    private var dayPager: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 0) {
                ForEach(dateRange, id: \.dayID) { date in
                    dayPage(for: date)
                        .containerRelativeFrame(.horizontal)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $scrolledDateID)
        .onChange(of: scrolledDateID) { _, newID in
            guard let newID else { return }
            if let date = DateTextFormatters.dayID.date(from: newID) {
                let normalized = calendar.startOfDay(for: date)
                if !calendar.isDate(normalized, inSameDayAs: selectedDate) {
                    selectedDate = normalized
                }
            }
        }
        .onChange(of: selectedDate) { _, newDate in
            let id = newDate.dayID
            if scrolledDateID != id {
                withAnimation {
                    scrolledDateID = id
                }
            }
        }
        .onAppear {
            scrolledDateID = selectedDate.dayID
        }
    }

    private func dayPage(for date: Date) -> some View {
        let entries = store.entries(for: date)

        return ScrollView {
            LazyVStack(spacing: 10) {
                if entries.isEmpty {
                    noLessonsCard
                } else {
                    ForEach(entries) { entry in
                        lessonCard(entry)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 40)
        }
    }

    // MARK: - Lesson Card (kept intact)

    private func lessonCard(_ entry: ScheduleEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(entry.timeString)
                    .font(
                        .system(
                            .subheadline,
                            design: .rounded,
                            weight: .semibold
                        )
                    )
                Spacer()
                Text(entry.classType.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(
                        classTypeColor(for: entry.classType).opacity(0.2),
                        in: Capsule()
                    )
            }

            Text(entry.subject)
                .font(.headline)

            if let teacher = entry.teacher, !teacher.isEmpty {
                Text(teacher)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Label(
                    entry.isRemote
                        ? "Дистанционно" : (entry.room ?? "Дистанционно"),
                    systemImage: entry.isRemote ? "video" : "building.2"
                )
                .font(.footnote)
                .foregroundStyle(.secondary)

                Spacer()

                if entry.subgroup != .all {
                    Text("Подгруппа \(entry.subgroup.rawValue)")
                        .font(.footnote)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.white.opacity(0.14), in: Capsule())
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            .thinMaterial,
            in: RoundedRectangle(cornerRadius: 18, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(.white.opacity(0.2), lineWidth: 1)
        )
    }

    // MARK: - No Lessons Card

    private var noLessonsCard: some View {
        Text("Пар нет")
            .font(.headline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(.white.opacity(0.25), lineWidth: 1)
            )
    }

    // MARK: - Onboarding

    private var onboardingState: some View {
        VStack(spacing: 14) {
            Image(systemName: "person.2.circle")
                .font(.system(size: 34, weight: .medium))

            Text("Нет расписания")
                .font(.title3.weight(.semibold))

            Text("Выберите вашу группу, и приложение загрузит расписание.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                isGroupPickerPresented = true
            } label: {
                Text("Выбрать группу")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .background(
            .ultraThinMaterial,
            in: RoundedRectangle(cornerRadius: 24, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.25), lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.12)
                .ignoresSafeArea()

            VStack(spacing: 10) {
                ProgressView()
                    .progressViewStyle(.circular)
                Text("Загружаю расписание…")
                    .font(.subheadline)
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 18)
            .background(
                .ultraThinMaterial,
                in: RoundedRectangle(cornerRadius: 20, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(.white.opacity(0.25), lineWidth: 1)
            )
        }
        .transition(.opacity)
    }

    // MARK: - Helpers

    private func classTypeColor(for type: ClassType) -> Color {
        switch type {
        case .lecture: return .blue
        case .seminar: return .orange
        case .lab: return .green
        }
    }
}

// MARK: - Group Picker View

private struct GroupPickerView: View {
    @ObservedObject var store: ScheduleStore
    @Environment(\.dismiss) private var dismiss
    @State private var searchText = ""

    private var filteredGroups: [String] {
        if searchText.isEmpty { return store.availableGroups }
        return store.availableGroups.filter {
            $0.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            Group {
                if store.availableGroups.isEmpty && store.isLoadingGroups {
                    ProgressView("Загрузка групп…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if store.availableGroups.isEmpty {
                    ContentUnavailableView(
                        "Нет данных",
                        systemImage: "wifi.slash",
                        description: Text(
                            "Не удалось загрузить список групп.\nПроверьте подключение к интернету."
                        )
                    )
                } else {
                    List(filteredGroups, id: \.self) { group in
                        Button {
                            store.loadSchedule(group: group)
                            dismiss()
                        } label: {
                            Text(group)
                                .foregroundStyle(.primary)
                        }
                    }
                    .searchable(
                        text: $searchText,
                        prompt: "Поиск группы"
                    )
                }
            }
            .navigationTitle("Выберите группу")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Закрыть") { dismiss() }
                }
            }
        }
        .onAppear {
            store.fetchGroups()
        }
    }
}

// MARK: - App Theme

private enum AppTheme: String, CaseIterable {
    case system, light, dark

    var title: String {
        switch self {
        case .system: return "Системная"
        case .light:  return "Светлая"
        case .dark:   return "Тёмная"
        }
    }

    var userInterfaceStyle: UIUserInterfaceStyle {
        switch self {
        case .system: return .unspecified
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

// MARK: - Settings View

private struct SettingsView: View {
    let groupName: String?
    let hasSchedule: Bool
    @Binding var selectedSubgroup: Subgroup
    let isExpanded: Bool
    @Binding var appTheme: AppTheme
    let onChangeGroup: () -> Void
    let onRefresh: () -> Void
    let onDeleteSchedule: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    var body: some View {
        Form {
            Section("Расписание") {
                HStack(spacing: 12) {
                    Image(systemName: "person.2")
                        .foregroundStyle(.blue)
                        .frame(width: 24)
                    Text("Группа")
                    Spacer()
                    Text(groupName ?? "Не выбрана")
                        .foregroundStyle(.secondary)
                }

                Button {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        onChangeGroup()
                    }
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundStyle(.orange)
                            .frame(width: 24)
                        Text("Сменить группу")
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .tint(.primary)

                Button {
                    onRefresh()
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(.green)
                            .frame(width: 24)
                        Text("Обновить расписание")
                    }
                }
                .tint(.primary)

                if hasSchedule {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                                .frame(width: 24)
                            Text("Удалить расписание")
                        }
                    }
                }
            }

            Section("Подгруппа") {
                Picker("Подгруппа", selection: $selectedSubgroup) {
                    ForEach(Subgroup.pickerValues, id: \.rawValue) { subgroup in
                        Text(subgroup.title).tag(subgroup)
                    }
                }
                .pickerStyle(.segmented)
            }

            if isExpanded {
                Section("Оформление") {
                    Picker("Тема", selection: $appTheme) {
                        ForEach(AppTheme.allCases, id: \.self) { theme in
                            Text(theme.title).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Правила пользования") {
                    Link(destination: URL(
                        string: "https://github.com/skyvxl/schedule-parser/blob/main/PRIVACY.md"
                    )!) {
                        HStack(spacing: 12) {
                            Image(systemName: "hand.raised")
                                .foregroundStyle(.blue)
                                .frame(width: 24)
                            Text("Политика конфиденциальности")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    Link(destination: URL(
                        string: "https://github.com/skyvxl/schedule-parser/blob/main/TERMS.md"
                    )!) {
                        HStack(spacing: 12) {
                            Image(systemName: "doc.text")
                                .foregroundStyle(.blue)
                                .frame(width: 24)
                            Text("Условия использования")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                Section {
                    HStack(spacing: 12) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                        Text("Версия")
                        Spacer()
                        Text(appVersion)
                            .foregroundStyle(.secondary)
                    }
                    Link(destination: URL(
                        string: "mailto:skyvxl@icloud.com"
                    )!) {
                        HStack(spacing: 12) {
                            Image(systemName: "envelope")
                                .foregroundStyle(.blue)
                                .frame(width: 24)
                            Text("Обратная связь")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
        .animation(.default, value: isExpanded)
        .navigationTitle("Настройки")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Готово") { dismiss() }
            }
        }
        .alert(
            "Удалить текущее расписание?",
            isPresented: $showDeleteConfirmation
        ) {
            Button("Удалить", role: .destructive) {
                onDeleteSchedule()
                dismiss()
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Вы сможете выбрать новую группу в любой момент.")
        }
    }

}

// MARK: - Formatters

private enum WeekStripFormatters {
    static let monthYear: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "LLLL, yyyy"
        return f
    }()

    static let shortWeekday: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "ru_RU")
        f.dateFormat = "EE"
        return f
    }()
}

private enum DateTextFormatters {
    static let dayID: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
}

extension Subgroup {
    fileprivate static var pickerValues: [Subgroup] {
        [.all, .a, .b]
    }

    fileprivate var title: String {
        switch self {
        case .all: return "Все"
        case .a: return "А"
        case .b: return "Б"
        }
    }
}

extension Date {
    fileprivate var dayID: String {
        DateTextFormatters.dayID.string(from: self)
    }
}
