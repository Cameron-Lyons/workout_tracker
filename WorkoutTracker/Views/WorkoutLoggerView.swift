import SwiftUI

private struct ActiveSessionHeaderState: Equatable {
    var templateName: String
    var startedAt: Date
    var blockCount: Int
    var completedSetCount: Int
    var restTimerEndsAt: Date?
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
                        message: "Start a workout from Today or Plans."
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
        VStack(spacing: 14) {
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

            ActiveSessionFooterView()
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
            Text("Session Notes")
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)

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
                            label: "Rest",
                            value: "\(block.restSeconds)s",
                            systemImage: "timer"
                        )

                        if let supersetGroup = block.supersetGroup, !supersetGroup.isEmpty {
                            MetricBadge(
                                label: "Superset",
                                value: supersetGroup,
                                systemImage: "link"
                            )
                        }

                        MetricBadge(
                            label: "Rule",
                            value: block.progressionRule.kind.displayLabel,
                            systemImage: "arrow.up.right"
                        )
                    }
                }

                Spacer()
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
                .tint(AppColors.accent)

                Button {
                    appStore.copyLastSet(in: block.id)
                } label: {
                    Label("Copy Last", systemImage: "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(AppColors.accent)
            }
        }
        .padding(14)
        .appSurface(cornerRadius: 16, shadow: false)
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

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(row.target.setKind.displayName)
                    .font(.caption.weight(.semibold))
                    .tracking(0.5)
                    .foregroundStyle(AppColors.textSecondary)

                Spacer()

                Text(targetSummary)
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }

            HStack(spacing: 10) {
                SessionStatControlView(
                    title: "Load",
                    value: loadValue,
                    unit: weightUnit.symbol,
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
                    onDecrease: {
                        appStore.adjustSetReps(blockID: blockID, setID: row.id, delta: -1)
                    },
                    onIncrease: {
                        appStore.adjustSetReps(blockID: blockID, setID: row.id, delta: 1)
                    }
                )

                Button {
                    appStore.toggleSetCompletion(blockID: blockID, setID: row.id)
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: row.log.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 24, weight: .bold))
                        Text(row.log.isCompleted ? "Done" : "Complete")
                            .font(.caption.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity, minHeight: 74)
                }
                .buttonStyle(.borderedProminent)
                .tint(row.log.isCompleted ? AppColors.accent : AppColors.accent.opacity(0.78))
                .accessibilityIdentifier("session.completeSet.\(blockID.uuidString).\(row.id.uuidString)")
            }

            if let note = row.target.note, !note.isEmpty {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(AppColors.accent)
            }
        }
        .padding(12)
        .appInsetCard(cornerRadius: 12, fillOpacity: 0.8, borderOpacity: 0.68)
    }
}

private struct SessionStatControlView: View {
    let title: String
    let value: String
    let unit: String
    let onDecrease: () -> Void
    let onIncrease: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColors.textSecondary)

            Text(unit.isEmpty ? value : "\(value) \(unit)")
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            HStack(spacing: 8) {
                Button {
                    onDecrease()
                } label: {
                    Image(systemName: "minus")
                }
                .buttonStyle(.bordered)
                .tint(AppColors.accent)

                Button {
                    onIncrease()
                } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.bordered)
                .tint(AppColors.accent)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 74)
    }
}

private struct ActiveSessionFooterView: View {
    @Environment(AppStore.self) private var appStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HStack(spacing: 12) {
            Button {
                appStore.clearRestTimer()
            } label: {
                Label("Clear Rest", systemImage: "timer")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(AppColors.accent)

            Button {
                appStore.finishActiveSession()
                dismiss()
            } label: {
                Label("Finish Workout", systemImage: "checkmark.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColors.accent)
            .accessibilityIdentifier("session.finishButton")
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }
}

private struct ActiveSessionHeaderView: View, Equatable {
    let state: ActiveSessionHeaderState

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            AppHeroCard(
                eyebrow: "Active Session",
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
                        label: "Completed",
                        value: "\(state.completedSetCount)",
                        systemImage: "checklist"
                    ),
                    AppHeroMetric(
                        id: "timer",
                        label: "Rest",
                        value: restTimerLabel(at: context.date),
                        systemImage: "timer"
                    )
                ]
            )
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
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
