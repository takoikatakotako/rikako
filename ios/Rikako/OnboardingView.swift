import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var selectedCategoryRaw = ""
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

            IntroPage(
                title: "結果を振り返る",
                description: "成績を確認して\n苦手な分野を克服しましょう",
                systemImage: "chart.bar.fill",
                currentPage: $currentPage
            )
            .tag(3)

            CategorySelectPage(
                selectedCategoryRaw: $selectedCategoryRaw,
                hasCompletedOnboarding: $hasCompletedOnboarding
            )
            .tag(4)
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

struct CategorySelectPage: View {
    @Binding var selectedCategoryRaw: String
    @Binding var hasCompletedOnboarding: Bool
    @State private var selectedCategory: Category?

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("どの分野を学びますか？")
                .font(.title2)
                .fontWeight(.bold)

            Text("あとから設定で変更できます")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            VStack(spacing: 12) {
                ForEach(Category.allCases) { category in
                    Button {
                        selectedCategory = category
                    } label: {
                        HStack {
                            Image(systemName: category.icon)
                                .font(.title2)
                                .frame(width: 32)
                            Text(category.displayName)
                                .font(.body)
                                .fontWeight(.medium)
                            Spacer()
                            if selectedCategory == category {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .padding()
                        .background(selectedCategory == category ? Color.accentColor.opacity(0.1) : Color(.systemGray6))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(selectedCategory == category ? Color.accentColor : Color.clear, lineWidth: 2)
                        )
                    }
                    .foregroundStyle(.primary)
                }
            }
            .padding(.horizontal, 32)

            Spacer()

            Button {
                if let category = selectedCategory {
                    selectedCategoryRaw = category.rawValue
                }
                hasCompletedOnboarding = true
            } label: {
                Text("はじめる")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(selectedCategory != nil ? Color.accentColor : Color.gray)
                    .foregroundStyle(.white)
                    .cornerRadius(12)
            }
            .disabled(selectedCategory == nil)
            .padding(.horizontal, 32)
            .padding(.bottom, 60)
        }
    }
}

#Preview {
    OnboardingView(hasCompletedOnboarding: .constant(false))
}
