import SwiftUI

struct TodayRecentRecordsSectionView: View {
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(TodayStore.self) private var todayStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppSectionHeader(
                title: "Recent PRs",
                systemImage: "rosette",
                trailing: "\(todayStore.recentPersonalRecords.count)",
                tone: .success,
                trailingStyle: .plain
            )

            TodayGroupedPanel(tone: .success) {
                VStack(spacing: 0) {
                    ForEach(Array(todayStore.recentPersonalRecords.enumerated()), id: \.element.id) { index, record in
                        NavigationLink {
                            PersonalRecordDetailView(record: record)
                        } label: {
                            TodayPersonalRecordRow(
                                record: record,
                                weightUnit: settingsStore.weightUnit,
                                tone: .success,
                                showsDisclosureIndicator: true
                            )
                        }
                        .buttonStyle(.plain)

                        if index < todayStore.recentPersonalRecords.count - 1 {
                            SectionSurfaceDivider()
                        }
                    }
                }
            }
        }
    }
}
