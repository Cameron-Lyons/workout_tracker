import SwiftUI

struct PlansHeroCardView: View {
    @Environment(PlansStore.self) private var plansStore

    var body: some View {
        AppHeroCard(
            eyebrow: "Plan Builder",
            title: "\(plansStore.planCount) plans",
            subtitle:
                "Templates define your future sessions. Schedule them loosely, pin your Today favorite, and start whenever you want.",
            systemImage: "list.bullet.rectangle",
            metrics: [
                AppHeroMetric(
                    id: "plans",
                    label: "Plans",
                    value: "\(plansStore.planCount)",
                    systemImage: "list.bullet"
                ),
                AppHeroMetric(
                    id: "templates",
                    label: "Templates",
                    value: "\(plansStore.templateReferenceCount)",
                    systemImage: "rectangle.stack"
                ),
                AppHeroMetric(
                    id: "catalog",
                    label: "Exercises",
                    value: "\(plansStore.catalog.count)",
                    systemImage: "dumbbell"
                ),
                AppHeroMetric(
                    id: "profiles",
                    label: "Profiles",
                    value: "\(plansStore.profileCount)",
                    systemImage: "slider.horizontal.3"
                ),
            ],
            tone: .plans
        )
    }
}
