import ActivityKit
import SwiftUI
import WidgetKit

struct WorkoutRestLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutRestLiveActivityAttributes.self) { context in
            WorkoutRestLiveActivityLockScreenView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.16))
                .activitySystemActionForegroundColor(Color.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("Rest", systemImage: "timer")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Text(context.state.endDate, style: .timer)
                        .font(.title3.weight(.bold))
                        .monospacedDigit()
                }

                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.attributes.workoutName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .foregroundStyle(.orange)
            } compactTrailing: {
                Text(context.state.endDate, style: .timer)
                    .font(.caption2.weight(.bold))
                    .monospacedDigit()
            } minimal: {
                Image(systemName: "timer")
                    .foregroundStyle(.orange)
            }
        }
    }
}

private struct WorkoutRestLiveActivityLockScreenView: View {
    let context: ActivityViewContext<WorkoutRestLiveActivityAttributes>

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: "timer")
                .font(.title3.weight(.bold))
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 4) {
                Text("REST")
                    .font(.caption.weight(.black))
                    .tracking(1)
                    .foregroundStyle(.orange)

                Text(context.state.endDate, style: .timer)
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
            }

            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
    }
}
