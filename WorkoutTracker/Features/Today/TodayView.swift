import SwiftUI

struct TodayView: View {
    @Environment(AppStore.self) private var appStore
    @Environment(SessionStore.self) private var sessionStore
    @Environment(TodayStore.self) private var todayStore

    @State private var pendingStartRequest: SessionStartRequest?

    private var activeDraft: SessionDraft? {
        sessionStore.activeDraft
    }

    private var heroState: TodayHeroCardState {
        TodayHeroCardState(
            title: activeDraft?.templateNameSnapshot ?? "Ready to train",
            subtitle: activeDraft == nil
                ? "Start from a pinned template, relaunch a recent session, or jump into Programs to build something custom."
                : "Pick up your active session or switch programs when you are ready."
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    LazyVStack(spacing: 18) {
                        TodayHeroCardView(state: heroState)
                            .appReveal(delay: 0.01)

                        if let activeDraft {
                            TodayResumeCardView(draft: activeDraft)
                                .appReveal(delay: 0.03)
                        } else if let pinnedTemplate = todayStore.pinnedTemplate {
                            TodayPinnedTemplateCardView(
                                reference: pinnedTemplate,
                                activeDraft: activeDraft,
                                pendingStartRequest: $pendingStartRequest
                            )
                            .appReveal(delay: 0.03)
                        } else {
                            AppEmptyStateCard(
                                systemImage: "sparkles.rectangle.stack",
                                title: "Start from a program",
                                message: "Finish onboarding or create a template in Programs to get a pinned next workout.",
                                tone: .today
                            )
                            .appReveal(delay: 0.03)
                        }

                        TodayQuickStartSectionView(
                            activeDraft: activeDraft,
                            pendingStartRequest: $pendingStartRequest
                        )
                        .appReveal(delay: 0.05)

                        TodayRecentRecordsSectionView()
                            .appReveal(delay: 0.07)

                        TodayRecentSessionsSectionView()
                            .appReveal(delay: 0.09)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Today")
            .sessionStartConfirmationDialog(
                pendingStartRequest: $pendingStartRequest,
                activeDraft: activeDraft,
                onResumeCurrent: {
                    appStore.resumeActiveSession()
                },
                onReplace: { request in
                    appStore.replaceActiveSessionAndStart(
                        planID: request.planID,
                        templateID: request.templateID
                    )
                }
            )
        }
    }
}
