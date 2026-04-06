import SwiftUI

struct GroupPickerView: View {
    @Environment(\.dismiss) private var dismiss

    let store: ScheduleStore
    let onSelect: (String) -> Void

    @State private var searchText = ""

    private var currentGroup: String? {
        store.schedule?.groupName
    }

    private var filteredGroups: [String] {
        let groups = store.availableGroups.filter { $0 != currentGroup }

        guard !searchText.isEmpty else {
            return groups
        }

        return groups.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        ZStack {
            ScheduleBackdrop(style: .sheet)

            List {
                if let currentGroup {
                    Section("Текущая группа") {
                        Button {
                            dismiss()
                        } label: {
                            GroupRow(title: currentGroup, isSelected: true)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section(store.availableGroups.isEmpty ? "" : "Все группы") {
                    content
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: "Поиск группы"
        )
        .overlay {
            if !store.availableGroups.isEmpty && !searchText.isEmpty && filteredGroups.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
        .navigationTitle("Выбор группы")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Закрыть") {
                    dismiss()
                }
                .fontWeight(.semibold)
            }
        }
        .task {
            await store.fetchGroupsIfNeeded()
        }
    }
}

private extension GroupPickerView {
    @ViewBuilder
    var content: some View {
        if store.availableGroups.isEmpty && store.isLoadingGroups {
            HStack(spacing: 12) {
                ProgressView()
                    .progressViewStyle(.circular)

                Text("Загрузка групп…")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 8)
            .listRowSeparator(.hidden)
        } else if store.availableGroups.isEmpty {
            ContentUnavailableView(
                "Нет данных",
                systemImage: "wifi.slash",
                description: Text("Не удалось получить список групп. Проверьте подключение и попробуйте снова.")
            )
            .frame(maxWidth: .infinity)
            .listRowSeparator(.hidden)
        } else {
            ForEach(filteredGroups, id: \.self) { group in
                Button {
                    dismiss()
                    onSelect(group)
                } label: {
                    GroupRow(title: group, isSelected: false)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct GroupRow: View {
    let title: String
    let isSelected: Bool

    var body: some View {
        HStack {
            Text(title)
                .foregroundStyle(.primary)

            Spacer()

            if isSelected {
                Image(systemName: "checkmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
            }
        }
        .contentShape(Rectangle())
    }
}
