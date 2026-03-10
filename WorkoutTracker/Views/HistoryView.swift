import Charts
import SwiftUI

private enum ProgressDashboardMetrics {
    static let recentRecordLimit = 6
    static let trendChartHeight: CGFloat = 220
    static let trendAxisMarkCount = 4
    static let calendarWorkoutIndicatorSize: CGFloat = 6
    static let calendarWorkoutIndicatorWidth: CGFloat = 18
    static let calendarCellHeight: CGFloat = 42
    static let calendarCellCornerRadius: CGFloat = 12
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
                        message: "Finish a session and PRs, trends, and calendar history will populate here.",
                        tone: .progress
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

    private var momentumTone: AppToneStyle {
        if progressStore.overview.sessionsThisWeek >= 4 {
            return .success
        }
        if progressStore.overview.sessionsThisWeek >= 1 {
            return .progress
        }
        return .warning
    }

    private var heroSubtitle: String {
        if progressStore.overview.sessionsThisWeek >= 4 {
            return "A strong week is already in motion. Keep the streak alive and watch your trend lines compound."
        }
        if progressStore.overview.sessionsThisWeek >= 1 {
            return "Momentum is building this week. Use the trends and calendar to keep your next session on pace."
        }
        return "Your history is ready. Log the next session to restart the weekly rhythm and keep PRs moving."
    }

    private var momentumTitle: String {
        "\(progressStore.overview.sessionsThisWeek) this week"
    }

    private var momentumMessage: String {
        if progressStore.overview.sessionsThisWeek >= 4 {
            return "You are ahead of your usual pace and stacking meaningful volume early in the week."
        }
        if progressStore.overview.sessionsThisWeek >= 1 {
            return "You already have traction this week. Keep the cadence steady and the averages will follow."
        }
        return "No sessions logged this week yet. One workout is enough to put the dashboard back in motion."
    }

    var body: some View {
        VStack(spacing: 12) {
            AppHeroCard(
                eyebrow: "Analytics",
                title: "\(progressStore.overview.totalSessions) sessions logged",
                subtitle: heroSubtitle,
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
                    ),
                ],
                tone: .progress
            )

            ProgressSpotlightCard(tone: momentumTone) {
                VStack(alignment: .leading, spacing: 12) {
                    AppSectionHeader(
                        title: "Momentum",
                        systemImage: "flame.fill",
                        subtitle: momentumMessage,
                        trailing: momentumTitle,
                        tone: momentumTone
                    )

                    HStack(spacing: 8) {
                        MetricBadge(
                            label: "30 Days",
                            value: "\(progressStore.overview.sessionsLast30Days)",
                            systemImage: "calendar",
                            tone: .progress
                        )
                        MetricBadge(
                            label: "Avg/Week",
                            value: String(format: "%.1f", progressStore.overview.averageSessionsPerWeek),
                            systemImage: "waveform.path.ecg",
                            tone: .warning
                        )
                        MetricBadge(
                            label: "Volume",
                            value: WeightFormatter.displayString(progressStore.overview.totalVolume, unit: settingsStore.weightUnit),
                            systemImage: "scalemass",
                            tone: .success
                        )
                    }
                }
            }
        }
    }
}

private struct ProgressRecordsSectionView: View {
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(ProgressStore.self) private var progressStore

    private var recentRecords: [PersonalRecord] {
        Array(progressStore.personalRecords.prefix(ProgressDashboardMetrics.recentRecordLimit))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppSectionHeader(
                title: "Recent Personal Records",
                systemImage: "rosette",
                subtitle: recentRecords.isEmpty
                    ? "Heavy work and rep PRs will surface here after you log more sessions."
                    : "Your latest highlights stay pinned at the top so progress feels visible.",
                trailing: recentRecords.isEmpty ? nil : "\(recentRecords.count)",
                tone: .success
            )

            if let featuredRecord = recentRecords.first {
                ProgressRecordSpotlightCardView(record: featuredRecord, weightUnit: settingsStore.weightUnit)

                if recentRecords.count > 1 {
                    LazyVStack(spacing: 10) {
                        ForEach(Array(recentRecords.dropFirst())) { record in
                            PersonalRecordSummaryCardView(record: record, weightUnit: settingsStore.weightUnit, tone: .success)
                        }
                    }
                }
            } else {
                AppEmptyStateCard(
                    systemImage: "rosette",
                    title: "No PRs yet",
                    message: "Your first standout sets will show up here once a logged session beats an earlier benchmark.",
                    tone: .success
                )
            }
        }
    }
}

