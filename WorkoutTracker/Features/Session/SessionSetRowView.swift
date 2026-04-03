import SwiftUI

private enum SessionSetMetricField: Hashable {
    case weight
    case reps
}

@MainActor
struct SessionSetRowView: View, Equatable {
    let blockID: UUID
    let row: SessionSetRow
    let weightUnit: WeightUnit
    let actions: ActiveSessionActions
    let showsDetailedChrome: Bool
    let showsMetricColumnTitles: Bool
    let noteLine: String?
    let showSetKindHeading: Bool
    @State private var weightInputText: String
    @State private var repsInputText: String
    @State private var weightCommitTask: Task<Void, Never>?
    @State private var repsCommitTask: Task<Void, Never>?
    @FocusState private var focusedField: SessionSetMetricField?

    init(
        blockID: UUID,
        row: SessionSetRow,
        weightUnit: WeightUnit,
        actions: ActiveSessionActions,
        showsDetailedChrome: Bool,
        showsMetricColumnTitles: Bool = true,
        noteLine: String? = nil,
        showSetKindHeading: Bool = true
    ) {
        self.blockID = blockID
        self.row = row
        self.weightUnit = weightUnit
        self.actions = actions
        self.showsDetailedChrome = showsDetailedChrome
        self.showsMetricColumnTitles = showsMetricColumnTitles
        self.noteLine = noteLine
        self.showSetKindHeading = showSetKindHeading
        _weightInputText = State(initialValue: Self.weightInputText(for: row, unit: weightUnit))
        _repsInputText = State(initialValue: Self.repsInputText(for: row))
    }

    nonisolated static func == (lhs: SessionSetRowView, rhs: SessionSetRowView) -> Bool {
        lhs.blockID == rhs.blockID
            && lhs.row == rhs.row
            && lhs.weightUnit == rhs.weightUnit
            && lhs.showsDetailedChrome == rhs.showsDetailedChrome
            && lhs.showsMetricColumnTitles == rhs.showsMetricColumnTitles
            && lhs.noteLine == rhs.noteLine
            && lhs.showSetKindHeading == rhs.showSetKindHeading
    }

