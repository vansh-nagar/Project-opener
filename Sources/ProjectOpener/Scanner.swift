import Foundation

struct Project: Identifiable, Hashable {
    let path: String
    let name: String
    /// Path relative to its scan root, e.g. `office/sarj/bulbul`.
    let relativePath: String
    let kind: Kind

    var id: String { path }
    var url: URL { URL(fileURLWithPath: path) }

    enum Kind: String {
        case swift, javascript, rust, go, python, ruby, git, folder

        var symbol: String {
            switch self {
            case .swift: return "swift"
            case .javascript: return "curlybraces"
            case .rust: return "gearshape.2"
            case .go: return "shippingbox"
            case .python: return "chevron.left.forwardslash.chevron.right"
            case .ruby: return "diamond"
            case .git, .folder: return "folder"
            }
        }
    }
}

enum Scanner {
    /// Directories that never contain a project we care about, and which are
    /// expensive to walk.
    private static let pruned: Set<String> = [
        "node_modules", ".next", ".git", ".build", ".turbo", ".venv", "venv",
        "build", "dist", "out", "target", "Pods", "vendor", "DerivedData",
        "__pycache__", ".cache", ".svelte-kit", "Carthage", ".gradle",
    ]

    /// Files whose presence means "this directory is a project root".
    private static let markers: [String: Project.Kind] = [
        "Package.swift": .swift,
        "package.json": .javascript,
        "Cargo.toml": .rust,
        "go.mod": .go,
        "pyproject.toml": .python,
        "requirements.txt": .python,
        "Gemfile": .ruby,
    ]

    static func scan(roots: [URL], maxDepth: Int) -> [Project] {
        let fm = FileManager.default
        var found: [Project] = []
        var seen = Set<String>()

        for root in roots {
            let rootPath = root.standardizedFileURL.path
            var stack: [(url: URL, depth: Int)] = [(root.standardizedFileURL, 0)]

            while let (dir, depth) = stack.popLast() {
                guard let entries = try? fm.contentsOfDirectory(
                    at: dir,
                    includingPropertiesForKeys: [.isDirectoryKey],
                    options: []
                ) else { continue }

                let names = Set(entries.map { $0.lastPathComponent })

                // Detect a project root.
                var kind: Project.Kind?
                if names.contains(where: { $0.hasSuffix(".xcodeproj") || $0.hasSuffix(".xcworkspace") }) {
                    kind = .swift
                } else {
                    for (marker, k) in markers where names.contains(marker) {
                        kind = k
                        break
                    }
                    if kind == nil && names.contains(".git") { kind = .git }
                }

                if let kind, dir.path != rootPath {
                    let rel = dir.path.hasPrefix(rootPath + "/")
                        ? String(dir.path.dropFirst(rootPath.count + 1))
                        : dir.lastPathComponent
                    if seen.insert(dir.path).inserted {
                        found.append(Project(
                            path: dir.path,
                            name: dir.lastPathComponent,
                            relativePath: rel,
                            kind: kind
                        ))
                    }
                    // Stop here: nested repos inside a project are noise.
                    continue
                }

                guard depth < maxDepth else { continue }
                for entry in entries {
                    let name = entry.lastPathComponent
                    if name.hasPrefix(".") || pruned.contains(name) { continue }
                    let isDir = (try? entry.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                    if isDir { stack.append((entry, depth + 1)) }
                }
            }
        }

        return found.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