private struct ProgressChartSectionView: View {
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(ProgressStore.self) private var progressStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppSectionHeader(
                title: "Exercise Trends",
                systemImage: "chart.line.uptrend.xyaxis",
                subtitle: progressStore.exerciseSummaries.isEmpty
                    ? "Weighted logs unlock exercise-level trend lines and PR callouts."
                    : "Follow top-set load and estimated strength over time for a single exercise.",
                trailing: progressStore.selectedExerciseSummary.map { "\($0.pointCount) points" },
                tone: .progress
            )

            if progressStore.exerciseSummaries.isEmpty {
                AppEmptyStateCard(
                    systemImage: "chart.line.uptrend.xyaxis",
                    title: "No trend data yet",
                    message: "Weighted logs will unlock exercise trend charts and strength callouts.",
                    tone: .progress
                )
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    AppSectionHeader(
                        title: "Tracked Exercise",
                        systemImage: "dumbbell",
                        subtitle: "Switch the active movement to compare long-term load and strength trends.",
                        tone: .today
                    )

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
                }
                .appInsetContentCard(
                    fill: AppToneStyle.today.softFill.opacity(0.45),
                    border: AppToneStyle.today.softBorder
                )

                if let summary = progressStore.selectedExerciseSummary,
                    let chartSeries = progressStore.selectedExerciseChartSeries
                {
                    ProgressExerciseSummaryCardView(summary: summary, weightUnit: settingsStore.weightUnit)

                    VStack(alignment: .leading, spacing: 12) {
                        AppSectionHeader(
                            title: "Top Set Trend",
                            systemImage: "chart.xyaxis.line",
                            subtitle: "Solid line shows top logged load. Dashed line estimates one-rep max from the same sessions.",
                            trailing: summary.currentPR.map {
                                "PR \(WeightFormatter.displayString($0.weight, unit: settingsStore.weightUnit)) \(settingsStore.weightUnit.symbol)"
                            },
                            tone: .progress
                        )

                        Chart {
                            ForEach(chartSeries.trendPoints) { point in
                                AreaMark(
                                    x: .value("Date", point.date),
                                    y: .value("Top Weight", point.topWeight)
                                )
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [AppColors.accentProgress.opacity(0.34), AppColors.accentProgress.opacity(0.05)],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )

                                LineMark(
                                    x: .value("Date", point.date),
                                    y: .value("Top Weight", point.topWeight)
                                )
                                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))
                                .foregroundStyle(AppColors.accentProgress)

                                LineMark(
                                    x: .value("Date", point.date),
                                    y: .value("Estimated 1RM", point.estimatedOneRepMax)
                                )
                                .lineStyle(StrokeStyle(lineWidth: 1.8, lineCap: .round, lineJoin: .round, dash: [5, 4]))
                                .foregroundStyle(AppColors.success.opacity(0.78))
                            }

                            ForEach(chartSeries.markerPoints) { point in
                                PointMark(
                                    x: .value("Date", point.date),
                                    y: .value("Top Weight", point.topWeight)
                                )
                                .foregroundStyle(AppColors.accentProgress)
                            }

