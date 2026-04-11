import SwiftUI

struct RootView: View {
    @Environment(StudyStore.self) private var studyStore

    var body: some View {
        if !studyStore.hasCompletedOnboarding {
            OnboardingView()
        } else {
            MainView()
        }
    }
}

#Preview {
    RootView()
        .environment(StudyStore.shared)
}
