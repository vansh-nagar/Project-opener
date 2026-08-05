import AppKit

// Top-level entry point. Using main.swift (instead of @main) keeps the
// activation policy set before any window machinery spins up.
//
// `NSApplication.delegate` is a weak reference, so the delegate needs a strong
// owner that outlives the run loop.
nonisolated(unsafe) var appDelegate: AppDelegate?

// Debug helper: `ProjectOpener --scan` prints what the scanner finds and exits,
// so the index can be checked without opening the UI.
if CommandLine.arguments.contains("--scan") {
    let config = Config.load()
    let projects = Scanner.scan(roots: config.rootURLs, maxDepth: config.maxDepth)
    print("roots: \(config.roots.joined(separator: ", "))  maxDepth: \(config.maxDepth)")
    print("found \(projects.count) projects\n")
    for p in projects {
        print("  \(p.kind.rawValue.padding(toLength: 11, withPad: " ", startingAt: 0)) \(p.relativePath)")
    }
    exit(0)
}

// Debug helper: `ProjectOpener --match <query>` prints the ranked results.
if let i = CommandLine.arguments.firstIndex(of: "--match"),
   i + 1 < CommandLine.arguments.count {
    let query = CommandLine.arguments[i + 1]
    let config = Config.load()
    let projects = Scanner.scan(roots: config.rootURLs, maxDepth: config.maxDepth)
    let hits = Ranker.rank(projects: projects, query: query)
    print("query “\(query)” → \(hits.count) hits\n")
    for hit in hits.prefix(8) {
        print("  \(String(format: "%5d", hit.score))  \(hit.project.name)  —  \(hit.project.relativePath)")
    }
    exit(0)
}

MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    appDelegate = delegate
    app.delegate = delegate
    app.setActivationPolicy(.accessory) // no Dock icon; menu bar only
    app.run()
}
