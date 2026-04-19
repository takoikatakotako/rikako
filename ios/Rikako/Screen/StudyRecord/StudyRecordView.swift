import SwiftUI

struct StudyRecordView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = StudyRecordViewModel()
    @State private var summary: UserSummary?
    @State private var wrongAnswersTotal = 0
    @State private var popoverDayIndex: Int? = nil
    @State private var isLoading = true
    private let isPreview: Bool

    init() {
        isPreview = false
    }

    fileprivate init(skeletonPreview: Bool) {
        isPreview = skeletonPreview
    }

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
                            studyHistorySection
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
        .task {
            guard !isPreview else { return }
            await load()
        }
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

                // studyHistorySection skeleton
                VStack(alignment: .leading, spacing: 12) {
                    skeletonRect(width: 130, height: 15)
                    VStack(alignment: .leading, spacing: 10) {
                        skeletonRect(height: 108)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        HStack { Spacer(); skeletonRect(width: 90, height: 10) }
                    }
                    .padding(16)
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
                    Button {
                        popoverDayIndex = index
                    } label: {
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
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: Binding(
                        get: { popoverDayIndex == index },
                        set: { if !$0 { popoverDayIndex = nil } }
                    )) {
                        dayPopoverContent(dayIndex: index)
                    }
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

    private var weeklyWrongCount: Int {
        let answered = summary?.weeklyAnswered ?? 0
        let correct = summary?.weeklyCorrect ?? 0
        return max(0, answered - correct)
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
                statTile(title: "間違えた問題", value: "\(weeklyWrongCount)問", icon: "arrow.counterclockwise.circle.fill", accentColor: Color.orange)
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

    private func dayPopoverContent(dayIndex: Int) -> some View {
        let date = viewModel.weeklyDate(at: dayIndex)
        let studyDates = Set(summary?.studyDates ?? [])
        let studied = date.map { studyDates.contains(DateFormatter.yyyyMMdd.string(from: $0)) } ?? false
        let dayNames = ["月", "火", "水", "木", "金", "土", "日"]
        let dateLabel: String = {
            guard let date else { return "--" }
            let f = DateFormatter()
            f.dateFormat = "M月d日"
            return "\(f.string(from: date))（\(dayNames[dayIndex])）"
        }()

        return VStack(alignment: .leading, spacing: 10) {
            Text(dateLabel)
                .font(.headline.bold())
            if studied {
                Label("学習しました", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(Color(.main))
                    .font(.subheadline)
            } else {
                Label("学習していません", systemImage: "minus.circle")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }
        }
        .padding(18)
        .presentationCompactAdaptation(.popover)
    }

    private static let heatmapDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private var studyHistorySection: some View {
        let studySet = Set(summary?.studyDates ?? [])
        let weeks = makeWeeks()
        return VStack(alignment: .leading, spacing: 12) {
            Text("今までの学習記録")
                .font(.headline.bold())

            VStack(alignment: .leading, spacing: 10) {
                ScrollView(.horizontal, showsIndicators: false) {
                    ScrollViewReader { proxy in
                        heatmapGrid(weeks: weeks, studySet: studySet)
                            .padding(.vertical, 2)
                            .onAppear {
                                proxy.scrollTo("week-\(weeks.count - 1)", anchor: .trailing)
                            }
                    }
                }

                HStack(spacing: 6) {
                    Spacer()
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color(.main).opacity(0.75))
                        .frame(width: 11, height: 11)
                    Text("学習した日")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)
            .background(Color.white)
            .clipShape(RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(Color(.main).opacity(0.08), lineWidth: 1.5)
            )
        }
    }

    private func heatmapGrid(weeks: [[Date?]], studySet: Set<String>) -> some View {
        let cellSize: CGFloat = 11
        let gap: CGFloat = 3
        let dayLabelWidth: CGFloat = 18
        let dayLabels = ["月", "", "水", "", "金", "", ""]

        return VStack(alignment: .leading, spacing: 4) {
            // Month labels
            HStack(alignment: .bottom, spacing: gap) {
                Color.clear.frame(width: dayLabelWidth + gap)
                ForEach(weeks.indices, id: \.self) { i in
                    Text(heatmapMonthLabel(for: weeks[i]))
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                        .frame(width: cellSize, alignment: .leading)
                }
            }

            // Grid
            HStack(alignment: .top, spacing: gap) {
                // Day labels (月水金 only)
                VStack(alignment: .leading, spacing: gap) {
                    ForEach(0..<7, id: \.self) { i in
                        Text(dayLabels[i])
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                            .frame(width: dayLabelWidth, height: cellSize, alignment: .leading)
                    }
                }

                // Week columns
                ForEach(weeks.indices, id: \.self) { weekIndex in
                    VStack(spacing: gap) {
                        ForEach(0..<7, id: \.self) { dayIndex in
                            if let date = weeks[weekIndex][dayIndex] {
                                let str = Self.heatmapDateFormatter.string(from: date)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(studySet.contains(str) ? Color(.main).opacity(0.75) : Color(.systemGray5))
                                    .frame(width: cellSize, height: cellSize)
                            } else {
                                Color.clear.frame(width: cellSize, height: cellSize)
                            }
                        }
                    }
                    .id("week-\(weekIndex)")
                }
            }
        }
    }

    private func heatmapMonthLabel(for week: [Date?]) -> String {
        let calendar = Calendar.current
        for date in week.compactMap({ $0 }) {
            if calendar.component(.day, from: date) == 1 {
                return "\(calendar.component(.month, from: date))月"
            }
        }
        return ""
    }

    private func makeWeeks(count: Int = 53) -> [[Date?]] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        let today = Date()
        let weekday = calendar.component(.weekday, from: today)
        let daysBack = (weekday - 2 + 7) % 7
        let monday = calendar.date(byAdding: .day, value: -daysBack, to: today)!
        let startDate = calendar.date(byAdding: .weekOfYear, value: -(count - 1), to: monday)!
        var weeks: [[Date?]] = []
        var weekStart = startDate
        for _ in 0..<count {
            var week: [Date?] = []
            for d in 0..<7 {
                if let day = calendar.date(byAdding: .day, value: d, to: weekStart) {
                    week.append(day <= today ? day : nil)
                } else {
                    week.append(nil)
                }
            }
            weeks.append(week)
            weekStart = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart)!
        }
        return weeks
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

#Preview("通常") {
    StudyRecordView()
        .environment(AppState.shared)
}

#Preview("読み込み中") {
    StudyRecordView(skeletonPreview: true)
        .environment(AppState.shared)
}
