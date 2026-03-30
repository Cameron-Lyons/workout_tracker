import SwiftUI

struct ProgressCalendarSectionView: View {
    @Environment(ProgressStore.self) private var progressStore

    @Binding var displayedMonth: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppSectionHeader(
                title: "Session Calendar",
                systemImage: "calendar",
                subtitle: progressStore.selectedDay == nil
                    ? "Tap any logged day to focus the session history below."
                    : "A selected day narrows the history list so you can inspect that training date quickly.",
                trailing: "\(progressStore.workoutDays.count) active",
                tone: .progress,
                trailingStyle: .plain
            )

            if let selectedDay = progressStore.selectedDay {
                ProgressSelectedDayCardView(selectedDay: selectedDay, sessionCount: progressStore.historySessions.count)
            }

            AppCalendarGrid(
                displayedMonth: $displayedMonth,
                workoutDays: progressStore.workoutDays,
                selectedDay: Binding(
                    get: { progressStore.selectedDay },
                    set: { progressStore.selectDay($0) }
                )
            )

            HStack(spacing: 8) {
                ProgressLegendPill(title: "Logged day", systemImage: "circle.fill", tone: .success)
                ProgressLegendPill(title: "Selected", systemImage: "calendar.badge.clock", tone: .progress)
                ProgressLegendPill(title: "Today", systemImage: "sun.max.fill", tone: .warning)
            }
        }
        .progressSectionSpacing(topPadding: 6, bottomPadding: 2)
    }
}

private struct ProgressSelectedDayCardView: View {
    let selectedDay: Date
    let sessionCount: Int

    var body: some View {
        ProgressSpotlightCard(tone: .success) {
            VStack(alignment: .leading, spacing: 12) {
                AppSectionHeader(
                    title: selectedDay.formatted(date: .complete, time: .omitted),
                    systemImage: "calendar.badge.clock",
                    subtitle: "The history list below is filtered to this training date.",
                    trailing: "\(sessionCount) session\(sessionCount == 1 ? "" : "s")",
                    tone: .success,
                    trailingStyle: .plain
                )

                HStack(spacing: 8) {
                    AppStatePill(
                        title: "Day Filter Active",
                        systemImage: "line.3.horizontal.decrease.circle.fill",
                        tone: .success,
                        style: .plain
                    )
                    AppStatePill(
                        title: "Tap again to clear",
                        systemImage: "hand.tap.fill",
                        tone: .progress,
                        style: .plain
                    )
                }
            }
        }
    }
}
