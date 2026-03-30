import SwiftUI

struct TemplateDraftBlockEditorView: View {
    @Binding var block: TemplateDraftBlock

    let weightUnit: WeightUnit
    let onPickExercise: (UUID) -> Void
    let onDelete: (UUID) -> Void

    @State private var isShowingAdvancedSettings: Bool

    init(
        block: Binding<TemplateDraftBlock>,
        weightUnit: WeightUnit,
        onPickExercise: @escaping (UUID) -> Void,
        onDelete: @escaping (UUID) -> Void
    ) {
        _block = block
        self.weightUnit = weightUnit
        self.onPickExercise = onPickExercise
        self.onDelete = onDelete
        _isShowingAdvancedSettings = State(initialValue: Self.shouldStartExpanded(for: block.wrappedValue))
    }

    private var exerciseTitle: String {
        block.exerciseName.nonEmptyTrimmed ?? "Choose exercise"
    }

    private var tone: AppToneStyle {
        block.exerciseID == nil ? .warning : .plans
    }

    private var usesWavePrescription: Bool {
        block.progressionKind == .percentageWave
    }

    private var prescriptionSummary: String {
        if usesWavePrescription {
            return "\(block.setCount) working sets - 5/3/1 wave"
        }

        return "\(block.setCount) set\(block.setCount == 1 ? "" : "s") • \(block.repLower)-\(block.repUpper) reps"
    }

    private var wavePrescriptionDetail: String {
        if block.trainingMaxText.isEmpty {
            return "5/3/1 sets and reps are generated automatically. Add a TM below to unlock target weights."
        }

        return "5/3/1 sets and reps are generated automatically from the current week and your TM."
    }

    private var advancedSummary: String {
        var labels: [String] = []

        if block.progressionKind != .manual {
            labels.append(block.progressionKind.displayLabel)
        }
        if !usesWavePrescription && block.setKind != .working {
            labels.append(block.setKind.rawValue.capitalized)
        }
        if block.supersetGroup.nonEmptyTrimmed != nil {
            labels.append("Superset")
        }
        if !block.allowsAutoWarmups {
            labels.append("Warmups Off")
        }
        if block.blockNote.nonEmptyTrimmed != nil {
            labels.append("Notes")
        }

        return labels.isEmpty ? "Optional" : labels.joined(separator: " • ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    AppStatePill(
                        title: block.exerciseID == nil ? "Needs Exercise" : prescriptionSummary,
                        systemImage: block.exerciseID == nil ? "exclamationmark.triangle.fill" : "dumbbell.fill",
                        tone: tone
                    )

                    Text(exerciseTitle)
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(AppColors.textPrimary)

                    Text(
                        block.exerciseID == nil
                            ? "Pick the movement first, then set the working prescription."
                            : "Keep the core prescription visible and hide the extra tuning below."
                    )
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                }

                Spacer(minLength: 12)

                VStack(spacing: 8) {
                    Button {
                        onPickExercise(block.id)
                    } label: {
                        Text("Pick")
                    }
                    .appSecondaryActionButton(tone: .plans, controlSize: .small)
                    .accessibilityIdentifier("plans.template.pickExerciseButton")

                    Button(role: .destructive) {
                        onDelete(block.id)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .appSecondaryActionButton(tone: .danger, controlSize: .small)
                }
            }

            Picker("Progression", selection: $block.progressionKind) {
                Text("Manual").tag(ProgressionRuleKind.manual)
                Text("Double").tag(ProgressionRuleKind.doubleProgression)
                Text("Wave").tag(ProgressionRuleKind.percentageWave)
            }
            .pickerStyle(.segmented)

