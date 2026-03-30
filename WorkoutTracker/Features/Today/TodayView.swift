import SwiftUI

struct TodayView: View {
    @Environment(AppStore.self) private var appStore
    @Environment(SessionStore.self) private var sessionStore
    @Environment(TodayStore.self) private var todayStore

    @State private var pendingStartRequest: SessionStartRequest?

    private var activeDraft: SessionDraft? {
        sessionStore.activeDraft
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    LazyVStack(spacing: 20) {
                        if let activeDraft {
                            TodayResumeCardView(draft: activeDraft)
                        } else if let pinnedTemplate = todayStore.pinnedTemplate {
                            TodayPinnedTemplateCardView(
                                reference: pinnedTemplate,
                                activeDraft: activeDraft,
                                pendingStartRequest: $pendingStartRequest
                            )
                        } else {
                            AppEmptyStateCard(
                                systemImage: "sparkles.rectangle.stack",
                                title: "Start from a program",
                                message: "Finish onboarding or create a template in Programs to get a pinned next workout.",
                                tone: .today
                            )
                        }

                        if !todayStore.quickStartTemplates.isEmpty {
                            TodayQuickStartSectionView(
                                activeDraft: activeDraft,
                                pendingStartRequest: $pendingStartRequest
                            )
                        }

                        if !todayStore.recentSessions.isEmpty {
                            TodayRecentSessionsSectionView()
                        }

                        if !todayStore.recentPersonalRecords.isEmpty {
                            TodayRecentRecordsSectionView()
                        }
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
                    Task { @MainActor in
                        await appStore.preparePlanInteractionDataIfNeeded()
                        appStore.replaceActiveSessionAndStart(
                            planID: request.planID,
                            templateID: request.templateID
                        )
                    }
                }
            )
        }
    }
}
