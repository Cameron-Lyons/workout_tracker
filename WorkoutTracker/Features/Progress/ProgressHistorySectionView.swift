import SwiftUI

struct ProgressHistorySectionView: View {
    @Environment(ProgressStore.self) private var progressStore

    private var selectedDayLabel: String? {
        progressStore.selectedDay?.formatted(date: .abbreviated, time: .omitted)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppSectionHeader(
                title: "Logged Sessions",
                systemImage: "clock.arrow.circlepath",
                subtitle: selectedDayLabel == nil
                    ? "Browse the latest completed sessions or narrow the list from the calendar above."
                    : "Showing only the workouts logged on \(selectedDayLabel!).",
                trailing: "\(progressStore.historySessions.count)",
                tone: progressStore.selectedDay == nil ? .progress : .success,
                trailingStyle: .plain
            )

            if let selectedDayLabel {
                HStack(spacing: 8) {
                    AppStatePill(
                        title: selectedDayLabel,
                        systemImage: "calendar.badge.clock",
                        tone: .success,
                        style: .plain
                    )

                    Button("Show All") {
                        progressStore.selectDay(nil)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.accentProgress)
                    .buttonStyle(.plain)
                }
            }

            if progressStore.historySessions.isEmpty {
                AppInlineMessage(
                    systemImage: "calendar.badge.exclamationmark",
                    title: "No sessions for this filter",
                    message: "Choose another logged day or clear the calendar filter to see every completed workout.",
                    tone: .warning,
                    style: .plain
                )
                .progressSectionSpacing()
            } else {
                let listTone: AppToneStyle = progressStore.selectedDay == nil ? .progress : .success

                VStack(spacing: 0) {
                    ForEach(Array(progressStore.historySessions.enumerated()), id: \.element.id) { index, session in
                        CompletedSessionSummaryCardView(
                            session: session,
                            detailSuffix: " logged",
                            tone: listTone,
                            style: .plain
                        )

                        if index < progressStore.historySessions.count - 1 {
                            Rectangle()
                                .fill(AppColors.stroke.opacity(0.78))
                                .frame(height: 1)
                            }
                        }
                    }
                .progressSectionSpacing()
            }
        }
    }
}
