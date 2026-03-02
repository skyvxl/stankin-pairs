import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var store = ScheduleStore()
    @State private var selectedDate = Calendar(identifier: .gregorian)
        .startOfDay(for: Date())
    @State private var isImporterPresented = false
    @State private var isSettingsPresented = false

    private static let russianCalendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.locale = Locale(identifier: "ru_RU")
        cal.firstWeekday = 2
        return cal
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
                if store.isImporting {
                    importingOverlay
                }
            }
            .navigationTitle(store.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if store.hasSchedule {
                    ToolbarItem(placement: .topBarTrailing) {
                        HStack(spacing: 2) {
                            Button {
                                goToToday()
                            } label: {
                                Image(systemName: "calendar")
                            }
                            Button {
                                isSettingsPresented = true
                            } label: {
                                Image(systemName: "gearshape")
                            }
                            .disabled(store.isImporting)
                        }
                    }
                }
            }
            .sheet(isPresented: $isSettingsPresented) {
                NavigationStack {
                    SettingsView(
                        groupName: store.schedule?.groupName,
                        hasSchedule: store.hasSchedule,
                        isImporting: store.isImporting,
                        selectedSubgroup: $store.selectedSubgroup,
                        onImportPDF: {
                            isImporterPresented = true
                        },
                        onDeleteSchedule: {
                            store.removeSchedule()
                        }
                    )
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .fileImporter(
                isPresented: $isImporterPresented,
                allowedContentTypes: [.pdf],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let files):
                    guard let first = files.first else { return }
                    store.importSchedule(from: first)
                case .failure(let error):
                    store.errorMessage = "Не удалось открыть файл: \(error.localizedDescription)"
                }
            }
            .alert("Ошибка", isPresented: Binding(
                get: { store.errorMessage != nil },
                set: { newValue in
                    if !newValue {
                        store.errorMessage = nil
                    }
                }
            )) {
                Button("Ок", role: .cancel) {}
            } message: {
                Text(store.errorMessage ?? "")
            }
        }
    }

    // MARK: - Schedule View

    private var scheduleView: some View {
        VStack(spacing: 0) {
            weekStrip
            Divider()
            daySchedule
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

    private var weekStrip: some View {
        VStack(spacing: 10) {
            HStack {
                Button { moveWeek(by: -1) } label: {
                    Image(systemName: "chevron.left")
                        .fontWeight(.semibold)
                        .contentShape(Rectangle())
                }

                Spacer()

                Text(monthYearTitle)
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Button { moveWeek(by: 1) } label: {
                    Image(systemName: "chevron.right")
                        .fontWeight(.semibold)
                        .contentShape(Rectangle())
                }
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
        guard let d = calendar.date(
            byAdding: .weekOfYear,
            value: direction,
            to: selectedDate
        ) else { return }
        withAnimation(.snappy(duration: 0.25)) {
            selectedDate = d
        }
    }

    private func goToToday() {
        withAnimation(.snappy(duration: 0.25)) {
            selectedDate = calendar.startOfDay(for: Date())
        }
    }

    // MARK: - Day Schedule

    private var dayTitle: String {
        if calendar.isDateInToday(selectedDate) {
            return "Сегодня"
        }
        if calendar.isDateInTomorrow(selectedDate) {
            return "Завтра"
        }
        if calendar.isDateInYesterday(selectedDate) {
            return "Вчера"
        }
        return selectedDate.fullDayTitle
    }

    private var daySchedule: some View {
        let entries = store.entries(for: selectedDate)

        return ScrollView {
            LazyVStack(spacing: 10) {
                Text(dayTitle)
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 12)

                if entries.isEmpty {
                    noLessonsCard
                } else {
                    ForEach(entries) { entry in
                        lessonCard(entry)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 40)
        }
        .id(selectedDate.dayID)
    }

    // MARK: - Lesson Card (kept intact)

    private func lessonCard(_ entry: ScheduleEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(entry.timeString)
                    .font(.system(.subheadline, design: .rounded, weight: .semibold))
                Spacer()
                Text(entry.classType.rawValue)
                    .font(.caption)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(classTypeColor(for: entry.classType).opacity(0.2), in: Capsule())
            }

            Text(entry.subject)
                .font(.headline)

            if let teacher = entry.teacher, !teacher.isEmpty {
                Text(teacher)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Label(entry.isRemote ? "Дистанционно" : (entry.room ?? "Дистанционно"), systemImage: entry.isRemote ? "video" : "building.2")
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
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(.white.opacity(0.25), lineWidth: 1)
            )
    }

    // MARK: - Onboarding

    private var onboardingState: some View {
        VStack(spacing: 14) {
            Image(systemName: "doc.viewfinder")
                .font(.system(size: 34, weight: .medium))

            Text("Нет расписания")
                .font(.title3.weight(.semibold))

            Text("Добавьте PDF-файл с расписанием, и приложение сразу покажет пары.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                isImporterPresented = true
            } label: {
                Text("Добавить расписание")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(22)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.25), lineWidth: 1)
        )
        .padding(.horizontal, 16)
    }

    // MARK: - Importing Overlay

    private var importingOverlay: some View {
        ZStack {
            Color.black.opacity(0.12)
                .ignoresSafeArea()

            VStack(spacing: 10) {
                ProgressView()
                    .progressViewStyle(.circular)
                Text("Распознаю PDF…")
                    .font(.subheadline)
            }
            .padding(.horizontal, 26)
            .padding(.vertical, 18)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
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

// MARK: - Settings View

private struct SettingsView: View {
    let groupName: String?
    let hasSchedule: Bool
    let isImporting: Bool
    @Binding var selectedSubgroup: Subgroup
    let onImportPDF: () -> Void
    let onDeleteSchedule: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirmation = false

    var body: some View {
        Form {
            Section("Расписание") {
                HStack {
                    Text("Группа")
                    Spacer()
                    Text(groupName ?? "Не загружено")
                        .foregroundStyle(.secondary)
                }

                Button {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                        onImportPDF()
                    }
                } label: {
                    Label(hasSchedule ? "Заменить PDF" : "Загрузить PDF", systemImage: "doc.viewfinder")
                }
                .disabled(isImporting)

                if hasSchedule {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Удалить расписание", systemImage: "trash")
                            .foregroundStyle(.red)
                    }
                    .disabled(isImporting)
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
        }
        .navigationTitle("Настройки")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Готово") {
                    dismiss()
                }
            }
        }
        .alert("Удалить текущее расписание?", isPresented: $showDeleteConfirmation) {
            Button("Удалить", role: .destructive) {
                onDeleteSchedule()
                dismiss()
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Вы сможете загрузить новое PDF в любой момент.")
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

    static let fullDay: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "EEEE, d MMMM"
        return formatter
    }()
}

private extension Subgroup {
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

private extension Date {
    var dayID: String {
        DateTextFormatters.dayID.string(from: self)
    }

    var fullDayTitle: String {
        DateTextFormatters.fullDay.string(from: self).capitalized
    }
}
