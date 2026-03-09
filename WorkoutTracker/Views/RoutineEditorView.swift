import SwiftUI

private struct TemplateDraftBlock: Identifiable, Equatable {
    var id: UUID
    var exerciseID: UUID?
    var exerciseName: String
    var blockNote: String
    var restSeconds: Int
    var setCount: Int
    var repLower: Int
    var repUpper: Int
    var targetWeightText: String
    var supersetGroup: String
    var progressionKind: ProgressionRuleKind
    var incrementText: String
    var trainingMaxText: String
    var preferredIncrementText: String
    var allowsAutoWarmups: Bool
    var setKind: SetKind

    init(
        id: UUID = UUID(),
        exerciseID: UUID? = nil,
        exerciseName: String = "",
        blockNote: String = "",
        restSeconds: Int = 90,
        setCount: Int = 3,
        repLower: Int = 8,
        repUpper: Int = 12,
        targetWeightText: String = "",
        supersetGroup: String = "",
        progressionKind: ProgressionRuleKind = .manual,
        incrementText: String = "",
        trainingMaxText: String = "",
        preferredIncrementText: String = "",
        allowsAutoWarmups: Bool = true,
        setKind: SetKind = .working
    ) {
        self.id = id
        self.exerciseID = exerciseID
        self.exerciseName = exerciseName
        self.blockNote = blockNote
        self.restSeconds = restSeconds
        self.setCount = setCount
        self.repLower = repLower
        self.repUpper = repUpper
        self.targetWeightText = targetWeightText
        self.supersetGroup = supersetGroup
        self.progressionKind = progressionKind
        self.incrementText = incrementText
        self.trainingMaxText = trainingMaxText
        self.preferredIncrementText = preferredIncrementText
        self.allowsAutoWarmups = allowsAutoWarmups
        self.setKind = setKind
    }
}

struct PlanEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let existingPlan: Plan?
    let onSave: (Plan) -> Void

    @State private var name = ""

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                VStack(spacing: 14) {
                    TextField("Plan name", text: $name)
                        .textInputAutocapitalization(.words)
                        .foregroundStyle(AppColors.textPrimary)
                        .appInputField()
                }
                .padding()
            }
            .navigationTitle(existingPlan == nil ? "New Plan" : "Edit Plan")
            .toolbarBackground(AppColors.chrome, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        let trimmedName = name.nonEmptyTrimmed ?? ""
                        guard !trimmedName.isEmpty else {
                            return
                        }

                        onSave(
                            Plan(
                                id: existingPlan?.id ?? UUID(),
                                name: trimmedName,
                                createdAt: existingPlan?.createdAt ?? .now,
                                pinnedTemplateID: existingPlan?.pinnedTemplateID,
                                presetPackID: existingPlan?.presetPackID,
                                templates: existingPlan?.templates ?? []
                            )
                        )
                        dismiss()
                    }
                    .disabled(name.nonEmptyTrimmed == nil)
                }
            }
            .onAppear {
                name = existingPlan?.name ?? ""
            }
        }
    }
}

