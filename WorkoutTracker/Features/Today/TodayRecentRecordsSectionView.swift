import SwiftUI

struct TodayRecentRecordsSectionView: View {
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(TodayStore.self) private var todayStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppSectionHeader(
                title: "Recent PRs",
                systemImage: "rosette",
                subtitle: "Your latest high points stay visible after every session.",
                trailing: todayStore.recentPersonalRecords.isEmpty ? nil : "\(todayStore.recentPersonalRecords.count)",
                tone: .success
            )

            if todayStore.recentPersonalRecords.isEmpty {
                AppInlineMessage(
                    systemImage: "rosette",
                    title: "No PRs yet",
                    message: "Finish sessions and the latest PRs will appear here.",
                    tone: .success
                )
                .appSectionFrame(tone: .success)
            } else {
                TodayGroupedPanel(tone: .success) {
                    VStack(spacing: 0) {
                        ForEach(Array(todayStore.recentPersonalRecords.enumerated()), id: \.element.id) { index, record in
                            TodayPersonalRecordRow(record: record, weightUnit: settingsStore.weightUnit, tone: .success)

                            if index < todayStore.recentPersonalRecords.count - 1 {
                                SectionSurfaceDivider()
                            }
                        }
                    }
                }
            }
        }
    }
}
