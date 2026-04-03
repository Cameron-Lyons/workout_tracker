import SwiftUI

struct ActiveSessionContentView: View {
    private enum Layout {
        static let defaultBlockSpacing: CGFloat = 24
        static let repeatedExerciseBlockSpacing: CGFloat = 10
    }

    let headerState: ActiveSessionHeaderState
    let exercises: [SessionExercise]
    let displaySettings: ActiveSessionDisplaySettings
    let actions: ActiveSessionActions
    let showsDetailedChrome: Bool

    var body: some View {
        VStack(spacing: 0) {
            ActiveSessionHeaderView(state: headerState)
                .equatable()

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(exercises.enumerated()), id: \.element.id) { index, sessionExercise in
                        SessionExerciseCardView(
                            sessionExercise: sessionExercise,
                            displaySettings: displaySettings,
                            actions: actions,
                            showsDetailedChrome: showsDetailedChrome
                        )
                        .equatable()

                        if index < exercises.count - 1 {
                            Color.clear
                                .frame(height: spacing(after: index))
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 18)
                .padding(.bottom, 14)
            }
            .scrollIndicators(.hidden)

            ActiveSessionFooterView(
                state: headerState,
                onClearRest: actions.clearRest,
                onFinishWorkout: actions.finishWorkout
            )
        }
    }

    private func spacing(after index: Int) -> CGFloat {
        guard index < exercises.count - 1 else {
            return 0
        }

        return exercises[index].exerciseID == exercises[index + 1].exerciseID
            ? Layout.repeatedExerciseBlockSpacing
            : Layout.defaultBlockSpacing
    }
}
