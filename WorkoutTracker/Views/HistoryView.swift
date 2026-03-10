import Charts
import SwiftUI

private enum ProgressDashboardMetrics {
    static let recentRecordLimit = 6
    static let trendChartHeight: CGFloat = 220
    static let trendAxisMarkCount = 4
    static let calendarWorkoutIndicatorSize: CGFloat = 6
    static let calendarCellHeight: CGFloat = 42
}

struct ProgressDashboardView: View {
    @Environment(ProgressStore.self) private var progressStore

    @State private var displayedMonth = Calendar.autoupdatingCurrent.startOfDay(for: .now)

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                if progressStore.overview.totalSessions == 0 {
                    AppEmptyStateCard(
                        systemImage: "chart.xyaxis.line",
                        title: "No progress yet",
                        message: "Finish a session and PRs, trends, and calendar history will populate here."
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            ProgressOverviewSectionView()
                            ProgressRecordsSectionView()
                            ProgressChartSectionView()
                            ProgressCalendarSectionView(displayedMonth: $displayedMonth)
                            ProgressHistorySectionView()
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .navigationTitle("Progress")
            .toolbarBackground(AppColors.chrome, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }
}

private struct ProgressOverviewSectionView: View {
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(ProgressStore.self) private var progressStore

    var body: some View {
        AppHeroCard(
            eyebrow: "Analytics",
            title: "\(progressStore.overview.totalSessions) sessions logged",
            subtitle: "Track frequency, total volume, PRs, and exercise-level trends in one place.",
            systemImage: "chart.line.uptrend.xyaxis",
            metrics: [
                AppHeroMetric(
                    id: "week",
                    label: "This Week",
                    value: "\(progressStore.overview.sessionsThisWeek)",
                    systemImage: "calendar.badge.clock"
                ),
                AppHeroMetric(
                    id: "last30",
                    label: "Last 30d",
                    value: "\(progressStore.overview.sessionsLast30Days)",
                    systemImage: "calendar"
                ),
                AppHeroMetric(
                    id: "volume",
                    label: "Volume",
                    value: WeightFormatter.displayString(
                        progressStore.overview.totalVolume,
                        unit: settingsStore.weightUnit
                    ),
                    systemImage: "scalemass"
                ),
                AppHeroMetric(
                    id: "avg",
                    label: "Avg / Week",
                    value: String(format: "%.1f", progressStore.overview.averageSessionsPerWeek),
                    systemImage: "waveform.path.ecg"
                )
            ]
        )
    }
}

private struct ProgressRecordsSectionView: View {
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(ProgressStore.self) private var progressStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Recent Personal Records", systemImage: "rosette")
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)

            ForEach(Array(progressStore.personalRecords.prefix(ProgressDashboardMetrics.recentRecordLimit))) { record in
                PersonalRecordSummaryCardView(record: record, weightUnit: settingsStore.weightUnit)
            }
        }
    }
}

private struct ProgressChartSectionView: View {
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(ProgressStore.self) private var progressStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Exercise Trends", systemImage: "chart.line.uptrend.xyaxis")
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)

            if progressStore.exerciseSummaries.isEmpty {
                Text("Weighted logs will unlock exercise trend charts.")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
            } else {
                Picker(
                    "Exercise",
                    selection: Binding(
                        get: { progressStore.selectedExerciseID },
                        set: { progressStore.selectExercise($0) }
                    )
                ) {
                    ForEach(progressStore.exerciseSummaries) { summary in
                        Text(summary.displayName).tag(Optional(summary.exerciseID))
                    }
                }
                .pickerStyle(.menu)
                .tint(AppColors.textPrimary)

                if let summary = progressStore.selectedExerciseSummary,
                   let chartSeries = progressStore.selectedExerciseChartSeries {
                    Chart {
                        ForEach(chartSeries.trendPoints) { point in
                            AreaMark(
                                x: .value("Date", point.date),
                                y: .value("Top Weight", point.topWeight)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [AppColors.accent.opacity(0.30), AppColors.accent.opacity(0.04)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )

                            LineMark(
                                x: .value("Date", point.date),
                                y: .value("Top Weight", point.topWeight)
                            )
                            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                            .foregroundStyle(AppColors.accent)
                        }

                        ForEach(chartSeries.markerPoints) { point in
                            PointMark(
                                x: .value("Date", point.date),
                                y: .value("Top Weight", point.topWeight)
                            )
                            .foregroundStyle(AppColors.accent)
                        }
                    }
                    .frame(height: ProgressDashboardMetrics.trendChartHeight)
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: ProgressDashboardMetrics.trendAxisMarkCount))
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }

                    if chartSeries.isSampled {
                        Text("Showing a sampled trend for longer exercise histories.")
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    HStack(spacing: 10) {
                        MetricBadge(
                            label: "Points",
                            value: "\(summary.pointCount)",
                            systemImage: "chart.bar"
                        )
                        MetricBadge(
                            label: "Volume",
                            value: WeightFormatter.displayString(summary.totalVolume, unit: settingsStore.weightUnit),
                            systemImage: "scalemass"
                        )
                    }
                }
            }
        }
        .padding(AppCardMetrics.compactPadding)
        .appSurface(cornerRadius: AppCardMetrics.compactCornerRadius, shadow: false)
    }
}