            VStack(alignment: .leading, spacing: 10) {
                AppSectionHeader(
                    title: "Prescription",
                    systemImage: "figure.strengthtraining.traditional",
                    subtitle: usesWavePrescription
                        ? "Wave blocks generate their working sets automatically from the current 5/3/1 week."
                        : "Set the default workload you want this block to start with.",
                    tone: .today
                )

                if usesWavePrescription {
                    VStack(alignment: .leading, spacing: 8) {
                        AppStatePill(title: "TM Driven", systemImage: "waveform.path.ecg", tone: .progress)

                        Text(wavePrescriptionDetail)
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .appInsetContentCard(
                        fill: AppToneStyle.progress.softFill.opacity(0.45),
                        border: AppToneStyle.progress.softBorder
                    )

                    NumericInputField(title: "Rest (sec)", text: $block.restSecondsTextBinding, keyboardType: .numberPad)
                } else {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(minimum: 70), spacing: 10),
                            GridItem(.flexible(minimum: 70), spacing: 10),
                            GridItem(.flexible(minimum: 70), spacing: 10),
                        ],
                        spacing: 10
                    ) {
                        NumericInputField(title: "Sets", text: $block.setCountTextBinding, keyboardType: .numberPad)
                        NumericInputField(title: "Rep Min", text: $block.repLowerTextBinding, keyboardType: .numberPad)
                        NumericInputField(title: "Rep Max", text: $block.repUpperTextBinding, keyboardType: .numberPad)
                    }

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(minimum: 120), spacing: 10),
                            GridItem(.flexible(minimum: 120), spacing: 10),
                        ],
                        spacing: 10
                    ) {
                        NumericInputField(title: "Target Weight (\(weightUnit.symbol))", text: $block.targetWeightText)
                        NumericInputField(title: "Rest (sec)", text: $block.restSecondsTextBinding, keyboardType: .numberPad)
                    }
                }
            }

            DisclosureGroup(isExpanded: $isShowingAdvancedSettings) {
                VStack(alignment: .leading, spacing: 12) {
                    if block.progressionKind != .manual {
                        VStack(alignment: .leading, spacing: 10) {
                            AppSectionHeader(
                                title: "Progression Details",
                                systemImage: "arrow.up.right",
                                subtitle: "Fine-tune increments and profile values for this block.",
                                tone: .progress
                            )

                            LazyVGrid(
                                columns: [
                                    GridItem(.flexible(minimum: 120), spacing: 10),
                                    GridItem(.flexible(minimum: 120), spacing: 10),
                                ],
                                spacing: 10
                            ) {
                                NumericInputField(title: "Increment (\(weightUnit.symbol))", text: $block.incrementText)
                                NumericInputField(title: "TM / Profile Weight (\(weightUnit.symbol))", text: $block.trainingMaxText)
                            }

                            NumericInputField(
                                title: "Preferred Increment Override (\(weightUnit.symbol))",
                                text: $block.preferredIncrementText
                            )
                        }
                        .appInsetContentCard(
                            fill: AppToneStyle.progress.softFill.opacity(0.45),
                            border: AppToneStyle.progress.softBorder
                        )
                    }

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(minimum: 120), spacing: 10),
                            GridItem(.flexible(minimum: 120), spacing: 10),
                        ],
                        spacing: 10
                    ) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Superset")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppColors.textSecondary)

                            TextField("Superset group", text: $block.supersetGroup)
                                .textInputAutocapitalization(.characters)
                                .foregroundStyle(AppColors.textPrimary)
                                .appInputField()
                        }

                        if !usesWavePrescription {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Set Type")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppColors.textSecondary)

                                Picker("Set Type", selection: $block.setKind) {
                                    Text("Working").tag(SetKind.working)
                                    Text("Dropset").tag(SetKind.dropSet)
                                    Text("Warmup").tag(SetKind.warmup)
                                }
                                .pickerStyle(.menu)
                                .tint(AppColors.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .appInputField()
                            }
                        }
                    }

                    Toggle("Auto warmups", isOn: $block.allowsAutoWarmups)
                        .tint(AppToneStyle.plans.accent)

                    TextField("Block note", text: $block.blockNote, axis: .vertical)
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(2...3)
                        .appInputField()
                }
                .padding(.top, 10)
            } label: {
                AppSectionHeader(
                    title: "Advanced Settings",
                    systemImage: "slider.horizontal.3",
                    subtitle: "Superset, set type, notes, and progression overrides.",
                    trailing: advancedSummary,
                    tone: .progress
                )
            }
            .tint(AppToneStyle.progress.accent)
        }
        .appSectionFrame(tone: tone, topPadding: 16, bottomPadding: 8)
        .onChange(of: block.progressionKind) { _, newValue in
            if newValue == .percentageWave {
                block.setKind = .working
            }
        }
    }

    private static func shouldStartExpanded(for block: TemplateDraftBlock) -> Bool {
        block.progressionKind != .manual
            || block.supersetGroup.nonEmptyTrimmed != nil
            || block.setKind != .working
            || !block.allowsAutoWarmups
            || block.blockNote.nonEmptyTrimmed != nil
    }
}

private extension Binding where Value == TemplateDraftBlock {
    var setCountTextBinding: Binding<String> {
        Binding<String>(
            get: { String(wrappedValue.setCount) },
            set: { wrappedValue.setCount = Swift.max(1, Int($0) ?? wrappedValue.setCount) }
        )
    }

    var repLowerTextBinding: Binding<String> {
        Binding<String>(
            get: { String(wrappedValue.repLower) },
            set: { wrappedValue.repLower = Swift.max(1, Int($0) ?? wrappedValue.repLower) }
        )
    }

    var repUpperTextBinding: Binding<String> {
        Binding<String>(
            get: { String(wrappedValue.repUpper) },
            set: {
                wrappedValue.repUpper = Swift.max(
                    wrappedValue.repLower,
                    Int($0) ?? wrappedValue.repUpper
                )
            }
        )
    }

    var restSecondsTextBinding: Binding<String> {
        Binding<String>(
            get: { String(wrappedValue.restSeconds) },
            set: { wrappedValue.restSeconds = Swift.max(1, Int($0) ?? wrappedValue.restSeconds) }
        )
    }
}
