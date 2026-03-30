import SwiftUI

struct TemplateEditorScheduleSectionView: View {
    @Binding var selectedWeekdays: Set<Weekday>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppSectionHeader(
                title: "Schedule",
                systemImage: "calendar.badge.clock",
                subtitle: "Pin recurring days now or leave the template flexible.",
                trailing: selectedWeekdays.isEmpty ? "Any day" : "\(selectedWeekdays.count) selected",
                tone: .plans
            )

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 72), spacing: 10)],
                spacing: 10
            ) {
                ForEach(Weekday.allCases) { weekday in
                    Button {
                        toggle(weekday)
                    } label: {
                        Text(weekday.shortLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(
                                selectedWeekdays.contains(weekday)
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary
                            )
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .appInsetCard(
                                cornerRadius: 12,
                                fill: selectedWeekdays.contains(weekday)
                                    ? AppToneStyle.plans.softFill.opacity(0.92)
                                    : nil,
                                border: selectedWeekdays.contains(weekday)
                                    ? AppToneStyle.plans.softBorder
                                    : nil
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .appSectionFrame(tone: .today)
    }

    private func toggle(_ weekday: Weekday) {
        if selectedWeekdays.contains(weekday) {
            selectedWeekdays.remove(weekday)
        } else {
            selectedWeekdays.insert(weekday)
        }
    }
}
