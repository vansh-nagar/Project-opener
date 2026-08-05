import AppKit
import Combine

enum Row: Identifiable, Hashable {
    case header(String)
    case project(Project, matches: [Int])

    var id: String {
        switch self {
        case .header(let title): return "h:\(title)"
        case .project(let p, _): return "p:\(p.path)"
        }
    }

    var isSelectable: Bool {
        if case .project = self { return true }
        return false
    }

    var height: CGFloat {
        switch self {
        case .header: return 24
        case .project: return 46
        }
    }
}

@MainActor
final class AppModel: ObservableObject {
    @Published var query: String = "" { didSet { rebuild() } }
    @Published private(set) var rows: [Row] = []
    @Published var selection: Int = 0
    @Published private(set) var isScanning = false

    private(set) var config = Config.load()
    let store = Store()

    private var projects: [Project] = []
    private var lastScan: Date?

    // MARK: - Scanning

    /// Rescans in the background. Cheap enough to run on every panel open, but
    /// throttled so rapid toggling doesn't thrash the disk.
    func refresh(force: Bool = false) {
        if !force, let last = lastScan, Date().timeIntervalSince(last) < 30 { return }
        guard !isScanning else { return }

        isScanning = true
        let roots = config.rootURLs
        let depth = config.maxDepth

        DispatchQueue.global(qos: .userInitiated).async {
            let found = Scanner.scan(roots: roots, maxDepth: depth)
            DispatchQueue.main.async {
                self.projects = found
                self.lastScan = Date()
                self.isScanning = false
                self.rebuild()
            }
        }
    }

    func reloadConfig() {
        config = Config.load()
        refresh(force: true)
    }

    // MARK: - Result list

    private func rebuild() {
        let byPath = Dictionary(uniqueKeysWithValues: projects.map { ($0.path, $0) })
        let trimmed = query.trimmingCharacters(in: .whitespaces)

        var next: [Row] = []

        if trimmed.isEmpty {
            let pinned = store.pinnedPaths.compactMap { byPath[$0] }
            if !pinned.isEmpty {
                next.append(.header("Pinned"))
                next += pinned.map { .project($0, matches: []) }
            }

            let pinnedSet = Set(store.pinnedPaths)
            let recent = store.recentPaths.compactMap { byPath[$0] }.filter { !pinnedSet.contains($0.path) }
            if !recent.isEmpty {
                next.append(.header("Recent"))
                next += recent.map { .project($0, matches: []) }
            }

            let shownSet = pinnedSet.union(recent.map(\.path))
            let rest = projects.filter { !shownSet.contains($0.path) }
            if !rest.isEmpty {
                next.append(.header("All Projects"))
                next += rest.map { .project($0, matches: []) }
            }
        } else {
            let hits = Ranker.rank(
                projects: projects,
                query: trimmed,
                pinned: Set(store.pinnedPaths),
                recents: store.recentPaths
            )
            next = hits.map { .project($0.project, matches: $0.matches) }
        }

        rows = next
        clampSelection()
    }

    // MARK: - Selection

    private func clampSelection() {
        guard !rows.isEmpty else { selection = 0; return }
        if !rows.indices.contains(selection) || !rows[selection].isSelectable {
            selection = rows.firstIndex(where: \.isSelectable) ?? 0
        }
    }

    func moveSelection(by delta: Int) {
        guard !rows.isEmpty else { return }
        var idx = selection
        for _ in 0..<rows.count {
            idx += delta
            if idx < 0 { idx = rows.count - 1 }
            if idx >= rows.count { idx = 0 }
            if rows[idx].isSelectable { selection = idx; return }
        }
    }

    var selectedProject: Project? {
        guard rows.indices.contains(selection), case .project(let p, _) = rows[selection] else { return nil }
        return p
    }

    // MARK: - Actions

    func openSelected() {
        guard let project = selectedProject else { return }
        store.recordOpen(project.path)
        Opener.open(project, bundleIDs: config.editorBundleIDs)
        rebuild()
    }

    func togglePinSelected() {
        guard let project = selectedProject else { return }
        store.togglePin(project.path)
        rebuild()
    }

    func isPinned(_ project: Project) -> Bool { store.isPinned(project.path) }

    func reset() {
        query = ""
        selection = 0
    }
}
