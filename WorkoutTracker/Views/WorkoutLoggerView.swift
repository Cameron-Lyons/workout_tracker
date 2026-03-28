import SwiftUI

private struct ActiveSessionHeaderState: Equatable {
    var templateName: String
    var startedAtLabel: String
    var progress: ActiveSessionProgress
    var restTimerEndsAt: Date?
}

private struct ActiveSessionDisplaySettings: Equatable {
    var weightUnit: WeightUnit
    var upperBodyIncrement: Double
    var lowerBodyIncrement: Double

    func weightStep(for block: SessionBlock) -> Double {
        ExerciseClassification.isLowerBody(block.exerciseNameSnapshot)
            ? lowerBodyIncrement
            : upperBodyIncrement
    }
}

private struct ActiveSessionActions {
    var updateSessionNotes: (String) -> Void
    var updateBlockNotes: (UUID, String) -> Void
    var addSet: (UUID) -> Void
    var copyLastSet: (UUID) -> Void
    var adjustWeight: (UUID, UUID, Double) -> Void
    var adjustReps: (UUID, UUID, Int) -> Void
    var toggleSetCompletion: (UUID, UUID) -> Void
    var clearRest: () -> Void
    var finishWorkout: () -> Void
}

private enum ActiveSessionViewMetrics {
    static let statControlHeight: CGFloat = 104
    static let detailedChromeRevealDelayNanoseconds: UInt64 = 120_000_000
}

private struct ActiveSessionRestTimerPresentation {
    let tone: AppToneStyle
    let label: String
    let eyebrow: String
    let subtitle: String

    init(endDate: Date?, now: Date) {
        guard let endDate else {
            tone = .today
            label = "Off"
            eyebrow = "Active Session"
            subtitle = "Tap complete to auto-start rest timers, then use +/- controls to adjust each set."
            return
        }

        let remaining = max(0, Int(endDate.timeIntervalSince(now)))
        if remaining == 0 {
            tone = .success
            label = "Ready"
            eyebrow = "Next Set Ready"
            subtitle = "Rest timer complete. Start the next set whenever you are ready."
            return
        }

        let durationText = Self.durationText(remaining)
        tone = .warning
        label = durationText
        eyebrow = "Rest Timer Live"
        subtitle = "Rest timer running: \(durationText) remaining."
    }

    private static func durationText(_ totalSeconds: Int) -> String {
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return "\(minutes):\(String(format: "%02d", seconds))"
    }
}

enum ActiveSessionWeightStep {
    @MainActor
    static func resolve(for block: SessionBlock, settings: SettingsStore) -> Double {
        settings.preferredIncrement(for: block.exerciseNameSnapshot)
    }
}

struct ActiveSessionView: View {
    @Environment(AppStore.self) private var appStore
    @Environment(PlansStore.self) private var plansStore
    @Environment(SessionStore.self) private var sessionStore
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(\.dismiss) private var dismiss

    var onDisplayed: (() -> Void)?

    @State private var showingAddExerciseSheet = false
    @State private var showsDetailedChrome = false
    @State private var chromeRevealTask: Task<Void, Never>?

    private var draft: SessionDraft? {
        sessionStore.activeDraft
    }

    private var headerState: ActiveSessionHeaderState? {
        guard let draft else {
            return nil
        }

        return ActiveSessionHeaderState(
            templateName: draft.templateNameSnapshot,
            startedAtLabel: draft.startedAt.formatted(date: .omitted, time: .shortened),
            progress: sessionStore.activeDraftProgress,
            restTimerEndsAt: draft.restTimerEndsAt
        )
    }

    private var displaySettings: ActiveSessionDisplaySettings {
        ActiveSessionDisplaySettings(
            weightUnit: settingsStore.weightUnit,
            upperBodyIncrement: settingsStore.upperBodyIncrement,
            lowerBodyIncrement: settingsStore.lowerBodyIncrement
        )
    }

