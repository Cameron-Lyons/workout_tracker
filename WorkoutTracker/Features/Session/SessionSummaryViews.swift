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
    let showsDisclosureIndicator: Bool

    init(
        record: PersonalRecord,
        weightUnit: WeightUnit,
        tone: AppToneStyle = .success,
        style: AppRowStyle = .surface,
        showsDisclosureIndicator: Bool = false
    ) {
        self.record = record
        self.weightUnit = weightUnit
        self.tone = tone
        self.style = style
        self.showsDisclosureIndicator = showsDisclosureIndicator
    }

    nonisolated static func == (lhs: PersonalRecordSummaryCardView, rhs: PersonalRecordSummaryCardView) -> Bool {
        lhs.record == rhs.record
            && lhs.weightUnit == rhs.weightUnit
            && lhs.tone == rhs.tone
            && lhs.style == rhs.style
            && lhs.showsDisclosureIndicator == rhs.showsDisclosureIndicator
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

            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .trailing, spacing: 8) {
                    AppStatePill(
                        title: "Record",
                        systemImage: "rosette",
                        tone: tone,
                        style: style == .plain ? .plain : .boxed
                    )

                    Text(record.achievedAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption.weight(.black))
                        .monospacedDigit()
                        .foregroundStyle(tone.accent)
                }

                if showsDisclosureIndicator {
                    AppDisclosureIndicator()
                }
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
    let showsDisclosureIndicator: Bool

    init(
        session: CompletedSession,
        detailSuffix: String = "",
        tone: AppToneStyle = .base,
        style: AppRowStyle = .surface,
        showsDisclosureIndicator: Bool = false
    ) {
        self.session = session
        self.detailSuffix = detailSuffix
        self.tone = tone
        self.style = style
        self.showsDisclosureIndicator = showsDisclosureIndicator
    }

    nonisolated static func == (lhs: CompletedSessionSummaryCardView, rhs: CompletedSessionSummaryCardView) -> Bool {
        lhs.session == rhs.session
            && lhs.detailSuffix == rhs.detailSuffix
            && lhs.tone == rhs.tone
            && lhs.style == rhs.style
            && lhs.showsDisclosureIndicator == rhs.showsDisclosureIndicator
    }

    private var detailText: String {
        "\(session.exercises.count) exercise\(session.exercises.count == 1 ? "" : "s")\(detailSuffix)"
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

                HStack(alignment: .top, spacing: 8) {
                    AppStatePill(
                        title: "Logged",
                        systemImage: "checkmark.circle.fill",
                        tone: tone,
                        style: style == .plain ? .plain : .boxed
                    )

                    if showsDisclosureIndicator {
                        AppDisclosureIndicator()
                    }
                }
            }

            Text(detailText)
                .font(.caption.weight(.black))
                .foregroundStyle(tone.accent)
        }
    }
}

struct CompletedSessionDetailView: View {
    @Environment(SettingsStore.self) private var settingsStore

    let session: CompletedSession
    var highlightedExerciseID: UUID?

    private var totalCompletedSetCount: Int {
        session.exercises.reduce(0) { count, completedExercise in
            count + completedExercise.sets.filter(\.isCompleted).count
        }
    }

