import AppKit

enum Opener {
    /// Resolves the first installed editor from the configured bundle IDs.
    ///
    /// Uses `NSWorkspace` rather than shelling out to a `cursor` binary, which
    /// is not on `PATH` by default.
    static func editorURL(bundleIDs: [String]) -> URL? {
        for id in bundleIDs {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
                return url
            }
        }
        // Last resort: look for the apps by name on disk.
        for name in ["Cursor", "Visual Studio Code"] {
            let url = URL(fileURLWithPath: "/Applications/\(name).app")
            if FileManager.default.fileExists(atPath: url.path) { return url }
        }
        return nil
    }

    static func open(_ project: Project, bundleIDs: [String]) {
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true

        if let app = editorURL(bundleIDs: bundleIDs) {
            NSWorkspace.shared.open([project.url], withApplicationAt: app, configuration: config)
        } else {
            // No editor installed — at least reveal the folder.
            NSWorkspace.shared.activateFileViewerSelecting([project.url])
        }
    }
}
