import SwiftUI

struct StudyRecordView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = StudyRecordViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    saleBanner
                    greetingSection
                    streakCard
                    reminderBanner
                    statsSection
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("学習記録")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var saleBanner: some View {
        RoundedRectangle(cornerRadius: 18)
            .fill(
                LinearGradient(
                    colors: [Color.pink.opacity(0.18), Color.orange.opacity(0.16)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 72)
            .overlay(
                HStack {
                    Text("春のチャレンジ応援")
                        .font(.headline.bold())
                    Spacer()
                    Image(systemName: "chevron.right.circle.fill")
                        .foregroundStyle(Color("main"))
                }
                .padding(.horizontal, 18)
            )
    }

    private var greetingSection: some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(Color.orange.opacity(0.2))
                .frame(width: 52, height: 52)
                .overlay(
                    Image(systemName: "tortoise.fill")
                        .foregroundStyle(Color.orange)
                )

            Text("理科子さん、久しぶりだね。会いたかったよ！")
                .font(.title3.bold())
                .foregroundStyle(.primary)
        }
        .padding(.horizontal, 4)
    }

    private var streakCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("連続学習日数")
                        .font(.headline.bold())
                    Text("自己ベスト: 2日")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(viewModel.streakText(completedWorkbookIDs: appState.completedWorkbookIDs))
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(Color.orange)
                    Text("日")
                        .font(.headline.bold())
                        .foregroundStyle(Color.orange)
                }
            }

            HStack(spacing: 10) {
                ForEach(0..<7, id: \.self) { index in
                    VStack(spacing: 8) {
                        Text(["月", "火", "水", "木", "金", "土", "日"][index])
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Circle()
                            .stroke(Color.orange.opacity(0.6), lineWidth: 2)
                            .frame(width: 24, height: 24)
                            .background(
                                Circle()
                                    .fill(index < viewModel.activeDays(completedWorkbookIDs: appState.completedWorkbookIDs) ? Color.orange.opacity(0.18) : Color.clear)
                            )
                    }
                    .frame(maxWidth: .infinity)
                }
            }

            VStack(spacing: 12) {
                chartRow(label: "学習時間", value: viewModel.chartValue(totalAnswered: appState.totalAnswered))
                chartRow(label: "問題数", value: viewModel.chartValue(totalAnswered: appState.totalAnswered))
            }
        }
        .padding(18)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private var reminderBanner: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.green.opacity(0.18))
                .frame(height: 88)
                .overlay(
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ウィジェットで勉強を\n忘れないようにしよう")
                            .font(.headline.bold())
                        Text("設定方法を見る")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                )

            RoundedRectangle(cornerRadius: 18)
                .fill(Color.orange.opacity(0.16))
                .frame(width: 110, height: 88)
                .overlay(
                    VStack(spacing: 8) {
                        Image(systemName: "square.grid.2x2.fill")
                            .font(.title2)
                            .foregroundStyle(Color.orange)
                        Text("127")
                            .font(.caption.bold())
                    }
                )
        }
    }

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("学習時間・日数")
                .font(.headline.bold())

            HStack(spacing: 12) {
                statTile(title: "解答した問題", value: "\(appState.totalAnswered)問")
                statTile(title: "正答率", value: appState.accuracyText)
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
                    Text("\(appState.wrongQuestions.count)問")
                        .font(.headline.bold())
                        .foregroundStyle(Color("main"))
                }
                .padding(18)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 18))
            }
            .buttonStyle(.plain)
        }
    }

    private func chartRow(label: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.orange.opacity(0.8))
                        .frame(width: max(proxy.size.width * CGFloat(value) / 30.0, 12), height: 8)
                }
            }
            .frame(height: 8)
        }
    }

    private func statTile(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.bold())
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }
}

#Preview {
    StudyRecordView()
        .environment(AppState.shared)
}
