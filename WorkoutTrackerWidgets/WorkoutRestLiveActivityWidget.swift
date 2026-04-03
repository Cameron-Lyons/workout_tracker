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

/// `Text(_:style: .timer)` counts up after the end date; we clamp at zero to match in-session rest UI.
private struct RestTimerCountdownLabel: View {
    let endDate: Date
    let font: Font
    let foreground: Color

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let remaining = max(0, Int(endDate.timeIntervalSince(timeline.date)))
            Text(Self.displayString(remainingSeconds: remaining))
                .font(font)
                .monospacedDigit()
                .foregroundStyle(foreground)
        }
    }

    private static func displayString(remainingSeconds: Int) -> String {
        guard remainingSeconds > 0 else {
            return "Ready"
        }
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
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
            } compactTrailing: {
                RestTimerCountdownLabel(
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
