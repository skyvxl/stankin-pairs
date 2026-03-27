import SwiftUI

struct ContentView: View {
    @StateObject private var store = ScheduleStore()
    @Environment(\.colorScheme) private var colorScheme
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
                adaptiveBackground

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
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button {
                            isDatePickerPresented = true
                        } label: {
                            Image(systemName: "calendar")
                        }
                        .accessibilityLabel("Выбрать дату")

                        Button {
                            isSettingsPresented = true
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                        }
                        .accessibilityLabel("Настройки")
                    }
                    .sharedBackgroundVisibility(.visible)
                }
            }
            .sheet(isPresented: $isDatePickerPresented) {
                datePickerSheet
            }
            .sheet(
                isPresented: $isSettingsPresented,
                onDismiss: {
                    settingsDetent = .medium
                }
            ) {
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
                .preferredColorScheme(appTheme.colorScheme)
                .presentationDetents(
                    [.medium, .large],
                    selection: $settingsDetent
                )
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
                .presentationBackground(
                    Color(uiColor: .systemGroupedBackground)
                )
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
        .preferredColorScheme(appTheme.colorScheme)
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
    }

    // MARK: - Schedule View

    private var scheduleView: some View {
        VStack(spacing: 0) {
            weekStrip
            Divider()
                .overlay(
                    Color.primary.opacity(colorScheme == .dark ? 0.12 : 0.06)
                )
            dayPager
        }
    }

    private var adaptiveBackground: some View {
        Color(uiColor: .systemGroupedBackground)
            .ignoresSafeArea()
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
                .background {
                    Capsule()
                        .fill(Color.accentColor.opacity(0.18))
                }
                .overlay(
                    Capsule()
                        .strokeBorder(
                            Color.accentColor.opacity(0.4),
                            lineWidth: 0.5
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private var weekStrip: some View {
        VStack(spacing: 14) {
            ZStack {
                Text(monthYearTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                HStack {
                    weekArrowButton(
                        systemName: "chevron.left",
                        accessibilityLabel: "Предыдущая неделя"
                    ) {
                        moveWeek(by: -1)
                    }

                    todayChip
                        .opacity(!isOnToday && isTodayBefore ? 1 : 0)
                        .allowsHitTesting(!isOnToday && isTodayBefore)

                    Spacer()

                    todayChip
                        .opacity(!isOnToday && !isTodayBefore ? 1 : 0)
                        .allowsHitTesting(!isOnToday && !isTodayBefore)

                    weekArrowButton(
                        systemName: "chevron.right",
                        accessibilityLabel: "Следующая неделя"
                    ) {
                        moveWeek(by: 1)
                    }
                }
                .frame(height: 40)
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
        .padding(.top, 8)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private func dayButton(for date: Date) -> some View {
        let isSelected = calendar.isDate(date, inSameDayAs: selectedDate)
        let isToday = calendar.isDateInToday(date)
        let dayNum = calendar.component(.day, from: date)
        let weekdayName = WeekStripFormatters.shortWeekday
            .string(from: date).lowercased()
        let selectedTextColor: Color = colorScheme == .dark ? .white : .primary
        let selectedSecondaryTextColor: Color =
            colorScheme == .dark
            ? .white.opacity(0.82)
            : .primary.opacity(0.72)

        Button {
            withAnimation(.snappy(duration: 0.25)) {
                selectedDate = calendar.startOfDay(for: date)
            }
        } label: {
            VStack(spacing: 3) {
                Text(weekdayName)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(
                        isSelected ? selectedSecondaryTextColor : .secondary
                    )

                Text("\(dayNum)")
                    .font(
                        .system(size: 18, weight: .bold, design: .rounded)
                            .monospacedDigit()
                    )
                    .foregroundStyle(
                        isSelected
                            ? selectedTextColor
                            : (isToday ? Color.accentColor : .primary)
                    )

                if isToday {
                    Circle()
                        .fill(
                            isSelected
                                ? selectedTextColor.opacity(0.9)
                                : Color.accentColor
                        )
                        .frame(width: 4, height: 4)
                } else {
                    Color.clear
                        .frame(width: 4, height: 4)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(
                            Color.accentColor.opacity(
                                colorScheme == .dark ? 0.42 : 0.18
                            )
                        )
                        .overlay {
                            RoundedRectangle(
                                cornerRadius: 16,
                                style: .continuous
                            )
                            .stroke(
                                Color.accentColor.opacity(
                                    colorScheme == .dark ? 0.55 : 0.26
                                ),
                                lineWidth: 1
                            )
                        }
                        .padding(.horizontal, 2)
                        .padding(.vertical, 1)
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
            min(d, Self.pagerDateRange.upperBound)
        )
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
            if entries.isEmpty {
                noLessonsCard
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 320)
                    .padding(.horizontal, 18)
                    .padding(.top, 12)
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(entries) { entry in
                        lessonCard(entry, on: date)
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Lesson Card (kept intact)

    private func lessonCard(_ entry: ScheduleEntry, on date: Date) -> some View
    {
        let progress = entry.progress(on: date)
        let badgeColor = classTypeColor(for: entry.classType)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
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

                HStack(spacing: 6) {
                    Text(entry.classType.rawValue)
                        .font(.caption.weight(.semibold))
                    if let progress {
                        Text("·")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(badgeColor.opacity(0.65))

                        Text("\(progress.completed)/\(progress.total)")
                            .font(.caption.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(.primary.opacity(0.9))
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background {
                    Capsule()
                        .fill(badgeColor.opacity(0.15))
                }
                .overlay(
                    Capsule()
                        .strokeBorder(
                            badgeColor.opacity(0.3),
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
                    systemImage: entry.isRemote
                        ? "video.fill" : "building.2.fill"
                )
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)

                Spacer()

                if entry.subgroup != .all {
                    Text("Подгруппа \(entry.subgroup.rawValue)")
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background {
                            Capsule()
                                .fill(Color.white.opacity(0.2))
                        }
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    .white.opacity(0.3),
                                    lineWidth: 0.5
                                )
                        )
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.ultraThinMaterial)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.25), lineWidth: 1)
        }
        .compositingGroup()
        .shadow(color: Color.black.opacity(0.07), radius: 6, x: 0, y: 3)
    }

    // MARK: - No Lessons Card

    private var noLessonsCard: some View {
        ContentUnavailableView {
            Label("Пар нет", systemImage: "calendar")
        } description: {
            Text("На этот день занятий нет.")
        }
    }

    // MARK: - Onboarding

    private var onboardingState: some View {
        ContentUnavailableView {
            Label("Нет расписания", systemImage: "calendar.badge.clock")
        } description: {
            Text("Выберите группу, и приложение загрузит расписание.")
        } actions: {
            Button("Выбрать группу") {
                isGroupPickerPresented = true
            }
            .buttonStyle(.glassProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
            .glassEffect(
                .regular,
                in: RoundedRectangle(cornerRadius: 26, style: .continuous)
            )
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }

    // MARK: - Helpers

    @ViewBuilder
    private func weekArrowButton(
        systemName: String,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(.primary)
                .frame(width: 32, height: 32)
                .background {
                    Circle()
                        .fill(.ultraThinMaterial)
                }
                .overlay {
                    Circle()
                        .strokeBorder(.white.opacity(0.25), lineWidth: 0.5)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }

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
                            dismiss()
                            guard group != store.schedule?.groupName else {
                                return
                            }
                            store.loadSchedule(group: group)
                        } label: {
                            HStack(spacing: 12) {
                                Text(group)
                                    .font(.body.weight(.medium))
                                    .foregroundStyle(.primary)

                                Spacer()

                                if group == store.schedule?.groupName {
                                    Image(systemName: "checkmark")
                                        .font(.footnote.weight(.bold))
                                        .foregroundStyle(.tint)
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .searchable(
                        text: $searchText,
                        prompt: "Поиск группы"
                    )
                    .overlay {
                        if !searchText.isEmpty && filteredGroups.isEmpty {
                            ContentUnavailableView.search(text: searchText)
                        }
                    }
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
        case .light: return "Светлая"
        case .dark: return "Тёмная"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
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
        let v =
            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            ?? "1.0"
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

                if hasSchedule {
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
                }

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
                    Link(
                        destination: URL(
                            string:
                                "https://github.com/skyvxl/schedule-parser/blob/main/PRIVACY.md"
                        )!
                    ) {
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
                    Link(
                        destination: URL(
                            string:
                                "https://github.com/skyvxl/schedule-parser/blob/main/TERMS.md"
                        )!
                    ) {
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
                    Link(
                        destination: URL(
                            string: "mailto:skyvxl@icloud.com"
                        )!
                    ) {
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
        .scrollContentBackground(.hidden)
        .background(Color(uiColor: .systemGroupedBackground))
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
