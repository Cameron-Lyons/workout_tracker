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
    var updateWeight: (UUID, UUID, Double) -> Void
    var updateReps: (UUID, UUID, Int) -> Void
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
            updateWeight: { blockID, setID, weight in
                appStore.updateSetWeight(blockID: blockID, setID: setID, weight: weight)
            },
            updateReps: { blockID, setID, reps in
                appStore.updateSetReps(blockID: blockID, setID: setID, reps: reps)
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
        VStack(spacing: 0) {
            ActiveSessionHeaderView(state: headerState)
                .equatable()

            ScrollView {
                LazyVStack(spacing: 24) {
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
                .padding(.top, 18)
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
            .modifier(SessionUnderlineFieldModifier())

            SessionSectionDivider()
        }
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
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(block.exerciseNameSnapshot)
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(AppColors.textPrimary)

                    Text(compactBlockSummary)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer()

                Text("\(completedSetCount)/\(block.sets.count) done")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(completedSetCount == block.sets.count ? AppToneStyle.success.accent : AppColors.textSecondary)
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
            .modifier(SessionUnderlineFieldModifier())

            VStack(spacing: 0) {
                ForEach(Array(block.sets.enumerated()), id: \.element.id) { index, row in
                    SessionSetRowView(
                        blockID: block.id,
                        row: row,
                        weightUnit: displaySettings.weightUnit,
                        weightStep: displaySettings.weightStep(for: block),
                        actions: actions,
                        showsDetailedChrome: showsDetailedChrome
                    )
                    .equatable()

                    if index < block.sets.count - 1 {
                        Rectangle()
                            .fill(AppColors.stroke.opacity(0.78))
                            .frame(height: 1)
                    }
                }
            }

            HStack(spacing: 18) {
                Button {
                    actions.addSet(block.id)
                } label: {
                    Label("Add Set", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppToneStyle.today.accent)

                Button {
                    actions.copyLastSet(block.id)
                } label: {
                    Label("Copy Last", systemImage: "doc.on.doc")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppToneStyle.plans.accent)

                Spacer(minLength: 0)
            }

            SessionSectionDivider()
        }
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

private enum SessionSetMetricField: Hashable {
    case weight
    case reps
}

@MainActor
private struct SessionSetRowView: View, Equatable {
    let blockID: UUID
    let row: SessionSetRow
    let weightUnit: WeightUnit
    let weightStep: Double
    let actions: ActiveSessionActions
    let showsDetailedChrome: Bool
    @State private var weightInputText: String
    @State private var repsInputText: String
    @FocusState private var focusedField: SessionSetMetricField?

    init(
        blockID: UUID,
        row: SessionSetRow,
        weightUnit: WeightUnit,
        weightStep: Double,
        actions: ActiveSessionActions,
        showsDetailedChrome: Bool
    ) {
        self.blockID = blockID
        self.row = row
        self.weightUnit = weightUnit
        self.weightStep = weightStep
        self.actions = actions
        self.showsDetailedChrome = showsDetailedChrome
        _weightInputText = State(initialValue: Self.weightInputText(for: row, unit: weightUnit))
        _repsInputText = State(initialValue: Self.repsInputText(for: row))
    }

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
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(setKindTitle.uppercased())
                        .font(.caption.weight(.black))
                        .tracking(0.8)
                        .foregroundStyle(row.log.isCompleted ? AppToneStyle.success.accent : AppColors.textSecondary)

                    if showsDetailedChrome {
                        Text(targetSummary)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }

                Spacer()

                Button {
                    actions.toggleSetCompletion(blockID, row.id)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: row.log.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.body.weight(.bold))

                        Text(row.log.isCompleted ? "Logged" : "Complete")
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(row.log.isCompleted ? AppToneStyle.success.accent : AppColors.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("session.completeSet.\(blockID.uuidString).\(row.id.uuidString)")
            }

            HStack(alignment: .top, spacing: 18) {
                statControl(
                    title: "Load",
                    caption: loadCaption,
                    tone: tone,
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
                ) {
                    metricInputField(
                        text: $weightInputText,
                        placeholder: "0",
                        suffix: weightUnit.symbol,
                        keyboardType: .decimalPad,
                        field: .weight,
                        accessibilityIdentifier: "session.input.load.\(blockID.uuidString).\(row.id.uuidString)"
                    )
                }

                statControl(
                    title: "Reps",
                    caption: "Target \(repsLabel)",
                    tone: tone,
                    decreaseAccessibilityLabel: "Decrease reps for the \(accessibilityContext) set",
                    increaseAccessibilityLabel: "Increase reps for the \(accessibilityContext) set",
                    accessibilityValue: repsAccessibilityValue,
                    decreaseAccessibilityIdentifier: "session.adjust.reps.\(blockID.uuidString).\(row.id.uuidString).decrease",
                    increaseAccessibilityIdentifier: "session.adjust.reps.\(blockID.uuidString).\(row.id.uuidString).increase",
                    onDecrease: {
                        actions.adjustReps(blockID, row.id, -1)
                    },
                    onIncrease: {
                        actions.adjustReps(blockID, row.id, 1)
                    }
                ) {
                    metricInputField(
                        text: $repsInputText,
                        placeholder: canonicalRepsText,
                        keyboardType: .numberPad,
                        field: .reps,
                        accessibilityIdentifier: "session.input.reps.\(blockID.uuidString).\(row.id.uuidString)"
                    )
                }
            }

            if showsDetailedChrome, let note = row.target.note, !note.isEmpty {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(AppToneStyle.progress.accent)
            }
        }
        .onChange(of: row) { _, _ in
            syncMetricInputsIfNeeded()
        }
        .onChange(of: weightUnit) { _, _ in
            syncMetricInputsIfNeeded()
        }
        .onChange(of: focusedField) { previousValue, newValue in
            if previousValue == .weight, newValue != .weight {
                normalizeWeightInput()
            }
            if previousValue == .reps, newValue != .reps {
                normalizeRepsInput()
            }
        }
        .onChange(of: weightInputText) { _, newValue in
            guard focusedField == .weight else {
                return
            }

            guard
                let storedWeight = WeightInputConversion.parseStoredPounds(
                    from: newValue,
                    unit: weightUnit,
                    allowsZero: true
                )
            else {
                return
            }

            actions.updateWeight(blockID, row.id, storedWeight)
        }
        .onChange(of: repsInputText) { _, newValue in
            guard focusedField == .reps, let reps = parsedReps(from: newValue) else {
                return
            }

            actions.updateReps(blockID, row.id, reps)
        }
        .padding(.vertical, showsDetailedChrome ? 14 : 12)
    }

    private var setKindTitle: String {
        row.target.setKind.displayName
    }

    private var accessibilityContext: String {
        setKindTitle.lowercased()
    }

    private var canonicalWeightText: String {
        Self.weightInputText(for: row, unit: weightUnit)
    }

    private var canonicalRepsText: String {
        Self.repsInputText(for: row)
    }

    private var loadAccessibilityValue: String {
        let displayValue = weightInputText.nonEmptyTrimmed ?? canonicalWeightText.nonEmptyTrimmed ?? "0"
        return "\(displayValue) \(weightUnit.symbol)"
    }

    private var repsAccessibilityValue: String {
        repsInputText.nonEmptyTrimmed ?? canonicalRepsText
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

    private func statControl<ValueContent: View>(
        title: String,
        caption: String?,
        tone: AppToneStyle,
        decreaseAccessibilityLabel: String,
        increaseAccessibilityLabel: String,
        accessibilityValue: String,
        decreaseAccessibilityIdentifier: String,
        increaseAccessibilityIdentifier: String,
        onDecrease: @escaping () -> Void,
        onIncrease: @escaping () -> Void,
        @ViewBuilder valueContent: () -> ValueContent
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(0.5)
                .foregroundStyle(AppColors.textSecondary)

            valueContent()

            if showsDetailedChrome, let caption, !caption.isEmpty {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            HStack(spacing: 14) {
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
    }

    private func metricInputField(
        text: Binding<String>,
        placeholder: String,
        suffix: String? = nil,
        keyboardType: UIKeyboardType,
        field: SessionSetMetricField,
        accessibilityIdentifier: String
    ) -> some View {
        let isFocused = focusedField == field

        return HStack(alignment: .firstTextBaseline, spacing: 4) {
            TextField(placeholder, text: text)
                .keyboardType(keyboardType)
                .textFieldStyle(.plain)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.done)
                .focused($focusedField, equals: field)
                .font(.system(size: 24, weight: .black))
                .monospacedDigit()
                .foregroundStyle(AppColors.textPrimary)
                .accessibilityIdentifier(accessibilityIdentifier)

            if let suffix {
                Text(suffix)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppColors.textSecondary)
                    .monospacedDigit()
            }
        }
        .lineLimit(1)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(isFocused ? tone.softBorder : AppColors.strokeStrong.opacity(0.72))
                .frame(height: 1)
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
                .foregroundStyle(tone.accent)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(accessibilityValue)
        .accessibilityIdentifier(accessibilityIdentifier)
    }

    private func syncMetricInputsIfNeeded() {
        if focusedField != .weight {
            weightInputText = canonicalWeightText
        }

        if focusedField != .reps {
            repsInputText = canonicalRepsText
        }
    }

    private func normalizeWeightInput() {
        weightInputText = canonicalWeightText
    }

    private func normalizeRepsInput() {
        repsInputText = canonicalRepsText
    }

    private func parsedReps(from text: String) -> Int? {
        let sanitized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitized.isEmpty, let reps = Int(sanitized), reps >= 0 else {
            return nil
        }

        return reps
    }

    private static func weightInputText(for row: SessionSetRow, unit: WeightUnit) -> String {
        WeightFormatter.displayString(row.log.weight ?? row.target.targetWeight, unit: unit)
    }

    private static func repsInputText(for row: SessionSetRow) -> String {
        "\(row.log.reps ?? row.target.repRange.upperBound)"
    }
}

private struct SessionUnderlineFieldModifier: ViewModifier {
    var lineColor: Color = AppColors.strokeStrong.opacity(0.72)

    func body(content: Content) -> some View {
        content
            .padding(.bottom, 10)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(lineColor)
                    .frame(height: 1)
            }
    }
}

private struct SessionSectionDivider: View {
    var body: some View {
        Rectangle()
            .fill(AppColors.stroke.opacity(0.78))
            .frame(height: 1)
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
        HStack(spacing: 10) {
            if state.restTimerEndsAt != nil {
                Button {
                    onClearRest()
                } label: {
                    Label("Clear Rest", systemImage: "timer")
                        .frame(maxWidth: .infinity)
                }
                .appSecondaryActionButton(tone: .warning, controlSize: .regular)
            }

            Button {
                onFinishWorkout()
            } label: {
                Label("Finish Workout", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .appPrimaryActionButton(tone: .success, controlSize: .regular)
            .disabled(!state.progress.canFinishWorkout)
            .accessibilityIdentifier("session.finishButton")
        }
        .padding(.top, 6)
    }
}

private struct ActiveSessionHeaderView: View, Equatable {
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
