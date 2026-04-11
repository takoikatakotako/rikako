import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = OnboardingViewModel(
        fetchWorkbooksUseCase: AppContainer.shared.learningUseCases.fetchWorkbooks
    )
    @State private var currentPage = 0

    var body: some View {
        TabView(selection: $currentPage) {
            OnboardingWelcomePage(currentPage: $currentPage)
                .tag(0)

            OnboardingWorkbookIntroPage(currentPage: $currentPage)
                .tag(1)

            OnboardingWorkbookSelectionPage(
                currentPage: $currentPage,
                viewModel: viewModel
            )
            .tag(2)

            OnboardingAppIntroPage(currentPage: $currentPage)
                .tag(3)

            OnboardingFinishPage {
                appState.completeOnboarding()
            }
            .tag(4)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .background(Color(.systemBackground))
    }
}

private struct OnboardingContainer<Content: View>: View {
    let title: String
    let messageLines: [String]
    let primaryButtonTitle: String
    let isPrimaryEnabled: Bool
    let artwork: Content
    let action: () -> Void

    init(
        title: String,
        messageLines: [String],
        primaryButtonTitle: String,
        isPrimaryEnabled: Bool = true,
        @ViewBuilder artwork: () -> Content,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.messageLines = messageLines
        self.primaryButtonTitle = primaryButtonTitle
        self.isPrimaryEnabled = isPrimaryEnabled
        self.artwork = artwork()
        self.action = action
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 24)

            artwork

            VStack(spacing: 12) {
                Text(title)
                    .font(.system(size: 30, weight: .bold))
                    .multilineTextAlignment(.center)

                VStack(spacing: 8) {
                    ForEach(messageLines, id: \.self) { line in
                        Text(line)
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            Button(action: action) {
                Text(primaryButtonTitle)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isPrimaryEnabled ? Color("main") : Color(.systemGray4))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(!isPrimaryEnabled)
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
    }
}

private struct OnboardingCharacterArt: View {
    var body: some View {
        VStack(spacing: 12) {
            Image("top-rikako-standing")
                .resizable()
                .scaledToFit()
                .frame(maxHeight: 260)

            Image("top-app-logo")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 180)
        }
        .padding(.horizontal, 24)
    }
}

private struct OnboardingWelcomePage: View {
    @Binding var currentPage: Int

    var body: some View {
        OnboardingContainer(
            title: "こんにちは、理科子です！",
            messageLines: [
                "このアプリは高校生向けの化学を楽しく学ぶためのアプリです！",
                "一緒に楽しく勉強していこうね！"
            ],
            primaryButtonTitle: "次へ",
            artwork: { OnboardingCharacterArt() },
            action: {
                withAnimation { currentPage = 1 }
            }
        )
    }
}

private struct OnboardingWorkbookIntroPage: View {
    @Binding var currentPage: Int

    var body: some View {
        OnboardingContainer(
            title: "君にあった分野を選ぼう！",
            messageLines: [
                "高校化学とはいっても、範囲や分野はいろいろあります。",
                "次のページで問題集を選択できるから、学びたい問題集を選んでみてね。",
                "特になければ、おすすめの基礎の問題集を選んでみよう！"
            ],
            primaryButtonTitle: "問題集を選ぶ",
            artwork: {
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color("correctPink").opacity(0.16))
                        .frame(width: 220, height: 220)
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 84))
                        .foregroundStyle(Color("main"))
                }
            },
            action: {
                withAnimation { currentPage = 2 }
            }
        )
    }
}

private struct OnboardingWorkbookSelectionPage: View {
    @Environment(AppState.self) private var appState
    @Binding var currentPage: Int
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 24)

            VStack(spacing: 10) {
                Text("最初の問題集を選ぼう")
                    .font(.system(size: 28, weight: .bold))
                    .multilineTextAlignment(.center)

                Text("おすすめの1冊を用意したよ。まずはここから始めてみよう！")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            if viewModel.isLoading {
                Spacer()
                ProgressView("問題集を読み込み中...")
                Spacer()
            } else if let errorMessage = viewModel.errorMessage {
                Spacer()
                ContentUnavailableView {
                    Label("読み込みエラー", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(errorMessage)
                } actions: {
                    Button("再読み込み") {
                        Task { await viewModel.loadRecommendedWorkbook() }
                    }
                }
                Spacer()
            } else if let recommendedWorkbook = viewModel.recommendedWorkbook {
                VStack(alignment: .leading, spacing: 16) {
                    Text("おすすめ")
                        .font(.headline)
                        .foregroundStyle(Color("main"))

                    Button {
                        appState.selectWorkbook(recommendedWorkbook.id)
                        withAnimation { currentPage = 3 }
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(recommendedWorkbook.title)
                                .font(.title3.bold())
                            Text(recommendedWorkbook.description)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.leading)
                            HStack {
                                Text("\(recommendedWorkbook.questionCount)問")
                                    .font(.caption.bold())
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(appState.selectedWorkbookID == recommendedWorkbook.id ? "選択中" : "この問題集にする")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(Color("main"))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(Color("main").opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(20)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(.secondarySystemBackground))
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .stroke(Color("main").opacity(0.2), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 24))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)

                Spacer()
            } else {
                Spacer()
                ContentUnavailableView("問題集がありません", systemImage: "book")
                Spacer()
            }
        }
        .task {
            await viewModel.loadRecommendedWorkbookIfNeeded()
        }
    }
}

private struct OnboardingAppIntroPage: View {
    @Binding var currentPage: Int

    var body: some View {
        OnboardingContainer(
            title: "選びおわったね！",
            messageLines: [
                "他の機能は使いながら覚えていこうね！",
                "このアプリはログインしなくても使えるけど、ログインすると他の端末でも学習記録を共有できるよ。",
                "よかったらログインして使ってみてね！"
            ],
            primaryButtonTitle: "次へ",
            artwork: {
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color("incorrectBlue").opacity(0.14))
                        .frame(width: 220, height: 220)
                    Image(systemName: "ipad.and.iphone")
                        .font(.system(size: 80))
                        .foregroundStyle(Color("incorrectBlue"))
                }
            },
            action: {
                withAnimation { currentPage = 4 }
            }
        )
    }
}

private struct OnboardingFinishPage: View {
    let action: () -> Void

    var body: some View {
        OnboardingContainer(
            title: "それではさっそく勉強していこう！",
            messageLines: ["一緒に頑張ろうね！"],
            primaryButtonTitle: "はじめる",
            artwork: { OnboardingCharacterArt() },
            action: action
        )
    }
}

#Preview {
    OnboardingView()
        .environment(AppState.shared)
}
