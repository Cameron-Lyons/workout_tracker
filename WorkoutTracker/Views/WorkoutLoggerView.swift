import SwiftUI

private struct ActiveSessionHeaderState: Equatable {
    var templateName: String
    var startedAt: Date
    var blockCount: Int
    var completedSetCount: Int
    var restTimerEndsAt: Date?
}

private enum ActiveSessionViewMetrics {
    static let statControlHeight: CGFloat = 104
}

struct ActiveSessionView: View {
    @Environment(AppStore.self) private var appStore
    @Environment(PlansStore.self) private var plansStore
    @Environment(SessionStore.self) private var sessionStore
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(\.dismiss) private var dismiss

    @State private var showingAddExerciseSheet = false

    private var draft: SessionDraft? {
        sessionStore.activeDraft
    }

    private var headerState: ActiveSessionHeaderState? {
        guard let draft else {
            return nil
        }

        return ActiveSessionHeaderState(
            templateName: draft.templateNameSnapshot,
            startedAt: draft.startedAt,
            blockCount: draft.blocks.count,
            completedSetCount: draft.blocks.reduce(0) { partialResult, block in
                partialResult + block.sets.filter(\.log.isCompleted).count
            },
            restTimerEndsAt: draft.restTimerEndsAt
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                if let draft, let headerState {
                    ActiveSessionContentView(
                        headerState: headerState,
                        notes: draft.notes,
                        blocks: draft.blocks,
                        weightUnit: settingsStore.weightUnit,
                        weightStep: settingsStore.upperBodyIncrement
                    )
                } else {
                    AppEmptyStateCard(
                        systemImage: "figure.cooldown",
                        title: "No active session",
                        message: "Start a workout from Today or Plans.",
                        tone: .today
                    )
                }
            }
            .navigationTitle(draft?.templateNameSnapshot ?? "Session")
            .toolbarBackground(AppColors.chrome, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        appStore.sessionStore.dismissSessionPresentation()
                        dismiss()
                    }
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Undo") {
                        appStore.undoSessionMutation()
                    }
                    .disabled(sessionStore.undoStack.isEmpty)

                    Button("Add Exercise") {
                        showingAddExerciseSheet = true
                    }

                    Button("Discard", role: .destructive) {
                        appStore.discardActiveSession()
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingAddExerciseSheet) {
                ExercisePickerSheet(
                    catalog: plansStore.catalog,
                    title: "Add Exercise",
                    onPick: { exercise in
                        appStore.addExerciseToActiveSession(exerciseID: exercise.id)
                    },
                    onCreateCustom: { customName in
                        appStore.addCustomExerciseToActiveSession(name: customName)
                    }
                )
            }
        }
    }
}

private struct ActiveSessionContentView: View {
    let headerState: ActiveSessionHeaderState
    let notes: String
    let blocks: [SessionBlock]
    let weightUnit: WeightUnit
    let weightStep: Double

    var body: some View {
        VStack(spacing: 12) {
            ActiveSessionHeaderView(state: headerState)
                .equatable()

            ScrollView {
                LazyVStack(spacing: 14) {
                    ActiveSessionNotesCardView(notes: notes)
                        .equatable()

                    ForEach(blocks) { block in
                        SessionBlockCardView(
                            block: block,
                            weightUnit: weightUnit,
                            weightStep: weightStep
                        )
                        .equatable()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }
            .scrollIndicators(.hidden)

            ActiveSessionFooterView(state: headerState)
        }
    }
}

@MainActor
private struct ActiveSessionNotesCardView: View, Equatable {
    @Environment(AppStore.self) private var appStore

    let notes: String

    nonisolated static func == (lhs: ActiveSessionNotesCardView, rhs: ActiveSessionNotesCardView) -> Bool {
        lhs.notes == rhs.notes
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AppSectionHeader(
                title: "Session Notes",
                systemImage: "note.text",
                subtitle: "Capture anything you want to remember before you finish.",
                tone: .plans
            )

            TextField(
                "How did the session feel?",
                text: Binding(
                    get: { notes },
                    set: { appStore.updateActiveSessionNotes($0) }
                ),
                axis: .vertical
            )
            .foregroundStyle(AppColors.textPrimary)
            .lineLimit(2...4)
            .appInputField()
        }
        .appSectionSurface()
    }
}

@MainActor
private struct SessionBlockCardView: View, Equatable {
    @Environment(AppStore.self) private var appStore

    let block: SessionBlock
    let weightUnit: WeightUnit
    let weightStep: Double

    private var completedSetCount: Int {
        block.sets.filter { $0.log.isCompleted }.count
    }

