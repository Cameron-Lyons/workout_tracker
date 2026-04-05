import SwiftUI

struct ActiveSessionFooterView: View {
    let state: ActiveSessionHeaderState
    let onClearRest: () -> Void
    let onFinishWorkout: () -> Void

    var body: some View {
        RestTimerTickView(endDate: state.restTimerEndsAt) { now in
            footerContent(now: now)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(Color.clear.ignoresSafeArea(edges: .bottom))
    }

    @ViewBuilder
    private func footerContent(now: Date) -> some View {
        let restPresentation = ActiveSessionRestTimerPresentation(endDate: state.restTimerEndsAt, now: now)

        VStack(alignment: .leading, spacing: 10) {
            if state.restTimerEndsAt != nil {
                HStack(alignment: .center, spacing: 10) {
                    Text("REST")
                        .font(.caption2.weight(.black))
                        .tracking(0.8)
                        .foregroundStyle(restPresentation.tone.accent)

                    Text(restPresentation.label)
                        .font(.title2.weight(.black))
                        .monospacedDigit()
                        .foregroundStyle(AppColors.textPrimary)

                    Spacer(minLength: 0)

                    Image(systemName: restPresentation.label == "Ready" ? "checkmark.circle.fill" : "timer")
                        .font(.title3.weight(.black))
                        .foregroundStyle(restPresentation.tone.accent)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("Rest timer, \(restPresentation.label)")
            }

            HStack(spacing: 10) {
                if state.restTimerEndsAt != nil {
                    Button {
                        onClearRest()
                    } label: {
                        Label("Clear Rest", systemImage: "timer")
                            .frame(maxWidth: .infinity)
                    }
                    .appSecondaryActionButton(tone: .warning, controlSize: .regular)
                }

                Button {
                    onFinishWorkout()
                } label: {
                    Label("Finish Workout", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .appPrimaryActionButton(tone: .success, controlSize: .regular)
                .disabled(!state.progress.canFinishWorkout)
                .accessibilityIdentifier("session.finishButton")
            }
            .padding(.top, state.restTimerEndsAt == nil ? 6 : 0)
        }
    }
}
