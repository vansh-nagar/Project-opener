import Foundation

/// Stderr logging, enabled with `PROJECTOPENER_DEBUG=1`.
enum Log {
    static let enabled =
        ProcessInfo.processInfo.environment["PROJECTOPENER_DEBUG"] == "1"

    static func debug(_ message: @autoclosure () -> String) {
        guard enabled else { return }
        FileHandle.standardError.write("[PO] \(message())\n".data(using: .utf8)!)
    }
}
