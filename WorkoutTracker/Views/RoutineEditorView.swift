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
        restSeconds: Int = ExerciseBlockDefaults.restSeconds,
        setCount: Int = ExerciseBlockDefaults.setCount,
        repLower: Int = ExerciseBlockDefaults.repRange.lowerBound,
        repUpper: Int = ExerciseBlockDefaults.repRange.upperBound,
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

    private var planTitle: String {
        name.nonEmptyTrimmed ?? existingPlan?.name ?? "Name your plan"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    LazyVStack(spacing: 18) {
                        AppHeroCard(
                            eyebrow: existingPlan == nil ? "New Plan" : "Edit Plan",
                            title: planTitle,
                            subtitle: "Plans keep related templates together so Today stays fast and organized.",
                            systemImage: "list.bullet.rectangle",
                            metrics: [
                                AppHeroMetric(
                                    id: "templates",
                                    label: "Templates",
                                    value: "\(existingPlan?.templates.count ?? 0)",
                                    systemImage: "rectangle.stack"
                                ),
                                AppHeroMetric(
                                    id: "pin",
                                    label: "Pinned",
                                    value: existingPlan?.pinnedTemplateID == nil ? "None" : "Set",
                                    systemImage: "pin"
                                ),
                            ],
                            tone: .plans
                        )

                        VStack(alignment: .leading, spacing: 12) {
                            AppSectionHeader(
                                title: "Plan Identity",
                                systemImage: "textformat",
                                subtitle: "Choose a short name you will recognize from Today and Plans.",
                                tone: .plans
                            )

                            TextField("Plan name", text: $name)
                                .textInputAutocapitalization(.words)
                                .foregroundStyle(AppColors.textPrimary)
                                .appInputField()

                            Text("Examples: Upper / Lower, Garage Gym, Travel Split.")
                                .font(.caption)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                        .appFeatureSurface()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .scrollIndicators(.hidden)
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

    private var templateTitle: String {
        templateName.nonEmptyTrimmed ?? existingTemplate?.name ?? "Build a template"
    }

    private var hasInvalidBlocks: Bool {
        blocks.contains(where: { $0.exerciseID == nil })
    }

    private var unresolvedBlockCount: Int {
        blocks.filter { $0.exerciseID == nil }.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    LazyVStack(spacing: 18) {
                        AppHeroCard(
                            eyebrow: existingTemplate == nil ? "New Template" : "Edit Template",
                            title: templateTitle,
                            subtitle: blocks.isEmpty
                                ? "Start with the basics first, then open advanced settings only for the blocks that need them."
                                : "Keep the main prescription up front and tuck progression details into each block as needed.",
                            systemImage: "rectangle.stack.badge.plus",
                            metrics: [
                                AppHeroMetric(
                                    id: "blocks",
                                    label: "Blocks",
                                    value: "\(blocks.count)",
                                    systemImage: "square.grid.2x2"
                                ),
                                AppHeroMetric(
                                    id: "schedule",
                                    label: "Schedule",
                                    value: selectedWeekdays.isEmpty ? "Flexible" : "\(selectedWeekdays.count) days",
                                    systemImage: "calendar"
                                ),
                                AppHeroMetric(
                                    id: "ready",
                                    label: "Needs Setup",
                                    value: "\(unresolvedBlockCount)",
                                    systemImage: "exclamationmark.circle"
                                ),
                                AppHeroMetric(
                                    id: "unit",
                                    label: "Weight Unit",
                                    value: weightUnit.symbol.uppercased(),
                                    systemImage: "scalemass"
                                ),
                            ],
                            tone: .plans
                        )

                        VStack(alignment: .leading, spacing: 12) {
                            AppSectionHeader(
                                title: "Overview",
                                systemImage: "square.and.pencil",
                                subtitle: "Name the template and leave a note for the next time you run it.",
                                tone: .plans
                            )

                            TextField("Template name", text: $templateName)
                                .textInputAutocapitalization(.words)
                                .foregroundStyle(AppColors.textPrimary)
                                .appInputField()

                            TextField("Notes", text: $templateNote, axis: .vertical)
                                .foregroundStyle(AppColors.textPrimary)
                                .lineLimit(2...4)
                                .appInputField()
                        }
                        .appFeatureSurface()

                        VStack(alignment: .leading, spacing: 12) {
                            AppSectionHeader(
                                title: "Schedule",
                                systemImage: "calendar.badge.clock",
                                subtitle: "Pin recurring days now or leave the template flexible.",
                                trailing: selectedWeekdays.isEmpty ? "Any day" : "\(selectedWeekdays.count) selected",
                                tone: .plans
                            )

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
                                                cornerRadius: 12,
                                                fill: selectedWeekdays.contains(weekday)
                                                    ? AppToneStyle.plans.softFill.opacity(0.92)
                                                    : nil,
                                                border: selectedWeekdays.contains(weekday)
                                                    ? AppToneStyle.plans.softBorder
                                                    : nil
                                            )
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        .appFeatureSurface()

                        VStack(alignment: .leading, spacing: 12) {
                            HStack(alignment: .top, spacing: 12) {
                                AppSectionHeader(
                                    title: "Exercise Blocks",
                                    systemImage: "dumbbell",
                                    subtitle: "Keep the default prescription simple, then expand a block for more control.",
                                    trailing: blocks.isEmpty ? nil : "\(blocks.count)",
                                    tone: .today
                                )

                                Button {
                                    blocks.append(TemplateDraftBlock())
                                } label: {
                                    Label("Add Block", systemImage: "plus")
                                }
                                .buttonStyle(.borderedProminent)
                                .buttonBorderShape(.roundedRectangle(radius: 14))
                                .tint(AppToneStyle.today.accent)
                                .accessibilityIdentifier("plans.template.addBlockButton")
                            }

                            if blocks.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    AppStatePill(title: "Start Here", systemImage: "sparkles", tone: .today)

                                    Text("Add at least one exercise block.")
                                        .font(.headline.weight(.semibold))
                                        .foregroundStyle(AppColors.textPrimary)

                                    Text("Each block holds the main prescription up front, with progression details hidden until you need them.")
                                        .font(.subheadline)
                                        .foregroundStyle(AppColors.textSecondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .appInsetContentCard(
                                    fill: AppToneStyle.today.softFill.opacity(0.55),
                                    border: AppToneStyle.today.softBorder
                                )
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
                        .appFeatureSurface()
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
                    .disabled(templateName.nonEmptyTrimmed == nil || hasInvalidBlocks)
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
            let repRange = block.targets.first?.repRange ?? ExerciseBlockDefaults.repRange

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
                preferredIncrement: preferredIncrement
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
                    percentageWave: PercentageWaveRule.fiveThreeOne(
                        trainingMax: profileTrainingMax,
                        currentWeekIndex: existingTemplate?.blocks.first(where: { $0.id == block.id })?.progressionRule.percentageWave?
                            .currentWeekIndex ?? 0,
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

    private var prescriptionSummary: String {
        "\(block.setCount) set\(block.setCount == 1 ? "" : "s") • \(block.repLower)-\(block.repUpper) reps"
    }

    private var advancedSummary: String {
        var labels: [String] = []

        if block.progressionKind != .manual {
            labels.append(block.progressionKind.displayLabel)
        }
        if block.setKind != .working {
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
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(AppColors.textPrimary)

                    Text(block.exerciseID == nil
                        ? "Pick the movement first, then set the working prescription."
                        : "Keep the core prescription visible and hide the extra tuning below.")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer(minLength: 12)

                VStack(spacing: 8) {
                    Button("Pick") {
                        onPickExercise(block.id)
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle(radius: 12))
                    .tint(AppToneStyle.plans.accent)

                    Button(role: .destructive) {
                        onDelete(block.id)
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.roundedRectangle(radius: 12))
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
                    subtitle: "Set the default workload you want this block to start with.",
                    tone: .today
                )

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
        .appEditorInsetCard(borderOpacity: 0.78)
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
