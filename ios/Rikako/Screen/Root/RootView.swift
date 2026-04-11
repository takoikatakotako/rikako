import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        if !appState.hasCompletedOnboarding {
            OnboardingView()
        } else {
            MainView()
        }
    }
}

#Preview {
    RootView()
        .environment(AppState.shared)
}
