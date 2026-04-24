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
                trailing: "\(todayStore.quickStartTemplates.count)",
                tone: .today,
                trailingStyle: .plain
            )

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
                                    appStore.send(.resumeActiveSession)
                                },
                                onStartNew: { planID, templateID in
                                    Task { @MainActor in
                                        await appStore.preparePlanInteractionDataIfNeeded()
                                        appStore.send(.startSession(planID: planID, templateID: templateID))
                                    }
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
