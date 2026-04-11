import SwiftUI

struct OnboardingView: View {
    @Environment(StudyStore.self) private var studyStore
    @State private var currentPage = 0

    var body: some View {
        TabView(selection: $currentPage) {
            WelcomePage(currentPage: $currentPage)
                .tag(0)

            IntroPage(
                title: "問題集を選ぶ",
                description: "化学の様々な分野から\n自分に合った問題集を選べます",
                systemImage: "books.vertical.fill",
                currentPage: $currentPage
            )
            .tag(1)

            IntroPage(
                title: "クイズに挑戦",
                description: "4択問題に答えて\nすぐに正誤と解説を確認できます",
                systemImage: "questionmark.circle.fill",
                currentPage: $currentPage
            )
            .tag(2)

            StartPage()
                .tag(3)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
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
        }
    }
}

struct StartPage: View {
    @Environment(StudyStore.self) private var studyStore

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "chart.bar.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.accentColor)

            Text("結果を振り返る")
                .font(.title)
                .fontWeight(.bold)

            Text("成績を確認して\n苦手な分野を克服しましょう")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            Button {
                studyStore.completeOnboarding()
            } label: {
                Text("はじめる")
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

#Preview {
    OnboardingView()
        .environment(StudyStore.shared)
}
