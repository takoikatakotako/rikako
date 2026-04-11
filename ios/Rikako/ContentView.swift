import SwiftUI

struct ContentView: View {
    @Environment(StudyStore.self) private var studyStore

    var body: some View {
        if !studyStore.hasCompletedOnboarding {
            OnboardingView()
        } else if !studyStore.isLoggedIn {
            LoginView()
        } else {
            MainTabView()
        }
    }
}

struct MainTabView: View {
    var body: some View {
        TabView {
            LegacyTopView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Top")
                }

            LegacyCategoryListView()
                .tabItem {
                    Image(systemName: "square.grid.2x2.fill")
                    Text("Category")
                }

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Image(systemName: "gearshape.fill")
                Text("Config")
            }
        }
    }
}

#Preview {
    ContentView()
        .environment(StudyStore.shared)
}
