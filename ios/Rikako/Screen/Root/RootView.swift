import SwiftUI

struct RootView: View {
    @Environment(AppState.self) private var appState
    @State private var isReady = false
    @State private var errorMessage: String?
    private let skipInitialize: Bool

    init(skipInitialize: Bool = false) {
        self.skipInitialize = skipInitialize
    }

    var body: some View {
        Group {
            if let errorMessage {
                errorView(errorMessage)
            } else if !isReady {
                splashView
            } else if !appState.hasCompletedOnboarding {
                OnboardingView()
            } else {
                MainView()
            }
        }
        .task {
            guard !skipInitialize else { return }
            await initialize()
        }
    }

    private var splashView: some View {
        ZStack {
            Color(.main)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                Image(.topAppLogo)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 280, height: 180)
                
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.8)
                
                Spacer()
                
                Image(.topRikakoStanding)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 260)
                
            }
        }
    }

    private func errorView(_ message: String) -> some View {
        ContentUnavailableView {
            Label("エラー", systemImage: "exclamationmark.triangle")
        } description: {
            Text(message)
        } actions: {
            Button("再試行") {
                errorMessage = nil
                Task { await initialize() }
            }
            .buttonStyle(.borderedProminent)
            .tint(Color(.main))
        }
    }

    private func initialize() async {
        do {
            try await checkForceUpdate()
            try await checkVersion()
            if appState.hasCompletedOnboarding {
                await syncProfile()
            }
            isReady = true
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func syncProfile() async {
        do {
            let profile = try await AppContainer.shared.learningUseCases.fetchUserProfile.execute(appSlug: "chemistry")
            appState.userId = profile.userId
            appState.displayName = profile.displayName
            if let workbookId = profile.selectedWorkbookId {
                appState.selectWorkbook(workbookId)
            }
        } catch {
            // Profile sync failure is non-fatal
        }
    }

    // MARK: - チェック処理（将来実装）

    private func checkForceUpdate() async throws {
        // TODO: 強制アップデートチェック
    }

    private func checkVersion() async throws {
        // TODO: バージョンチェック
    }
}

#Preview {
    RootView()
        .environment(AppState.shared)
}

#Preview("Splash") {
    RootView(skipInitialize: true)
        .environment(AppState.preview())
}
