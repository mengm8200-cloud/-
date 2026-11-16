import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: TodoStore
    @State private var newTitle = ""
    @FocusState private var inputFocused: Bool

    private var canAdd: Bool {
        !newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 12) {
                        TextField("添加新的待办…", text: $newTitle)
                            .focused($inputFocused)
                            .submitLabel(.done)
                            .onSubmit(add)
                        Button(action: add) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(canAdd ? .accentColor : .secondary)
                        .disabled(!canAdd)
                        .accessibilityLabel("添加")
                    }
                }

                if store.items.isEmpty {
                    Section {
                        VStack(spacing: 8) {
                            Image(systemName: "checklist")
                                .font(.largeTitle)
                                .foregroundColor(.secondary)
                            Text("还没有待办事项")
                                .font(.headline)
                            Text("在上方输入内容，点 + 添加第一条。")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                    }
                }

                if !store.pending.isEmpty {
                    Section("待完成") {
                        ForEach(store.pending) { item in
                            TodoRow(item: item) { store.toggle(item) }
                        }
                        .onDelete { offsets in
                            let pending = store.pending
                            store.remove(ids: offsets.map { pending[$0].id })
                        }
                    }
                }

                if !store.completed.isEmpty {
                    Section("已完成") {
                        ForEach(store.completed) { item in
                            TodoRow(item: item) { store.toggle(item) }
                        }
                        .onDelete { offsets in
                            let completed = store.completed
                            store.remove(ids: offsets.map { completed[$0].id })
                        }
                    }
                }
            }
            .navigationTitle("待办清单")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !store.completed.isEmpty {
                        Button("清除已完成") {
                            withAnimation { store.clearCompleted() }
                        }
                    }
                }
            }
        }
    }

    private func add() {
        guard canAdd else { return }
        withAnimation { store.add(title: newTitle) }
        newTitle = ""
        inputFocused = true
    }
}

private struct TodoRow: View {
    let item: TodoItem
    let toggle: () -> Void

    var body: some View {
        Button {
            withAnimation { toggle() }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(item.isDone ? .accentColor : .secondary)
                Text(item.title)
                    .strikethrough(item.isDone)
                    .foregroundColor(item.isDone ? .secondary : .primary)
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
