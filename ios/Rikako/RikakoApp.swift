import SwiftUI

@main
struct RikakoApp: App {
    @State private var appState = AppContainer.shared.appState

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .preferredColorScheme(.light)
        }
    }
}
