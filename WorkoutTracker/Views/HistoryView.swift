import Charts
import SwiftUI

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

            ForEach(Array(progressStore.personalRecords.prefix(6))) { record in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(record.displayName)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppColors.textPrimary)

                        Text(
                            "\(WeightFormatter.displayString(record.weight, unit: settingsStore.weightUnit)) \(settingsStore.weightUnit.symbol) x \(record.reps)"
                        )
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                    }

                    Spacer()

                    Text(record.achievedAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption)
                        .foregroundStyle(AppColors.accent)
                }
                .padding(14)
                .appSurface(cornerRadius: 14, shadow: false)
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
                    .frame(height: 220)
                    .chartXAxis {
                        AxisMarks(values: .automatic(desiredCount: 4))
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
        .padding(14)
        .appSurface(cornerRadius: 14, shadow: false)
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
        .padding(14)
        .appSurface(cornerRadius: 14, shadow: false)
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
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .appSurface(cornerRadius: 14, shadow: false)
            } else {
                ForEach(progressStore.historySessions) { session in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(session.templateNameSnapshot)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppColors.textPrimary)

                        Text(session.completedAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)

                        Text("\(session.blocks.count) exercise block\(session.blocks.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(AppColors.accent)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .appSurface(cornerRadius: 14, shadow: false)
                }
            }
        }
    }
}

private struct AppCalendarGrid: View {
    @Binding var displayedMonth: Date
    let workoutDays: Set<Date>
    @Binding var selectedDay: Date?

    private let calendar = Calendar.autoupdatingCurrent

    private var monthStart: Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: displayedMonth)) ?? displayedMonth
    }

    private var monthTitle: String {
        monthStart.formatted(.dateTime.month(.wide).year())
    }

    private var weekdaySymbols: [String] {
        calendar.shortStandaloneWeekdaySymbols
    }

    private var days: [Date?] {
        guard let dayRange = calendar.range(of: .day, in: .month, for: monthStart),
              let firstWeekday = calendar.dateComponents([.weekday], from: monthStart).weekday else {
            return []
        }

        let leadingEmptyCount = max(0, firstWeekday - calendar.firstWeekday)
        let normalizedLeading = leadingEmptyCount < 0 ? leadingEmptyCount + 7 : leadingEmptyCount
        let placeholders = Array(repeating: Optional<Date>.none, count: normalizedLeading)
        let monthDays = dayRange.compactMap { day -> Date? in
            calendar.date(byAdding: .day, value: day - 1, to: monthStart)
        }
        return placeholders + monthDays
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

                Text(monthTitle)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(AppColors.textPrimary)

                Spacer()

                Button {
                    shiftMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                }
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7),
                spacing: 8
            ) {
                ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                    Text(symbol)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                }

                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    if let day {
                        dayButton(day)
                    } else {
                        Color.clear
                            .frame(height: 42)
                    }
                }
            }
        }
    }

    private func dayButton(_ day: Date) -> some View {
        let normalized = calendar.startOfDay(for: day)
        let hasWorkout = workoutDays.contains(normalized)
        let isSelected = selectedDay.map { calendar.isDate($0, inSameDayAs: day) } ?? false

        return Button {
            selectedDay = isSelected ? nil : normalized
        } label: {
            VStack(spacing: 3) {
                Text("\(calendar.component(.day, from: day))")
                    .font(.subheadline.weight(hasWorkout ? .semibold : .regular))
                    .foregroundStyle(hasWorkout ? AppColors.textPrimary : AppColors.textSecondary)

                Circle()
                    .fill(hasWorkout ? AppColors.accent : .clear)
                    .frame(width: 6, height: 6)
            }
            .frame(maxWidth: .infinity, minHeight: 42)
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
        .disabled(!hasWorkout)
    }

    private func shiftMonth(by value: Int) {
        guard let nextMonth = calendar.date(byAdding: .month, value: value, to: monthStart) else {
            return
        }

        displayedMonth = nextMonth
    }
}
