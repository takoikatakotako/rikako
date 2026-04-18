import SwiftUI

private enum AppReadyState {
    case loading
    case updateRequired
    case maintenance(message: String)
    case ready
}

struct RootView: View {
    @Environment(AppState.self) private var appState
    @State private var state: AppReadyState = .loading
    @State private var errorMessage: String?
    private let skipInitialize: Bool

    init(skipInitialize: Bool = false) {
        self.skipInitialize = skipInitialize
    }

    var body: some View {
        Group {
            if let errorMessage {
                errorView(errorMessage)
            } else {
                switch state {
                case .loading:
                    splashView
                case .updateRequired:
                    UpdateRequiredView()
                case .maintenance(let message):
                    MaintenanceView(message: message)
                case .ready:
                    if !appState.hasCompletedOnboarding {
                        OnboardingView()
                    } else {
                        MainView()
                    }
                }
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
            let appStatus = try await AppContainer.shared.learningUseCases.fetchAppStatus.execute()

            if appStatus.isMaintenance {
                state = .maintenance(message: appStatus.maintenanceMessage)
                return
            }

            if isUpdateRequired(minimumVersion: appStatus.minimumVersion) {
                state = .updateRequired
                return
            }

            if appState.hasCompletedOnboarding {
                await syncProfile()
            }
            state = .ready
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func isUpdateRequired(minimumVersion: String) -> Bool {
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        let current = versionComponents(currentVersion)
        let minimum = versionComponents(minimumVersion)
        for i in 0..<current.count {
            if current[i] < minimum[i] { return true }
            if current[i] > minimum[i] { return false }
        }
        return false
    }

    private func versionComponents(_ version: String) -> [Int] {
        let parts = version.split(separator: ".").compactMap { Int($0) }
        return parts + Array(repeating: 0, count: max(0, 3 - parts.count))
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
}

#Preview {
    RootView()
        .environment(AppState.shared)
}

#Preview("Splash") {
    RootView(skipInitialize: true)
        .environment(AppState.preview())
}

#Preview("UpdateRequired") {
    UpdateRequiredView()
}

#Preview("Maintenance") {
    MaintenanceView(message: "システムの改善のため、メンテナンスを実施中です。")
}
