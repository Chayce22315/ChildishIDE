import Foundation

/// Tiny bundled strings used only for on-device training (no network).
enum ToyCorpus {
    static let lines: [String] = [
        "func greet() { print(\"hello\") }",
        "let x = 1 + 2 * 3",
        "for i in 0..<10 { print(i) }",
        "struct Point { var x: Double; var y: Double }",
        "enum Mood { case happy, silly, curious }",
        "class Robot { func beep() {} }",
        "import SwiftUI",
        "var message = \"Super Code Fort\"",
        "// Draw a rainbow",
        "if x > 0 { return true } else { return false }",
        "array.map { $0 * 2 }",
        "dictionary[\"key\"] = value",
        "try await load()",
        "guard let z = optional else { return }",
        "extension String { var fun: Bool { true } }",
    ]
}
