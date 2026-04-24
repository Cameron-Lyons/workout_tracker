import SwiftUI

struct TodayResumeCardView: View {
    @Environment(AppStore.self) private var appStore

    let draft: SessionDraft

    var body: some View {
        TodaySpotlightCard(tone: .today) {
            VStack(alignment: .leading, spacing: 12) {
                Text(draft.templateNameSnapshot)
                    .font(.system(size: 28, weight: .black))
                    .foregroundStyle(AppColors.textPrimary)

                Text("Updated \(draft.lastUpdatedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)

                Button {
                    appStore.send(.resumeActiveSession)
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
