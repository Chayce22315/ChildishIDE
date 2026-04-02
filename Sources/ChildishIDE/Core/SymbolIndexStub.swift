import Foundation

/// Placeholder for future incremental parsing / LSP-style symbol tracking.
final class SymbolIndexStub {
    private var versionByPath: [String: Int] = [:]

    func bumpVersion(path: String) -> Int {
        let next = (versionByPath[path] ?? 0) + 1
        versionByPath[path] = next
        return next
    }

    func version(for path: String) -> Int {
        versionByPath[path] ?? 0
    }
}
