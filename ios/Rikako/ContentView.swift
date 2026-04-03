import SwiftUI

struct ContentView: View {
    @State private var hasCompletedOnboarding = false
    @State private var isLoggedIn = false

    var body: some View {
        if !hasCompletedOnboarding {
            OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
        } else if !isLoggedIn {
            LoginView(isLoggedIn: $isLoggedIn)
        } else {
            MainTabView(isLoggedIn: $isLoggedIn)
        }
    }
}

struct MainTabView: View {
    @Binding var isLoggedIn: Bool

    var body: some View {
        NavigationStack {
            WorkbookListView()
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        NavigationLink(destination: WrongAnswersView()) {
                            Image(systemName: "arrow.counterclockwise")
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink(destination: SettingsView(isLoggedIn: $isLoggedIn)) {
                            Image(systemName: "gearshape")
                        }
                    }
                }
        }
    }
}

#Preview {
    ContentView()
}