    private var actions: ActiveSessionActions {
        ActiveSessionActions(
            updateSessionNotes: { appStore.updateActiveSessionNotes($0) },
            updateBlockNotes: { blockID, note in
                appStore.updateActiveBlockNotes(blockID: blockID, note: note)
            },
            addSet: { appStore.addSet(to: $0) },
            copyLastSet: { appStore.copyLastSet(in: $0) },
            adjustWeight: { blockID, setID, delta in
                appStore.adjustSetWeight(blockID: blockID, setID: setID, delta: delta)
            },
            adjustReps: { blockID, setID, delta in
                appStore.adjustSetReps(blockID: blockID, setID: setID, delta: delta)
            },
            toggleSetCompletion: { blockID, setID in
                appStore.toggleSetCompletion(blockID: blockID, setID: setID)
            },
            clearRest: { appStore.clearRestTimer() },
            finishWorkout: {
                if appStore.finishActiveSession() {
                    dismiss()
                }
            }
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
                        displaySettings: displaySettings,
                        actions: actions,
                        showsDetailedChrome: showsDetailedChrome
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
                    .disabled(sessionStore.canUndo == false)

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
            .onAppear {
                onDisplayed?()
                scheduleDetailedChromeReveal()
            }
            .onDisappear {
                chromeRevealTask?.cancel()
                chromeRevealTask = nil
                showsDetailedChrome = false
            }
        }
    }

    private func scheduleDetailedChromeReveal() {
        guard showsDetailedChrome == false else {
            return
        }

        chromeRevealTask?.cancel()
        chromeRevealTask = Task { @MainActor in
            await Task.yield()
            try? await Task.sleep(nanoseconds: ActiveSessionViewMetrics.detailedChromeRevealDelayNanoseconds)
            guard !Task.isCancelled else {
                return
            }

            showsDetailedChrome = true
        }
    }
}

private struct ActiveSessionContentView: View {
    let headerState: ActiveSessionHeaderState
    let notes: String
    let blocks: [SessionBlock]
    let displaySettings: ActiveSessionDisplaySettings
    let actions: ActiveSessionActions
    let showsDetailedChrome: Bool

    var body: some View {
        VStack(spacing: 12) {
            ActiveSessionHeaderView(state: headerState)
                .equatable()

            ScrollView {
                LazyVStack(spacing: 14) {
                    ActiveSessionNotesCardView(notes: notes, onUpdateNotes: actions.updateSessionNotes)
                        .equatable()

                    ForEach(blocks) { block in
                        SessionBlockCardView(
                            block: block,
                            displaySettings: displaySettings,
                            actions: actions,
                            showsDetailedChrome: showsDetailedChrome
                        )
                        .equatable()
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
            }
            .scrollIndicators(.hidden)

            ActiveSessionFooterView(
                state: headerState,
                onClearRest: actions.clearRest,
                onFinishWorkout: actions.finishWorkout
            )
        }
    }
}

@MainActor
private struct ActiveSessionNotesCardView: View, Equatable {
    let notes: String
    let onUpdateNotes: (String) -> Void

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
                    set: { onUpdateNotes($0) }
                ),
                axis: .vertical
            )
            .foregroundStyle(AppColors.textPrimary)
            .lineLimit(2...4)
            .appInputField()
        }
        .appSectionSurface(tone: .plans)
    }
}

@MainActor
private struct SessionBlockCardView: View, Equatable {
    let block: SessionBlock
    let displaySettings: ActiveSessionDisplaySettings
    let actions: ActiveSessionActions
    let showsDetailedChrome: Bool

    nonisolated static func == (lhs: SessionBlockCardView, rhs: SessionBlockCardView) -> Bool {
        lhs.block == rhs.block
            && lhs.displaySettings == rhs.displaySettings
            && lhs.showsDetailedChrome == rhs.showsDetailedChrome
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(block.exerciseNameSnapshot)
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(AppColors.textPrimary)

                    if showsDetailedChrome {
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
                    } else {
                        Text(compactBlockSummary)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }

                Spacer()

                if showsDetailedChrome {
                    AppStatePill(
                        title: "\(completedSetCount)/\(block.sets.count) done",
                        systemImage: completedSetCount == block.sets.count ? "checkmark.circle.fill" : "circle.dotted",
                        tone: completedSetCount == block.sets.count ? .success : .today
                    )
                } else {
                    Text("\(completedSetCount)/\(block.sets.count) done")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(completedSetCount == block.sets.count ? AppToneStyle.success.accent : AppColors.textSecondary)
                }
            }

            TextField(
                "Block note",
                text: Binding(
                    get: { block.blockNote },
                    set: { actions.updateBlockNotes(block.id, $0) }
                ),
                axis: .vertical
            )
            .foregroundStyle(AppColors.textPrimary)
            .lineLimit(2...3)
            .appInputField()

            LazyVStack(spacing: 12) {
                ForEach(block.sets) { row in
                    SessionSetRowView(
                        blockID: block.id,
                        row: row,
                        weightUnit: displaySettings.weightUnit,
                        weightStep: displaySettings.weightStep(for: block),
                        actions: actions,
                        showsDetailedChrome: showsDetailedChrome
                    )
                    .equatable()
                }
            }

