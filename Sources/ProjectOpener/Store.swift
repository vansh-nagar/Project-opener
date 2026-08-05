import Foundation

/// Pins and recents, persisted as JSON next to the config.
final class Store {
    private struct State: Codable {
        var pinned: [String] = []
        var recents: [String] = []
    }

    private static let recentsLimit = 12
    private var state = State()
    private let fileURL = Config.directory.appendingPathComponent("state.json")

    init() { load() }

    var pinnedPaths: [String] { state.pinned }
    var recentPaths: [String] { state.recents }

    func isPinned(_ path: String) -> Bool { state.pinned.contains(path) }

    func togglePin(_ path: String) {
        if let idx = state.pinned.firstIndex(of: path) {
            state.pinned.remove(at: idx)
        } else {
            state.pinned.append(path)
        }
        save()
    }

    /// Moves `path` to the front of the recents list (most-recent-first).
    func recordOpen(_ path: String) {
        state.recents.removeAll { $0 == path }
        state.recents.insert(path, at: 0)
        if state.recents.count > Store.recentsLimit {
            state.recents = Array(state.recents.prefix(Store.recentsLimit))
        }
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode(State.self, from: data)
        else { return }
        state = decoded
    }

    private func save() {
        try? FileManager.default.createDirectory(at: Config.directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try? encoder.encode(state).write(to: fileURL)
    }
}
