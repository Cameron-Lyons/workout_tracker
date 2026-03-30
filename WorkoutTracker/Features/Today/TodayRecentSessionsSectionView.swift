import SwiftUI

struct TodayRecentSessionsSectionView: View {
    @Environment(TodayStore.self) private var todayStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppSectionHeader(
                title: "Recent Sessions",
                systemImage: "clock.arrow.circlepath",
                trailing: "\(todayStore.recentSessions.count)",
                tone: .progress,
                trailingStyle: .plain
            )

            TodayGroupedPanel(tone: .progress) {
                VStack(spacing: 0) {
                    ForEach(Array(todayStore.recentSessions.enumerated()), id: \.element.id) { index, session in
                        NavigationLink {
                            CompletedSessionDetailView(session: session)
                        } label: {
                            TodayCompletedSessionRow(
                                session: session,
                                tone: .progress,
                                showsDisclosureIndicator: true
                            )
                        }
                        .buttonStyle(.plain)

                        if index < todayStore.recentSessions.count - 1 {
                            SectionSurfaceDivider()
                        }
                    }
                }
            }
        }
    }
}
