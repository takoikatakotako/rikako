import SwiftUI

struct ProfileView: View {
    @Environment(AppState.self) private var appState
    @State private var displayName = ""
    @State private var isSaving = false
    @State private var summary: UserSummary?
    @FocusState private var isDisplayNameFocused: Bool

    var body: some View {
        List {
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Circle()
                            .fill(Color(.main).opacity(0.10))
                            .frame(width: 92, height: 92)
                            .overlay(
                                Image(systemName: "tortoise.fill")
                                    .font(.system(size: 40, weight: .bold))
                                    .foregroundStyle(Color(.main))
                            )
                        Text(appState.displayName ?? "ゲストユーザー")
                            .font(.headline)
                    }
                    Spacer()
                }
                .listRowBackground(Color.clear)
            }

            Section("プロフィール") {
                HStack {
                    Text("表示名")
                    Spacer()
                    TextField("未設定", text: $displayName)
                        .multilineTextAlignment(.trailing)
                        .foregroundStyle(.secondary)
                        .focused($isDisplayNameFocused)
                        .onSubmit {
                            Task { await saveDisplayName() }
                        }
                }
            }

            Section("学習記録") {
                HStack {
                    Label("総解答数", systemImage: "number")
                    Spacer()
                    Text("\(summary?.totalAnswered ?? 0)")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Label("正答数", systemImage: "checkmark")
                    Spacer()
                    Text("\(summary?.totalCorrect ?? 0)")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("プロフィール")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            displayName = appState.displayName ?? ""
            summary = try? await AppContainer.shared.learningUseCases.fetchUserSummary.execute()
        }
        .onChange(of: isDisplayNameFocused) { _, focused in
            if !focused {
                Task { await saveDisplayName() }
            }
        }
    }

    private func saveDisplayName() async {
        let trimmed = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != (appState.displayName ?? "") else { return }
        isSaving = true
        defer { isSaving = false }
        do {
            let profile = try await AppContainer.shared.learningUseCases.updateUserProfile.execute(
                appSlug: AppFlavor.current.slug,
                request: UpdateUserProfileRequest(displayName: trimmed.isEmpty ? nil : trimmed)
            )
            appState.displayName = profile.displayName
        } catch {
            // Save failure is non-fatal
        }
    }
}

#Preview {
        NavigationStack {
            ProfileView()
            .environment(AppState.shared)
    }
}