    private var tone: AppToneStyle {
        row.log.isCompleted ? .success : .today
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                Group {
                    if showSetKindHeading {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(setKindTitle.uppercased())
                                .font(.caption.weight(.black))
                                .tracking(0.8)
                                .foregroundStyle(row.log.isCompleted ? AppToneStyle.success.accent : AppColors.textSecondary)
                        }
                    }
                }
                .frame(minWidth: 0, alignment: .leading)

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
                    title: showsMetricColumnTitles ? "Load" : nil,
                    caption: loadCaption,
                    valueContent: {
                        metricInputField(
                            text: $weightInputText,
                            placeholder: "0",
                            suffix: weightUnit.symbol,
                            keyboardType: .decimalPad,
                            field: .weight,
                            accessibilityIdentifier: "session.input.load.\(blockID.uuidString).\(row.id.uuidString)"
                        )
                    }
                )

                statControl(
                    title: showsMetricColumnTitles ? "Reps" : nil,
                    caption: "Target \(repsLabel)",
                    valueContent: {
                        metricInputField(
                            text: $repsInputText,
                            placeholder: canonicalRepsText,
                            keyboardType: .numberPad,
                            field: .reps,
                            accessibilityIdentifier: "session.input.reps.\(blockID.uuidString).\(row.id.uuidString)"
                        )
                    }
                )
            }

            if showsDetailedChrome, let note = displayedSetNote {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(AppToneStyle.progress.accent)
            }
        }
        .onChange(of: row) { _, _ in
            cancelPendingCommitTasks()
            syncMetricInputsIfNeeded()
        }
        .onChange(of: weightUnit) { _, _ in
            cancelPendingCommitTasks()
            syncMetricInputsIfNeeded()
        }
        .onChange(of: focusedField) { previousValue, newValue in
            if previousValue == .weight, newValue != .weight {
                commitWeightInputImmediately()
                normalizeWeightInput()
            }
            if previousValue == .reps, newValue != .reps {
                commitRepsInputImmediately()
                normalizeRepsInput()
            }
        }
        .onChange(of: weightInputText) { _, newValue in
            guard focusedField == .weight else {
                return
            }

            scheduleWeightCommit(for: newValue)
        }
        .onChange(of: repsInputText) { _, newValue in
            guard focusedField == .reps else {
                return
            }

            scheduleRepsCommit(for: newValue)
        }
        .onDisappear {
            commitPendingInputs()
        }
        .padding(.vertical, showsDetailedChrome ? 14 : 12)
    }

    private var setKindTitle: String {
        row.target.setKind.displayName
    }

    private var displayedSetNote: String? {
        SessionSetNoteDisplay.rowCaption(noteLine: noteLine, fullNote: row.target.note)
    }

    private var canonicalWeightText: String {
        Self.weightInputText(for: row, unit: weightUnit)
    }

    private var canonicalRepsText: String {
        Self.repsInputText(for: row)
    }

    private var repsLabel: String {
        row.target.repRange.displayLabel
    }

    private var loadCaption: String {
        if let targetWeight = row.target.targetWeight {
            return "Target \(WeightFormatter.displayString(targetWeight, unit: weightUnit)) \(weightUnit.symbol)"
        }

        return "Enter load"
    }

    private func statControl<ValueContent: View>(
        title: String?,
        caption: String?,
        @ViewBuilder valueContent: () -> ValueContent
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title, !title.isEmpty {
                Text(title.uppercased())
                    .font(.caption2.weight(.semibold))
                    .tracking(0.5)
                    .foregroundStyle(AppColors.textSecondary)
            }

            valueContent()

            if showsDetailedChrome, let caption, !caption.isEmpty {
                Text(caption)
                    .font(.caption2)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func metricInputField(
        text: Binding<String>,
        placeholder: String,
        suffix: String? = nil,
        keyboardType: UIKeyboardType,
        field: SessionSetMetricField,
        accessibilityIdentifier: String
    ) -> some View {
        let textField = TextField(placeholder, text: text)
            .keyboardType(keyboardType)
            .textFieldStyle(.plain)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.done)
            .onSubmit {
                submit(field)
            }
            .focused($focusedField, equals: field)
            .font(.system(size: 24, weight: .black))
            .monospacedDigit()
            .foregroundStyle(AppColors.textPrimary)
            .accessibilityIdentifier(accessibilityIdentifier)

        return HStack(alignment: .firstTextBaseline, spacing: 4) {
            Group {
                if showsMetricColumnTitles {
                    textField
                } else {
                    textField.accessibilityLabel(field == .weight ? "Load" : "Reps")
                }
            }

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

    private func scheduleWeightCommit(for text: String) {
        weightCommitTask?.cancel()
        weightCommitTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: SessionInputCommitDefaults.debounceNanoseconds)
            guard !Task.isCancelled else {
                return
            }

            commitWeightInputIfNeeded(from: text)
        }
    }

    private func scheduleRepsCommit(for text: String) {
        repsCommitTask?.cancel()
        repsCommitTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: SessionInputCommitDefaults.debounceNanoseconds)
            guard !Task.isCancelled else {
                return
            }

            commitRepsInputIfNeeded(from: text)
        }
    }

    private func commitWeightInputImmediately() {
        weightCommitTask?.cancel()
        weightCommitTask = nil
        commitWeightInputIfNeeded(from: weightInputText)
    }

    private func commitRepsInputImmediately() {
        repsCommitTask?.cancel()
        repsCommitTask = nil
        commitRepsInputIfNeeded(from: repsInputText)
    }

    private func commitWeightInputIfNeeded(from text: String) {
        guard
            let storedWeight = WeightInputConversion.parseStoredPounds(
                from: text,
                unit: weightUnit,
                allowsZero: true
            )
        else {
            return
        }

        guard storedWeight != currentStoredWeight else {
            return
        }

        actions.updateWeight(blockID, row.id, storedWeight)
    }

    private func commitRepsInputIfNeeded(from text: String) {
        guard let reps = parsedReps(from: text), reps != currentReps else {
            return
        }

        actions.updateReps(blockID, row.id, reps)
    }

    private func submit(_ field: SessionSetMetricField) {
        switch field {
        case .weight:
            commitWeightInputImmediately()
            normalizeWeightInput()
        case .reps:
            commitRepsInputImmediately()
            normalizeRepsInput()
        }

        focusedField = nil
    }

    private func commitPendingInputs() {
        commitWeightInputImmediately()
        commitRepsInputImmediately()
    }

    private func cancelPendingCommitTasks() {
        weightCommitTask?.cancel()
        weightCommitTask = nil
        repsCommitTask?.cancel()
        repsCommitTask = nil
    }

    private func parsedReps(from text: String) -> Int? {
        let sanitized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sanitized.isEmpty, let reps = Int(sanitized), reps >= 0 else {
            return nil
        }

        return reps
    }

    private var currentStoredWeight: Double {
        row.log.weight ?? row.target.targetWeight ?? 0
    }

    private var currentReps: Int {
        row.log.reps ?? row.target.repRange.upperBound
    }

    private static func weightInputText(for row: SessionSetRow, unit: WeightUnit) -> String {
        WeightFormatter.displayString(row.log.weight ?? row.target.targetWeight, unit: unit)
    }

    private static func repsInputText(for row: SessionSetRow) -> String {
        "\(row.log.reps ?? row.target.repRange.upperBound)"
    }
}
