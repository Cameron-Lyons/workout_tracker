import SwiftUI

struct SessionFinishSummaryView: View {
    let summary: SessionFinishSummary
    @Environment(\.dismiss) private var dismiss
    @Environment(SettingsStore.self) private var settingsStore

    private var weightUnit: WeightUnit {
        settingsStore.weightUnit
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    LazyVStack(spacing: 16) {
                        SessionFinishHeroCardView(summary: summary, weightUnit: weightUnit)

                        if summary.personalRecords.isEmpty {
                            AppEmptyStateCard(
                                systemImage: "bolt.badge.clock",
                                title: "Session locked in",
                                message: "No new PRs this time, but the log is saved and progression rules were advanced.",
                                tone: .success
                            )
                        } else {
                            SessionFinishRecordsSectionView(
                                records: summary.personalRecords,
                                weightUnit: weightUnit
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Summary")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct SessionFinishHeroCardView: View, Equatable {
    let summary: SessionFinishSummary
    let weightUnit: WeightUnit

    nonisolated static func == (lhs: SessionFinishHeroCardView, rhs: SessionFinishHeroCardView) -> Bool {
        lhs.summary == rhs.summary && lhs.weightUnit == rhs.weightUnit
    }

    var body: some View {
        AppHeroCard(
            eyebrow: "Workout Complete",
            title: summary.templateName,
            subtitle: "Session saved and analytics refreshed.",
            systemImage: "checkmark.seal.fill",
            metrics: [
                AppHeroMetric(
                    id: "sets",
                    label: "Completed Sets",
                    value: "\(summary.completedSetCount)",
                    systemImage: "checklist"
                ),
                AppHeroMetric(
                    id: "volume",
                    label: "Volume",
                    value: WeightFormatter.displayString(summary.totalVolume, unit: weightUnit),
                    systemImage: "scalemass"
                ),
                AppHeroMetric(
                    id: "records",
                    label: "New PRs",
                    value: "\(summary.personalRecords.count)",
                    systemImage: "rosette"
                ),
                AppHeroMetric(
                    id: "time",
                    label: "Finished",
                    value: summary.completedAt.formatted(date: .omitted, time: .shortened),
                    systemImage: "clock"
                ),
            ],
            tone: .success
        )
    }
}

private struct SessionFinishRecordsSectionView: View, Equatable {
    let records: [PersonalRecord]
    let weightUnit: WeightUnit

    nonisolated static func == (lhs: SessionFinishRecordsSectionView, rhs: SessionFinishRecordsSectionView) -> Bool {
        lhs.records == rhs.records && lhs.weightUnit == rhs.weightUnit
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppSectionHeader(
                title: "New Personal Records",
                systemImage: "rosette",
                subtitle: "\(records.count) milestone\(records.count == 1 ? "" : "s") captured in this session.",
                trailing: "\(records.count)",
                tone: .success
            )

            LazyVStack(spacing: 12) {
                ForEach(records) { record in
                    SessionFinishRecordCardView(record: record, weightUnit: weightUnit)
                        .equatable()
                }
            }
        }
    }
}

private struct SessionFinishRecordCardView: View, Equatable {
    let record: PersonalRecord
    let weightUnit: WeightUnit

    nonisolated static func == (lhs: SessionFinishRecordCardView, rhs: SessionFinishRecordCardView) -> Bool {
        lhs.record == rhs.record && lhs.weightUnit == rhs.weightUnit
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(record.displayName)
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(AppColors.textPrimary)

                    Text(
                        "\(WeightFormatter.displayString(record.weight, unit: weightUnit)) \(weightUnit.symbol) x \(record.reps)"
                    )
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppColors.textSecondary)
                }

                Spacer()

                AppStatePill(title: "PR", systemImage: "rosette", tone: .success)
            }

            Text(
                "Estimated 1RM \(WeightFormatter.displayString(record.estimatedOneRepMax, unit: weightUnit)) \(weightUnit.symbol)"
            )
            .font(.caption.weight(.black))
            .foregroundStyle(AppColors.success)
        }
        .padding(AppCardMetrics.compactPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appSurface(cornerRadius: AppCardMetrics.compactCornerRadius, shadow: false, tone: .success)
    }
}

struct PersonalRecordSummaryCardView: View, Equatable {
    let record: PersonalRecord
    let weightUnit: WeightUnit
    let tone: AppToneStyle
    let style: AppRowStyle

    init(
        record: PersonalRecord,
        weightUnit: WeightUnit,
        tone: AppToneStyle = .success,
        style: AppRowStyle = .surface
    ) {
        self.record = record
        self.weightUnit = weightUnit
        self.tone = tone
        self.style = style
    }

    nonisolated static func == (lhs: PersonalRecordSummaryCardView, rhs: PersonalRecordSummaryCardView) -> Bool {
        lhs.record == rhs.record
            && lhs.weightUnit == rhs.weightUnit
            && lhs.tone == rhs.tone
            && lhs.style == rhs.style
    }

    var body: some View {
        Group {
            if style == .surface {
                rowContent
                    .padding(AppCardMetrics.compactPadding)
                    .appSurface(cornerRadius: AppCardMetrics.compactCornerRadius, shadow: false, tone: tone)
            } else {
                rowContent
                    .padding(.vertical, 14)
            }
        }
    }

    private var rowContent: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(record.displayName)
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(AppColors.textPrimary)

                Text(
                    "\(WeightFormatter.displayString(record.weight, unit: weightUnit)) \(weightUnit.symbol) x \(record.reps)"
                )
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppColors.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                AppStatePill(title: "Record", systemImage: "rosette.fill", tone: tone)

                Text(record.achievedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption.weight(.black))
                    .monospacedDigit()
                    .foregroundStyle(tone.accent)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CompletedSessionSummaryCardView: View, Equatable {
    let session: CompletedSession
    let detailSuffix: String
    let tone: AppToneStyle
    let style: AppRowStyle

    init(
        session: CompletedSession,
        detailSuffix: String = "",
        tone: AppToneStyle = .base,
        style: AppRowStyle = .surface
    ) {
        self.session = session
        self.detailSuffix = detailSuffix
        self.tone = tone
        self.style = style
    }

    nonisolated static func == (lhs: CompletedSessionSummaryCardView, rhs: CompletedSessionSummaryCardView) -> Bool {
        lhs.session == rhs.session
            && lhs.detailSuffix == rhs.detailSuffix
            && lhs.tone == rhs.tone
            && lhs.style == rhs.style
    }

    private var detailText: String {
        "\(session.blocks.count) exercise block\(session.blocks.count == 1 ? "" : "s")\(detailSuffix)"
    }

    var body: some View {
        Group {
            if style == .surface {
                rowContent
                    .padding(AppCardMetrics.compactPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .appSurface(cornerRadius: AppCardMetrics.compactCornerRadius, shadow: false, tone: tone)
            } else {
                rowContent
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var rowContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(session.templateNameSnapshot)
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(AppColors.textPrimary)

                    Text(session.completedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer()

                AppStatePill(title: "Logged", systemImage: "checkmark.circle.fill", tone: tone)
            }

            Text(detailText)
                .font(.caption.weight(.black))
                .foregroundStyle(tone.accent)
        }
    }
}
