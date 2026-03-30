import SwiftUI

enum ProgressDashboardMetrics {
    static let recentRecordLimit = 6
    static let trendChartHeight: CGFloat = 220
    static let trendAxisMarkCount = 4
    static let calendarWorkoutIndicatorSize: CGFloat = 6
    static let calendarWorkoutIndicatorWidth: CGFloat = 18
    static let calendarCellHeight: CGFloat = 42
    static let calendarCellCornerRadius: CGFloat = 12
    static let activeWeekSessionThreshold = 1
    static let strongWeekSessionThreshold = 4
}

struct ProgressChartSectionState: Equatable {
    var exerciseSummaries: [ExerciseAnalyticsSummary]
    var selectedExerciseID: UUID?
    var selectedExerciseSummary: ExerciseAnalyticsSummary?
    var selectedExerciseChartSeries: ExerciseChartSeries?
    var weightUnit: WeightUnit
}

struct ProgressDashboardView: View {
    @Environment(AppStore.self) private var appStore

    var onDisplayed: (() -> Void)?

    @State private var displayedMonth = Calendar.autoupdatingCurrent.startOfDay(for: .now)
    @State private var displayTask: Task<Void, Never>?
    @State private var didReportDisplayed = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ProgressDashboardBodyView(displayedMonth: $displayedMonth)
            }
            .navigationTitle("Progress")
            .onAppear {
                displayTask?.cancel()
                displayTask = Task {
                    await appStore.hydrateCompletedSessionHistoryIfNeeded(priority: .userInitiated)
                    guard !Task.isCancelled else {
                        return
                    }

                    reportDisplayed()
                }
            }
            .onDisappear {
                displayTask?.cancel()
                displayTask = nil
                didReportDisplayed = false
            }
        }
    }

    private func reportDisplayed() {
        guard didReportDisplayed == false else {
            return
        }

        didReportDisplayed = true
        onDisplayed?()
    }
}

private struct ProgressDashboardBodyView: View {
    @Environment(ProgressStore.self) private var progressStore
    @Environment(SessionStore.self) private var sessionStore
    @Binding var displayedMonth: Date

    var body: some View {
        if sessionStore.hasLoadedCompletedSessionHistory == false {
            ProgressHistoryLoadingCardView()
        } else if progressStore.overview.totalSessions == 0 {
            AppEmptyStateCard(
                systemImage: "chart.xyaxis.line",
                title: "No progress yet",
                message: "Finish a session and PRs, trends, and calendar history will populate here.",
                tone: .progress,
                style: .plain,
                textAlignment: .center
            )
        } else {
            ProgressDashboardLoadedView(displayedMonth: $displayedMonth)
        }
    }
}

private struct ProgressDashboardLoadedView: View {
    @Binding var displayedMonth: Date

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ProgressOverviewSectionView()
                ProgressRecordsSectionView()
                ProgressChartSectionContainerView()
                ProgressCalendarSectionView(displayedMonth: $displayedMonth)
                ProgressHistorySectionView()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
        }
        .scrollIndicators(.hidden)
    }
}

private struct ProgressChartSectionContainerView: View {
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(ProgressStore.self) private var progressStore

    private var chartSectionState: ProgressChartSectionState {
        ProgressChartSectionState(
            exerciseSummaries: progressStore.exerciseSummaries,
            selectedExerciseID: progressStore.selectedExerciseID,
            selectedExerciseSummary: progressStore.selectedExerciseSummary,
            selectedExerciseChartSeries: progressStore.selectedExerciseChartSeries,
            weightUnit: settingsStore.weightUnit
        )
    }

    var body: some View {
        ProgressChartSectionView(
            state: chartSectionState,
            onSelectExercise: progressStore.selectExercise
        )
    }
}

private struct ProgressHistoryLoadingCardView: View {
    var body: some View {
        VStack(spacing: 14) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(AppColors.accentProgress)
                .scaleEffect(1.08)

            Text("Hydrating progress history...")
                .font(.headline.weight(.bold))
                .foregroundStyle(AppColors.textPrimary)

            Text("Large session logs are loading in the background so the tab can open immediately.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(AppColors.textSecondary)
        }
        .padding(.vertical, 22)
        .padding(.horizontal, 24)
        .padding(.horizontal, 24)
    }
}
