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
                trailing: "\(progressStore.historySessions.count)",
                tone: progressStore.selectedDay == nil ? .progress : .success,
                trailingStyle: .plain
            )

            if let selectedDayLabel {
                HStack(spacing: 8) {
                    Text("Filtered to \(selectedDayLabel)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.textSecondary)

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
                    message: "Choose another day or clear the filter.",
                    tone: .warning,
                    style: .plain
                )
                .progressSectionSpacing()
            } else {
                let listTone: AppToneStyle = progressStore.selectedDay == nil ? .progress : .success

                LazyVStack(spacing: 0) {
                    ForEach(Array(progressStore.historySessions.enumerated()), id: \.element.id) { index, session in
                        NavigationLink {
                            CompletedSessionDetailView(session: session)
                        } label: {
                            CompletedSessionSummaryCardView(
                                session: session,
                                detailSuffix: " logged",
                                tone: listTone,
                                style: .plain,
                                showsDisclosureIndicator: true
                            )
                        }
                        .buttonStyle(.plain)

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
