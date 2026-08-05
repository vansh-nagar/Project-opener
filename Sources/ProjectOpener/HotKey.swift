import AppKit
import Carbon.HIToolbox

/// A system-wide hotkey via Carbon's `RegisterEventHotKey`.
///
/// Deliberately not `NSEvent.addGlobalMonitorForEvents`, which would require
/// Accessibility permission. This route needs no permission prompt at all.
final class HotKey {
    /// Weak, deliberately. A strong registry would keep every HotKey alive
    /// forever, so `deinit` would never run, `UnregisterEventHotKey` would never
    /// be called, and re-registering the same combination would fail with a
    /// conflict against the instance we thought we'd dropped.
    private final class WeakBox {
        weak var value: HotKey?
        init(_ value: HotKey) { self.value = value }
    }

    private static var registry: [UInt32: WeakBox] = [:]
    private static var nextID: UInt32 = 1
    private static var handlerInstalled = false

    private let id: UInt32
    private let callback: () -> Void
    private var ref: EventHotKeyRef?

    init?(keyCode: UInt32, modifiers: UInt32, callback: @escaping () -> Void) {
        self.callback = callback
        self.id = HotKey.nextID
        HotKey.nextID += 1

        HotKey.installHandlerIfNeeded()
        HotKey.registry = HotKey.registry.filter { $0.value.value != nil } // drop dead boxes
        HotKey.registry[id] = WeakBox(self)

        let hotKeyID = EventHotKeyID(signature: OSType(0x504F_504E), id: id) // 'POPN'
        let status = RegisterEventHotKey(
            keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &ref
        )
        guard status == noErr else {
            HotKey.registry[id] = nil
            return nil
        }
    }

    deinit {
        invalidate()
    }

    /// Releases the system registration. Safe to call more than once. Called
    /// from `deinit`, but callers re-registering the same combination should
    /// invoke it explicitly so the slot is free before the new registration.
    func invalidate() {
        if let ref {
            UnregisterEventHotKey(ref)
            self.ref = nil
        }
        HotKey.registry[id] = nil
    }

    fileprivate func fire() { callback() }

    private static func installHandlerIfNeeded() {
        guard !handlerInstalled else { return }
        handlerInstalled = true

        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        InstallEventHandler(
            GetApplicationEventTarget(),
            { _, event, _ -> OSStatus in
                guard let event else { return OSStatus(eventNotHandledErr) }
                var hkID = EventHotKeyID()
                let status = GetEventParameter(
                    event,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hkID
                )
                guard status == noErr else { return status }
                if let hk = HotKey.registry[hkID.id]?.value {
                    DispatchQueue.main.async { hk.fire() }
                }
                return noErr
            },
            1, &spec, nil, nil
        )
    }
}
