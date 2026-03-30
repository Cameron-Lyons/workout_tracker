import SwiftUI

struct ProgressRecordsSectionView: View {
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(ProgressStore.self) private var progressStore

    private var recentRecords: [PersonalRecord] {
        Array(progressStore.personalRecords.prefix(ProgressDashboardMetrics.recentRecordLimit))
    }

    var body: some View {
        Group {
            if !recentRecords.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    AppSectionHeader(
                        title: "Recent PRs",
                        systemImage: "rosette",
                        trailing: "\(recentRecords.count)",
                        tone: .success,
                        trailingStyle: .plain
                    )

                    VStack(spacing: 0) {
                        ForEach(Array(recentRecords.enumerated()), id: \.element.id) { index, record in
                            NavigationLink {
                                PersonalRecordDetailView(record: record)
                            } label: {
                                PersonalRecordSummaryCardView(
                                    record: record,
                                    weightUnit: settingsStore.weightUnit,
                                    tone: .success,
                                    style: .plain,
                                    showsDisclosureIndicator: true
                                )
                            }
                            .buttonStyle(.plain)

                            if index < recentRecords.count - 1 {
                                Rectangle()
                                    .fill(AppColors.stroke.opacity(0.78))
                                    .frame(height: 1)
                            }
                        }
                    }
                    .progressSectionSpacing()
                }
            }
        }
    }
}
