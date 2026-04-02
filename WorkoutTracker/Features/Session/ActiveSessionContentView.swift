import SwiftUI

struct ActiveSessionContentView: View {
    private enum Layout {
        static let defaultBlockSpacing: CGFloat = 24
        static let repeatedExerciseBlockSpacing: CGFloat = 10
    }

    let headerState: ActiveSessionHeaderState
    let blocks: [SessionBlock]
    let displaySettings: ActiveSessionDisplaySettings
    let actions: ActiveSessionActions
    let showsDetailedChrome: Bool

    var body: some View {
        VStack(spacing: 0) {
            ActiveSessionHeaderView(state: headerState)
                .equatable()

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(blocks.enumerated()), id: \.element.id) { index, block in
                        SessionBlockCardView(
                            block: block,
                            displaySettings: displaySettings,
                            actions: actions,
                            showsDetailedChrome: showsDetailedChrome
                        )
                        .equatable()

                        if index < blocks.count - 1 {
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
        guard index < blocks.count - 1 else {
            return 0
        }

        return blocks[index].exerciseID == blocks[index + 1].exerciseID
            ? Layout.repeatedExerciseBlockSpacing
            : Layout.defaultBlockSpacing
    }
}
