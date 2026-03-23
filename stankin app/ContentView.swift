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
            ZStack {
                // Subtle background gradient
                LinearGradient(
                    colors: [
                        Color.primary.opacity(0.02),
                        Color.primary.opacity(0.0)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                Group {
                    if store.hasSchedule {
                        scheduleView
                    } else {
                        onboardingState
                    }
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
                        HStack(spacing: 8) {
                            Button {
                                isDatePickerPresented = true
                            } label: {
                                Image(systemName: "calendar")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.primary)
                                    .frame(width: 36, height: 36)
                                    .background(
                                        Circle()
                                            .fill(.ultraThinMaterial)
                                    )
                                    .overlay(
                                        Circle()
                                            .strokeBorder(.white.opacity(0.25), lineWidth: 0.5)
                                    )
                                    .shadow(color: .black.opacity(0.04), radius: 3, x: 0, y: 1)
                            }
                            .buttonStyle(.plain)

                            Button {
                                isSettingsPresented = true
                            } label: {
                                Image(systemName: "gearshape.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.primary)
                                    .frame(width: 36, height: 36)
                                    .background(
                                        Circle()
                                            .fill(.ultraThinMaterial)
                                    )
                                    .overlay(
                                        Circle()
                                            .strokeBorder(.white.opacity(0.25), lineWidth: 0.5)
                                    )
                                    .shadow(color: .black.opacity(0.04), radius: 3, x: 0, y: 1)
                            }
                            .buttonStyle(.plain)
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
                .presentationCornerRadius(28)
                .presentationBackground(.regularMaterial)
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
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .navigationTitle("Выберите дату")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isDatePickerPresented = false
                    } label: {
                        Text("Готово")
                            .font(.body.weight(.semibold))
                    }
                }
            }
        }
        .presentationDetents([.height(480)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        .presentationBackground(.regularMaterial)
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
                .font(.caption.weight(.bold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    ZStack {
                        Color.accentColor.opacity(0.2)
                        Color.accentColor.opacity(0.1)
                            .blur(radius: 4)
                    },
                    in: Capsule()
                )
                .overlay(
                    Capsule()
                        .strokeBorder(
                            Color.accentColor.opacity(0.4),
                            lineWidth: 0.5
                        )
                )
                .shadow(color: Color.accentColor.opacity(0.15), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }

    private var weekStrip: some View {
        VStack(spacing: 12) {
            ZStack {
                Text(monthYearTitle)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)

                HStack {
                    Button {
                        moveWeek(by: -1)
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.primary)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
                            )
                            .overlay(
                                Circle()
                                    .strokeBorder(.white.opacity(0.3), lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(.plain)

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
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.primary)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(.ultraThinMaterial)
                                    .shadow(color: .black.opacity(0.06), radius: 4, x: 0, y: 2)
                            )
                            .overlay(
                                Circle()
                                    .strokeBorder(.white.opacity(0.3), lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(.plain)
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
        .padding(.vertical, 10)
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
                    .font(.caption2.weight(.semibold))
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
            .padding(.vertical, 10)
            .background {
                if isSelected {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.accentColor,
                                        Color.accentColor.opacity(0.85)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.white.opacity(0.15))
                            .blur(radius: 2)
                    }
                    .shadow(color: Color.accentColor.opacity(0.4), radius: 8, x: 0, y: 4)
                    .shadow(color: Color.accentColor.opacity(0.2), radius: 2, x: 0, y: 1)
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
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text(entry.timeString)
                    .font(
                        .system(
                            .subheadline,
                            design: .rounded,
                            weight: .bold
                        )
                    )
                    .foregroundStyle(.primary)
                Spacer()
                Text(entry.classType.rawValue)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        ZStack {
                            classTypeColor(for: entry.classType).opacity(0.15)
                            classTypeColor(for: entry.classType).opacity(0.08)
                                .blur(radius: 4)
                        },
                        in: Capsule()
                    )
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                classTypeColor(for: entry.classType).opacity(0.3),
                                lineWidth: 0.5
                            )
                    )
            }

            Text(entry.subject)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)

            if let teacher = entry.teacher, !teacher.isEmpty {
                Text(teacher)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Label(
                    entry.isRemote
                        ? "Дистанционно" : (entry.room ?? "Дистанционно"),
                    systemImage: entry.isRemote ? "video.fill" : "building.2.fill"
                )
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)

                Spacer()

                if entry.subgroup != .all {
                    Text("Подгруппа \(entry.subgroup.rawValue)")
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(
                            ZStack {
                                Color.white.opacity(0.18)
                                Color.white.opacity(0.08)
                                    .blur(radius: 3)
                            },
                            in: Capsule()
                        )
                        .overlay(
                            Capsule()
                                .strokeBorder(.white.opacity(0.3), lineWidth: 0.5)
                        )
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.05),
                                Color.white.opacity(0.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.4),
                            Color.white.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 4)
        .shadow(color: Color.black.opacity(0.03), radius: 2, x: 0, y: 1)
    }

    // MARK: - No Lessons Card

    private var noLessonsCard: some View {
        Text("Пар нет")
            .font(.headline.weight(.semibold))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.03),
                                    Color.white.opacity(0.0)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.35),
                                Color.white.opacity(0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
    }

    // MARK: - Onboarding

    private var onboardingState: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.circle.fill")
                .font(.system(size: 48, weight: .medium))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .blue.opacity(0.7)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)

            Text("Нет расписания")
                .font(.title3.weight(.bold))

            Text("Выберите вашу группу, и приложение загрузит расписание.")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                isGroupPickerPresented = true
            } label: {
                Text("Выбрать группу")
                    .font(.body.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 2)
            }
            .buttonStyle(.borderedProminent)
            .shadow(color: Color.accentColor.opacity(0.25), radius: 8, x: 0, y: 4)
        }
        .padding(28)
        .frame(maxWidth: .infinity)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.05),
                                Color.white.opacity(0.0)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.4),
                            Color.white.opacity(0.15)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.5
                )
        )
        .shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 6)
        .shadow(color: Color.black.opacity(0.03), radius: 4, x: 0, y: 2)
        .padding(.horizontal, 20)
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.2)
                .ignoresSafeArea()
                .background(.ultraThinMaterial)

            VStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(1.1)
                Text("Загружаю расписание…")
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(.regularMaterial)
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.08),
                                    Color.white.opacity(0.0)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.5),
                                Color.white.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1.5
                    )
            )
            .shadow(color: Color.black.opacity(0.15), radius: 20, x: 0, y: 10)
            .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 3)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
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
                        .font(.subheadline.weight(.semibold))
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
                                .font(.body.weight(.medium))
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
                    Button {
                        dismiss()
                    } label: {
                        Text("Закрыть")
                            .font(.body.weight(.semibold))
                    }
                }
            }
        }
        .presentationCornerRadius(28)
        .presentationBackground(.regularMaterial)
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
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.blue)
                        .frame(width: 28)
                    Text("Группа")
                        .font(.body.weight(.medium))
                    Spacer()
                    Text(groupName ?? "Не выбрана")
                        .font(.body.weight(.medium))
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
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.orange)
                            .frame(width: 28)
                        Text("Сменить группу")
                            .font(.body.weight(.medium))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
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
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.green)
                            .frame(width: 28)
                        Text("Обновить расписание")
                            .font(.body.weight(.medium))
                    }
                }
                .tint(.primary)

                if hasSchedule {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "trash.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.red)
                                .frame(width: 28)
                            Text("Удалить расписание")
                                .font(.body.weight(.medium))
                        }
                    }
                }
            }

            Section("Подгруппа") {
                Picker("Подгруппа", selection: $selectedSubgroup) {
                    ForEach(Subgroup.pickerValues, id: \.rawValue) { subgroup in
                        Text(subgroup.title)
                            .font(.body.weight(.semibold))
                            .tag(subgroup)
                    }
                }
                .pickerStyle(.segmented)
            }

            if isExpanded {
                Section("Оформление") {
                    Picker("Тема", selection: $appTheme) {
                        ForEach(AppTheme.allCases, id: \.self) { theme in
                            Text(theme.title)
                                .font(.body.weight(.semibold))
                                .tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Правила пользования") {
                    Link(destination: URL(
                        string: "https://github.com/skyvxl/schedule-parser/blob/main/PRIVACY.md"
                    )!) {
                        HStack(spacing: 12) {
                            Image(systemName: "hand.raised.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.blue)
                                .frame(width: 28)
                            Text("Политика конфиденциальности")
                                .font(.body.weight(.medium))
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    Link(destination: URL(
                        string: "https://github.com/skyvxl/schedule-parser/blob/main/TERMS.md"
                    )!) {
                        HStack(spacing: 12) {
                            Image(systemName: "doc.text.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.blue)
                                .frame(width: 28)
                            Text("Условия использования")
                                .font(.body.weight(.medium))
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                Section("О приложении") {
                    HStack(spacing: 12) {
                        Image(systemName: "info.circle.fill")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .frame(width: 28)
                        Text("Версия")
                            .font(.body.weight(.medium))
                        Spacer()
                        Text(appVersion)
                            .font(.body.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    Link(destination: URL(
                        string: "mailto:skyvxl@icloud.com"
                    )!) {
                        HStack(spacing: 12) {
                            Image(systemName: "envelope.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.blue)
                                .frame(width: 28)
                            Text("Обратная связь")
                                .font(.body.weight(.medium))
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption.weight(.bold))
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
                Button {
                    dismiss()
                } label: {
                    Text("Готово")
                        .font(.body.weight(.semibold))
                }
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
