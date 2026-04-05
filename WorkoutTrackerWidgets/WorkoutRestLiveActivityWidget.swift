import ActivityKit
import SwiftUI
import WidgetKit

private extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

private enum RestActivityColors {
    static let textPrimary = Color(hex: 0xC0CAF5)
    static let textSecondary = Color(hex: 0xA9B1D6)
    static let warning = Color(hex: 0xFF9E64)
}

/// Lock screen Live Activities do not reliably advance `TimelineView(.periodic)`; system-driven `Text(timerInterval:countsDown:)` updates correctly.
private struct RestTimerCountdownLabel: View {
    let startDate: Date
    let endDate: Date
    let font: Font
    let foreground: Color

    var body: some View {
        Text(timerInterval: startDate...endDate, countsDown: true)
            .font(font)
            .monospacedDigit()
            .foregroundStyle(foreground)
    }
}

struct WorkoutRestLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutRestLiveActivityAttributes.self) { context in
            WorkoutRestLiveActivityLockScreenView(context: context)
                .activityBackgroundTint(.clear)
                .activitySystemActionForegroundColor(RestActivityColors.textPrimary)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label("Rest", systemImage: "timer")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(RestActivityColors.warning)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    RestTimerCountdownLabel(
                        startDate: context.state.startDate,
                        endDate: context.state.endDate,
                        font: .title3.weight(.bold),
                        foreground: RestActivityColors.textPrimary
                    )
                }

                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.attributes.workoutName)
                        .font(.caption)
                        .foregroundStyle(RestActivityColors.textSecondary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                Image(systemName: "timer")
                    .foregroundStyle(RestActivityColors.warning)
            }             compactTrailing: {
                RestTimerCountdownLabel(
                    startDate: context.state.startDate,
                    endDate: context.state.endDate,
                    font: .caption2.weight(.bold),
                    foreground: RestActivityColors.textPrimary
                )
            } minimal: {
                Image(systemName: "timer")
                    .foregroundStyle(RestActivityColors.warning)
            }
        }
    }
}

private struct WorkoutRestLiveActivityLockScreenView: View {
    let context: ActivityViewContext<WorkoutRestLiveActivityAttributes>

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "timer")
                    .font(.caption.weight(.bold))

                Text("REST")
                    .font(.caption.weight(.black))
                    .tracking(1.1)
            }
            .foregroundStyle(RestActivityColors.warning)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(RestActivityColors.warning.opacity(0.16), in: Capsule())

            RestTimerCountdownLabel(
                startDate: context.state.startDate,
                endDate: context.state.endDate,
                font: .system(size: 34, weight: .black, design: .rounded),
                foreground: RestActivityColors.textPrimary
            )
            .frame(maxWidth: .infinity, alignment: .center)

            Text(context.attributes.workoutName)
                .font(.caption2.weight(.medium))
                .foregroundStyle(RestActivityColors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
