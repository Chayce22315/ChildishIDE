import Foundation

enum AppEvent: Equatable {
    case documentOpened(name: String)
    case documentDirty(Bool)
    case brainTrained(steps: Int)
    case suggestionsUpdated
}
