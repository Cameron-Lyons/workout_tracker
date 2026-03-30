import Charts
import SwiftUI

@MainActor
struct ProgressChartSectionView: View {
    let state: ProgressChartSectionState
    let onSelectExercise: @MainActor (UUID?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppSectionHeader(
                title: "Exercise Trends",
                systemImage: "chart.line.uptrend.xyaxis",
                subtitle: state.exerciseSummaries.isEmpty
                    ? "Weighted logs unlock exercise-level trend lines and PR callouts."
                    : "Follow top-set load and estimated strength over time for a single exercise.",
                trailing: state.selectedExerciseSummary.map { "\($0.pointCount) points" },
                tone: .progress
            )

            if state.exerciseSummaries.isEmpty {
                AppInlineMessage(
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
                            get: { state.selectedExerciseID },
                            set: { selection in
                                onSelectExercise(selection)
                            }
                        )
                    ) {
                        ForEach(state.exerciseSummaries) { summary in
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

                if let summary = state.selectedExerciseSummary,
                    let chartSeries = state.selectedExerciseChartSeries
                {
                    ProgressExerciseSummaryCardView(summary: summary, weightUnit: state.weightUnit)

                    VStack(alignment: .leading, spacing: 12) {
                        AppSectionHeader(
                            title: "Top Set Trend",
                            systemImage: "chart.xyaxis.line",
                            subtitle: "Solid line shows top logged load. Dashed line estimates one-rep max from the same sessions.",
                            trailing: summary.currentPR.map {
                                let oneRepMax = WeightFormatter.displayString(
                                    $0.estimatedOneRepMax,
                                    unit: state.weightUnit
                                )
                                return "e1RM PR \(oneRepMax) \(state.weightUnit.symbol)"
                            },
                            tone: .progress
                        )

                        Chart {
                            ForEach(chartSeries.trendPoints) { point in
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
                                RuleMark(y: .value("PR e1RM", currentPR.estimatedOneRepMax))
                                    .foregroundStyle(AppColors.success.opacity(0.44))
                                    .lineStyle(StrokeStyle(lineWidth: 1.2, dash: [4, 4]))
                                    .annotation(position: .top, alignment: .trailing) {
                                        Text("Current e1RM PR")
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
                                                displayValue: state.weightUnit.displayValue(fromStoredPounds: axisWeight),
                                                unit: state.weightUnit
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
                                value: WeightFormatter.displayString(summary.totalVolume, unit: state.weightUnit),
                                systemImage: "scalemass",
                                tone: .warning
                            )

                            if let currentPR = summary.currentPR {
                                MetricBadge(
                                    label: "e1RM PR",
                                    value: WeightFormatter.displayString(currentPR.estimatedOneRepMax, unit: state.weightUnit),
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
        .appSectionFrame(tone: .progress, topPadding: 16, bottomPadding: 8)
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
                            value:
                                "\(WeightFormatter.displayString(latestPoint.estimatedOneRepMax, unit: weightUnit)) \(weightUnit.symbol)",
                            systemImage: "waveform.path.ecg",
                            tone: .success
                        )
                    }
                }
            }
        }
    }
}
