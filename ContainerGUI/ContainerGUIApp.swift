import SwiftUI

@main
struct ContainerGUIApp: App {
    @State private var showAbout = false

    // Dependency graph — assembled once, injected everywhere
    private let dependencies: AppDIContainer = .makeDefault()

    var body: some Scene {
        WindowGroup {
            RootView(dependencies: dependencies)
                .sheet(isPresented: $showAbout) {
                    AboutView()
                }
        }
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) {} // Remove "New Window" for this app

            CommandGroup(replacing: .appInfo) {
                Button("About ContainerGUI") {
                    showAbout = true
                }
            }
        }
    }
}
