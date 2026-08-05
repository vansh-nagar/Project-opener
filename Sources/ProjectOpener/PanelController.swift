import AppKit
import Combine
import SwiftUI

/// A panel that can take keyboard focus despite being borderless.
final class FloatingPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class PanelController: NSObject, NSWindowDelegate {
    private let model: AppModel
    private var panel: FloatingPanel!
    private var keyMonitor: Any?
    private var cancellables = Set<AnyCancellable>()
    /// Activation is asynchronous, so the panel is briefly visible-but-not-key.
    /// Only treat a resign as "user clicked away" once it has actually been key.
    private var hasBeenKey = false

    private let width: CGFloat = 660
    private let headerHeight: CGFloat = 53
    private let maxListHeight: CGFloat = 380

    init(model: AppModel) {
        self.model = model
        super.init()
        buildPanel()

        // Resize to fit the current result list.
        model.$rows
            .receive(on: RunLoop.main)
            .sink { [weak self] rows in self?.resize(for: rows) }
            .store(in: &cancellables)
    }

    private func buildPanel() {
        panel = FloatingPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: 400),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .floating
        panel.isMovableByWindowBackground = false
        panel.hidesOnDeactivate = false
        panel.animationBehavior = .utilityWindow
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.delegate = self

        let host = NSHostingView(rootView: SearchView(model: model))
        host.frame = panel.contentView?.bounds ?? .zero
        host.autoresizingMask = [.width, .height]
        panel.contentView = host
    }

    // MARK: - Show / hide

    var isVisible: Bool { panel.isVisible }

    func toggle() { isVisible ? hide() : show() }

    func show() {
        hasBeenKey = false
        model.reset()
        model.refresh()
        resize(for: model.rows)
        positionOnActiveScreen()

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        focusSearchField()
        installKeyMonitor()
        Log.debug("show: visible=\(panel.isVisible) key=\(panel.isKeyWindow) frame=\(panel.frame)")

        if Log.enabled {
            // Re-check once the background scan has landed and resized us.
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
                guard let self else { return }
                Log.debug("""
                    +2.5s: visible=\(self.panel.isVisible) \
                    key=\(self.panel.isKeyWindow) \
                    onScreen=\(self.panel.screen != nil) \
                    occluded=\(!self.panel.occlusionState.contains(.visible)) \
                    alpha=\(self.panel.alphaValue) \
                    frame=\(self.panel.frame) \
                    rows=\(self.model.rows.count)
                    """)
            }
        }
    }

    func hide(caller: String = #function, line: Int = #line) {
        Log.debug("hide (from \(caller):\(line))")
        removeKeyMonitor()
        hasBeenKey = false
        panel.orderOut(nil)
        model.reset()
    }

    func windowDidBecomeKey(_ notification: Notification) {
        hasBeenKey = true
        Log.debug("becameKey")
    }

    func windowDidResignKey(_ notification: Notification) {
        Log.debug("resignKey (hasBeenKey=\(hasBeenKey))")
        guard hasBeenKey, model.config.shouldHideOnBlur else { return }
        hide()
    }

    /// Centres horizontally on whichever screen holds the mouse, sitting a bit
    /// above centre — the usual launcher position.
    private func positionOnActiveScreen() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) }
            ?? NSScreen.main
        guard let frame = screen?.visibleFrame else { return }

        let size = panel.frame.size
        let x = frame.midX - size.width / 2
        let y = frame.midY + frame.height * 0.12 - size.height / 2
        panel.setFrameOrigin(NSPoint(x: x.rounded(), y: y.rounded()))
    }

    private func resize(for rows: [Row]) {
        let listHeight = rows.isEmpty ? 60 : min(maxListHeight, rows.reduce(12) { $0 + $1.height })
        let target = headerHeight + listHeight
        guard abs(panel.frame.height - target) > 0.5 else { return }

        // Grow downward: keep the top edge fixed.
        var frame = panel.frame
        frame.origin.y += frame.size.height - target
        frame.size.height = target
        panel.setFrame(frame, display: true)
    }

    private func focusSearchField() {
        guard let root = panel.contentView,
              let field = Self.findSearchField(in: root) else { return }
        panel.makeFirstResponder(field)
        field.currentEditor()?.selectedRange = NSRange(location: field.stringValue.count, length: 0)
    }

    private static func findSearchField(in view: NSView) -> NSTextField? {
        if let field = view as? NSTextField,
           field.identifier?.rawValue == "ProjectOpenerSearchField" {
            return field
        }
        for sub in view.subviews {
            if let found = findSearchField(in: sub) { return found }
        }
        return nil
    }

    // MARK: - Keyboard

    /// A local monitor handles navigation keys before the text field sees them,
    /// so arrows and Return don't get swallowed by the field editor.
    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            return self.handle(event) ? nil : event
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }

    private func handle(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        switch Int(event.keyCode) {
        case 53: // escape
            hide()
            return true
        case 125: // down
            model.moveSelection(by: 1)
            return true
        case 126: // up
            model.moveSelection(by: -1)
            return true
        case 36, 76: // return / keypad enter
            // Only dismiss if something was actually opened. Otherwise a stray
            // Return (e.g. arriving as the panel steals focus) would close it.
            guard model.selectedProject != nil else { return true }
            model.openSelected()
            hide()
            return true
        default:
            break
        }

        // ⌘P toggles a pin, ⌘R forces a rescan.
        if flags == .command, let chars = event.charactersIgnoringModifiers?.lowercased() {
            if chars == "p" {
                model.togglePinSelected()
                return true
            }
            if chars == "r" {
                model.refresh(force: true)
                return true
            }
        }

        // ⌃N / ⌃P navigation, for muscle memory.
        if flags == .control, let chars = event.charactersIgnoringModifiers?.lowercased() {
            if chars == "n" { model.moveSelection(by: 1); return true }
            if chars == "p" { model.moveSelection(by: -1); return true }
        }

        return false
    }
}