    private var totalVolume: Double {
        session.exercises.reduce(0) { total, completedExercise in
            total
                + completedExercise.sets.reduce(0) { subtotal, set in
                    guard let weight = set.weight, let reps = set.reps, set.isCompleted else {
                        return subtotal
                    }

                    return subtotal + (weight * Double(reps))
                }
        }
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                LazyVStack(spacing: 16) {
                    AppHeroCard(
                        eyebrow: "Completed Session",
                        title: session.templateNameSnapshot,
                        subtitle: session.completedAt.formatted(date: .abbreviated, time: .shortened),
                        systemImage: "checkmark.circle.fill",
                        metrics: [
                            AppHeroMetric(
                                id: "exercises",
                                label: "Exercises",
                                value: "\(session.exercises.count)",
                                systemImage: "dumbbell"
                            ),
                            AppHeroMetric(
                                id: "sets",
                                label: "Completed Sets",
                                value: "\(totalCompletedSetCount)",
                                systemImage: "checklist"
                            ),
                            AppHeroMetric(
                                id: "volume",
                                label: "Volume",
                                value: WeightFormatter.displayString(totalVolume, unit: settingsStore.weightUnit),
                                systemImage: "scalemass"
                            ),
                            AppHeroMetric(
                                id: "finished",
                                label: "Finished",
                                value: session.completedAt.formatted(date: .omitted, time: .shortened),
                                systemImage: "clock"
                            ),
                        ],
                        tone: highlightedExerciseID == nil ? .progress : .success
                    )

                    VStack(alignment: .leading, spacing: 12) {
                        AppSectionHeader(
                            title: "Exercises",
                            systemImage: "list.bullet",
                            trailing: "\(session.exercises.count)",
                            tone: .progress
                        )

                        VStack(spacing: 0) {
                            ForEach(Array(session.exercises.enumerated()), id: \.element.id) { index, completedExercise in
                                CompletedSessionExerciseDetailView(
                                    completedExercise: completedExercise,
                                    weightUnit: settingsStore.weightUnit,
                                    isHighlighted: highlightedExerciseID == completedExercise.exerciseID
                                )

                                if index < session.exercises.count - 1 {
                                    SectionSurfaceDivider()
                                }
                            }
                        }
                        .appSectionFrame(
                            tone: highlightedExerciseID == nil ? .progress : .success,
                            topPadding: 8,
                            bottomPadding: 8
                        )
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle(session.templateNameSnapshot)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct PersonalRecordDetailView: View {
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(SessionStore.self) private var sessionStore

    let record: PersonalRecord

    private var relatedSession: CompletedSession? {
        sessionStore.completedSessions.first(where: { $0.id == record.sessionID })
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                LazyVStack(spacing: 16) {
                    AppHeroCard(
                        eyebrow: "Personal Record",
                        title: record.displayName,
                        subtitle: record.achievedAt.formatted(date: .abbreviated, time: .shortened),
                        systemImage: "rosette",
                        metrics: [
                            AppHeroMetric(
                                id: "load",
                                label: "Load",
                                value:
                                    "\(WeightFormatter.displayString(record.weight, unit: settingsStore.weightUnit)) \(settingsStore.weightUnit.symbol)",
                                systemImage: "scalemass"
                            ),
                            AppHeroMetric(
                                id: "reps",
                                label: "Reps",
                                value: "\(record.reps)",
                                systemImage: "number"
                            ),
                            AppHeroMetric(
                                id: "e1rm",
                                label: "e1RM",
                                value:
                                    """
                                    \(WeightFormatter.displayString(record.estimatedOneRepMax, unit: settingsStore.weightUnit)) \
                                    \(settingsStore.weightUnit.symbol)
                                    """,
                                systemImage: "waveform.path.ecg"
                            ),
                            AppHeroMetric(
                                id: "day",
                                label: "Logged",
                                value: record.achievedAt.formatted(date: .numeric, time: .omitted),
                                systemImage: "calendar"
                            ),
                        ],
                        tone: .success
                    )

                    AppInlineMessage(
                        systemImage: "bolt.fill",
                        title: "Estimated strength milestone",
                        message:
                            """
                            This set projects an estimated 1RM of \
                            \(WeightFormatter.displayString(record.estimatedOneRepMax, unit: settingsStore.weightUnit)) \
                            \(settingsStore.weightUnit.symbol).
                            """,
                        tone: .success
                    )
                    .appSectionFrame(tone: .success)

                    if let relatedSession {
                        VStack(alignment: .leading, spacing: 12) {
                            AppSectionHeader(
                                title: "Related Workout",
                                systemImage: "clock.arrow.circlepath",
                                tone: .progress,
                                trailingStyle: .plain
                            )

                            NavigationLink {
                                CompletedSessionDetailView(
                                    session: relatedSession,
                                    highlightedExerciseID: record.exerciseID
                                )
                            } label: {
                                CompletedSessionSummaryCardView(
                                    session: relatedSession,
                                    detailSuffix: " logged",
                                    tone: .progress,
                                    showsDisclosureIndicator: true
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("PR")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct CompletedSessionExerciseDetailView: View {
    let completedExercise: CompletedSessionExercise
    let weightUnit: WeightUnit
    let isHighlighted: Bool

    private var tone: AppToneStyle {
        isHighlighted ? .success : .progress
    }

    private var completedSetCount: Int {
        completedExercise.sets.filter(\.isCompleted).count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(completedExercise.exerciseNameSnapshot)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppColors.textPrimary)

                    Text("\(completedSetCount) logged set\(completedSetCount == 1 ? "" : "s")")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer(minLength: 12)

                if isHighlighted {
                    AppStatePill(title: "Record", systemImage: "rosette", tone: .success, style: .plain)
                }
            }

            VStack(spacing: 8) {
                ForEach(Array(completedExercise.sets.enumerated()), id: \.element.id) { index, set in
                    CompletedSessionSetDetailRow(
                        setNumber: index + 1,
                        set: set,
                        weightUnit: weightUnit,
                        tone: tone
                    )
                }
            }
        }
        .padding(.vertical, 14)
    }
}

private struct CompletedSessionSetDetailRow: View {
    let setNumber: Int
    let set: CompletedSetRow
    let weightUnit: WeightUnit
    let tone: AppToneStyle

    private var performanceText: String {
        if let weight = set.weight, let reps = set.reps {
            return "\(WeightFormatter.displayString(weight, unit: weightUnit)) \(weightUnit.symbol) x \(reps)"
        }

        if let reps = set.reps {
            return "\(reps) reps"
        }

        if let weight = set.weight {
            return "\(WeightFormatter.displayString(weight, unit: weightUnit)) \(weightUnit.symbol)"
        }

        return set.isCompleted ? "Completed" : "Skipped"
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Set \(setNumber)")
                    .font(.caption.weight(.black))
                    .foregroundStyle(tone.accent)

                Text(set.setKind.displayName)
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 4) {
                Text(performanceText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)

                if let completedAt = set.completedAt {
                    Text(completedAt.formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                        .monospacedDigit()
                }
            }
            .multilineTextAlignment(.trailing)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .appInsetCard(
            cornerRadius: 8,
            fill: tone.softFill.opacity(0.48)
        )
    }
}
