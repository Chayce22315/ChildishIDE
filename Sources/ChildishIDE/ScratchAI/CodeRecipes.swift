import Foundation

struct CodeRecipe: Identifiable, Equatable {
    let id: String
    let title: String
    /// Lowercased tokens; used to match the user’s wish string.
    let keywords: [String]
    let code: String
}

/// Big offline snippets — the bot can drop these in wholesale (no API).
enum CodeRecipes {
    static let all: [CodeRecipe] = [
        CodeRecipe(
            id: "swiftui_screen",
            title: "SwiftUI screen",
            keywords: ["swiftui", "screen", "view", "ui", "app", "layout"],
            code: """

            struct GeneratedScreen: View {
                @State private var titleText = "Hello from Scratch-AI"
                @State private var counter = 0

                var body: some View {
                    VStack(spacing: 16) {
                        Text(titleText)
                            .font(.largeTitle.bold())
                        Text("Counter: \\(counter)")
                            .font(.title2.monospacedDigit())
                        HStack(spacing: 12) {
                            Button("−") { counter -= 1 }
                                .buttonStyle(.borderedProminent)
                            Button("+") { counter += 1 }
                                .buttonStyle(.borderedProminent)
                        }
                        Spacer()
                    }
                    .padding()
                }
            }

            #Preview {
                GeneratedScreen()
            }
            """,
        ),
        CodeRecipe(
            id: "list_fetch",
            title: "List + model",
            keywords: ["list", "foreach", "array", "model", "row"],
            code: """

            struct ItemRow: Identifiable {
                let id = UUID()
                var title: String
            }

            struct ItemListView: View {
                @State private var items: [ItemRow] = [
                    ItemRow(title: "Alpha"),
                    ItemRow(title: "Bravo"),
                    ItemRow(title: "Charlie"),
                ]

                var body: some View {
                    List {
                        ForEach(items) { item in
                            Text(item.title)
                        }
                    }
                }
            }
            """,
        ),
        CodeRecipe(
            id: "observable_vm",
            title: "Observable view-model",
            keywords: ["observable", "viewmodel", "view", "model", "state", "combine"],
            code: """

            import Combine

            final class CounterBrain: ObservableObject {
                @Published var value: Int = 0

                func bump() { value += 1 }
                func reset() { value = 0 }
            }

            struct CounterView: View {
                @ObservedObject var brain: CounterBrain

                var body: some View {
                    VStack(spacing: 12) {
                        Text("Count: \\(brain.value)")
                            .font(.title.monospacedDigit())
                        Button("Bump", action: brain.bump)
                            .buttonStyle(.borderedProminent)
                        Button("Reset", action: brain.reset)
                    }
                    .padding()
                }
            }
            """,
        ),
        CodeRecipe(
            id: "urlsession",
            title: "URLSession JSON fetch",
            keywords: ["network", "url", "json", "fetch", "http", "api", "download"],
            code: """

            struct GitHubUser: Codable {
                let login: String
                let id: Int
            }

            enum FetchError: Error {
                case badURL
                case badResponse
                case decodeFailed
            }

            func fetchExampleUser() async throws -> GitHubUser {
                guard let url = URL(string: "https://api.github.com/users/octocat") else {
                    throw FetchError.badURL
                }
                let (data, response) = try await URLSession.shared.data(from: url)
                guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                    throw FetchError.badResponse
                }
                return try JSONDecoder().decode(GitHubUser.self, from: data)
            }
            """,
        ),
        CodeRecipe(
            id: "task_mainactor",
            title: "Task + MainActor",
            keywords: ["task", "async", "await", "main", "actor", "background"],
            code: """

            @MainActor
            func runOnMain(_ update: @escaping () -> Void) {
                update()
            }

            func kickOffBackgroundWork() {
                Task {
                    let result = await computeHeavy()
                    await MainActor.run {
                        print("Done: \\(result)")
                    }
                }
            }

            func computeHeavy() async -> Int {
                await Task.yield()
                return (1...1000).reduce(0, +)
            }
            """,
        ),
        CodeRecipe(
            id: "form_validation",
            title: "Simple form",
            keywords: ["form", "textfield", "input", "validate", "submit"],
            code: """

            struct TinyForm: View {
                @State private var name = ""
                @State private var message = ""

                private var canSubmit: Bool {
                    !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                }

                var body: some View {
                    Form {
                        Section("Profile") {
                            TextField("Name", text: $name)
                            TextField("Message", text: $message, axis: .vertical)
                                .lineLimit(3...8)
                        }
                        Section {
                            Button("Submit") {
                                // Handle locally — no network in Scratch-AI recipes
                                print(name, message)
                            }
                            .disabled(!canSubmit)
                        }
                    }
                }
            }
            """,
        ),
        CodeRecipe(
            id: "animation",
            title: "Animation demo",
            keywords: ["animation", "animate", "spring", "bounce", "fun"],
            code: """

            struct BouncyBadge: View {
                @State private var big = false

                var body: some View {
                    Text("Boing!")
                        .font(.title.bold())
                        .padding()
                        .background(.pink.opacity(0.35))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .scaleEffect(big ? 1.2 : 1.0)
                        .animation(.spring(response: 0.35, dampingFraction: 0.55), value: big)
                        .onTapGesture { big.toggle() }
                }
            }
            """,
        ),
        CodeRecipe(
            id: "navigation_stack",
            title: "NavigationStack",
            keywords: ["navigation", "navigate", "push", "stack", "detail"],
            code: """

            struct NavDemo: View {
                private let colors = ["Pink", "Mint", "Sun"]

                var body: some View {
                    NavigationStack {
                        List(colors, id: \\.self) { color in
                            NavigationLink(color) {
                                Text("You picked \\(color)")
                                    .font(.title2)
                            }
                        }
                        .navigationTitle("Pick a vibe")
                    }
                }
            }
            """,
        ),
        CodeRecipe(
            id: "error_result",
            title: "Result + mapping",
            keywords: ["error", "result", "throw", "try", "map"],
            code: """

            enum MathError: Error {
                case divideByZero
            }

            func safeDivide(_ a: Double, _ b: Double) -> Result<Double, MathError> {
                guard b != 0 else { return .failure(.divideByZero) }
                return .success(a / b)
            }

            func describe(_ r: Result<Double, MathError>) -> String {
                switch r {
                case let .success(v): return String(format: "%.3f", v)
                case .failure: return "oops"
                }
            }
            """,
        ),
        CodeRecipe(
            id: "protocol_extension",
            title: "Protocol + extension",
            keywords: ["protocol", "extension", "generic", "reuse"],
            code: """

            protocol Describable {
                var label: String { get }
            }

            extension Describable {
                func prettyLine() -> String { "✨ \\(label)" }
            }

            struct Candy: Describable {
                let label: String
            }
            """,
        ),
        CodeRecipe(
            id: "unit_test_stub",
            title: "XCTest stub",
            keywords: ["test", "xctest", "assert", "unit"],
            code: """

            import XCTest

            final class ScratchAITests: XCTestCase {
                func testExampleMath() {
                    XCTAssertEqual(1 + 1, 2)
                }
            }
            """,
        ),
    ]
}
