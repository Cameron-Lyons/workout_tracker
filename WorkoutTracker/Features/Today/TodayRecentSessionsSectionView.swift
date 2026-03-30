import SwiftUI

struct TodayRecentSessionsSectionView: View {
    @Environment(TodayStore.self) private var todayStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppSectionHeader(
                title: "Recent Sessions",
                systemImage: "clock.arrow.circlepath",
                subtitle: "Keep momentum by reliving the last few workouts at a glance.",
                tone: .progress
            )

            if todayStore.recentSessions.isEmpty {
                AppInlineMessage(
                    systemImage: "clock.arrow.circlepath",
                    title: "No sessions logged yet",
                    message: "Your finished workouts will show up here.",
                    tone: .progress
                )
                .appSectionFrame(tone: .progress)
            } else {
                TodayGroupedPanel(tone: .progress) {
                    VStack(spacing: 0) {
                        ForEach(Array(todayStore.recentSessions.enumerated()), id: \.element.id) { index, session in
                            TodayCompletedSessionRow(session: session, tone: .progress)

                            if index < todayStore.recentSessions.count - 1 {
                                SectionSurfaceDivider()
                            }
                        }
                    }
                }
            }
        }
    }
}
