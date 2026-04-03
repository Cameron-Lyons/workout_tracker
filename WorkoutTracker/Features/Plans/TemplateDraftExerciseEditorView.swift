import SwiftUI

struct TemplateDraftExerciseEditorView: View {
    @Binding var draft: TemplateDraftExercise

    let weightUnit: WeightUnit
    let onPickExercise: (UUID) -> Void
    let onDelete: (UUID) -> Void

    @State private var isShowingAdvancedSettings: Bool

    init(
        draft: Binding<TemplateDraftExercise>,
        weightUnit: WeightUnit,
        onPickExercise: @escaping (UUID) -> Void,
        onDelete: @escaping (UUID) -> Void
    ) {
        _draft = draft
        self.weightUnit = weightUnit
        self.onPickExercise = onPickExercise
        self.onDelete = onDelete
        _isShowingAdvancedSettings = State(initialValue: Self.shouldStartExpanded(for: draft.wrappedValue))
    }

    private var exerciseTitle: String {
        draft.exerciseName.nonEmptyTrimmed ?? "Choose exercise"
    }

    private var tone: AppToneStyle {
        draft.exerciseID == nil ? .warning : .plans
    }

    private var usesWavePrescription: Bool {
        draft.progressionKind == .percentageWave
    }

    private var prescriptionSummary: String {
        if usesWavePrescription {
            return "\(draft.setCount) working sets - 5/3/1 wave"
        }

        return "\(draft.setCount) set\(draft.setCount == 1 ? "" : "s") • \(draft.repLower)-\(draft.repUpper) reps"
    }

    private var wavePrescriptionDetail: String {
        if draft.trainingMaxText.isEmpty {
            return "5/3/1 sets and reps are generated automatically. Add a TM below to unlock target weights."
        }

        return "5/3/1 sets and reps are generated automatically from the current week and your TM."
    }

    private var advancedSummary: String {
        var labels: [String] = []

        if draft.progressionKind != .manual {
            labels.append(draft.progressionKind.displayLabel)
        }
        if !usesWavePrescription && draft.setKind != .working {
            labels.append(draft.setKind.rawValue.capitalized)
        }
        if draft.supersetGroup.nonEmptyTrimmed != nil {
            labels.append("Superset")
        }
        if !draft.allowsAutoWarmups {
            labels.append("Warmups Off")
        }

        return labels.isEmpty ? "Optional" : labels.joined(separator: " • ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 8) {
                    AppStatePill(
                        title: draft.exerciseID == nil ? "Needs Exercise" : prescriptionSummary,
                        systemImage: draft.exerciseID == nil ? "exclamationmark.triangle.fill" : "dumbbell.fill",
                        tone: tone
                    )

                    Text(exerciseTitle)
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(AppColors.textPrimary)

                    Text(
                        draft.exerciseID == nil
                            ? "Pick the movement first, then set the working prescription."
                            : "Keep the core prescription visible and hide the extra tuning below."
                    )
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                }

                Spacer(minLength: 12)

                VStack(spacing: 8) {
                    Button {
                        onPickExercise(draft.id)
                    } label: {
                        Text("Pick")
                    }
                    .appSecondaryActionButton(tone: .plans, controlSize: .small)
                    .accessibilityIdentifier("plans.template.pickExerciseButton")

                    Button(role: .destructive) {
                        onDelete(draft.id)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .appSecondaryActionButton(tone: .danger, controlSize: .small)
                }
            }

            Picker("Progression", selection: $draft.progressionKind) {
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
                        ? "Wave progression generates working sets automatically from the current 5/3/1 week."
                        : "Set the default workload you want this exercise to start with.",
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

                    NumericInputField(title: "Rest (sec)", text: $draft.restSecondsTextBinding, keyboardType: .numberPad)
                } else {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(minimum: 70), spacing: 10),
                            GridItem(.flexible(minimum: 70), spacing: 10),
                            GridItem(.flexible(minimum: 70), spacing: 10),
                        ],
                        spacing: 10
                    ) {
                        NumericInputField(title: "Sets", text: $draft.setCountTextBinding, keyboardType: .numberPad)
                        NumericInputField(title: "Rep Min", text: $draft.repLowerTextBinding, keyboardType: .numberPad)
                        NumericInputField(title: "Rep Max", text: $draft.repUpperTextBinding, keyboardType: .numberPad)
                    }

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(minimum: 120), spacing: 10),
                            GridItem(.flexible(minimum: 120), spacing: 10),
                        ],
                        spacing: 10
                    ) {
                        NumericInputField(title: "Target Weight (\(weightUnit.symbol))", text: $draft.targetWeightText)
                        NumericInputField(title: "Rest (sec)", text: $draft.restSecondsTextBinding, keyboardType: .numberPad)
                    }
                }
            }

            DisclosureGroup(isExpanded: $isShowingAdvancedSettings) {
                VStack(alignment: .leading, spacing: 12) {
                    if draft.progressionKind != .manual {
                        VStack(alignment: .leading, spacing: 10) {
                            AppSectionHeader(
                                title: "Progression Details",
                                systemImage: "arrow.up.right",
                                subtitle: "Fine-tune increments and profile values for this exercise.",
                                tone: .progress
                            )

                            LazyVGrid(
                                columns: [
                                    GridItem(.flexible(minimum: 120), spacing: 10),
                                    GridItem(.flexible(minimum: 120), spacing: 10),
                                ],
                                spacing: 10
                            ) {
                                NumericInputField(title: "Increment (\(weightUnit.symbol))", text: $draft.incrementText)
                                NumericInputField(title: "TM / Profile Weight (\(weightUnit.symbol))", text: $draft.trainingMaxText)
                            }

                            NumericInputField(
                                title: "Preferred Increment Override (\(weightUnit.symbol))",
                                text: $draft.preferredIncrementText
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

                            TextField("Superset group", text: $draft.supersetGroup)
                                .textInputAutocapitalization(.characters)
                                .foregroundStyle(AppColors.textPrimary)
                                .appInputField()
                        }

                        if !usesWavePrescription {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Set Type")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(AppColors.textSecondary)

                                Picker("Set Type", selection: $draft.setKind) {
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

                    Toggle("Auto warmups", isOn: $draft.allowsAutoWarmups)
                        .tint(AppToneStyle.plans.accent)
                }
                .padding(.top, 10)
            } label: {
                AppSectionHeader(
                    title: "Advanced Settings",
                    systemImage: "slider.horizontal.3",
                    subtitle: "Superset, set type, and progression overrides.",
                    trailing: advancedSummary,
                    tone: .progress
                )
            }
            .tint(AppToneStyle.progress.accent)
        }
        .appSectionFrame(tone: tone, topPadding: 16, bottomPadding: 8)
        .onChange(of: draft.progressionKind) { _, newValue in
            if newValue == .percentageWave {
                draft.setKind = .working
            }
        }
    }

    private static func shouldStartExpanded(for draft: TemplateDraftExercise) -> Bool {
        draft.progressionKind != .manual
            || draft.supersetGroup.nonEmptyTrimmed != nil
            || draft.setKind != .working
            || !draft.allowsAutoWarmups
    }
}

private extension Binding where Value == TemplateDraftExercise {
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
