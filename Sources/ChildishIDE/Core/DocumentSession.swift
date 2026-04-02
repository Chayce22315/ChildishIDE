import Combine
import Foundation

@MainActor
final class DocumentSession: ObservableObject {
    @Published private(set) var buffer: BufferState
    @Published private(set) var fileName: String

    private let events: EventBus

    init(events: EventBus, initial: BufferState = BufferState(text: "// Tap Open to pick a file!\n", isDirty: false)) {
        self.events = events
        fileName = "untitled"
        buffer = initial
    }

    func replaceContent(_ text: String, markDirty: Bool) {
        buffer = BufferState(text: text, isDirty: markDirty)
        events.emit(.documentDirty(markDirty))
    }

    func setFromOpen(name: String, text: String) {
        fileName = name
        buffer = BufferState(text: text, isDirty: false)
        events.emit(.documentOpened(name: name))
        events.emit(.documentDirty(false))
    }

    func userEdited(_ text: String) {
        buffer = BufferState(text: text, isDirty: true)
        events.emit(.documentDirty(true))
    }

    func markSaved(currentText: String) {
        buffer = BufferState(text: currentText, isDirty: false)
        events.emit(.documentDirty(false))
    }
}
