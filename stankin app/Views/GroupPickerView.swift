import SwiftUI
import UIKit

struct GroupPickerView: View {
    @Environment(\.dismiss) private var dismiss

    let store: ScheduleStore
    let onSelect: (String) -> Void

    @State private var searchText = ""

    private var currentGroup: String? {
        store.schedule?.groupName
    }

    private var filteredGroups: [String] {
        let groups = store.availableGroups.filter { group in
            group != currentGroup
        }

        guard !searchText.isEmpty else {
            return groups
        }

        return groups.filter { group in
            group.localizedCaseInsensitiveContains(searchText)
        }
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
                            GroupRow(
                                title: currentGroup,
                                subtitle: "Уже выбрана",
                                isSelected: true
                            )
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
            .overlay {
                if !store.availableGroups.isEmpty && !searchText.isEmpty && filteredGroups.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
        }
        .navigationTitle("Выбор группы")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                SheetToolbarIconButton(
                    systemImage: "xmark",
                    accessibilityLabel: "Закрыть"
                ) {
                    dismiss()
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            BottomPinnedSearchField(text: $searchText)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 10)
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
                    GroupRow(
                        title: group,
                        subtitle: "Нажмите, чтобы загрузить",
                        isSelected: false
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct GroupRow: View {
    let title: String
    let subtitle: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(subtitle)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Color.accentColor)
            }
        }
        .contentShape(Rectangle())
    }
}

private struct BottomPinnedSearchField: View {
    @Binding var text: String

    var body: some View {
        StandardSearchBar(text: $text)
            .frame(height: 44)
    }
}

private struct StandardSearchBar: UIViewRepresentable {
    @Binding var text: String

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text)
    }

    func makeUIView(context: Context) -> UISearchBar {
        let searchBar = UISearchBar(frame: .zero)
        searchBar.delegate = context.coordinator
        searchBar.searchBarStyle = .minimal
        searchBar.placeholder = "Поиск группы"
        searchBar.returnKeyType = .done
        searchBar.autocapitalizationType = .none
        searchBar.autocorrectionType = .no
        searchBar.accessibilityIdentifier = "group-picker-search"
        searchBar.searchTextField.accessibilityIdentifier = "group-picker-search-field"
        return searchBar
    }

    func updateUIView(_ uiView: UISearchBar, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
    }

    final class Coordinator: NSObject, UISearchBarDelegate {
        @Binding private var text: String

        init(text: Binding<String>) {
            _text = text
        }

        func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
            text = searchText
        }

        func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
            searchBar.resignFirstResponder()
        }
    }
}