            GlassEffectContainer(spacing: 10) {
                HStack(spacing: 10) {
                    Button {
                        actions.addSet(block.id)
                    } label: {
                        Label("Add Set", systemImage: "plus")
                            .frame(maxWidth: .infinity)
                    }
                    .appSecondaryActionButton(tone: .today)

                    Button {
                        actions.copyLastSet(block.id)
                    } label: {
                        Label("Copy Last", systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .appSecondaryActionButton(tone: .plans)
                }
            }
        }
        .appSurfaceCard(
            padding: AppCardMetrics.compactPadding,
            cornerRadius: AppCardMetrics.panelCornerRadius,
            tone: completedSetCount == block.sets.count ? .success : .today
        )
    }

    private var completedSetCount: Int {
        block.sets.reduce(0) { partialResult, row in
            partialResult + (row.log.isCompleted ? 1 : 0)
        }
    }

    private var compactBlockSummary: String {
        var parts = ["\(block.sets.count) sets", "\(block.restSeconds)s rest", block.progressionRule.kind.displayLabel]
        if let supersetGroup = block.supersetGroup, !supersetGroup.isEmpty {
            parts.insert("Superset \(supersetGroup)", at: 2)
        }
        return parts.joined(separator: " • ")
    }
}

@MainActor
private struct SessionSetRowView: View, Equatable {
    let blockID: UUID
    let row: SessionSetRow
    let weightUnit: WeightUnit
    let weightStep: Double
    let actions: ActiveSessionActions
    let showsDetailedChrome: Bool

    nonisolated static func == (lhs: SessionSetRowView, rhs: SessionSetRowView) -> Bool {
        lhs.blockID == rhs.blockID
            && lhs.row == rhs.row
            && lhs.weightUnit == rhs.weightUnit
            && lhs.weightStep == rhs.weightStep
            && lhs.showsDetailedChrome == rhs.showsDetailedChrome
    }

