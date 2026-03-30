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
        .padding(.top, 6)
    }
}
