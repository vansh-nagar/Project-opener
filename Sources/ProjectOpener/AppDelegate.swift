import AppKit
import Carbon.HIToolbox // cmdKey / optionKey

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: AppModel!
    private var panelController: PanelController!
    private var hotKey: HotKey?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        model = AppModel()
        panelController = PanelController(model: model)

        setUpStatusItem()
        registerHotKey()

        model.refresh(force: true)

        // Start hidden, like every other launcher — the menu bar icon is the
        // signal that it's running. `PROJECTOPENER_SHOW_ON_LAUNCH=1` overrides
        // this for testing.
        if ProcessInfo.processInfo.environment["PROJECTOPENER_SHOW_ON_LAUNCH"] == "1" {
            panelController.show()
        }
    }

    private func setUpStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(
            systemSymbolName: "folder.badge.gearshape",
            accessibilityDescription: "Project Opener"
        )
        item.button?.image?.isTemplate = true

        let menu = NSMenu()
        menu.addItem(
            withTitle: "Open Project…  (\(Self.displayHotkey(model.config.hotkey)))",
            action: #selector(togglePanel),
            keyEquivalent: ""
        ).target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Rescan Projects", action: #selector(rescan), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Edit Config…", action: #selector(editConfig), keyEquivalent: "").target = self
        menu.addItem(withTitle: "Reload Config", action: #selector(reloadConfig), keyEquivalent: "").target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        item.menu = menu
        statusItem = item
    }

    private func registerHotKey() {
        guard let parsed = model.config.parsedHotkey else {
            warn("Could not parse the hotkey “\(model.config.hotkey)”. Falling back to ⌥⌘O.")
            hotKey = HotKey(keyCode: 31, modifiers: UInt32(cmdKey | optionKey)) { [weak self] in
                self?.panelController.toggle()
            }
            return
        }

        hotKey = HotKey(keyCode: parsed.keyCode, modifiers: parsed.modifiers) { [weak self] in
            Log.debug("hotkey fired")
            self?.panelController.toggle()
        }
        Log.debug("hotkey “\(model.config.hotkey)” registered: \(hotKey != nil)")

        if hotKey == nil {
            warn("The hotkey “\(model.config.hotkey)” is already taken by another app. Use the menu bar icon, or pick a different one in config.json.")
        }
    }

    // MARK: - Menu actions

    @objc private func togglePanel() { panelController.toggle() }

    @objc private func rescan() { model.refresh(force: true) }

    @objc private func editConfig() {
        NSWorkspace.shared.activateFileViewerSelecting([Config.fileURL])
    }

    @objc private func reloadConfig() {
        model.reloadConfig()
        hotKey = nil
        registerHotKey()
    }

    private func warn(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Project Opener"
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.runModal()
    }

    private static func displayHotkey(_ raw: String) -> String {
        raw.lowercased()
            .replacingOccurrences(of: "cmd", with: "⌘")
            .replacingOccurrences(of: "command", with: "⌘")
            .replacingOccurrences(of: "opt", with: "⌥")
            .replacingOccurrences(of: "option", with: "⌥")
            .replacingOccurrences(of: "alt", with: "⌥")
            .replacingOccurrences(of: "ctrl", with: "⌃")
            .replacingOccurrences(of: "shift", with: "⇧")
            .replacingOccurrences(of: "+", with: "")
            .uppercased()
    }
}