                            if let currentPR = summary.currentPR {
                                RuleMark(y: .value("PR Weight", currentPR.weight))
                                    .foregroundStyle(AppColors.success.opacity(0.44))
                                    .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [4, 4]))
                                    .annotation(position: .top, alignment: .trailing) {
                                        Text("Current PR")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(AppColors.success)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 5)
                                            .appInsetCard(
                                                cornerRadius: 999,
                                                fill: AppToneStyle.success.softFill.opacity(0.84),
                                                border: AppToneStyle.success.softBorder
                                            )
                                    }
                            }
                        }
                        .frame(height: ProgressDashboardMetrics.trendChartHeight)
                        .chartPlotStyle { plotArea in
                            plotArea
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(AppColors.input.opacity(0.60))
                                )
                        }
                        .chartXAxis {
                            AxisMarks(values: .automatic(desiredCount: ProgressDashboardMetrics.trendAxisMarkCount)) { value in
                                AxisGridLine()
                                    .foregroundStyle(AppColors.stroke.opacity(0.16))
                                AxisTick()
                                    .foregroundStyle(AppColors.stroke.opacity(0.5))
                                AxisValueLabel {
                                    if let date = value.as(Date.self) {
                                        Text(date.formatted(.dateTime.month(.abbreviated).day()))
                                            .font(.caption2)
                                            .foregroundStyle(AppColors.textSecondary)
                                    }
                                }
                            }
                        }
                        .chartYAxis {
                            AxisMarks(position: .leading) { value in
                                AxisGridLine()
                                    .foregroundStyle(AppColors.stroke.opacity(0.22))
                                AxisTick()
                                    .foregroundStyle(AppColors.stroke.opacity(0.5))
                                AxisValueLabel {
                                    if let axisWeight = value.as(Double.self) {
                                        Text(
                                            WeightFormatter.displayString(
                                                displayValue: settingsStore.weightUnit.displayValue(fromStoredPounds: axisWeight),
                                                unit: settingsStore.weightUnit
                                            )
                                        )
                                        .font(.caption2)
                                        .foregroundStyle(AppColors.textSecondary)
                                    }
                                }
                            }
                        }

                        HStack(spacing: 8) {
                            ProgressLegendPill(title: "Top weight", systemImage: "line.diagonal", tone: .progress)
                            ProgressLegendPill(title: "Estimated 1RM", systemImage: "waveform.path.ecg", tone: .success)

                            if chartSeries.isSampled {
                                ProgressLegendPill(title: "Sampled", systemImage: "ellipsis", tone: .warning)
                            }
                        }

                        HStack(spacing: 10) {
                            MetricBadge(
                                label: "Points",
                                value: "\(summary.pointCount)",
                                systemImage: "chart.bar",
                                tone: .progress
                            )
                            MetricBadge(
                                label: "Volume",
                                value: WeightFormatter.displayString(summary.totalVolume, unit: settingsStore.weightUnit),
                                systemImage: "scalemass",
                                tone: .warning
                            )

                            if let currentPR = summary.currentPR {
                                MetricBadge(
                                    label: "PR",
                                    value: WeightFormatter.displayString(currentPR.estimatedOneRepMax, unit: settingsStore.weightUnit),
                                    systemImage: "rosette",
                                    tone: .success
                                )
                            }
                        }
                    }
                    .appInsetContentCard(
                        fill: AppToneStyle.progress.softFill.opacity(0.34),
                        border: AppToneStyle.progress.softBorder
                    )
                }
            }
        }
        .padding(AppCardMetrics.featurePadding)
        .appSurface(cornerRadius: AppCardMetrics.featureCornerRadius, shadow: false)
    }
}

private struct ProgressCalendarSectionView: View {
    @Environment(ProgressStore.self) private var progressStore

    @Binding var displayedMonth: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppSectionHeader(
                title: "Session Calendar",
                systemImage: "calendar",
                subtitle: progressStore.selectedDay == nil
                    ? "Tap any logged day to focus the session history below."
                    : "A selected day narrows the history list so you can inspect that training date quickly.",
                trailing: "\(progressStore.workoutDays.count) active",
                tone: .progress
            )

            if let selectedDay = progressStore.selectedDay {
                ProgressSelectedDayCardView(selectedDay: selectedDay, sessionCount: progressStore.historySessions.count)
            }

