import SwiftUI

struct ProgressRecordsSectionView: View {
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
                    let additionalRecords = Array(recentRecords.dropFirst())

                    VStack(spacing: 0) {
                        ForEach(Array(additionalRecords.enumerated()), id: \.element.id) { index, record in
                            PersonalRecordSummaryCardView(
                                record: record,
                                weightUnit: settingsStore.weightUnit,
                                tone: .success,
                                style: .plain
                            )

                            if index < additionalRecords.count - 1 {
                                Rectangle()
                                    .fill(AppColors.stroke.opacity(0.78))
                                    .frame(height: 1)
                            }
                        }
                    }
                    .appSectionFrame(tone: .success)
                }
            } else {
                AppInlineMessage(
                    systemImage: "rosette",
                    title: "No PRs yet",
                    message: "Your first standout sets will show up here once a logged session beats an earlier benchmark.",
                    tone: .success
                )
                .appSectionFrame(tone: .success)
            }
        }
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
                    .font(.system(size: 26, weight: .black))
                    .foregroundStyle(AppColors.textPrimary)

                let loggedWeight = WeightFormatter.displayString(record.weight, unit: weightUnit)
                Text(
                    "Logged \(loggedWeight) \(weightUnit.symbol) for \(record.reps) reps, "
                        + "setting a new estimated strength high point."
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
