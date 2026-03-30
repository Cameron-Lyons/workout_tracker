import SwiftUI

struct ProgressCalendarSectionView: View {
    @Environment(ProgressStore.self) private var progressStore

    @Binding var displayedMonth: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppSectionHeader(
                title: "Session Calendar",
                systemImage: "calendar",
                trailing: "\(progressStore.workoutDays.count)",
                tone: .progress,
                trailingStyle: .plain
            )

            AppCalendarGrid(
                displayedMonth: $displayedMonth,
                workoutDays: progressStore.workoutDays,
                selectedDay: Binding(
                    get: { progressStore.selectedDay },
                    set: { progressStore.selectDay($0) }
                )
            )
        }
        .progressSectionSpacing(topPadding: 6, bottomPadding: 2)
    }
}