            AppCalendarGrid(
                displayedMonth: $displayedMonth,
                workoutDays: progressStore.workoutDays,
                selectedDay: Binding(
                    get: { progressStore.selectedDay },
                    set: { progressStore.selectDay($0) }
                )
            )

            HStack(spacing: 8) {
                ProgressLegendPill(title: "Logged day", systemImage: "circle.fill", tone: .success)
                ProgressLegendPill(title: "Selected", systemImage: "calendar.badge.clock", tone: .progress)
                ProgressLegendPill(title: "Today", systemImage: "sun.max.fill", tone: .warning)
            }
        }
        .padding(AppCardMetrics.featurePadding)
        .appSurface(cornerRadius: AppCardMetrics.featureCornerRadius, shadow: false)
    }
}

private struct ProgressHistorySectionView: View {
    @Environment(ProgressStore.self) private var progressStore

    private var selectedDayLabel: String? {
        progressStore.selectedDay?.formatted(date: .abbreviated, time: .omitted)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppSectionHeader(
                title: "Logged Sessions",
                systemImage: "clock.arrow.circlepath",
                subtitle: selectedDayLabel == nil
                    ? "Browse the latest completed sessions or narrow the list from the calendar above."
                    : "Showing only the workouts logged on \(selectedDayLabel!).",
                trailing: "\(progressStore.historySessions.count)",
                tone: progressStore.selectedDay == nil ? .progress : .success
            )

            if let selectedDayLabel {
                HStack(spacing: 8) {
                    AppStatePill(title: selectedDayLabel, systemImage: "calendar.badge.clock", tone: .success)

                    Button("Show All") {
                        progressStore.selectDay(nil)
                    }
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .appInsetCard(
                        cornerRadius: 999,
                        fill: AppToneStyle.progress.softFill.opacity(0.84),
                        border: AppToneStyle.progress.softBorder
                    )
                    .buttonStyle(.plain)
                }
            }

            if progressStore.historySessions.isEmpty {
                AppEmptyStateCard(
                    systemImage: "calendar.badge.exclamationmark",
                    title: "No sessions for this filter",
                    message: "Choose another logged day or clear the calendar filter to see every completed workout.",
                    tone: .warning
                )
            } else {
                ForEach(progressStore.historySessions) { session in
                    CompletedSessionSummaryCardView(
                        session: session,
                        detailSuffix: " logged",
                        tone: progressStore.selectedDay == nil ? .progress : .success
                    )
                }
            }
        }
    }
}

private struct ProgressSpotlightCard<Content: View>: View {
    let tone: AppToneStyle
    let content: Content

    init(tone: AppToneStyle, @ViewBuilder content: () -> Content) {
        self.tone = tone
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    AppColors.chrome.opacity(0.95),
                                    tone.softFill.opacity(0.94),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .opacity(0.18)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(tone.softBorder, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.14), radius: 16, x: 0, y: 10)
    }
}

private struct ProgressRecordSpotlightCardView: View {
    let record: PersonalRecord
    let weightUnit: WeightUnit

    var body: some View {
        ProgressSpotlightCard(tone: .success) {
            VStack(alignment: .leading, spacing: 14) {
                AppSectionHeader(
                    title: "Latest PR",
                    systemImage: "rosette",
                    subtitle: "Your freshest milestone stays front and center until the next one lands.",
                    trailing: record.achievedAt.formatted(date: .abbreviated, time: .omitted),
                    tone: .success
                )

                Text(record.displayName)
                    .font(.system(.title2, design: .rounded).weight(.bold))
                    .foregroundStyle(AppColors.textPrimary)

                Text(
                    "Logged \(WeightFormatter.displayString(record.weight, unit: weightUnit)) \(weightUnit.symbol) for \(record.reps) reps, setting a new estimated strength high point."
                )
                .font(.subheadline)
                .foregroundStyle(AppColors.textSecondary)

                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                    spacing: 8
                ) {
                    MetricBadge(
                        label: "Load",
                        value: "\(WeightFormatter.displayString(record.weight, unit: weightUnit)) \(weightUnit.symbol)",
                        systemImage: "scalemass",
                        tone: .warning
                    )
                    MetricBadge(
                        label: "Estimated 1RM",
                        value: "\(WeightFormatter.displayString(record.estimatedOneRepMax, unit: weightUnit)) \(weightUnit.symbol)",
                        systemImage: "bolt.fill",
                        tone: .success
                    )
                }
            }
        }
    }
}

