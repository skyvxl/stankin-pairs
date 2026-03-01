import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var store = ScheduleStore()
    @State private var isImporterPresented = false
    @State private var showDeleteConfirmation = false

    var body: some View {
        NavigationStack {
            ZStack {
                glassBackground

                ScrollView {
                    VStack(spacing: 16) {
                        headerCard
                        controlsCard

                        if store.scope == .day {
                            dayAgenda
                        } else {
                            weekAgenda
                        }
                    }
                    .padding(.horizontal, 16)
                        .padding(.bottom, 20)
                }

                if store.isImporting {
                    importingOverlay
                }
            }
            .navigationTitle("Расписание")
            .toolbar {
                if store.schedule != nil {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("Удалить", systemImage: "trash")
                        }
                        .disabled(store.isImporting)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isImporterPresented = true
                    } label: {
                        Label(
                            store.schedule == nil ? "Загрузить PDF" : "Заменить PDF",
                            systemImage: "doc.viewfinder"
                        )
                    }
                    .disabled(store.isImporting)
                }
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
            .confirmationDialog("Удалить текущее расписание?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Удалить", role: .destructive) {
                    store.removeSchedule()
                }
                Button("Отмена", role: .cancel) {}
            } message: {
                Text("После удаления можно сразу загрузить новый PDF.")
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

    private var headerCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(store.schedule?.groupName ?? "Расписание не загружено")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)

            Text(store.selectedDateTitle.capitalized)
                .font(.headline)
                .foregroundStyle(.secondary)

            if store.schedule == nil {
                Text("Нажми «Загрузить PDF», выбери файл расписания, приложение распарсит его и сохранит локально.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button {
                    isImporterPresented = true
                } label: {
                    Label("Выбрать PDF", systemImage: "doc.viewfinder")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(.blue.gradient, in: Capsule())
                        .foregroundStyle(.white)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.25), lineWidth: 1)
        )
    }

    private var controlsCard: some View {
        VStack(spacing: 12) {
            Picker("Режим", selection: $store.scope) {
                ForEach(ScheduleStore.Scope.allCases) { scope in
                    Text(scope.rawValue).tag(scope)
                }
            }
            .pickerStyle(.segmented)

            Picker("Подгруппа", selection: $store.selectedSubgroup) {
                ForEach(Subgroup.pickerValues, id: \.rawValue) { subgroup in
                    Text(subgroup.title).tag(subgroup)
                }
            }
            .pickerStyle(.segmented)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(store.weekdayPills(), id: \.self) { day in
                        let isSelected = Calendar.current.isDate(day, inSameDayAs: store.selectedDate)
                        Button {
                            store.selectedDate = day
                        } label: {
                            VStack(spacing: 2) {
                                Text(day.weekdayShort)
                                    .font(.caption)
                                Text(day.dayNumber)
                                    .font(.headline)
                            }
                            .foregroundStyle(isSelected ? .white : .primary)
                            .frame(width: 54, height: 54)
                            .background(
                                Group {
                                    if isSelected {
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(.blue.gradient)
                                    } else {
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .fill(.ultraThinMaterial)
                                    }
                                }
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .strokeBorder(.white.opacity(0.22), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(14)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(.white.opacity(0.2), lineWidth: 1)
        )
    }

    private var dayAgenda: some View {
        LazyVStack(spacing: 10) {
            let entries = store.entriesForSelectedDate
            if entries.isEmpty {
                emptyState(text: "На выбранный день пар нет")
            } else {
                ForEach(entries) { entry in
                    lessonCard(entry)
                }
            }
        }
    }

    private var weekAgenda: some View {
        LazyVStack(spacing: 10) {
            ForEach(store.weekdayPills(), id: \.self) { day in
                let entries = store.entries(for: day)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(day.fullWeekday)
                            .font(.headline)
                        Spacer()
                        Text("\(entries.count) пар")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if entries.isEmpty {
                        Text("Свободный день")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(entries.prefix(3)) { entry in
                            Text("• \(entry.timeString) · \(entry.subject)")
                                .font(.subheadline)
                                .lineLimit(2)
                        }
                        if entries.count > 3 {
                            Text("Ещё \(entries.count - 3) пары")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(14)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .strokeBorder(.white.opacity(0.2), lineWidth: 1)
                )
            }
        }
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

    private func emptyState(text: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: "calendar.badge.checkmark")
                .font(.title3)
            Text(text)
                .font(.subheadline)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity)
        .padding(22)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
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
    var weekdayShort: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "EE"
        return formatter.string(from: self).capitalized
    }

    var fullWeekday: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "EEEE, d MMM"
        return formatter.string(from: self).capitalized
    }

    var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: self)
    }
}
