import SwiftUI

private struct ActiveSessionHeaderState: Equatable {
    var templateName: String
    var startedAt: Date
    var startedAtLabel: String
    var blockCount: Int
    var completedSetCount: Int
    var restTimerEndsAt: Date?
}

private struct ActiveSessionSetState: Identifiable, Equatable {
    var id: UUID
    var setKindTitle: String
    var loadValue: String
    var loadUnit: String
    var loadDisplayValue: String
    var loadAccessibilityValue: String
    var repsValue: String
    var repsAccessibilityValue: String
    var targetSummary: String
    var loadCaption: String
    var repsCaption: String
    var loadDecreaseAccessibilityLabel: String
    var loadIncreaseAccessibilityLabel: String
    var repsDecreaseAccessibilityLabel: String
    var repsIncreaseAccessibilityLabel: String
    var note: String?
    var isCompleted: Bool
    var completionTitle: String
    var completionSubtitle: String
    var weightStep: Double
}

private struct ActiveSessionBlockState: Identifiable, Equatable {
    var id: UUID
    var exerciseName: String
    var blockNote: String
    var restSeconds: Int
    var supersetGroup: String?
    var progressionRuleLabel: String
    var setCount: Int
    var completedSetCount: Int
    var rows: [ActiveSessionSetState]
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

    var onDisplayed: (() -> Void)? = nil

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
            startedAt: draft.startedAt,
            startedAtLabel: draft.startedAt.formatted(date: .omitted, time: .shortened),
            blockCount: draft.blocks.count,
            completedSetCount: draft.blocks.reduce(0) { partialResult, block in
                partialResult + block.sets.filter(\.log.isCompleted).count
            },
            restTimerEndsAt: draft.restTimerEndsAt
        )
    }

    private var blockStates: [ActiveSessionBlockState] {
        guard let draft else {
            return []
        }

        return draft.blocks.map { block in
            let weightStep = ActiveSessionWeightStep.resolve(for: block, settings: settingsStore)
            return ActiveSessionBlockState(
                id: block.id,
                exerciseName: block.exerciseNameSnapshot,
                blockNote: block.blockNote,
                restSeconds: block.restSeconds,
                supersetGroup: block.supersetGroup,
                progressionRuleLabel: block.progressionRule.kind.displayLabel,
                setCount: block.sets.count,
                completedSetCount: block.sets.reduce(0) { partialResult, row in
                    partialResult + (row.log.isCompleted ? 1 : 0)
                },
                rows: block.sets.map { row in
                    makeSetState(row, weightUnit: settingsStore.weightUnit, weightStep: weightStep)
                }
            )
        }
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
                        blockStates: blockStates,
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
            try? await Task.sleep(nanoseconds: 120_000_000)
            guard !Task.isCancelled else {
                return
            }

            showsDetailedChrome = true
        }
    }

    private func makeSetState(
        _ row: SessionSetRow,
        weightUnit: WeightUnit,
        weightStep: Double
    ) -> ActiveSessionSetState {
        let resolvedWeight = row.log.weight ?? row.target.targetWeight
        let loadValue = WeightFormatter.displayString(resolvedWeight, unit: weightUnit)
        let resolvedLoadValue = loadValue.isEmpty ? "0" : loadValue
        let repsValue = "\(row.log.reps ?? row.target.repRange.upperBound)"
        let repsLabel = row.target.repRange.displayLabel
        let setKindTitle = row.target.setKind.displayName
        let accessibilityContext = setKindTitle.lowercased()
        let targetSummary: String
        if let targetWeight = row.target.targetWeight {
            targetSummary = "\(WeightFormatter.displayString(targetWeight, unit: weightUnit)) \(weightUnit.symbol) • \(repsLabel)"
        } else {
            targetSummary = repsLabel
        }

        let loadCaption: String
        if let targetWeight = row.target.targetWeight {
            loadCaption = "Target \(WeightFormatter.displayString(targetWeight, unit: weightUnit)) \(weightUnit.symbol)"
        } else {
            loadCaption = "Adjust load"
        }

        return ActiveSessionSetState(
            id: row.id,
            setKindTitle: setKindTitle,
            loadValue: resolvedLoadValue,
            loadUnit: weightUnit.symbol,
            loadDisplayValue: "\(resolvedLoadValue) \(weightUnit.symbol)",
            loadAccessibilityValue: "\(resolvedLoadValue) \(weightUnit.symbol)",
            repsValue: repsValue,
            repsAccessibilityValue: repsValue,
            targetSummary: targetSummary,
            loadCaption: loadCaption,
            repsCaption: "Target \(repsLabel)",
            loadDecreaseAccessibilityLabel: "Decrease load for the \(accessibilityContext) set",
            loadIncreaseAccessibilityLabel: "Increase load for the \(accessibilityContext) set",
            repsDecreaseAccessibilityLabel: "Decrease reps for the \(accessibilityContext) set",
            repsIncreaseAccessibilityLabel: "Increase reps for the \(accessibilityContext) set",
            note: row.target.note,
            isCompleted: row.log.isCompleted,
            completionTitle: row.log.isCompleted ? "Logged" : "Complete",
            completionSubtitle: row.log.isCompleted ? "Tap to revise" : "Tap when done",
            weightStep: weightStep
        )
    }
}