    nonisolated static func == (lhs: SessionBlockCardView, rhs: SessionBlockCardView) -> Bool {
        lhs.block == rhs.block
            && lhs.weightUnit == rhs.weightUnit
            && lhs.weightStep == rhs.weightStep
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(block.exerciseNameSnapshot)
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(AppColors.textPrimary)

                    HStack(spacing: 8) {
                        MetricBadge(
                            label: "Sets",
                            value: "\(block.sets.count)",
                            systemImage: "number.square",
                            tone: .today
                        )

                        MetricBadge(
                            label: "Rest",
                            value: "\(block.restSeconds)s",
                            systemImage: "timer",
                            tone: .warning
                        )

                        if let supersetGroup = block.supersetGroup, !supersetGroup.isEmpty {
                            MetricBadge(
                                label: "Superset",
                                value: supersetGroup,
                                systemImage: "link",
                                tone: .plans
                            )
                        }

                        MetricBadge(
                            label: "Rule",
                            value: block.progressionRule.kind.displayLabel,
                            systemImage: "arrow.up.right",
                            tone: .progress
                        )
                    }
                }

                Spacer()

                AppStatePill(
                    title: "\(completedSetCount)/\(block.sets.count) done",
                    systemImage: completedSetCount == block.sets.count ? "checkmark.circle.fill" : "circle.dotted",
                    tone: completedSetCount == block.sets.count ? .success : .today
                )
            }

            TextField(
                "Block note",
                text: Binding(
                    get: { block.blockNote },
                    set: { appStore.updateActiveBlockNotes(blockID: block.id, note: $0) }
                ),
                axis: .vertical
            )
            .foregroundStyle(AppColors.textPrimary)
            .lineLimit(2...3)
            .appInputField()

            ForEach(block.sets) { row in
                SessionSetRowView(
                    blockID: block.id,
                    row: row,
                    weightUnit: weightUnit,
                    weightStep: weightStep
                )
                .equatable()
            }

            HStack(spacing: 10) {
                Button {
                    appStore.addSet(to: block.id)
                } label: {
                    Label("Add Set", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: 14))
                .tint(AppToneStyle.today.accent)

                Button {
                    appStore.copyLastSet(in: block.id)
                } label: {
                    Label("Copy Last", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: 14))
                .tint(AppToneStyle.plans.accent)
            }
        }
        .appSurfaceCard(
            padding: AppCardMetrics.compactPadding,
            cornerRadius: AppCardMetrics.panelCornerRadius
        )
    }
}

@MainActor
private struct SessionSetRowView: View, Equatable {
    @Environment(AppStore.self) private var appStore

    let blockID: UUID
    let row: SessionSetRow
    let weightUnit: WeightUnit
    let weightStep: Double

    nonisolated static func == (lhs: SessionSetRowView, rhs: SessionSetRowView) -> Bool {
        lhs.blockID == rhs.blockID
            && lhs.row == rhs.row
            && lhs.weightUnit == rhs.weightUnit
            && lhs.weightStep == rhs.weightStep
    }

    private var isCompleted: Bool {
        row.log.isCompleted
    }

    private var tone: AppToneStyle {
        isCompleted ? .success : .today
    }

    private var loadValue: String {
        let resolvedWeight = row.log.weight ?? row.target.targetWeight
        let displayValue = WeightFormatter.displayString(resolvedWeight, unit: weightUnit)
        return displayValue.isEmpty ? "0" : displayValue
    }

    private var repsValue: String {
        "\(row.log.reps ?? row.target.repRange.upperBound)"
    }

    private var targetSummary: String {
        let reps = row.target.repRange.displayLabel
        if let weight = row.target.targetWeight {
            return "\(WeightFormatter.displayString(weight, unit: weightUnit)) \(weightUnit.symbol) • \(reps)"
        }

        return reps
    }

    private var loadCaption: String {
        guard let targetWeight = row.target.targetWeight else {
            return "Adjust load"
        }

        return "Target \(WeightFormatter.displayString(targetWeight, unit: weightUnit)) \(weightUnit.symbol)"
    }

    private var repsCaption: String {
        "Target \(row.target.repRange.displayLabel)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                AppStatePill(
                    title: row.target.setKind.displayName,
                    systemImage: isCompleted ? "checkmark.circle.fill" : "circle.dashed",
                    tone: tone
                )

                Spacer()

