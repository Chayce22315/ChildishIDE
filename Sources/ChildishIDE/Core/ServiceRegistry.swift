import Combine
import Foundation

/// Composition root for the app target.
@MainActor
final class ServiceRegistry: ObservableObject {
    let events: EventBus
    let document: DocumentSession
    let brain: BrainService
    let symbolIndex = SymbolIndexStub()

    init() {
        let bus = EventBus()
        events = bus
        document = DocumentSession(events: bus)
        brain = BrainService(events: bus)
    }
}
