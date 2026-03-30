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

    var summary: String {
        switch self {
        case .waitingForFirstSession:
            return "Log the next session to get the week moving again."
        case .building:
            return "Momentum is building this week."
        case .strong:
            return "A strong week is already in motion."
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

    private var summaryText: String {
        momentumState.summary
    }

    var body: some View {
        ProgressSpotlightCard(tone: momentumTone) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(progressStore.overview.totalSessions) sessions logged")
                            .font(.system(size: 30, weight: .black))
                            .foregroundStyle(AppColors.textPrimary)

                        Text(summaryText)
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    Spacer(minLength: 12)

                    Text("\(progressStore.overview.sessionsThisWeek) this week")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(momentumTone.accent)
                }

                LazyVGrid(
                    columns: [GridItem(.flexible(minimum: 120), spacing: 8), GridItem(.flexible(minimum: 120), spacing: 8)],
                    alignment: .leading,
                    spacing: 8
                ) {
                    MetricBadge(
                        label: "Last 30d",
                        value: "\(progressStore.overview.sessionsLast30Days)",
                        systemImage: "calendar",
                        tone: .progress,
                        style: .plain
                    )
                    MetricBadge(
                        label: "Avg / Week",
                        value: String(format: "%.1f", progressStore.overview.averageSessionsPerWeek),
                        systemImage: "waveform.path.ecg",
                        tone: .warning,
                        style: .plain
                    )
                    MetricBadge(
                        label: "Volume",
                        value: WeightFormatter.displayString(
                            progressStore.overview.totalVolume,
                            unit: settingsStore.weightUnit
                        ),
                        systemImage: "scalemass",
                        tone: .success,
                        style: .plain
                    )
                }
            }
        }
    }
}
