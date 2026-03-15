import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0

    var body: some View {
        TabView(selection: $currentPage) {
            WelcomePage(currentPage: $currentPage)
                .tag(0)

            IntroPage(
                title: "問題集を選ぶ",
                description: "化学の様々な分野から\n自分に合った問題集を選べます",
                systemImage: "books.vertical.fill",
                currentPage: $currentPage,
                isLast: false
            )
            .tag(1)

            IntroPage(
                title: "クイズに挑戦",
                description: "4択問題に答えて\nすぐに正誤と解説を確認できます",
                systemImage: "questionmark.circle.fill",
                currentPage: $currentPage,
                isLast: false
            )
            .tag(2)

            IntroPage(
                title: "結果を振り返る",
                description: "成績を確認して\n苦手な分野を克服しましょう",
                systemImage: "chart.bar.fill",
                currentPage: $currentPage,
                isLast: true
            )
            .tag(3)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .overlay(alignment: .bottom) {
            if currentPage == 3 {
                startButtons
                    .padding(.bottom, 60)
            }
        }
    }

    private var startButtons: some View {
        VStack(spacing: 12) {
            Button {
                hasCompletedOnboarding = true
            } label: {
                Text("はじめる")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
            }

            Button {
                hasCompletedOnboarding = true
            } label: {
                Text("ログインする")
                    .font(.subheadline)
                    .foregroundStyle(Color.accentColor)
            }
        }
        .padding(.horizontal, 32)
    }
}

struct WelcomePage: View {
    @Binding var currentPage: Int

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "atom")
                .font(.system(size: 80))
                .foregroundStyle(Color.accentColor)

            Text("Rikako")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("化学を楽しく学ぼう")
                .font(.title3)
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                withAnimation {
                    currentPage = 1
                }
            } label: {
                Text("次へ")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 60)
        }
    }
}

struct IntroPage: View {
    let title: String
    let description: String
    let systemImage: String
    @Binding var currentPage: Int
    let isLast: Bool

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: systemImage)
                .font(.system(size: 64))
                .foregroundStyle(Color.accentColor)

            Text(title)
                .font(.title)
                .fontWeight(.bold)

            Text(description)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            if !isLast {
                Button {
                    withAnimation {
                        currentPage += 1
                    }
                } label: {
                    Text("次へ")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundStyle(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 60)
            } else {
                Spacer()
                    .frame(height: 120)
            }
        }
    }
}

#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
}
