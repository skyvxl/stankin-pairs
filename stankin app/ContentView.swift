import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var store = ScheduleStore()
    @State private var isImporterPresented = false
    @State private var isSettingsPresented = false
    @State private var timelineAnchorDate = Calendar(identifier: .gregorian)
        .startOfDay(for: Date())
    @State private var didInitialScroll = false
    @State private var visibleOffsets: Set<Int> = []
    @State private var canPrefetch = false

    private let calendar = Calendar(identifier: .gregorian)

    var body: some View {
        NavigationStack {
            ZStack {
                glassBackground

                if store.hasSchedule {
                    timelineBody
                } else {
                    onboardingState
                }

                if store.isImporting {
                    importingOverlay
                }
            }
            .navigationTitle(store.navigationTitle)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                if store.hasSchedule {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            isSettingsPresented = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                        .disabled(store.isImporting)
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

    private var timelineBody: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(store.timelineOffsets, id: \.self) { offset in
                        let date = store.date(
                            forOffset: offset,
                            anchor: timelineAnchorDate
                        )
                        daySection(for: date)
                            .id(date.dayID)
                            .onAppear {
                                visibleOffsets.insert(offset)
                                if canPrefetch {
                                    store.prefetchAround(offset: offset)
                                }
                            }
                            .onDisappear {
                                visibleOffsets.remove(offset)
                            }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 96)
            }
            .overlay(alignment: .bottomTrailing) {
                if shouldShowTodayButton {
                    todayFloatingButton {
                        scrollToToday(proxy: proxy, animated: true)
                    }
                    .padding(.trailing, 18)
                    .padding(.bottom, 20)
                }
            }
            .onAppear {
                guard !didInitialScroll else { return }
                didInitialScroll = true
                timelineAnchorDate = calendar.startOfDay(for: Date())
                visibleOffsets.removeAll()
                canPrefetch = false
                store.bootstrapTimeline(anchor: timelineAnchorDate)
                DispatchQueue.main.async {
                    scrollToToday(proxy: proxy, animated: false)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        canPrefetch = true
                    }
                }
            }
        }
    }

    private var shouldShowTodayButton: Bool {
        guard let focusedOffset = visibleOffsets.min(by: { abs($0) < abs($1) }) else {
            return false
        }
        let focusedDate = store.date(forOffset: focusedOffset, anchor: timelineAnchorDate)
        return !calendar.isDate(focusedDate, equalTo: Date(), toGranularity: .weekOfYear)
    }

    private var todayDayNumber: String {
        String(calendar.component(.day, from: Date()))
    }

    private func todayFloatingButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(todayDayNumber)
                .font(.headline.monospacedDigit().weight(.semibold))
                .foregroundStyle(.primary)
                .frame(width: 48, height: 48)
                .background(.regularMaterial, in: Circle())
                .overlay(
                    Circle()
                        .strokeBorder(.white.opacity(0.28), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Перейти к сегодняшней дате")
    }

    private func daySection(for date: Date) -> some View {
        let entries = store.entries(for: date)

        return VStack(alignment: .leading, spacing: 10) {
            Text(date.fullDayTitle)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)

            if entries.isEmpty {
                noLessonsCard
            } else {
                ForEach(entries) { entry in
                    lessonCard(entry)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
    }

    private var noLessonsCard: some View {
        VStack(spacing: 6) {
            Text("Пар нет")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.25), lineWidth: 1)
        )
    }

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

    private var glassBackground: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.91, green: 0.96, blue: 1.0),
                    Color(red: 0.86, green: 0.92, blue: 0.98),
                    Color(red: 0.94, green: 0.97, blue: 0.99),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            Circle()
                .fill(Color.cyan.opacity(0.22))
                .frame(width: 260)
                .blur(radius: 40)
                .offset(x: -120, y: -260)

            Circle()
                .fill(Color.blue.opacity(0.16))
                .frame(width: 300)
                .blur(radius: 40)
                .offset(x: 140, y: 260)
        }
    }

    private func classTypeColor(for type: ClassType) -> Color {
        switch type {
        case .lecture: return .blue
        case .seminar: return .orange
        case .lab: return .green
        }
    }

    private func scrollToToday(proxy: ScrollViewProxy, animated: Bool) {
        let todayID = Date().dayID
        if animated {
            withAnimation(.easeInOut(duration: 0.2)) {
                proxy.scrollTo(todayID, anchor: .top)
            }
        } else {
            proxy.scrollTo(todayID, anchor: .top)
        }
    }
}

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
        .confirmationDialog("Удалить текущее расписание?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
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