    private var tone: AppToneStyle {
        row.log.isCompleted ? .success : .today
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if showsDetailedChrome {
                    AppStatePill(
                        title: setKindTitle,
                        systemImage: row.log.isCompleted ? "checkmark.circle.fill" : "circle.dashed",
                        tone: tone
                    )
                } else {
                    Text(setKindTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer()

                if showsDetailedChrome {
                    Text(targetSummary)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppColors.textSecondary)
                }
            }

            HStack(spacing: 10) {
                statControl(
                    title: "Load",
                    displayValue: loadDisplayValue,
                    caption: loadCaption,
                    tone: tone,
                    showsDetailedChrome: showsDetailedChrome,
                    decreaseAccessibilityLabel: "Decrease load for the \(accessibilityContext) set",
                    increaseAccessibilityLabel: "Increase load for the \(accessibilityContext) set",
                    accessibilityValue: loadAccessibilityValue,
                    decreaseAccessibilityIdentifier: "session.adjust.load.\(blockID.uuidString).\(row.id.uuidString).decrease",
                    increaseAccessibilityIdentifier: "session.adjust.load.\(blockID.uuidString).\(row.id.uuidString).increase",
                    onDecrease: {
                        actions.adjustWeight(blockID, row.id, -weightStep)
                    },
                    onIncrease: {
                        actions.adjustWeight(blockID, row.id, weightStep)
                    }
                )

                statControl(
                    title: "Reps",
                    displayValue: repsValue,
                    caption: "Target \(repsLabel)",
                    tone: tone,
                    showsDetailedChrome: showsDetailedChrome,
                    decreaseAccessibilityLabel: "Decrease reps for the \(accessibilityContext) set",
                    increaseAccessibilityLabel: "Increase reps for the \(accessibilityContext) set",
                    accessibilityValue: repsValue,
                    decreaseAccessibilityIdentifier: "session.adjust.reps.\(blockID.uuidString).\(row.id.uuidString).decrease",
                    increaseAccessibilityIdentifier: "session.adjust.reps.\(blockID.uuidString).\(row.id.uuidString).increase",
                    onDecrease: {
                        actions.adjustReps(blockID, row.id, -1)
                    },
                    onIncrease: {
                        actions.adjustReps(blockID, row.id, 1)
                    }
                )

                Button {
                    actions.toggleSetCompletion(blockID, row.id)
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: row.log.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 28, weight: .bold))

                        Text(row.log.isCompleted ? "Logged" : "Complete")
                            .font(.caption.weight(.semibold))

                        if showsDetailedChrome {
                            Text(row.log.isCompleted ? "Tap to revise" : "Tap when done")
                                .font(.caption2)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    }
                    .foregroundStyle(AppColors.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: ActiveSessionViewMetrics.statControlHeight)
                }
                .buttonStyle(.plain)
                .background {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(row.log.isCompleted ? AppColors.success.opacity(0.18) : AppToneStyle.today.softFill.opacity(0.8))
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(row.log.isCompleted ? AppToneStyle.success.softBorder : AppToneStyle.today.softBorder, lineWidth: 1)
                )
                .accessibilityIdentifier("session.completeSet.\(blockID.uuidString).\(row.id.uuidString)")
            }

            if showsDetailedChrome, let note = row.target.note, !note.isEmpty {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(AppToneStyle.progress.accent)
            }
        }
        .modifier(
            SessionRowSurfaceModifier(
                isDetailed: showsDetailedChrome,
                isCompleted: row.log.isCompleted
            )
        )
    }

    private var setKindTitle: String {
        row.target.setKind.displayName
    }

    private var accessibilityContext: String {
        setKindTitle.lowercased()
    }

    private var resolvedLoadValue: String {
        let displayValue = WeightFormatter.displayString(
            row.log.weight ?? row.target.targetWeight,
            unit: weightUnit
        )
        return displayValue.isEmpty ? "0" : displayValue
    }

    private var loadDisplayValue: String {
        "\(resolvedLoadValue) \(weightUnit.symbol)"
    }

    private var loadAccessibilityValue: String {
        loadDisplayValue
    }

    private var repsValue: String {
        "\(row.log.reps ?? row.target.repRange.upperBound)"
    }

    private var repsLabel: String {
        row.target.repRange.displayLabel
    }

    private var targetSummary: String {
        if let targetWeight = row.target.targetWeight {
            return "\(WeightFormatter.displayString(targetWeight, unit: weightUnit)) \(weightUnit.symbol) • \(repsLabel)"
        }

        return repsLabel
    }

    private var loadCaption: String {
        if let targetWeight = row.target.targetWeight {
            return "Target \(WeightFormatter.displayString(targetWeight, unit: weightUnit)) \(weightUnit.symbol)"
        }

        return "Adjust load"
    }

    private func statControl(
        title: String,
        displayValue: String,
        caption: String?,
        tone: AppToneStyle,
        showsDetailedChrome: Bool,
        decreaseAccessibilityLabel: String,
        increaseAccessibilityLabel: String,
        accessibilityValue: String,
        decreaseAccessibilityIdentifier: String,
        increaseAccessibilityIdentifier: String,
        onDecrease: @escaping () -> Void,
        onIncrease: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(0.5)
                .foregroundStyle(AppColors.textSecondary)

            Text(displayValue)
                .font(.system(size: 24, weight: .black))
                .monospacedDigit()
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            if showsDetailedChrome, let caption, !caption.isEmpty {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            HStack(spacing: 8) {
                adjustButton(
                    systemImage: "minus",
                    tone: tone,
                    accessibilityLabel: decreaseAccessibilityLabel,
                    accessibilityValue: accessibilityValue,
                    accessibilityIdentifier: decreaseAccessibilityIdentifier,
                    action: onDecrease
                )
                adjustButton(
                    systemImage: "plus",
                    tone: tone,
                    accessibilityLabel: increaseAccessibilityLabel,
                    accessibilityValue: accessibilityValue,
                    accessibilityIdentifier: increaseAccessibilityIdentifier,
                    action: onIncrease
                )
            }
        }
        .frame(maxWidth: .infinity, minHeight: ActiveSessionViewMetrics.statControlHeight, alignment: .leading)
        .padding(showsDetailedChrome ? 12 : 10)
        .appInsetCard(
            cornerRadius: 10,
            fill: showsDetailedChrome ? AppColors.surfaceStrong.opacity(0.92) : tone.softFill.opacity(0.5),
            border: showsDetailedChrome ? AppColors.strokeStrong : tone.softBorder
        )
    }

    private func adjustButton(
        systemImage: String,
        tone: AppToneStyle,
        accessibilityLabel: String,
        accessibilityValue: String,
        accessibilityIdentifier: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.bold))
                .foregroundStyle(AppColors.textPrimary)
                .frame(width: 34, height: 34)
        }
        .appSecondaryActionButton(tone: tone, controlSize: .mini)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityIdentifier(accessibilityIdentifier)
    }
}

