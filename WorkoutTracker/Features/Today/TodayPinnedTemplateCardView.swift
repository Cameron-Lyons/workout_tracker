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

    var body: some View {
        TodaySpotlightCard(tone: .plans) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        AppStatePill(title: "Pinned Next", systemImage: "pin.fill", tone: .plans)

                        Text(reference.templateName)
                            .font(.system(size: 28, weight: .black))
                            .foregroundStyle(AppColors.textPrimary)

                        Text(reference.planName)
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    Spacer(minLength: 12)

                    Image(systemName: "figure.run")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(AppToneStyle.plans.accent)
                        .padding(12)
                        .appInsetCard(cornerRadius: 16, fill: AppToneStyle.plans.softFill, border: AppToneStyle.plans.softBorder)
                }

                if usesAlternatingRotation {
                    Text("A/B rotation keeps this aligned with the last alternating workout you finished.")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                } else if reference.scheduledWeekdays.isEmpty {
                    Text("No weekday pin yet. Keep this as your default whenever you want a fast start.")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                } else {
                    HStack(spacing: 8) {
                        ForEach(reference.scheduledWeekdays) { weekday in
                            Text(weekday.shortLabel)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppToneStyle.plans.accent)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .appInsetCard(
                                    cornerRadius: 999,
                                    fill: AppToneStyle.plans.softFill.opacity(0.8),
                                    border: AppToneStyle.plans.softBorder
                                )
                        }
                    }
                }

                Text("Start straight from Today and drop into the workout logger immediately.")
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
                            appStore.resumeActiveSession()
                        },
                        onStartNew: { planID, templateID in
                            appStore.startSession(planID: planID, templateID: templateID)
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
