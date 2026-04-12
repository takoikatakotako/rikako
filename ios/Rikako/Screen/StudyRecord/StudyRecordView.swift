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
                    colors: [Color.pink.opacity(0.22), Color.orange.opacity(0.20)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 76)
            .overlay(
                HStack(spacing: 14) {
                    Image("top-app-logo")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 48, height: 48)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("春のチャレンジ応援")
                            .font(.headline.bold())
                        Text("今日も10問ずつ進めていこう")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right.circle.fill")
                        .foregroundStyle(Color("main"))
                        .font(.title3)
                }
                .padding(.horizontal, 18)
            )
    }

    private var greetingSection: some View {
        HStack(alignment: .top, spacing: 12) {
            Image("top-rikako-standing")
                .resizable()
                .scaledToFit()
                .frame(width: 56, height: 56)
                .padding(4)
                .background(Color("main").opacity(0.10))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 6) {
                Text("理科子さん、今日も勉強してえらいね！")
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
                        .foregroundStyle(Color("main"))
                    Text("日")
                        .font(.headline.bold())
                        .foregroundStyle(Color("main"))
                }
            }

            HStack(spacing: 10) {
                ForEach(0..<7, id: \.self) { index in
                    VStack(spacing: 8) {
                        Text(["月", "火", "水", "木", "金", "土", "日"][index])
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Circle()
                            .stroke(Color("main").opacity(0.6), lineWidth: 2)
                            .frame(width: 24, height: 24)
                            .background(
                                Circle()
                                    .fill(index < viewModel.activeDays(completedWorkbookIDs: appState.completedWorkbookIDs) ? Color("main").opacity(0.18) : Color.clear)
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
        .padding(20)
        .background(
            LinearGradient(
                colors: [Color.white, Color("main").opacity(0.06)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22)
                .stroke(Color("main").opacity(0.10), lineWidth: 1.5)
        )
    }

    private var reminderBanner: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color("main").opacity(0.18))
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
                .fill(Color("main").opacity(0.12))
                .frame(width: 110, height: 88)
                .overlay(
                    VStack(spacing: 8) {
                        Text("\(appState.totalAnswered)")
                            .font(.title.bold())
                            .foregroundStyle(Color("main"))
                        Text("今までの解答数")
                            .font(.caption.bold())
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                )
        }
    }

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("学習時間・日数")
                    .font(.headline.bold())
                Spacer()
                Text("これまでの記録")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray6))
                    .clipShape(Capsule())
            }

            HStack(spacing: 12) {
                statTile(
                    title: "解答した問題",
                    value: "\(appState.totalAnswered)問",
                    icon: "square.and.pencil",
                    accentColor: Color("main")
                )
                statTile(
                    title: "正答率",
                    value: appState.accuracyText,
                    icon: "chart.line.uptrend.xyaxis",
                    accentColor: Color.green
                )
            }

            HStack(spacing: 12) {
                statTile(
                    title: "完了した問題集",
                    value: "\(appState.completedWorkbookIDs.count)冊",
                    icon: "books.vertical.fill",
                    accentColor: Color.blue
                )
                statTile(
                    title: "間違えた問題",
                    value: "\(appState.wrongQuestions.count)問",
                    icon: "arrow.counterclockwise.circle.fill",
                    accentColor: Color.orange
                )
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
                        Text("\(appState.wrongQuestions.count)問")
                            .font(.headline.bold())
                            .foregroundStyle(Color("main"))
                        Image("result-next")
                            .resizable()
                            .frame(width: 18, height: 18)
                            .opacity(0.35)
                    }
                }
                .padding(18)
                .background(
                    LinearGradient(
                        colors: [Color.white, Color("main").opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color("main").opacity(0.10), lineWidth: 1.5)
                )
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
                        .fill(Color("main").opacity(0.85))
                        .frame(width: max(proxy.size.width * CGFloat(value) / 30.0, 12), height: 8)
                }
            }
            .frame(height: 8)
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
}

#Preview {
    StudyRecordView()
        .environment(AppState.shared)
}
