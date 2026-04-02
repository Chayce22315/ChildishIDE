import SwiftUI

@main
struct ChildishIDEApp: App {
    @StateObject private var registry = ServiceRegistry()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(registry.document)
                .environmentObject(registry.brain)
        }
    }
}