private struct ProgressExerciseSummaryCardView: View {
    let summary: ExerciseAnalyticsSummary
    let weightUnit: WeightUnit

    private var latestPoint: ProgressPoint? {
        summary.points.last
    }

    var body: some View {
        ProgressSpotlightCard(tone: summary.currentPR == nil ? .progress : .success) {
            VStack(alignment: .leading, spacing: 14) {
                AppSectionHeader(
                    title: summary.displayName,
                    systemImage: "dumbbell.fill",
                    subtitle: latestPoint == nil
                        ? "Trend data is waiting for more weighted logs."
                        : "Follow top-set load alongside estimated strength changes over time.",
                    trailing: summary.currentPR == nil ? "Building" : "PR tracked",
                    tone: summary.currentPR == nil ? .progress : .success
                )

                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)],
                    spacing: 8
                ) {
                    MetricBadge(
                        label: "Sessions",
                        value: "\(summary.pointCount)",
                        systemImage: "chart.bar",
                        tone: .progress
                    )
                    MetricBadge(
                        label: "Volume",
                        value: WeightFormatter.displayString(summary.totalVolume, unit: weightUnit),
                        systemImage: "scalemass",
                        tone: .warning
                    )

                    if let latestPoint {
                        MetricBadge(
                            label: "Latest Top",
                            value: "\(WeightFormatter.displayString(latestPoint.topWeight, unit: weightUnit)) \(weightUnit.symbol)",
                            systemImage: "arrow.up.right",
                            tone: .today
                        )
                        MetricBadge(
                            label: "Latest 1RM",
                            value: "\(WeightFormatter.displayString(latestPoint.estimatedOneRepMax, unit: weightUnit)) \(weightUnit.symbol)",
                            systemImage: "waveform.path.ecg",
                            tone: .success
                        )
                    }
                }
            }
        }
    }
}

private struct ProgressSelectedDayCardView: View {
    let selectedDay: Date
    let sessionCount: Int

    var body: some View {
        ProgressSpotlightCard(tone: .success) {
            VStack(alignment: .leading, spacing: 12) {
                AppSectionHeader(
                    title: selectedDay.formatted(date: .complete, time: .omitted),
                    systemImage: "calendar.badge.clock",
                    subtitle: "The history list below is filtered to this training date.",
                    trailing: "\(sessionCount) session\(sessionCount == 1 ? "" : "s")",
                    tone: .success
                )

                HStack(spacing: 8) {
                    AppStatePill(title: "Day Filter Active", systemImage: "line.3.horizontal.decrease.circle.fill", tone: .success)
                    AppStatePill(title: "Tap again to clear", systemImage: "hand.tap.fill", tone: .progress)
                }
            }
        }
    }
}

private struct ProgressLegendPill: View {
    let title: String
    let systemImage: String
    let tone: AppToneStyle

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tone.accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .appInsetCard(cornerRadius: 999, fill: tone.softFill.opacity(0.76), border: tone.softBorder)
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
        let monthStart =
            calendar.date(
                from: calendar.dateComponents([.year, .month], from: displayedMonth)
            ) ?? displayedMonth
        let title = monthStart.formatted(.dateTime.month(.wide).year())
        let weekdaySymbols = calendar.shortStandaloneWeekdaySymbols

