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

    private var scheduleLabel: String {
        weekdaySummary(reference.scheduledWeekdays, emptyLabel: "READY ANY DAY")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(AppToneStyle.today.accent)
                .frame(width: 40, height: 40)
                .appInsetCard(
                    cornerRadius: 8,
                    fill: AppToneStyle.today.softFill.opacity(0.78),
                    border: AppToneStyle.today.softBorder
                )

            VStack(alignment: .leading, spacing: 6) {
                Text("QUICK START")
                    .font(.caption2.weight(.black))
                    .tracking(0.8)
                    .foregroundStyle(AppToneStyle.today.accent)

                Text(reference.templateName)
                    .font(.system(size: 21, weight: .black))
                    .foregroundStyle(AppColors.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text(reference.planName)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text(scheduleLabel)
                    .font(.caption.weight(.black))
                    .tracking(0.7)
                    .foregroundStyle(AppColors.textPrimary.opacity(0.88))

                if let lastStartedAt = reference.lastStartedAt {
                    Text("Last started \(lastStartedAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                } else {
                    Text("Fresh template ready to launch")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .layoutPriority(1)

            Spacer(minLength: 12)

            Image(systemName: "arrow.right")
                .font(.caption.weight(.black))
                .foregroundStyle(AppToneStyle.today.accent)
                .padding(.top, 4)
        }
        .padding(.vertical, 14)
    }
}

struct TodayPersonalRecordRow: View {
    let record: PersonalRecord
    let weightUnit: WeightUnit
    let tone: AppToneStyle

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("PR")
                    .font(.caption2.weight(.black))
                    .tracking(0.8)
                    .foregroundStyle(tone.accent)

                Text(record.displayName)
                    .font(.system(size: 19, weight: .black))
                    .foregroundStyle(AppColors.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text("\(WeightFormatter.displayString(record.weight, unit: weightUnit)) \(weightUnit.symbol) x \(record.reps)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppColors.textSecondary)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 6) {
                Text(record.achievedAt.formatted(date: .abbreviated, time: .omitted).uppercased())
                    .font(.caption2.weight(.black))
                    .tracking(0.7)
                    .foregroundStyle(AppColors.textSecondary)

                Text("E1RM \(WeightFormatter.displayString(record.estimatedOneRepMax, unit: weightUnit))")
                    .font(.caption.weight(.black))
                    .monospacedDigit()
                    .foregroundStyle(tone.accent)
            }
        }
        .padding(.vertical, 12)
    }
}

struct TodayCompletedSessionRow: View {
    let session: CompletedSession
    let tone: AppToneStyle

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("LOGGED")
                    .font(.caption2.weight(.black))
                    .tracking(0.8)
                    .foregroundStyle(tone.accent)

                Text(session.templateNameSnapshot)
                    .font(.system(size: 19, weight: .black))
                    .foregroundStyle(AppColors.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text("\(session.blocks.count) exercise block\(session.blocks.count == 1 ? "" : "s")")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppColors.textSecondary)
            }

            Spacer(minLength: 12)

            Text(session.completedAt.formatted(date: .abbreviated, time: .shortened).uppercased())
                .font(.caption.weight(.black))
                .monospacedDigit()
                .foregroundStyle(AppColors.textSecondary)
        }
        .padding(.vertical, 12)
    }
}