                Text(targetSummary)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppColors.textSecondary)
            }

            HStack(spacing: 10) {
                SessionStatControlView(
                    title: "Load",
                    value: loadValue,
                    unit: weightUnit.symbol,
                    caption: loadCaption,
                    tone: tone,
                    accessibilityLabelContext: row.target.setKind.displayName,
                    accessibilityIdentifierPrefix: "session.adjust.load.\(blockID.uuidString).\(row.id.uuidString)",
                    onDecrease: {
                        appStore.adjustSetWeight(
                            blockID: blockID,
                            setID: row.id,
                            delta: -weightStep
                        )
                    },
                    onIncrease: {
                        appStore.adjustSetWeight(
                            blockID: blockID,
                            setID: row.id,
                            delta: weightStep
                        )
                    }
                )

                SessionStatControlView(
                    title: "Reps",
                    value: repsValue,
                    unit: "",
                    caption: repsCaption,
                    tone: tone,
                    accessibilityLabelContext: row.target.setKind.displayName,
                    accessibilityIdentifierPrefix: "session.adjust.reps.\(blockID.uuidString).\(row.id.uuidString)",
                    onDecrease: {
                        appStore.adjustSetReps(blockID: blockID, setID: row.id, delta: -1)
                    },
                    onIncrease: {
                        appStore.adjustSetReps(blockID: blockID, setID: row.id, delta: 1)
                    }
                )

                SessionCompletionButtonView(isCompleted: isCompleted) {
                    appStore.toggleSetCompletion(blockID: blockID, setID: row.id)
                }
                .accessibilityIdentifier("session.completeSet.\(blockID.uuidString).\(row.id.uuidString)")
            }

            if let note = row.target.note, !note.isEmpty {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(AppToneStyle.progress.accent)
            }
        }
        .appInsetContentCard(
            fill: isCompleted ? AppColors.success.opacity(0.13) : nil,
            border: isCompleted ? AppToneStyle.success.softBorder : nil
        )
    }
}

private struct SessionStatControlView: View {
    let title: String
    let value: String
    let unit: String
    let caption: String?
    let tone: AppToneStyle
    let accessibilityLabelContext: String
    let accessibilityIdentifierPrefix: String
    let onDecrease: () -> Void
    let onIncrease: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(0.5)
                .foregroundStyle(AppColors.textSecondary)

            Text(unit.isEmpty ? value : "\(value) \(unit)")
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if let caption, !caption.isEmpty {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            HStack(spacing: 8) {
                SessionAdjustButton(
                    systemImage: "minus",
                    tone: tone,
                    accessibilityLabel: "Decrease \(title.lowercased()) for the \(accessibilityLabelContext.lowercased()) set",
                    accessibilityValue: unit.isEmpty ? value : "\(value) \(unit)",
                    accessibilityIdentifier: "\(accessibilityIdentifierPrefix).decrease",
                    action: onDecrease
                )
                SessionAdjustButton(
                    systemImage: "plus",
                    tone: tone,
                    accessibilityLabel: "Increase \(title.lowercased()) for the \(accessibilityLabelContext.lowercased()) set",
                    accessibilityValue: unit.isEmpty ? value : "\(value) \(unit)",
                    accessibilityIdentifier: "\(accessibilityIdentifierPrefix).increase",
                    action: onIncrease
                )
            }
        }
        .frame(maxWidth: .infinity, minHeight: ActiveSessionViewMetrics.statControlHeight, alignment: .leading)
        .padding(12)
        .appInsetCard(cornerRadius: 14, fillOpacity: 0.82, borderOpacity: 0.74, border: tone.softBorder)
    }
}

private struct SessionAdjustButton: View {
    let systemImage: String
    let tone: AppToneStyle
    let accessibilityLabel: String
    let accessibilityValue: String
    let accessibilityIdentifier: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.bold))
                .foregroundStyle(AppColors.textPrimary)
                .frame(width: 34, height: 34)
                .background(
                    Circle()
                        .fill(tone.softFill.opacity(0.9))
                )
                .overlay(
                    Circle()
                        .stroke(tone.softBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

private struct SessionCompletionButtonView: View {
    let isCompleted: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 28, weight: .bold))

                Text(isCompleted ? "Logged" : "Complete")
                    .font(.caption.weight(.semibold))

                Text(isCompleted ? "Tap to edit" : "Tap when done")
                    .font(.caption2)
                    .foregroundStyle(AppColors.textSecondary)
            }
            .foregroundStyle(AppColors.textPrimary)
            .frame(maxWidth: .infinity, minHeight: ActiveSessionViewMetrics.statControlHeight)
        }
        .buttonStyle(.plain)
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isCompleted ? AppColors.success.opacity(0.18) : AppToneStyle.today.softFill.opacity(0.8))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isCompleted ? AppToneStyle.success.softBorder : AppToneStyle.today.softBorder, lineWidth: 1)
        )
    }
}

