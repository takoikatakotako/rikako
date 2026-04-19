import SwiftUI

struct StudyRecordView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = StudyRecordViewModel()
    @State private var summary: UserSummary?
    @State private var wrongAnswersTotal = 0
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    skeletonView
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            greetingSection
                            streakCard
                            statsSection
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .background(Color(.systemGroupedBackground))
                }
            }
            .navigationTitle("学習記録")
            .navigationBarTitleDisplayMode(.inline)
        }
        .task { await load() }
    }

    private var skeletonView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // greetingSection skeleton
                HStack(alignment: .top, spacing: 12) {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 56, height: 56)
                    VStack(alignment: .leading, spacing: 8) {
                        skeletonRect(width: 200, height: 16)
                        skeletonRect(width: 160, height: 13)
                    }
                    .padding(.top, 6)
                }
                .padding(.horizontal, 4)

                // streakCard skeleton
                VStack(alignment: .leading, spacing: 18) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 6) {
                            skeletonRect(width: 110, height: 15)
                            skeletonRect(width: 80, height: 12)
                        }
                        Spacer()
                        skeletonRect(width: 70, height: 48)
                    }
                    HStack(spacing: 10) {
                        ForEach(0..<7, id: \.self) { _ in
                            VStack(spacing: 8) {
                                skeletonRect(width: 14, height: 11)
                                Circle()
                                    .fill(Color(.systemGray5))
                                    .frame(width: 24, height: 24)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(20)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 22))

                // statsSection skeleton
                VStack(alignment: .leading, spacing: 12) {
                    skeletonRect(width: 140, height: 15)

                    HStack(spacing: 12) {
                        skeletonTile()
                        skeletonTile()
                    }
                    HStack(spacing: 12) {
                        skeletonTile()
                        skeletonTile()
                    }

                    // Review list card skeleton
                    HStack {
                        VStack(alignment: .leading, spacing: 8) {
                            skeletonRect(width: 80, height: 15)
                            skeletonRect(width: 130, height: 12)
                        }
                        Spacer()
                        skeletonRect(width: 44, height: 15)
                    }
                    .padding(18)
                    .background(Color(.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 18))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .background(Color(.systemGroupedBackground))
    }

    private func skeletonRect(width: CGFloat? = nil, height: CGFloat = 14) -> some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color(.systemGray5))
            .frame(width: width, height: height)
    }

    private func skeletonTile() -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 24, height: 24)
                skeletonRect(width: 60, height: 12)
            }
            skeletonRect(width: 50, height: 24)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private var greetingSection: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "tortoise.fill")
                .font(.title2)
                .foregroundStyle(Color(.main))
                .frame(width: 56, height: 56)
                .background(Color(.main).opacity(0.10))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 6) {
                Text(appState.displayName.map { "\($0)さん、今日も勉強してえらいね！" } ?? "今日も勉強してえらいね！")
                    .font(.title3.bold())
                    .foregroundStyle(.primary)

                Text("学習記録を見ながら、少しずつ進めていこう。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 4)
    }

    private var streakCard: some View {
        let studyDates = Set(summary?.studyDates ?? [])
        let weekly = viewModel.weeklyStudied(studyDates: studyDates)
        let weeklyCount = viewModel.weeklyStudyCount(studyDates: studyDates)
        let streak = viewModel.streak(studyDates: studyDates)
        return VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("連続学習日数")
                        .font(.headline.bold())
                    Text("今週の学習: \(weeklyCount)日")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text("\(streak)")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(Color(.main))
                    Text("日")
                        .font(.headline.bold())
                        .foregroundStyle(Color(.main))
                }
            }

            HStack(spacing: 10) {
                ForEach(0..<7, id: \.self) { index in
                    VStack(spacing: 8) {
                        Text(["月", "火", "水", "木", "金", "土", "日"][index])
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Circle()
                            .stroke(Color(.main).opacity(0.6), lineWidth: 2)
                            .frame(width: 24, height: 24)
                            .background(
                                Circle()
                                    .fill(weekly[index] ? Color(.main).opacity(0.18) : Color.clear)
                            )
                    }
                    .frame(maxWidth: .infinity)
                }
            }

        }
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color.white, Color(.main).opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color(.main).opacity(0.10), lineWidth: 1.5)
        )
    }

    private var statsSection: some View {
        let weeklyAnswered = summary?.weeklyAnswered ?? 0
        let weeklyAccuracyText = summary?.weeklyAccuracyText ?? "---%"
        let weeklyWorkbookCount = summary?.weeklyWorkbookIds.count ?? 0

        return VStack(alignment: .leading, spacing: 12) {
            Text("今週の学習時間・日数")
                .font(.headline.bold())

            HStack(spacing: 12) {
                statTile(title: "解答した問題", value: "\(weeklyAnswered)問", icon: "square.and.pencil", accentColor: Color(.main))
                statTile(title: "正答率", value: weeklyAccuracyText, icon: "chart.line.uptrend.xyaxis", accentColor: Color.green)
            }

            HStack(spacing: 12) {
                statTile(title: "勉強した問題集", value: "\(weeklyWorkbookCount)冊", icon: "books.vertical.fill", accentColor: Color.blue)
                statTile(title: "間違えた問題", value: "\(wrongAnswersTotal)問", icon: "arrow.counterclockwise.circle.fill", accentColor: Color.orange)
            }

            NavigationLink(destination: WrongAnswersView()) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("復習リスト")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("間違えた問題を見直す")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(spacing: 6) {
                        Text("\(wrongAnswersTotal)問")
                            .font(.headline.bold())
                            .foregroundStyle(Color(.main))
                        Image(.resultNext)
                            .resizable()
                            .frame(width: 18, height: 18)
                            .opacity(0.35)
                    }
                }
                .padding(18)
                .background(
                    LinearGradient(
                        colors: [Color.white, Color(.main).opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color(.main).opacity(0.10), lineWidth: 1.5)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func statTile(title: String, value: String, icon: String, accentColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.caption.bold())
                    .foregroundStyle(accentColor)
                    .frame(width: 24, height: 24)
                    .background(accentColor.opacity(0.12))
                    .clipShape(Circle())

                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(accentColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.white)
                .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func load() async {
        isLoading = true
        async let summaryResult = try? AppContainer.shared.learningUseCases.fetchUserSummary.execute()
        async let wrongResult = try? AppContainer.shared.learningUseCases.fetchWrongAnswers.execute(limit: 1, offset: 0)
        summary = await summaryResult
        wrongAnswersTotal = await wrongResult?.total ?? 0
        isLoading = false
    }
}

#Preview {
    StudyRecordView()
        .environment(AppState.shared)
}
