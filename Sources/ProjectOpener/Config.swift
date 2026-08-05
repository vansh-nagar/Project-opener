import AppKit
import Carbon.HIToolbox

/// User-editable settings, stored as JSON so scan roots and the hotkey can be
/// changed without a rebuild.
struct Config: Codable {
    var roots: [String]
    var maxDepth: Int
    var hotkey: String
    /// Bundle identifiers tried in order when opening a project.
    var editorBundleIDs: [String]
    /// Dismiss the panel when it loses focus. Set false to keep it pinned open.
    var hideOnBlur: Bool?
    var shouldHideOnBlur: Bool { hideOnBlur ?? true }

    static let `default` = Config(
        roots: ["~/Desktop/mvp/dev"],
        maxDepth: 5,
        hotkey: "cmd+opt+o",
        editorBundleIDs: [
            "com.todesktop.230313mzl4w4u92", // Cursor
            "com.microsoft.VSCode",
        ],
        hideOnBlur: true
    )

    var rootURLs: [URL] {
        roots.map { URL(fileURLWithPath: ($0 as NSString).expandingTildeInPath) }
    }

    // MARK: - Persistence

    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("ProjectOpener", isDirectory: true)
    }

    static var fileURL: URL { directory.appendingPathComponent("config.json") }

    static func load() -> Config {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let data = try? Data(contentsOf: fileURL),
              let cfg = try? JSONDecoder().decode(Config.self, from: data)
        else {
            let cfg = Config.default
            cfg.save()
            return cfg
        }
        return cfg
    }

    func save() {
        try? FileManager.default.createDirectory(at: Config.directory, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try? encoder.encode(self).write(to: Config.fileURL)
    }

    // MARK: - Hotkey parsing

    /// Parses strings like `cmd+opt+o` or `ctrl+shift+space` into Carbon values.
    var parsedHotkey: (keyCode: UInt32, modifiers: UInt32)? {
        var mods: UInt32 = 0
        var key: UInt32?

        for raw in hotkey.lowercased().split(separator: "+") {
            let token = raw.trimmingCharacters(in: .whitespaces)
            switch token {
            case "cmd", "command", "⌘": mods |= UInt32(cmdKey)
            case "opt", "option", "alt", "⌥": mods |= UInt32(optionKey)
            case "ctrl", "control", "⌃": mods |= UInt32(controlKey)
            case "shift", "⇧": mods |= UInt32(shiftKey)
            default: key = Config.keyCode(for: token)
            }
        }

        guard let key, mods != 0 else { return nil }
        return (key, mods)
    }

    private static func keyCode(for name: String) -> UInt32? {
        let named: [String: Int] = [
            "space": kVK_Space, "return": kVK_Return, "enter": kVK_Return,
            "tab": kVK_Tab, "escape": kVK_Escape, "esc": kVK_Escape,
            "a": kVK_ANSI_A, "b": kVK_ANSI_B, "c": kVK_ANSI_C, "d": kVK_ANSI_D,
            "e": kVK_ANSI_E, "f": kVK_ANSI_F, "g": kVK_ANSI_G, "h": kVK_ANSI_H,
            "i": kVK_ANSI_I, "j": kVK_ANSI_J, "k": kVK_ANSI_K, "l": kVK_ANSI_L,
            "m": kVK_ANSI_M, "n": kVK_ANSI_N, "o": kVK_ANSI_O, "p": kVK_ANSI_P,
            "q": kVK_ANSI_Q, "r": kVK_ANSI_R, "s": kVK_ANSI_S, "t": kVK_ANSI_T,
            "u": kVK_ANSI_U, "v": kVK_ANSI_V, "w": kVK_ANSI_W, "x": kVK_ANSI_X,
            "y": kVK_ANSI_Y, "z": kVK_ANSI_Z,
            "0": kVK_ANSI_0, "1": kVK_ANSI_1, "2": kVK_ANSI_2, "3": kVK_ANSI_3,
            "4": kVK_ANSI_4, "5": kVK_ANSI_5, "6": kVK_ANSI_6, "7": kVK_ANSI_7,
            "8": kVK_ANSI_8, "9": kVK_ANSI_9,
        ]
        return named[name].map(UInt32.init)
    }
}