private struct ProgressCalendarSectionView: View {
    @Environment(ProgressStore.self) private var progressStore

    @Binding var displayedMonth: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Session Calendar", systemImage: "calendar")
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)

            AppCalendarGrid(
                displayedMonth: $displayedMonth,
                workoutDays: progressStore.workoutDays,
                selectedDay: Binding(
                    get: { progressStore.selectedDay },
                    set: { progressStore.selectDay($0) }
                )
            )
        }
        .padding(AppCardMetrics.compactPadding)
        .appSurface(cornerRadius: AppCardMetrics.compactCornerRadius, shadow: false)
    }
}

private struct ProgressHistorySectionView: View {
    @Environment(ProgressStore.self) private var progressStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Logged Sessions", systemImage: "clock.arrow.circlepath")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)

                Spacer()

                if progressStore.selectedDay != nil {
                    Button("Show All") {
                        progressStore.selectDay(nil)
                    }
                    .font(.caption.weight(.semibold))
                }
            }

            if progressStore.historySessions.isEmpty {
                Text("No workouts match the selected day.")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(AppCardMetrics.compactPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .appSurface(cornerRadius: AppCardMetrics.compactCornerRadius, shadow: false)
            } else {
                ForEach(progressStore.historySessions) { session in
                    CompletedSessionSummaryCardView(session: session)
                }
            }
        }
    }
}

struct AppCalendarMonthLayout: Equatable {
    struct DayEntry: Identifiable, Equatable {
        let id: Int
        let date: Date?
        let dayNumber: Int?
        let hasWorkout: Bool
    }

    let monthStart: Date
    let title: String
    let weekdaySymbols: [String]
    let dayEntries: [DayEntry]

    static func make(
        for displayedMonth: Date,
        workoutDays: Set<Date>,
        calendar: Calendar = .autoupdatingCurrent
    ) -> AppCalendarMonthLayout {
        let monthStart = calendar.date(
            from: calendar.dateComponents([.year, .month], from: displayedMonth)
        ) ?? displayedMonth
        let title = monthStart.formatted(.dateTime.month(.wide).year())
        let weekdaySymbols = calendar.shortStandaloneWeekdaySymbols

        guard let dayRange = calendar.range(of: .day, in: .month, for: monthStart),
              let firstWeekday = calendar.dateComponents([.weekday], from: monthStart).weekday else {
            return AppCalendarMonthLayout(
                monthStart: monthStart,
                title: title,
                weekdaySymbols: weekdaySymbols,
                dayEntries: []
            )
        }

        let normalizedLeading = (firstWeekday - calendar.firstWeekday + 7) % 7
        var dayEntries: [DayEntry] = []
        dayEntries.reserveCapacity(normalizedLeading + dayRange.count)

        for _ in 0..<normalizedLeading {
            dayEntries.append(
                DayEntry(
                    id: dayEntries.count,
                    date: nil,
                    dayNumber: nil,
                    hasWorkout: false
                )
            )
        }

        for dayNumber in dayRange {
            let date = calendar.date(byAdding: .day, value: dayNumber - 1, to: monthStart)
            let normalizedDate = date.map { calendar.startOfDay(for: $0) }
            dayEntries.append(
                DayEntry(
                    id: dayEntries.count,
                    date: normalizedDate,
                    dayNumber: dayNumber,
                    hasWorkout: normalizedDate.map { workoutDays.contains($0) } ?? false
                )
            )
        }

        return AppCalendarMonthLayout(
            monthStart: monthStart,
            title: title,
            weekdaySymbols: weekdaySymbols,
            dayEntries: dayEntries
        )
    }
}

