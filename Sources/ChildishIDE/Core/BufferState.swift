import Foundation

struct BufferState: Equatable {
    var text: String
    var isDirty: Bool

    static let empty = BufferState(text: "", isDirty: false)
}