private struct ActiveSessionContentView: View {
    let headerState: ActiveSessionHeaderState
    let notes: String
    let blockStates: [ActiveSessionBlockState]
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

                    ForEach(blockStates) { block in
                        SessionBlockCardView(
                            block: block,
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
        .appSectionSurface()
    }
}

@MainActor
private struct SessionBlockCardView: View, Equatable {
    let block: ActiveSessionBlockState
    let actions: ActiveSessionActions
    let showsDetailedChrome: Bool

    nonisolated static func == (lhs: SessionBlockCardView, rhs: SessionBlockCardView) -> Bool {
        lhs.block == rhs.block && lhs.showsDetailedChrome == rhs.showsDetailedChrome
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(block.exerciseName)
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(AppColors.textPrimary)

                    if showsDetailedChrome {
                        HStack(spacing: 8) {
                            MetricBadge(
                                label: "Sets",
                                value: "\(block.setCount)",
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
                                value: block.progressionRuleLabel,
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
                        title: "\(block.completedSetCount)/\(block.setCount) done",
                        systemImage: block.completedSetCount == block.setCount ? "checkmark.circle.fill" : "circle.dotted",
                        tone: block.completedSetCount == block.setCount ? .success : .today
                    )
                } else {
                    Text("\(block.completedSetCount)/\(block.setCount) done")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(block.completedSetCount == block.setCount ? AppToneStyle.success.accent : AppColors.textSecondary)
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
                ForEach(block.rows) { row in
                    SessionSetRowView(
                        blockID: block.id,
                        row: row,
                        actions: actions,
                        showsDetailedChrome: showsDetailedChrome
                    )
                    .equatable()
                }
            }

            HStack(spacing: 10) {
                Button {
                    actions.addSet(block.id)
                } label: {
                    Label("Add Set", systemImage: "plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: 14))
                .tint(AppToneStyle.today.accent)

                Button {
                    actions.copyLastSet(block.id)
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

    private var compactBlockSummary: String {
        var parts = ["\(block.setCount) sets", "\(block.restSeconds)s rest", block.progressionRuleLabel]
        if let supersetGroup = block.supersetGroup, !supersetGroup.isEmpty {
            parts.insert("Superset \(supersetGroup)", at: 2)
        }
        return parts.joined(separator: " • ")
    }
}

@MainActor
private struct SessionSetRowView: View, Equatable {
    let blockID: UUID
    let row: ActiveSessionSetState
    let actions: ActiveSessionActions
    let showsDetailedChrome: Bool

    nonisolated static func == (lhs: SessionSetRowView, rhs: SessionSetRowView) -> Bool {
        lhs.blockID == rhs.blockID
            && lhs.row == rhs.row
            && lhs.showsDetailedChrome == rhs.showsDetailedChrome
    }

    private var tone: AppToneStyle {
        row.isCompleted ? .success : .today
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                if showsDetailedChrome {
                    AppStatePill(
                        title: row.setKindTitle,
                        systemImage: row.isCompleted ? "checkmark.circle.fill" : "circle.dashed",
                        tone: tone
                    )
                } else {
                    Text(row.setKindTitle)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer()

                if showsDetailedChrome {
                    Text(row.targetSummary)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppColors.textSecondary)
                }
            }

            HStack(spacing: 10) {
                statControl(
                    title: "Load",
                    displayValue: row.loadDisplayValue,
                    caption: row.loadCaption,
                    tone: tone,
                    showsDetailedChrome: showsDetailedChrome,
                    decreaseAccessibilityLabel: row.loadDecreaseAccessibilityLabel,
                    increaseAccessibilityLabel: row.loadIncreaseAccessibilityLabel,
                    accessibilityValue: row.loadAccessibilityValue,
                    decreaseAccessibilityIdentifier: "session.adjust.load.\(blockID.uuidString).\(row.id.uuidString).decrease",
                    increaseAccessibilityIdentifier: "session.adjust.load.\(blockID.uuidString).\(row.id.uuidString).increase",
                    onDecrease: {
                        actions.adjustWeight(blockID, row.id, -row.weightStep)
                    },
                    onIncrease: {
                        actions.adjustWeight(blockID, row.id, row.weightStep)
                    }
                )

                statControl(
                    title: "Reps",
                    displayValue: row.repsValue,
                    caption: row.repsCaption,
                    tone: tone,
                    showsDetailedChrome: showsDetailedChrome,
                    decreaseAccessibilityLabel: row.repsDecreaseAccessibilityLabel,
                    increaseAccessibilityLabel: row.repsIncreaseAccessibilityLabel,
                    accessibilityValue: row.repsAccessibilityValue,
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
                        Image(systemName: row.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 28, weight: .bold))

                        Text(row.completionTitle)
                            .font(.caption.weight(.semibold))

                        if showsDetailedChrome {
                            Text(row.completionSubtitle)
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
                        .fill(row.isCompleted ? AppColors.success.opacity(0.18) : AppToneStyle.today.softFill.opacity(0.8))
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(row.isCompleted ? AppToneStyle.success.softBorder : AppToneStyle.today.softBorder, lineWidth: 1)
                )
                .accessibilityIdentifier("session.completeSet.\(blockID.uuidString).\(row.id.uuidString)")
            }

            if showsDetailedChrome, let note = row.note, !note.isEmpty {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(AppToneStyle.progress.accent)
            }
        }
        .modifier(
            SessionRowSurfaceModifier(
                isDetailed: showsDetailedChrome,
                isCompleted: row.isCompleted
            )
        )
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
                .font(.system(size: 20, weight: .bold, design: .rounded))
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
        .background {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(showsDetailedChrome ? AppColors.surfaceStrong.opacity(0.82) : tone.softFill.opacity(0.5))
        }
        .overlay {
            if showsDetailedChrome {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(tone.softBorder, lineWidth: 1)
            }
        }
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

private struct ActiveSessionFooterView: View {
    let state: ActiveSessionHeaderState
    let onClearRest: () -> Void
    let onFinishWorkout: () -> Void

    var body: some View {
        Group {
            if state.restTimerEndsAt == nil {
                footerContent(now: .now)
            } else {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    footerContent(now: context.date)
                }
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

    @ViewBuilder
    private func footerContent(now: Date) -> some View {
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
                    value: restTimerLabel(at: now),
                    systemImage: "timer",
                    tone: restTone(at: now)
                )
            }

            HStack(spacing: 12) {
                Button {
                    onClearRest()
                } label: {
                    Label("Clear Rest", systemImage: "timer")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: 16))
                .tint(AppToneStyle.warning.accent)
                .disabled(state.restTimerEndsAt == nil)

                Button {
                    onFinishWorkout()
                } label: {
                    Label("Finish Workout", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 16))
                .tint(AppToneStyle.success.accent)
                .disabled(state.completedSetCount == 0)
                .accessibilityIdentifier("session.finishButton")
            }
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
        Group {
            if state.restTimerEndsAt == nil {
                heroCard(now: .now)
            } else {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    heroCard(now: context.date)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
    }

    private func heroCard(now: Date) -> some View {
        AppHeroCard(
            eyebrow: headerEyebrow(at: now),
            title: state.templateName,
            subtitle: restTimerSubtitle(at: now),
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
                    value: restTimerLabel(at: now),
                    systemImage: "timer"
                ),
            ],
            tone: headerTone(at: now)
        )
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
