import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    let groupName: String?
    let hasSchedule: Bool

    @Binding var selectedSubgroup: Subgroup
    @Binding var appTheme: AppTheme

    let onChangeGroup: () -> Void
    let onRefresh: () -> Void
    let onDeleteSchedule: () -> Void

    @State private var showDeleteConfirmation = false

    private var appVersion: String {
        let version =
            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
            ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    var body: some View {
        ZStack {
            ScheduleBackdrop(style: .sheet)

            List {
                scheduleSection
                subgroupSection
                appearanceSection
                legalSection
                aboutSection
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Настройки")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                SheetToolbarTextButton(title: "Готово") {
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
            Text("Вы сможете выбрать новую группу в любой момент.")
        }
    }
}

private extension SettingsView {
    var scheduleSection: some View {
        Section {
            SettingsValueRow(
                title: "Группа",
                value: groupName ?? "Не выбрана",
                systemImage: "person.2.fill",
                tint: .blue
            )

            Button(action: changeGroup) {
                SettingsRowLabel(
                    title: "Сменить группу",
                    systemImage: "arrow.triangle.2.circlepath",
                    tint: .orange
                )
            }
            .foregroundStyle(.primary)

            if hasSchedule {
                Button(action: refreshSchedule) {
                    SettingsRowLabel(
                        title: "Обновить расписание",
                        systemImage: "arrow.clockwise",
                        tint: .green
                    )
                }
                .foregroundStyle(.primary)

                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    SettingsRowLabel(
                        title: "Удалить расписание",
                        systemImage: "trash",
                        tint: .red
                    )
                }
            }
        } header: {
            Text("Расписание")
        }
    }

    var subgroupSection: some View {
        Section {
            Picker("Подгруппа", selection: $selectedSubgroup) {
                ForEach(Subgroup.pickerValues, id: \.rawValue) { subgroup in
                    Text(subgroup.title).tag(subgroup)
                }
            }
            .pickerStyle(.segmented)
        } header: {
            Text("Подгруппа")
        } footer: {
            Text("Фильтр применяется только к текущей группе.")
        }
    }

    var appearanceSection: some View {
        Section("Оформление") {
            Picker("Тема", selection: $appTheme) {
                ForEach(AppTheme.allCases) { theme in
                    Text(theme.title).tag(theme)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    var legalSection: some View {
        Section("Документы") {
            Link(destination: URL(string: "https://github.com/skyvxl/schedule-parser/blob/main/PRIVACY.md")!) {
                SettingsLinkLabel(
                    title: "Политика конфиденциальности",
                    systemImage: "hand.raised.fill",
                    tint: .blue
                )
            }

            Link(destination: URL(string: "https://github.com/skyvxl/schedule-parser/blob/main/TERMS.md")!) {
                SettingsLinkLabel(
                    title: "Условия использования",
                    systemImage: "doc.text.fill",
                    tint: .blue
                )
            }
        }
    }

    var aboutSection: some View {
        Section("О приложении") {
            LabeledContent("Версия", value: appVersion)

            Link(destination: URL(string: "mailto:skyvxl@icloud.com")!) {
                SettingsLinkLabel(
                    title: "Обратная связь",
                    systemImage: "envelope.fill",
                    tint: .green
                )
            }
        }
    }

    func changeGroup() {
        dismiss()
        onChangeGroup()
    }

    func refreshSchedule() {
        onRefresh()
        dismiss()
    }
}

// MARK: - Row Components

private struct SettingsLinkLabel: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 14) {
            SettingsIcon(systemImage: systemImage, tint: tint)

            Text(title)
                .foregroundStyle(.primary)

            Spacer(minLength: 8)

            Image(systemName: "arrow.up.right")
                .font(.caption.weight(.bold))
                .foregroundStyle(.tertiary)
        }
    }
}

private struct SettingsRowLabel: View {
    let title: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 14) {
            SettingsIcon(systemImage: systemImage, tint: tint)

            Text(title)
                .foregroundStyle(.primary)
        }
    }
}

private struct SettingsValueRow: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        HStack(spacing: 14) {
            SettingsIcon(systemImage: systemImage, tint: tint)

            Text(title)

            Spacer(minLength: 8)

            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}

private struct SettingsIcon: View {
    let systemImage: String
    let tint: Color

    var body: some View {
        Image(systemName: systemImage)
            .foregroundStyle(.white)
            .font(.system(size: 13, weight: .semibold))
            .frame(width: 28, height: 28)
            .background(tint, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
    }
}
