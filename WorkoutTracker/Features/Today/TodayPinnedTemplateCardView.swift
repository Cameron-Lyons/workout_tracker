import SwiftUI

struct TodayPinnedTemplateCardView: View {
    @Environment(AppStore.self) private var appStore
    @Environment(PlansStore.self) private var plansStore

    let reference: TemplateReference
    let activeDraft: SessionDraft?
    @Binding var pendingStartRequest: SessionStartRequest?

    private var usesAlternatingRotation: Bool {
        TemplateReferenceSelection.isAlternatingPlan(
            plansStore.planSummary(for: reference.planID)
        )
    }

    private var contextLine: String {
        if usesAlternatingRotation {
            return "A/B rotation keeps this aligned with the last alternating workout you finished."
        }

        if reference.scheduledWeekdays.isEmpty {
            return "Ready any day."
        }

        return "Scheduled \(weekdaySummary(reference.scheduledWeekdays, emptyLabel: "READY ANY DAY"))."
    }

    var body: some View {
        TodaySpotlightCard(tone: .plans) {
            VStack(alignment: .leading, spacing: 12) {
                Text(reference.templateName)
                    .font(.system(size: 28, weight: .black))
                    .foregroundStyle(AppColors.textPrimary)

                Text("\(reference.planName) • \(contextLine)")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)

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
                    Label("Start Workout", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .appPrimaryActionButton(tone: .today)
                .accessibilityIdentifier("today.pinnedStartButton")
            }
        }
    }
}