private struct AppCalendarDayCellView: View, Equatable {
    let entry: AppCalendarMonthLayout.DayEntry
    let isSelected: Bool
    let onSelect: () -> Void

    nonisolated static func == (lhs: AppCalendarDayCellView, rhs: AppCalendarDayCellView) -> Bool {
        lhs.entry == rhs.entry && lhs.isSelected == rhs.isSelected
    }

    var body: some View {
        Group {
            if let date = entry.date,
               let dayNumber = entry.dayNumber {
                Button {
                    onSelect()
                } label: {
                    VStack(spacing: 3) {
                        Text("\(dayNumber)")
                            .font(.subheadline.weight(entry.hasWorkout ? .semibold : .regular))
                            .foregroundStyle(entry.hasWorkout ? AppColors.textPrimary : AppColors.textSecondary)

                        Circle()
                            .fill(entry.hasWorkout ? AppColors.accent : .clear)
                            .frame(
                                width: ProgressDashboardMetrics.calendarWorkoutIndicatorSize,
                                height: ProgressDashboardMetrics.calendarWorkoutIndicatorSize
                            )
                    }
                    .frame(maxWidth: .infinity, minHeight: ProgressDashboardMetrics.calendarCellHeight)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                isSelected
                                    ? AppColors.accent.opacity(0.20)
                                    : AppColors.surface.opacity(0.35)
                            )
                    )
                }
                .buttonStyle(.plain)
                .disabled(!entry.hasWorkout)
                .accessibilityIdentifier("progress.calendar.day.\(date.formatted(.iso8601.year().month().day()))")
            } else {
                Color.clear
                    .frame(height: ProgressDashboardMetrics.calendarCellHeight)
            }
        }
    }
}

private struct AppCalendarGrid: View {
    private static let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    @Binding var displayedMonth: Date
    let workoutDays: Set<Date>
    @Binding var selectedDay: Date?

    private let calendar = Calendar.autoupdatingCurrent

    @State private var monthLayout: AppCalendarMonthLayout

    init(displayedMonth: Binding<Date>, workoutDays: Set<Date>, selectedDay: Binding<Date?>) {
        self._displayedMonth = displayedMonth
        self.workoutDays = workoutDays
        self._selectedDay = selectedDay
        _monthLayout = State(
            initialValue: AppCalendarMonthLayout.make(
                for: displayedMonth.wrappedValue,
                workoutDays: workoutDays
            )
        )
    }

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    shiftMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                }

                Spacer()

                Text(monthLayout.title)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(AppColors.textPrimary)

                Spacer()

                Button {
                    shiftMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
            }

            LazyVGrid(columns: Self.columns, spacing: 8) {
                ForEach(Array(monthLayout.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(monthLayout.dayEntries) { entry in
                    AppCalendarDayCellView(
                        entry: entry,
                        isSelected: entry.date == selectedDay,
                        onSelect: {
                            selectedDay = entry.date == selectedDay ? nil : entry.date
                        }
                    )
                    .equatable()
                }
            }
        }
        .onChange(of: displayedMonth, initial: false) { _, newValue in
            monthLayout = AppCalendarMonthLayout.make(for: newValue, workoutDays: workoutDays)
        }
        .onChange(of: workoutDays, initial: false) { _, newValue in
            monthLayout = AppCalendarMonthLayout.make(for: displayedMonth, workoutDays: newValue)
        }
    }

    private func shiftMonth(by value: Int) {
        guard let nextMonth = calendar.date(byAdding: .month, value: value, to: monthLayout.monthStart) else {
            return
        }

        displayedMonth = nextMonth
    }
}