struct TemplateEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppStore.self) private var appStore

    let planID: UUID
    let existingTemplate: WorkoutTemplate?
    let onSave: (WorkoutTemplate, [ExerciseProfile]) -> Void

    @State private var templateName = ""
    @State private var templateNote = ""
    @State private var selectedWeekdays: Set<Weekday> = []
    @State private var blocks: [TemplateDraftBlock] = []
    @State private var showingExercisePickerForBlockID: UUID?

    private var weightUnit: WeightUnit {
        appStore.settingsStore.weightUnit
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    LazyVStack(spacing: 16) {
                        VStack(spacing: 12) {
                            TextField("Template name", text: $templateName)
                                .textInputAutocapitalization(.words)
                                .foregroundStyle(AppColors.textPrimary)
                                .appInputField()

                            TextField("Notes", text: $templateNote, axis: .vertical)
                                .foregroundStyle(AppColors.textPrimary)
                                .lineLimit(2...4)
                                .appInputField()
                        }
                        .padding(14)
                        .appSurface(cornerRadius: 14, shadow: false)

                        VStack(alignment: .leading, spacing: 10) {
                            Text("Schedule")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(AppColors.textPrimary)

                            LazyVGrid(
                                columns: [GridItem(.adaptive(minimum: 72), spacing: 10)],
                                spacing: 10
                            ) {
                                ForEach(Weekday.allCases) { weekday in
                                    Button {
                                        if selectedWeekdays.contains(weekday) {
                                            selectedWeekdays.remove(weekday)
                                        } else {
                                            selectedWeekdays.insert(weekday)
                                        }
                                    } label: {
                                        Text(weekday.shortLabel)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(
                                                selectedWeekdays.contains(weekday)
                                                    ? AppColors.textPrimary
                                                    : AppColors.textSecondary
                                            )
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .appInsetCard(
                                                cornerRadius: 10,
                                                fillOpacity: selectedWeekdays.contains(weekday) ? 0.95 : 0.75,
                                                borderOpacity: selectedWeekdays.contains(weekday) ? 0.95 : 0.55
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .padding(14)
                        .appSurface(cornerRadius: 14, shadow: false)

                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Exercise Blocks")
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(AppColors.textPrimary)

                                Spacer()

                                Button {
                                    blocks.append(TemplateDraftBlock())
                                } label: {
                                    Label("Add Block", systemImage: "plus")
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(AppColors.accent)
                                .accessibilityIdentifier("plans.template.addBlockButton")
                            }

                            if blocks.isEmpty {
                                Text("Add at least one exercise block.")
                                    .font(.subheadline)
                                    .foregroundStyle(AppColors.textSecondary)
                            } else {
                                LazyVStack(spacing: 12) {
                                    ForEach($blocks) { $block in
                                        TemplateDraftBlockEditorView(
                                            block: $block,
                                            weightUnit: weightUnit,
                                            onPickExercise: { blockID in
                                                showingExercisePickerForBlockID = blockID
                                            },
                                            onDelete: { blockID in
                                                blocks.removeAll(where: { $0.id == blockID })
                                            }
                                        )
                                    }
                                }
                            }
                        }
                        .padding(14)
                        .appSurface(cornerRadius: 14, shadow: false)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle(existingTemplate == nil ? "New Template" : "Edit Template")
            .toolbarBackground(AppColors.chrome, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveTemplate()
                    }
                    .disabled(templateName.nonEmptyTrimmed == nil || blocks.contains(where: { $0.exerciseID == nil }))
                    .accessibilityIdentifier("plans.template.saveButton")
                }
            }
            .sheet(
                isPresented: Binding(
                    get: { showingExercisePickerForBlockID != nil },
                    set: { isPresented in
                        if !isPresented {
                            showingExercisePickerForBlockID = nil
                        }
                    }
                )
            ) {
                if let blockID = showingExercisePickerForBlockID {
                    ExercisePickerSheet(
                        catalog: appStore.plansStore.catalog,
                        title: "Choose Exercise",
                        onPick: { exercise in
                            assignExercise(exercise, to: blockID)
                        },
                        onCreateCustom: { customName in
                            let exercise = appStore.plansStore.addCustomExercise(name: customName)
                            assignExercise(exercise, to: blockID)
                        }
                    )
                }
            }
            .onAppear {
                loadTemplate()
            }
        }
    }

    private func loadTemplate() {
        templateName = existingTemplate?.name ?? ""
        templateNote = existingTemplate?.note ?? ""
        selectedWeekdays = Set(existingTemplate?.scheduledWeekdays ?? [])

        guard let existingTemplate else {
            blocks = []
            return
        }

        blocks = existingTemplate.blocks.map { block in
            let profile = appStore.plansStore.profile(for: block.exerciseID)
            let targetWeight = block.targets.first?.targetWeight
            let repRange = block.targets.first?.repRange ?? RepRange(8, 12)

            return TemplateDraftBlock(
                id: block.id,
                exerciseID: block.exerciseID,
                exerciseName: block.exerciseNameSnapshot,
                blockNote: block.blockNote,
                restSeconds: block.restSeconds,
                setCount: max(1, block.targets.count),
                repLower: repRange.lowerBound,
                repUpper: repRange.upperBound,
                targetWeightText: WeightFormatter.displayString(targetWeight, unit: weightUnit),
                supersetGroup: block.supersetGroup ?? "",
                progressionKind: block.progressionRule.kind,
                incrementText: WeightFormatter.displayString(
                    block.progressionRule.doubleProgression?.increment
                        ?? block.progressionRule.percentageWave?.cycleIncrement,
                    unit: weightUnit
                ),
                trainingMaxText: WeightFormatter.displayString(
                    profile?.trainingMax ?? block.progressionRule.percentageWave?.trainingMax,
                    unit: weightUnit
                ),
                preferredIncrementText: WeightFormatter.displayString(profile?.preferredIncrement, unit: weightUnit),
                allowsAutoWarmups: block.allowsAutoWarmups,
                setKind: block.targets.first?.setKind ?? .working
            )
        }
    }

    private func assignExercise(_ exercise: ExerciseCatalogItem, to blockID: UUID) {
        guard let index = blocks.firstIndex(where: { $0.id == blockID }) else {
            return
        }

        blocks[index].exerciseID = exercise.id
        blocks[index].exerciseName = exercise.name
        if blocks[index].progressionKind == .doubleProgression && blocks[index].incrementText.isEmpty {
            let increment = appStore.settingsStore.preferredIncrement(for: exercise.name)
            blocks[index].incrementText = WeightFormatter.displayString(
                displayValue: appStore.settingsStore.weightUnit.displayValue(fromStoredPounds: increment),
                unit: weightUnit
            )
        }
    }

    private func saveTemplate() {
        let trimmedName = templateName.nonEmptyTrimmed ?? ""
        guard !trimmedName.isEmpty else {
            return
        }

        var savedProfiles: [ExerciseProfile] = []
        let exerciseBlocks: [ExerciseBlock] = blocks.compactMap { block in
            guard let exerciseID = block.exerciseID else {
                return nil
            }

            let exerciseName = appStore.plansStore.exerciseName(for: exerciseID)
            let repRange = RepRange(
                max(1, block.repLower),
                max(max(1, block.repLower), block.repUpper)
            )
            let targetWeight = WeightInputConversion.parseStoredPounds(
                from: block.targetWeightText,
                unit: weightUnit,
                allowsZero: true
            )
            let increment = WeightInputConversion.parseStoredPounds(
                from: block.incrementText,
                unit: weightUnit,
                allowsZero: true
            )
            let profileTrainingMax = WeightInputConversion.parseStoredPounds(
                from: block.trainingMaxText,
                unit: weightUnit,
                allowsZero: true
            )
            let preferredIncrement = WeightInputConversion.parseStoredPounds(
                from: block.preferredIncrementText,
                unit: weightUnit,
                allowsZero: true
            )

            let profile = ExerciseProfile(
                id: appStore.plansStore.profile(for: exerciseID)?.id ?? UUID(),
                exerciseID: exerciseID,
                trainingMax: profileTrainingMax,
                preferredIncrement: preferredIncrement,
                notes: appStore.plansStore.profile(for: exerciseID)?.notes ?? ""
            )
            savedProfiles.append(profile)

            let progressionRule: ProgressionRule
            switch block.progressionKind {
            case .manual:
                progressionRule = .manual
            case .doubleProgression:
                progressionRule = ProgressionRule(
                    kind: .doubleProgression,
                    doubleProgression: DoubleProgressionRule(
                        targetRepRange: repRange,
                        increment: increment ?? appStore.settingsStore.preferredIncrement(for: exerciseName)
                    )
                )
            case .percentageWave:
                progressionRule = ProgressionRule(
                    kind: .percentageWave,
                    percentageWave: PercentageWaveRule(
                        trainingMax: profileTrainingMax,
                        weeks: [
                            PercentageWaveWeek(
                                name: "Week 1",
                                sets: [
                                    PercentageWaveSet(percentage: 0.65, repRange: RepRange(5, 5)),
                                    PercentageWaveSet(percentage: 0.75, repRange: RepRange(5, 5)),
                                    PercentageWaveSet(percentage: 0.85, repRange: RepRange(5, 5), note: "AMRAP")
                                ]
                            ),
                            PercentageWaveWeek(
                                name: "Week 2",
                                sets: [
                                    PercentageWaveSet(percentage: 0.70, repRange: RepRange(3, 3)),
                                    PercentageWaveSet(percentage: 0.80, repRange: RepRange(3, 3)),
                                    PercentageWaveSet(percentage: 0.90, repRange: RepRange(3, 3), note: "AMRAP")
                                ]
                            ),
                            PercentageWaveWeek(
                                name: "Week 3",
                                sets: [
                                    PercentageWaveSet(percentage: 0.75, repRange: RepRange(5, 5)),
                                    PercentageWaveSet(percentage: 0.85, repRange: RepRange(3, 3)),
                                    PercentageWaveSet(percentage: 0.95, repRange: RepRange(1, 1), note: "AMRAP")
                                ]
                            ),
                            PercentageWaveWeek(
                                name: "Deload",
                                sets: [
                                    PercentageWaveSet(percentage: 0.40, repRange: RepRange(5, 5)),
                                    PercentageWaveSet(percentage: 0.50, repRange: RepRange(5, 5)),
                                    PercentageWaveSet(percentage: 0.60, repRange: RepRange(5, 5))
                                ]
                            )
                        ],
                        currentWeekIndex: existingTemplate?.blocks.first(where: { $0.id == block.id })?.progressionRule.percentageWave?.currentWeekIndex ?? 0,
                        cycle: existingTemplate?.blocks.first(where: { $0.id == block.id })?.progressionRule.percentageWave?.cycle ?? 1,
                        cycleIncrement: increment ?? appStore.settingsStore.preferredIncrement(for: exerciseName)
                    )
                )
            }

            let targets = (0..<max(1, block.setCount)).map { _ in
                SetTarget(
                    setKind: block.setKind,
                    targetWeight: block.progressionKind == .percentageWave ? nil : targetWeight,
                    repRange: repRange,
                    restSeconds: block.restSeconds
                )
            }

            return ExerciseBlock(
                id: block.id,
                exerciseID: exerciseID,
                exerciseNameSnapshot: exerciseName,
                blockNote: block.blockNote,
                restSeconds: block.restSeconds,
                supersetGroup: block.supersetGroup.nonEmptyTrimmed,
                progressionRule: progressionRule,
                targets: targets,
                allowsAutoWarmups: block.allowsAutoWarmups
            )
        }

        let template = WorkoutTemplate(
            id: existingTemplate?.id ?? UUID(),
            name: trimmedName,
            note: templateNote,
            scheduledWeekdays: Weekday.allCases.filter { selectedWeekdays.contains($0) },
            blocks: exerciseBlocks,
            lastStartedAt: existingTemplate?.lastStartedAt
        )
        onSave(template, savedProfiles)
        dismiss()
    }
}

private struct TemplateDraftBlockEditorView: View {
    @Binding var block: TemplateDraftBlock

    let weightUnit: WeightUnit
    let onPickExercise: (UUID) -> Void
    let onDelete: (UUID) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(block.exerciseName.nonEmptyTrimmed ?? "Choose exercise")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)

                Spacer()

                Button("Pick") {
                    onPickExercise(block.id)
                }
                .buttonStyle(.bordered)
                .tint(AppColors.accent)

                Button(role: .destructive) {
                    onDelete(block.id)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)
            }

            Picker("Progression", selection: $block.progressionKind) {
                Text("Manual").tag(ProgressionRuleKind.manual)
                Text("Double").tag(ProgressionRuleKind.doubleProgression)
                Text("Wave").tag(ProgressionRuleKind.percentageWave)
            }
            .pickerStyle(.segmented)

            HStack(spacing: 10) {
                NumericInputField(title: "Sets", text: $block.setCountTextBinding, keyboardType: .numberPad)
                NumericInputField(title: "Rep Min", text: $block.repLowerTextBinding, keyboardType: .numberPad)
                NumericInputField(title: "Rep Max", text: $block.repUpperTextBinding, keyboardType: .numberPad)
            }

            HStack(spacing: 10) {
                NumericInputField(title: "Target Weight (\(weightUnit.symbol))", text: $block.targetWeightText)
                NumericInputField(title: "Rest (sec)", text: $block.restSecondsTextBinding, keyboardType: .numberPad)
            }

            if block.progressionKind != .manual {
                HStack(spacing: 10) {
                    NumericInputField(title: "Increment (\(weightUnit.symbol))", text: $block.incrementText)
                    NumericInputField(title: "TM / Profile Weight (\(weightUnit.symbol))", text: $block.trainingMaxText)
                }

                NumericInputField(
                    title: "Preferred Increment Override (\(weightUnit.symbol))",
                    text: $block.preferredIncrementText
                )
            }

            HStack(spacing: 10) {
                TextField("Superset group", text: $block.supersetGroup)
                    .textInputAutocapitalization(.characters)
                    .foregroundStyle(AppColors.textPrimary)
                    .appInputField()

                Picker("Set Type", selection: $block.setKind) {
                    Text("Working").tag(SetKind.working)
                    Text("Dropset").tag(SetKind.dropSet)
                    Text("Warmup").tag(SetKind.warmup)
                }
                .pickerStyle(.menu)
                .tint(AppColors.textPrimary)
                .frame(maxWidth: .infinity)
                .appInputField()
            }

            Toggle("Auto warmups", isOn: $block.allowsAutoWarmups)
                .tint(AppColors.accent)

            TextField("Block note", text: $block.blockNote, axis: .vertical)
                .foregroundStyle(AppColors.textPrimary)
                .lineLimit(2...3)
                .appInputField()
        }
        .padding(14)
        .appInsetCard(cornerRadius: 14, fillOpacity: 0.82, borderOpacity: 0.7)
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
