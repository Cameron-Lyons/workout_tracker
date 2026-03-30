import SwiftUI

struct TodayResumeCardView: View {
    @Environment(AppStore.self) private var appStore
    @Environment(SessionStore.self) private var sessionStore

    let draft: SessionDraft

    var body: some View {
        let progress = sessionStore.activeDraftProgress

        return TodaySpotlightCard(tone: .today) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        AppStatePill(title: "Autosaved", systemImage: "bolt.fill", tone: .warning)

                        Text(draft.templateNameSnapshot)
                            .font(.system(size: 28, weight: .black))
                            .foregroundStyle(AppColors.textPrimary)

                        Text("Last updated \(draft.lastUpdatedAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    Spacer(minLength: 12)

                    VStack(alignment: .trailing, spacing: 8) {
                        MetricBadge(
                            label: "Blocks",
                            value: "\(progress.blockCount)",
                            systemImage: "square.grid.2x2",
                            tone: .today
                        )
                        MetricBadge(
                            label: "Logged",
                            value: "\(progress.completedSetCount)",
                            systemImage: "checklist",
                            tone: .success
                        )
                    }
                }

                Text("Jump back into the logger with every set, note, and timer exactly where you left it.")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)

                Button {
                    appStore.resumeActiveSession()
                } label: {
                    Label("Resume Session", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .appPrimaryActionButton(tone: .today)
                .accessibilityIdentifier("today.resumeSessionButton")
            }
        }
    }
}