private struct SessionRowSurfaceModifier: ViewModifier {
    let isDetailed: Bool
    let isCompleted: Bool

    func body(content: Content) -> some View {
        if isDetailed {
            content.appInsetContentCard(
                fill: isCompleted ? AppColors.success.opacity(0.13) : nil,
                border: isCompleted ? AppToneStyle.success.softBorder : nil
            )
        } else {
            content
                .padding(AppCardMetrics.insetPadding)
                .background {
                    RoundedRectangle(cornerRadius: AppCardMetrics.insetCornerRadius, style: .continuous)
                        .fill(isCompleted ? AppColors.success.opacity(0.1) : AppColors.surface.opacity(0.82))
                }
        }
    }
}

private struct RestTimerTickView<Content: View>: View {
    let endDate: Date?
    let content: (Date) -> Content

    init(endDate: Date?, @ViewBuilder content: @escaping (Date) -> Content) {
        self.endDate = endDate
        self.content = content
    }

    var body: some View {
        Group {
            if endDate == nil {
                content(.now)
            } else {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    content(context.date)
                }
            }
        }
    }
}

private struct ActiveSessionFooterView: View {
    let state: ActiveSessionHeaderState
    let onClearRest: () -> Void
    let onFinishWorkout: () -> Void

    var body: some View {
        RestTimerTickView(endDate: state.restTimerEndsAt) { now in
            footerContent(now: now)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 12)
        .background(Color.clear.ignoresSafeArea(edges: .bottom))
    }

    @ViewBuilder
    private func footerContent(now: Date) -> some View {
        let restTimerPresentation = ActiveSessionRestTimerPresentation(endDate: state.restTimerEndsAt, now: now)

        VStack(spacing: 12) {
            HStack {
                MetricBadge(
                    label: "Logged",
                    value: "\(state.progress.completedSetCount)",
                    systemImage: "checklist",
                    tone: .success
                )

                Spacer()

                MetricBadge(
                    label: "Rest",
                    value: restTimerPresentation.label,
                    systemImage: "timer",
                    tone: restTimerPresentation.tone
                )
            }

            GlassEffectContainer(spacing: 12) {
                HStack(spacing: 12) {
                    Button {
                        onClearRest()
                    } label: {
                        Label("Clear Rest", systemImage: "timer")
                            .frame(maxWidth: .infinity)
                    }
                    .appSecondaryActionButton(tone: .warning)
                    .disabled(state.restTimerEndsAt == nil)

                    Button {
                        onFinishWorkout()
                    } label: {
                        Label("Finish Workout", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .appPrimaryActionButton(tone: .success)
                    .disabled(!state.progress.canFinishWorkout)
                    .accessibilityIdentifier("session.finishButton")
                }
            }
        }
        .padding(14)
        .background {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(AppColors.chrome.opacity(0.20))
        }
        .glassEffect(.regular.tint(AppColors.glassTint), in: .rect(cornerRadius: 18))
    }
}

private struct ActiveSessionHeaderView: View, Equatable {
    let state: ActiveSessionHeaderState

    var body: some View {
        RestTimerTickView(endDate: state.restTimerEndsAt) { now in
            heroCard(now: now)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
    }

    private func heroCard(now: Date) -> some View {
        let restTimerPresentation = ActiveSessionRestTimerPresentation(endDate: state.restTimerEndsAt, now: now)

        return AppHeroCard(
            eyebrow: restTimerPresentation.eyebrow,
            title: state.templateName,
            subtitle: restTimerPresentation.subtitle,
            systemImage: "figure.strengthtraining.traditional",
            metrics: [
                AppHeroMetric(
                    id: "started",
                    label: "Started",
                    value: state.startedAtLabel,
                    systemImage: "clock"
                ),
                AppHeroMetric(
                    id: "blocks",
                    label: "Blocks",
                    value: "\(state.progress.blockCount)",
                    systemImage: "square.grid.2x2"
                ),
                AppHeroMetric(
                    id: "sets",
                    label: "Logged",
                    value: "\(state.progress.completedSetCount)",
                    systemImage: "checklist"
                ),
                AppHeroMetric(
                    id: "timer",
                    label: "Rest",
                    value: restTimerPresentation.label,
                    systemImage: "timer"
                ),
            ],
            tone: restTimerPresentation.tone
        )
    }
}
