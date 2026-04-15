import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel: OnboardingViewModel
    @State private var currentPage: Int
    @State private var hasAgreedToTerms = false

    @MainActor
    init() {
        _viewModel = State(initialValue: OnboardingViewModel(
            fetchWorkbooksUseCase: AppContainer.shared.learningUseCases.fetchWorkbooks,
            deviceIdentityProvider: AppContainer.shared.deviceIdentityProvider
        ))
        _currentPage = State(initialValue: 0)
    }

    init(viewModel: OnboardingViewModel, initialPage: Int = 0) {
        _viewModel = State(initialValue: viewModel)
        _currentPage = State(initialValue: initialPage)
    }

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

            OnboardingTermsAgreementPage(
                currentPage: $currentPage,
                hasAgreedToTerms: $hasAgreedToTerms
            )
            .tag(4)

            OnboardingFinishPage(viewModel: viewModel)
                .tag(5)
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
                    .background(isPrimaryEnabled ? Color(.main) : Color(.systemGray4))
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
        Image(.topRikakoStanding)
            .resizable()
            .scaledToFit()
            .frame(maxHeight: 260)
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
                        .fill(Color(.correctPink).opacity(0.16))
                        .frame(width: 220, height: 220)
                    Image(systemName: "books.vertical.fill")
                        .font(.system(size: 84))
                        .foregroundStyle(Color(.main))
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
        ScrollView {
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
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("おすすめ")
                                .font(.headline)
                                .foregroundStyle(Color(.main))

                            workbookButton(for: recommendedWorkbook, emphasizesPrimary: true)
                        }

                        if !viewModel.otherWorkbooks.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                Text("その他")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)

                                VStack(spacing: 12) {
                                    ForEach(viewModel.otherWorkbooks) { workbook in
                                        workbookButton(for: workbook, emphasizesPrimary: false)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)

                    Spacer()
                } else {
                    Spacer()
                    ContentUnavailableView("問題集がありません", systemImage: "book")
                    Spacer()
                }
            }
        }
        .task {
            await viewModel.loadRecommendedWorkbookIfNeeded()
        }
        .background(PageSwipeLock(isEnabled: true))
    }

    private func workbookButton(for workbook: Workbook, emphasizesPrimary: Bool) -> some View {
        Button {
            appState.selectWorkbook(workbook.id)
            withAnimation { currentPage = 3 }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                Text(workbook.title)
                    .font(emphasizesPrimary ? .title3.bold() : .headline)

                Text(workbook.description)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(emphasizesPrimary ? nil : 2)

                HStack {
                    Text("\(workbook.questionCount)問")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("この問題集で始める")
                        .font(.subheadline.bold())
                        .foregroundStyle(Color(.main))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(.main).opacity(0.12))
                        .clipShape(Capsule())
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 24)
                    .stroke(Color(.main).opacity(emphasizesPrimary ? 0.2 : 0.12), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 24))
        }
        .buttonStyle(.plain)
    }
}

private struct PageSwipeLock: UIViewRepresentable {
    let isEnabled: Bool

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        DispatchQueue.main.async {
            updateScrollState(from: view)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async {
            updateScrollState(from: uiView)
        }
    }

    private func updateScrollState(from view: UIView) {
        guard let scrollView = sequence(first: view.superview, next: { $0?.superview })
            .first(where: { $0 is UIScrollView }) as? UIScrollView else {
            return
        }

        scrollView.isScrollEnabled = !isEnabled
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
                        .fill(Color(.incorrectBlue).opacity(0.14))
                        .frame(width: 220, height: 220)
                    Image(systemName: "ipad.and.iphone")
                        .font(.system(size: 80))
                        .foregroundStyle(Color(.incorrectBlue))
                }
            },
            action: {
                withAnimation { currentPage = 4 }
            }
        )
    }
}

private struct OnboardingTermsAgreementPage: View {
    @Binding var currentPage: Int
    @Binding var hasAgreedToTerms: Bool

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 24)

            ZStack {
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.main).opacity(0.10))
                    .frame(width: 112, height: 112)
                Image(systemName: "checkmark.seal.text.page")
                    .font(.system(size: 40))
                    .foregroundStyle(Color(.main))
            }

            VStack(spacing: 12) {
                Text("利用規約に同意して始めよう")
                    .font(.system(size: 30, weight: .bold))
                    .multilineTextAlignment(.center)

                VStack(spacing: 8) {
                    Text("アプリを使い始める前に、利用規約への同意をお願いしています。")
                    Text("内容を確認したうえで、同意して次へ進んでください。")
                }
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            }

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("以下の内容を確認できます。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Link("利用規約を確認する", destination: Links.termsOfService)
                        .font(.subheadline.weight(.semibold))

                    Link("プライバシーポリシーを確認する", destination: Links.privacyPolicy)
                        .font(.subheadline.weight(.semibold))
                }

                Toggle(isOn: $hasAgreedToTerms) {
                    Text("利用規約に同意します")
                        .font(.headline)
                }
                .toggleStyle(.switch)

                Text("リンク先を確認したうえで、同意して次へ進んでください。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(20)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .padding(.horizontal, 24)

            Spacer()
        }
        .safeAreaInset(edge: .bottom) {
            Button {
                withAnimation { currentPage = 5 }
            } label: {
                Text("同意して次へ")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(hasAgreedToTerms ? Color(.main) : Color(.systemGray4))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(!hasAgreedToTerms)
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 56)
            .background(Color(.systemBackground))
        }
    }
}

private struct OnboardingFinishPage: View {
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: OnboardingViewModel

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 24)

            OnboardingCharacterArt()

            VStack(spacing: 12) {
                Text("それではさっそく勉強していこう！")
                    .font(.system(size: 30, weight: .bold))
                    .multilineTextAlignment(.center)

                if let errorMessage = viewModel.startErrorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                } else {
                    Text("一緒に頑張ろうね！")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 24)

            Spacer()

            Button {
                Task { await viewModel.start(appState: appState) }
            } label: {
                Group {
                    if viewModel.isStarting {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("はじめる")
                    }
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(viewModel.isStarting ? Color(.systemGray4) : Color(.main))
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(viewModel.isStarting)
            .padding(.horizontal, 24)
            .padding(.bottom, 48)
        }
    }
}

#Preview("Welcome") {
    OnboardingView(viewModel: PreviewAppContainer.makeOnboardingViewModel(), initialPage: 0)
        .environment(AppState.preview())
}

#Preview("WorkbookIntro") {
    OnboardingView(viewModel: PreviewAppContainer.makeOnboardingViewModel(), initialPage: 1)
        .environment(AppState.preview())
}

#Preview("WorkbookSelection") {
    OnboardingView(viewModel: PreviewAppContainer.makeOnboardingViewModel(), initialPage: 2)
        .environment(AppState.preview())
}

#Preview("AppIntro") {
    OnboardingView(viewModel: PreviewAppContainer.makeOnboardingViewModel(), initialPage: 3)
        .environment(AppState.preview())
}

#Preview("TermsAgreement") {
    OnboardingView(viewModel: PreviewAppContainer.makeOnboardingViewModel(), initialPage: 4)
        .environment(AppState.preview())
}

#Preview("Finish") {
    OnboardingView(viewModel: PreviewAppContainer.makeOnboardingViewModel(), initialPage: 5)
        .environment(AppState.preview())
}
