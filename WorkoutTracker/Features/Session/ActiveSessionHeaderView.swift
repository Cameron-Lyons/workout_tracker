import SwiftUI

struct ActiveSessionHeaderView: View, Equatable {
    let state: ActiveSessionHeaderState

    var body: some View {
        RestTimerTickView(endDate: state.restTimerEndsAt) { now in
            headerContent(now: now)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
    }

    @ViewBuilder
    private func headerContent(now: Date) -> some View {
        let restTimerPresentation = ActiveSessionRestTimerPresentation(endDate: state.restTimerEndsAt, now: now)

        VStack(alignment: .leading, spacing: 16) {
            if state.restTimerEndsAt != nil {
                compactRestTimerCard(restTimerPresentation)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text(restTimerPresentation.eyebrow.uppercased())
                        .font(.caption.weight(.black))
                        .tracking(1.1)
                        .foregroundStyle(restTimerPresentation.tone.accent)

                    Text(state.templateName)
                        .font(.system(size: 30, weight: .black))
                        .foregroundStyle(AppColors.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("Started \(state.startedAtLabel)")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppColors.textSecondary)
                }

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(minimum: 90), spacing: 16),
                        GridItem(.flexible(minimum: 90), spacing: 16),
                        GridItem(.flexible(minimum: 90), spacing: 16),
                    ],
                    alignment: .leading,
                    spacing: 14
                ) {
                    headerMetric(label: "Started", value: state.startedAtLabel, systemImage: "clock", tone: .today)
                    headerMetric(label: "Blocks", value: "\(state.progress.blockCount)", systemImage: "square.grid.2x2", tone: .progress)
                    headerMetric(label: "Logged", value: "\(state.progress.completedSetCount)", systemImage: "checklist", tone: .success)
                }
            }

            SessionSectionDivider()
        }
    }

    private func compactRestTimerCard(_ restTimerPresentation: ActiveSessionRestTimerPresentation) -> some View {
        HStack(alignment: .center, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text("REST TIMER")
                    .font(.caption.weight(.black))
                    .tracking(1.1)
                    .foregroundStyle(restTimerPresentation.tone.accent)

                Text(restTimerPresentation.label)
                    .font(.system(size: 34, weight: .black))
                    .monospacedDigit()
                    .foregroundStyle(AppColors.textPrimary)
            }

            Spacer(minLength: 0)

            Image(systemName: restTimerPresentation.label == "Ready" ? "checkmark.circle.fill" : "timer")
                .font(.title3.weight(.black))
                .foregroundStyle(restTimerPresentation.tone.accent)
        }
        .padding(.vertical, 4)
    }

    private func headerMetric(
        label: String,
        value: String,
        systemImage: String,
        tone: AppToneStyle
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .center, spacing: 6) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.black))
                    .foregroundStyle(tone.accent)

                Text(label.uppercased())
                    .font(.caption2.weight(.black))
                    .tracking(0.8)
                    .foregroundStyle(AppColors.textSecondary)
            }

            Text(value)
                .font(.headline.weight(.black))
                .monospacedDigit()
                .foregroundStyle(AppColors.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
