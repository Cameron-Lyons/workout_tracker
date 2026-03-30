import SwiftUI

struct TodayQuickStartSectionView: View {
    @Environment(AppStore.self) private var appStore
    @Environment(TodayStore.self) private var todayStore

    let activeDraft: SessionDraft?
    @Binding var pendingStartRequest: SessionStartRequest?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppSectionHeader(
                title: "Quick Start",
                systemImage: "bolt",
                subtitle: "Templates you launched recently stay close.",
                tone: .today
            )

            if todayStore.quickStartTemplates.isEmpty {
                AppInlineMessage(
                    systemImage: "bolt.fill",
                    title: "No quick starts yet",
                    message: "Templates you launch recently will show up here.",
                    tone: .today
                )
                .appSectionFrame(tone: .today)
            } else {
                TodayGroupedPanel(tone: .today) {
                    VStack(spacing: 0) {
                        ForEach(Array(todayStore.quickStartTemplates.enumerated()), id: \.element.id) { index, reference in
                            Button {
                                handleSessionStart(
                                    activeDraft: activeDraft,
                                    pendingStartRequest: $pendingStartRequest,
                                    planID: reference.planID,
                                    templateID: reference.templateID,
                                    templateName: reference.templateName,
                                    onResumeCurrent: {
                                        appStore.resumeActiveSession()
                                    },
                                    onStartNew: { planID, templateID in
                                        appStore.startSession(planID: planID, templateID: templateID)
                                    }
                                )
                            } label: {
                                TodayQuickStartRow(reference: reference)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("today.quickStart.\(reference.templateID.uuidString)")

                            if index < todayStore.quickStartTemplates.count - 1 {
                                SectionSurfaceDivider()
                            }
                        }
                    }
                }
            }
        }
    }
}