        guard let dayRange = calendar.range(of: .day, in: .month, for: monthStart),
            let firstWeekday = calendar.dateComponents([.weekday], from: monthStart).weekday
        else {
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

    private let calendar = Calendar.autoupdatingCurrent

    nonisolated static func == (lhs: AppCalendarDayCellView, rhs: AppCalendarDayCellView) -> Bool {
        lhs.entry == rhs.entry && lhs.isSelected == rhs.isSelected
    }

    var body: some View {
        Group {
            if let date = entry.date,
                let dayNumber = entry.dayNumber
            {
                Button {
                    onSelect()
                } label: {
                    VStack(spacing: 4) {
                        Text("\(dayNumber)")
                            .font(.subheadline.weight(entry.hasWorkout ? .semibold : .regular))
                            .foregroundStyle(
                                isSelected || entry.hasWorkout
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary
                            )

                        if entry.hasWorkout {
                            Capsule()
                                .fill(isSelected ? AppColors.textPrimary : AppColors.success)
                                .frame(
                                    width: ProgressDashboardMetrics.calendarWorkoutIndicatorWidth,
                                    height: ProgressDashboardMetrics.calendarWorkoutIndicatorSize
                                )
                        } else if calendar.isDateInToday(date) {
                            Circle()
                                .fill(AppColors.warning)
                                .frame(
                                    width: ProgressDashboardMetrics.calendarWorkoutIndicatorSize,
                                    height: ProgressDashboardMetrics.calendarWorkoutIndicatorSize
                                )
                        } else {
                            Color.clear
                                .frame(
                                    width: ProgressDashboardMetrics.calendarWorkoutIndicatorWidth,
                                    height: ProgressDashboardMetrics.calendarWorkoutIndicatorSize
                                )
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: ProgressDashboardMetrics.calendarCellHeight)
                    .background {
                        RoundedRectangle(cornerRadius: ProgressDashboardMetrics.calendarCellCornerRadius, style: .continuous)
                            .fill(backgroundFill(for: date))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: ProgressDashboardMetrics.calendarCellCornerRadius, style: .continuous)
                            .stroke(borderColor(for: date), lineWidth: 1)
                    }
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

    private func backgroundFill(for date: Date) -> Color {
        if isSelected {
            return AppToneStyle.progress.softFill.opacity(0.92)
        }
        if entry.hasWorkout {
            return AppToneStyle.success.softFill.opacity(0.52)
        }
        if calendar.isDateInToday(date) {
            return AppToneStyle.warning.softFill.opacity(0.22)
        }
        return AppColors.surface.opacity(0.30)
    }

    private func borderColor(for date: Date) -> Color {
        if isSelected {
            return AppToneStyle.progress.softBorder
        }
        if entry.hasWorkout {
            return AppToneStyle.success.softBorder
        }
        if calendar.isDateInToday(date) {
            return AppToneStyle.warning.softBorder
        }
        return AppColors.stroke.opacity(0.22)
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
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppColors.textPrimary)
                        .frame(width: 34, height: 34)
                        .appInsetCard(
                            cornerRadius: 12,
                            fill: AppToneStyle.progress.softFill.opacity(0.72),
                            border: AppToneStyle.progress.softBorder
                        )
                }
                .buttonStyle(.plain)

                Spacer()

                VStack(spacing: 4) {
                    Text(monthLayout.title)
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(AppColors.textPrimary)

                    Text(selectedDay?.formatted(date: .abbreviated, time: .omitted) ?? "Tap a highlighted day")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer()

                Button {
                    shiftMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppColors.textPrimary)
                        .frame(width: 34, height: 34)
                        .appInsetCard(
                            cornerRadius: 12,
                            fill: AppToneStyle.progress.softFill.opacity(0.72),
                            border: AppToneStyle.progress.softBorder
                        )
                }
                .buttonStyle(.plain)
            }

            LazyVGrid(columns: Self.columns, spacing: 8) {
                ForEach(Array(monthLayout.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol.uppercased())
                        .font(.caption2.weight(.semibold))
                        .tracking(0.5)
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
            .padding(12)
            .appInsetCard(
                cornerRadius: 18,
                fill: AppToneStyle.progress.softFill.opacity(0.24),
                border: AppToneStyle.progress.softBorder
            )
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
