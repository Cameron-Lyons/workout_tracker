import SwiftUI

private enum WeeklyMomentumState {
    case waitingForFirstSession
    case building
    case strong

    var tone: AppToneStyle {
        switch self {
        case .waitingForFirstSession:
            return .warning
        case .building:
            return .progress
        case .strong:
            return .success
        }
    }

    var heroSubtitle: String {
        switch self {
        case .waitingForFirstSession:
            return "Your history is ready. Log the next session to restart the weekly rhythm and keep PRs moving."
        case .building:
            return "Momentum is building this week. Use the trends and calendar to keep your next session on pace."
        case .strong:
            return "A strong week is already in motion. Keep the streak alive and watch your trend lines compound."
        }
    }

    var message: String {
        switch self {
        case .waitingForFirstSession:
            return "No sessions logged this week yet. One workout is enough to put the dashboard back in motion."
        case .building:
            return "You already have traction this week. Keep the cadence steady and the averages will follow."
        case .strong:
            return "You are ahead of your usual pace and stacking meaningful volume early in the week."
        }
    }
}

struct ProgressOverviewSectionView: View {
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(ProgressStore.self) private var progressStore

    private var momentumState: WeeklyMomentumState {
        let sessionsThisWeek = progressStore.overview.sessionsThisWeek

        if sessionsThisWeek >= ProgressDashboardMetrics.strongWeekSessionThreshold {
            return .strong
        }
        if sessionsThisWeek >= ProgressDashboardMetrics.activeWeekSessionThreshold {
            return .building
        }
        return .waitingForFirstSession
    }

    private var momentumTone: AppToneStyle {
        momentumState.tone
    }

    private var heroSubtitle: String {
        momentumState.heroSubtitle
    }

    private var momentumTitle: String {
        "\(progressStore.overview.sessionsThisWeek) this week"
    }

    private var momentumMessage: String {
        momentumState.message
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
                tone: .progress,
                style: .plain
            )

            ProgressSpotlightCard(tone: momentumTone) {
                VStack(alignment: .leading, spacing: 12) {
                    AppSectionHeader(
                        title: "Momentum",
                        systemImage: "flame.fill",
                        subtitle: momentumMessage,
                        trailing: momentumTitle,
                        tone: momentumTone,
                        trailingStyle: .plain
                    )

                    HStack(spacing: 8) {
                        MetricBadge(
                            label: "30 Days",
                            value: "\(progressStore.overview.sessionsLast30Days)",
                            systemImage: "calendar",
                            tone: .progress,
                            style: .plain
                        )
                        MetricBadge(
                            label: "Avg/Week",
                            value: String(format: "%.1f", progressStore.overview.averageSessionsPerWeek),
                            systemImage: "waveform.path.ecg",
                            tone: .warning,
                            style: .plain
                        )
                        MetricBadge(
                            label: "Volume",
                            value: WeightFormatter.displayString(progressStore.overview.totalVolume, unit: settingsStore.weightUnit),
                            systemImage: "scalemass",
                            tone: .success,
                            style: .plain
                        )
                    }
                }
            }
        }
    }
}
