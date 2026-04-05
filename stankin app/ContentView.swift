import SwiftUI

struct ContentView: View {
    @State private var store = ScheduleStore()
    @State private var selectedDate: Date
    @State private var activeSheet: ActiveSheet?
    @State private var settingsDetent: PresentationDetent = .medium
    @AppStorage("appTheme") private var appTheme: AppTheme = .system

    private let calendar = ScheduleCalendar.russian

    init() {
        _selectedDate = State(
            initialValue: AppLaunchContext.initialSelectedDate
                ?? ScheduleCalendar.russian.startOfDay(for: Date())
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                ScheduleBackdrop()

                Group {
                    if store.hasSchedule {
                        ScheduleDashboardView(
                            store: store,
                            calendar: calendar,
                            selectedDate: $selectedDate
                        )
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    } else {
                        ScheduleOnboardingView {
                            activeSheet = .groupPicker
                        }
                        .padding(.horizontal, 20)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    }
                }
            }
            .overlay {
                if store.isLoading {
                    ScheduleLoadingOverlay()
                }
            }
            .navigationTitle(store.navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if store.hasSchedule {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button {
                            activeSheet = .datePicker
                        } label: {
                            Image(systemName: "calendar")
                        }
                        .accessibilityLabel("Выбрать дату")

                        Button {
                            activeSheet = .settings
                        } label: {
                            Image(systemName: "slider.horizontal.3")
                        }
                        .accessibilityLabel("Настройки")
                    }
                }
            }
            .sheet(
                item: $activeSheet,
                onDismiss: { settingsDetent = .medium }
            ) { activeSheet in
                switch activeSheet {
                case .datePicker:
                    ScheduleDatePickerSheet(
                        selectedDate: $selectedDate,
                        calendar: calendar
                    )
                    .preferredColorScheme(appTheme.colorScheme)

                case .settings:
                    NavigationStack {
                        SettingsView(
                            groupName: store.schedule?.groupName,
                            hasSchedule: store.hasSchedule,
                            selectedSubgroup: Binding(
                                get: { store.selectedSubgroup },
                                set: { store.selectedSubgroup = $0 }
                            ),
                            appTheme: $appTheme,
                            onChangeGroup: {
                                openGroupPicker(fromSettings: true)
                            },
                            onRefresh: refreshSchedule,
                            onDeleteSchedule: deleteSchedule
                        )
                    }
                    .preferredColorScheme(appTheme.colorScheme)
                    .presentationDetents(
                        [.medium, .large],
                        selection: $settingsDetent
                    )
                    .presentationDragIndicator(.visible)
                    .presentationCornerRadius(36)
                    .presentationBackground(Color(uiColor: .systemGroupedBackground))

                case .groupPicker:
                    NavigationStack {
                        GroupPickerView(
                            store: store,
                            onSelect: selectGroup
                        )
                    }
                    .preferredColorScheme(appTheme.colorScheme)
                    .presentationCornerRadius(36)
                    .presentationBackground(Color(uiColor: .systemGroupedBackground))
                }
            }
            .alert("Ошибка", isPresented: errorBinding) {
                Button("Ок", role: .cancel) {}
            } message: {
                Text(store.errorMessage ?? "")
            }
        }
        .preferredColorScheme(appTheme.colorScheme)
    }
}

private extension ContentView {
    var errorBinding: Binding<Bool> {
        Binding(
            get: { store.errorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    store.errorMessage = nil
                }
            }
        )
    }

    func refreshSchedule() {
        Task {
            await store.refreshSchedule()
        }
    }

    func deleteSchedule() {
        store.removeSchedule()
    }

    func selectGroup(_ group: String) {
        Task {
            await store.loadSchedule(group: group)
        }
    }

    func openGroupPicker(fromSettings: Bool) {
        if fromSettings {
            activeSheet = nil

            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(180))
                activeSheet = .groupPicker
            }
        } else {
            activeSheet = .groupPicker
        }
    }
}

private struct ScheduleDatePickerSheet: View {
    @Environment(\.dismiss) private var dismiss

    @Binding var selectedDate: Date

    let calendar: Calendar

    var body: some View {
        NavigationStack {
            ZStack {
                ScheduleBackdrop(style: .sheet)

                DatePicker(
                    "Выберите дату",
                    selection: $selectedDate,
                    in: ScheduleCalendar.pagerDateRange,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .environment(\.locale, Locale(identifier: "ru_RU"))
                .labelsHidden()
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .navigationTitle("Дата")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    SheetToolbarTextButton(title: "Готово") {
                        selectedDate = calendar.startOfDay(for: selectedDate)
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.height(520)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(36)
        .presentationBackground(Color(uiColor: .systemGroupedBackground))
    }
}

private enum ActiveSheet: String, Identifiable {
    case datePicker
    case settings
    case groupPicker

    var id: String {
        rawValue
    }
}

#Preview {
    ContentView()
}
