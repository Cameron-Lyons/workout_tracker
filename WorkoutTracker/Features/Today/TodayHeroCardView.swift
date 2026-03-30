import SwiftUI

struct TodayHeroCardState: Equatable {
    var title: String
    var subtitle: String
}

struct TodayHeroCardView: View {
    let state: TodayHeroCardState

    var body: some View {
        AppHeroCard(
            eyebrow: nil,
            title: state.title,
            subtitle: state.subtitle,
            systemImage: "figure.strengthtraining.traditional",
            metrics: [],
            tone: .today,
            style: .plain
        )
    }
}
