import Charts
import SwiftUI

@MainActor
struct ProgressChartSectionView: View {
    let state: ProgressChartSectionState
    let onSelectExercise: @MainActor (UUID?) -> Void

    private var selectedExerciseLabel: String {
        state.selectedExerciseSummary?.displayName ?? "Choose Exercise"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppSectionHeader(
                title: "Exercise Trends",
                systemImage: "chart.line.uptrend.xyaxis",
                tone: .progress,
                trailingStyle: .plain
            )

            if state.exerciseSummaries.isEmpty {
                AppInlineMessage(
                    systemImage: "chart.line.uptrend.xyaxis",
                    title: "No trend data yet",
                    message: "Log weighted sets to unlock exercise trends.",
                    tone: .progress,
                    style: .plain
                )
            } else {
                Menu {
                    ForEach(state.exerciseSummaries) { summary in
                        Button(summary.displayName) {
                            onSelectExercise(summary.exerciseID)
                        }
                    }
                } label: {
                    Label(selectedExerciseLabel, systemImage: "dumbbell")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColors.textPrimary)
                }
                .buttonStyle(.plain)
                .progressSectionSpacing()

                if let summary = state.selectedExerciseSummary,
                    let chartSeries = state.selectedExerciseChartSeries
                {
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
                                }
                        }
                    }
                    .frame(height: ProgressDashboardMetrics.trendChartHeight)
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

                    if chartSeries.isSampled {
                        Text("Sampled view for long histories.")
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    LazyVGrid(
                        columns: [GridItem(.flexible(minimum: 120), spacing: 8), GridItem(.flexible(minimum: 120), spacing: 8)],
                        alignment: .leading,
                        spacing: 8
                    ) {
                        MetricBadge(
                            label: "Sessions",
                            value: "\(summary.pointCount)",
                            systemImage: "chart.bar",
                            tone: .progress,
                            style: .plain
                        )
                        MetricBadge(
                            label: "Volume",
                            value: WeightFormatter.displayString(summary.totalVolume, unit: state.weightUnit),
                            systemImage: "scalemass",
                            tone: .warning,
                            style: .plain
                        )

                        if let currentPR = summary.currentPR {
                            MetricBadge(
                                label: "e1RM PR",
                                value: WeightFormatter.displayString(currentPR.estimatedOneRepMax, unit: state.weightUnit),
                                systemImage: "rosette",
                                tone: .success,
                                style: .plain
                            )
                        }
                    }
                    .progressSectionSpacing()
                }
            }
        }
        .progressSectionSpacing(topPadding: 6, bottomPadding: 2)
    }
}
