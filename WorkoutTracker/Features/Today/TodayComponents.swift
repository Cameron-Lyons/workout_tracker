import SwiftUI

struct TodaySpotlightCard<Content: View>: View {
    let tone: AppToneStyle
    let content: Content

    init(tone: AppToneStyle, @ViewBuilder content: () -> Content) {
        self.tone = tone
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .appSurface(cornerRadius: TodayViewMetrics.spotlightCornerRadius, tone: tone)
    }
}

struct TodayGroupedPanel<Content: View>: View {
    let tone: AppToneStyle
    let content: Content

    init(tone: AppToneStyle, @ViewBuilder content: () -> Content) {
        self.tone = tone
        self.content = content()
    }

    var body: some View {
        content
            .appSectionFrame(tone: tone, topPadding: 12, bottomPadding: 4)
    }
}

struct TodayQuickStartRow: View {
    let reference: TemplateReference

    private var detailLine: String {
        let scheduleSummary = weekdaySummary(reference.scheduledWeekdays, emptyLabel: "")
        guard !scheduleSummary.isEmpty else {
            return reference.planName
        }

        return "\(reference.planName) • \(scheduleSummary)"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(reference.templateName)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text(detailLine)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)

            Spacer(minLength: 12)

            if let lastStartedAt = reference.lastStartedAt {
                HStack(alignment: .top, spacing: 8) {
                    Text(lastStartedAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.trailing)

                    Image(systemName: "play.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppToneStyle.today.accent)
                        .padding(.top, 2)
                }
            } else {
                Image(systemName: "play.fill")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(AppToneStyle.today.accent)
                    .padding(.top, 2)
            }
        }
        .padding(.vertical, 14)
    }
}

struct TodayPersonalRecordRow: View {
    let record: PersonalRecord
    let weightUnit: WeightUnit
    let tone: AppToneStyle
    var showsDisclosureIndicator = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(record.displayName)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text(
                    "\(WeightFormatter.displayString(record.weight, unit: weightUnit)) \(weightUnit.symbol) x \(record.reps) • "
                        + "e1RM \(WeightFormatter.displayString(record.estimatedOneRepMax, unit: weightUnit))"
                )
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
            }

            Spacer(minLength: 12)

            HStack(alignment: .top, spacing: 8) {
                Text(record.achievedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.trailing)

                if showsDisclosureIndicator {
                    AppDisclosureIndicator()
                }
            }
        }
        .padding(.vertical, 12)
    }
}

struct TodayCompletedSessionRow: View {
    let session: CompletedSession
    let tone: AppToneStyle
    var showsDisclosureIndicator = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(session.templateNameSnapshot)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text("\(session.blocks.count) exercise block\(session.blocks.count == 1 ? "" : "s")")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
            }

            Spacer(minLength: 12)

            HStack(alignment: .top, spacing: 8) {
                Text(session.completedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption.weight(.medium))
                    .monospacedDigit()
                    .foregroundStyle(AppColors.textSecondary)

                if showsDisclosureIndicator {
                    AppDisclosureIndicator()
                }
            }
        }
        .padding(.vertical, 12)
    }
}
