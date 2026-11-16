import Foundation

struct TodoItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var title: String
    var isDone = false
    var createdAt = Date()
}

/// Holds the to-do list and persists it as JSON in the app's Documents folder.
final class TodoStore: ObservableObject {
    @Published private(set) var items: [TodoItem] = []

    private let fileURL: URL

    init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = documents.appendingPathComponent("todos.json")
        load()
    }

    var pending: [TodoItem] { items.filter { !$0.isDone } }
    var completed: [TodoItem] { items.filter { $0.isDone } }

    func add(title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        items.insert(TodoItem(title: trimmed), at: 0)
        save()
    }

    func toggle(_ item: TodoItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index].isDone.toggle()
        save()
    }

    func remove(ids: [UUID]) {
        let doomed = Set(ids)
        items.removeAll { doomed.contains($0.id) }
        save()
    }

    func clearCompleted() {
        items.removeAll { $0.isDone }
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        items = (try? JSONDecoder().decode([TodoItem].self, from: data)) ?? []
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
