import SwiftUI

struct TodayHeroCardState: Equatable {
    var title: String
    var subtitle: String
    var status: String
    var templateReferenceCount: Int
    var sessionsLast30Days: Int
    var recentPersonalRecordCount: Int
}

struct TodayHeroCardView: View {
    let state: TodayHeroCardState

    var body: some View {
        AppHeroCard(
            eyebrow: "Session-First Logger",
            title: state.title,
            subtitle: state.subtitle,
            systemImage: "figure.strengthtraining.traditional",
            metrics: [
                AppHeroMetric(
                    id: "status",
                    label: "Status",
                    value: state.status,
                    systemImage: "play.circle"
                ),
                AppHeroMetric(
                    id: "plans",
                    label: "Templates",
                    value: "\(state.templateReferenceCount)",
                    systemImage: "rectangle.stack"
                ),
                AppHeroMetric(
                    id: "sessions",
                    label: "Last 30d",
                    value: "\(state.sessionsLast30Days)",
                    systemImage: "calendar"
                ),
                AppHeroMetric(
                    id: "records",
                    label: "Recent PRs",
                    value: "\(state.recentPersonalRecordCount)",
                    systemImage: "rosette"
                ),
            ],
            tone: .today
        )
    }
}
