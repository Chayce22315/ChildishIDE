import Foundation

/// In-process pub/sub (foundation for future multi-window or extension hooks).
final class EventBus {
    private var handlers: [(AppEvent) -> Void] = []
    private let lock = NSLock()

    func subscribe(_ handler: @escaping (AppEvent) -> Void) {
        lock.lock()
        handlers.append(handler)
        lock.unlock()
    }

    func emit(_ event: AppEvent) {
        lock.lock()
        let copy = handlers
        lock.unlock()
        copy.forEach { $0(event) }
    }
}
