import Foundation

/// Bounded undo stack for future editor integration.
struct MementoStack<T> {
    private let maxDepth: Int
    private var past: [T] = []
    private var future: [T] = []

    init(maxDepth: Int) {
        self.maxDepth = maxDepth
    }

    mutating func push(_ snapshot: T) {
        past.append(snapshot)
        if past.count > maxDepth {
            past.removeFirst()
        }
        future.removeAll(keepingCapacity: true)
    }

    mutating func undo(current: T) -> T? {
        guard let prev = past.popLast() else { return nil }
        future.append(current)
        return prev
    }

    mutating func redo(current: T) -> T? {
        guard let next = future.popLast() else { return nil }
        past.append(current)
        return next
    }
}