private struct ActiveSessionFooterView: View {
    @Environment(AppStore.self) private var appStore
    @Environment(\.dismiss) private var dismiss
    let state: ActiveSessionHeaderState

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                MetricBadge(
                    label: "Logged",
                    value: "\(state.completedSetCount)",
                    systemImage: "checklist",
                    tone: .success
                )

                Spacer()

                MetricBadge(
                    label: "Rest",
                    value: restTimerLabel(at: .now),
                    systemImage: "timer",
                    tone: restTone(at: .now)
                )
            }

            HStack(spacing: 12) {
                Button {
                    appStore.clearRestTimer()
                } label: {
                    Label("Clear Rest", systemImage: "timer")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: 16))
                .tint(AppToneStyle.warning.accent)
                .disabled(state.restTimerEndsAt == nil)

                Button {
                    appStore.finishActiveSession()
                    dismiss()
                } label: {
                    Label("Finish Workout", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 16))
                .tint(AppToneStyle.success.accent)
                .accessibilityIdentifier("session.finishButton")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background {
            ZStack {
                Rectangle()
                    .fill(AppColors.chrome.opacity(0.94))

                Rectangle()
                    .fill(.ultraThinMaterial)
                    .opacity(0.28)
            }
            .ignoresSafeArea(edges: .bottom)
        }
        .overlay(alignment: .top) {
            Rectangle()
                .fill(AppColors.stroke.opacity(0.72))
                .frame(height: 1)
        }
    }

    private func restTone(at now: Date) -> AppToneStyle {
        guard let endDate = state.restTimerEndsAt else {
            return .today
        }

        return endDate.timeIntervalSince(now) <= 0 ? .success : .warning
    }

    private func restTimerLabel(at now: Date) -> String {
        guard let endDate = state.restTimerEndsAt else {
            return "Off"
        }

        let remaining = max(0, Int(endDate.timeIntervalSince(now)))
        if remaining == 0 {
            return "Ready"
        }

        let minutes = remaining / 60
        let seconds = remaining % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
}

private struct ActiveSessionHeaderView: View, Equatable {
    let state: ActiveSessionHeaderState

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            AppHeroCard(
                eyebrow: headerEyebrow(at: context.date),
                title: state.templateName,
                subtitle: restTimerSubtitle(at: context.date),
                systemImage: "figure.strengthtraining.traditional",
                metrics: [
                    AppHeroMetric(
                        id: "started",
                        label: "Started",
                        value: state.startedAt.formatted(date: .omitted, time: .shortened),
                        systemImage: "clock"
                    ),
                    AppHeroMetric(
                        id: "blocks",
                        label: "Blocks",
                        value: "\(state.blockCount)",
                        systemImage: "square.grid.2x2"
                    ),
                    AppHeroMetric(
                        id: "sets",
                        label: "Logged",
                        value: "\(state.completedSetCount)",
                        systemImage: "checklist"
                    ),
                    AppHeroMetric(
                        id: "timer",
                        label: "Rest",
                        value: restTimerLabel(at: context.date),
                        systemImage: "timer"
                    ),
                ],
                tone: headerTone(at: context.date)
            )
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
    }

    private func headerEyebrow(at now: Date) -> String {
        guard let endDate = state.restTimerEndsAt else {
            return "Active Session"
        }

        return endDate.timeIntervalSince(now) <= 0 ? "Next Set Ready" : "Rest Timer Live"
    }

    private func headerTone(at now: Date) -> AppToneStyle {
        guard let endDate = state.restTimerEndsAt else {
            return .today
        }

        return endDate.timeIntervalSince(now) <= 0 ? .success : .warning
    }

    private func restTimerLabel(at now: Date) -> String {
        guard let endDate = state.restTimerEndsAt else {
            return "Off"
        }

        let remaining = max(0, Int(endDate.timeIntervalSince(now)))
        if remaining == 0 {
            return "Ready"
        }

        return durationText(remaining)
    }

    private func restTimerSubtitle(at now: Date) -> String {
        guard let endDate = state.restTimerEndsAt else {
            return "Tap complete to auto-start rest timers, then use +/- controls to adjust each set."
        }

        let remaining = max(0, Int(endDate.timeIntervalSince(now)))
        if remaining == 0 {
            return "Rest timer complete. Start the next set whenever you are ready."
        }

        return "Rest timer running: \(durationText(remaining)) remaining."
    }

    private func durationText(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
}
