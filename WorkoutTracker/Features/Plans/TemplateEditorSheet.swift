import SwiftUI

struct TemplateDraftExercise: Identifiable, Equatable {
    var id: UUID
    var exerciseID: UUID?
    var exerciseName: String
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
        restSeconds: Int = TemplateExerciseDefaults.restSeconds,
        setCount: Int = TemplateExerciseDefaults.setCount,
        repLower: Int = TemplateExerciseDefaults.repRange.lowerBound,
        repUpper: Int = TemplateExerciseDefaults.repRange.upperBound,
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

enum TemplateProfileResolver {
    static func mergedProfile(
        existing: ExerciseProfile?,
        exerciseID: UUID,
        trainingMax: Double?,
        preferredIncrement: Double?
    ) -> ExerciseProfile? {
        let resolvedTrainingMax = trainingMax ?? existing?.trainingMax
        let resolvedPreferredIncrement = preferredIncrement ?? existing?.preferredIncrement

        guard resolvedTrainingMax != nil || resolvedPreferredIncrement != nil else {
            return nil
        }

        return ExerciseProfile(
            id: existing?.id ?? UUID(),
            exerciseID: exerciseID,
            trainingMax: resolvedTrainingMax,
            preferredIncrement: resolvedPreferredIncrement
        )
    }
}

enum TemplateExerciseSelectionResolver {
    struct ResolvedFields: Equatable {
        var trainingMaxText: String
        var preferredIncrementText: String
        var incrementText: String
    }

    static func resolvedFields(
        previousExerciseID: UUID?,
        newExerciseID: UUID,
        newExerciseName: String,
        currentTrainingMaxText: String,
        currentPreferredIncrementText: String,
        currentIncrementText: String,
        progressionKind: ProgressionRuleKind,
        existingProfile: ExerciseProfile?,
        defaultIncrement: Double,
        weightUnit: WeightUnit
    ) -> ResolvedFields {
        let isSwitchingExercises = previousExerciseID != nil && previousExerciseID != newExerciseID
        let recommendedTrainingMax =
            existingProfile?.trainingMax
            ?? ExerciseRecommendationDefaults.defaultTrainingMax(for: newExerciseName)
        let profileTrainingMaxText = WeightFormatter.displayString(recommendedTrainingMax, unit: weightUnit)
        let profilePreferredIncrementText = WeightFormatter.displayString(
            existingProfile?.preferredIncrement,
            unit: weightUnit
        )
        let defaultIncrementText = WeightFormatter.displayString(
            displayValue: weightUnit.displayValue(fromStoredPounds: defaultIncrement),
            unit: weightUnit
        )

        return ResolvedFields(
            trainingMaxText: resolvedText(
                currentTrainingMaxText,
                replacement: profileTrainingMaxText,
                shouldReplace: isSwitchingExercises
            ),
            preferredIncrementText: resolvedText(
                currentPreferredIncrementText,
                replacement: profilePreferredIncrementText,
                shouldReplace: isSwitchingExercises
            ),
            incrementText: progressionKind == .manual
                ? currentIncrementText
                : resolvedText(
                    currentIncrementText,
                    replacement: defaultIncrementText,
                    shouldReplace: isSwitchingExercises
                )
        )
    }

    private static func resolvedText(
        _ current: String,
        replacement: String,
        shouldReplace: Bool
    ) -> String {
        if shouldReplace || current.isEmpty {
            return replacement
        }

        return current
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
    @State private var draftExercises: [TemplateDraftExercise] = []
    @State private var showingExercisePickerForBlockID: UUID?

    private var weightUnit: WeightUnit {
        appStore.settingsStore.weightUnit
    }

    private var templateTitle: String {
        templateName.nonEmptyTrimmed ?? existingTemplate?.name ?? "Build a template"
    }

    private var hasInvalidExercises: Bool {
        draftExercises.contains(where: { $0.exerciseID == nil })
    }

    private var unresolvedExerciseCount: Int {
        draftExercises.filter { $0.exerciseID == nil }.count
    }

    private var heroMetrics: [AppHeroMetric] {
        [
            AppHeroMetric(
                id: "exercises",
                label: "Exercises",
                value: "\(draftExercises.count)",
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
                value: "\(unresolvedExerciseCount)",
                systemImage: "exclamationmark.circle"
            ),
            AppHeroMetric(
                id: "unit",
                label: "Weight Unit",
                value: weightUnit.symbol.uppercased(),
                systemImage: "scalemass"
            ),
        ]
    }

    private var heroSubtitle: String {
        draftExercises.isEmpty
            ? "Start with the basics first, then open advanced settings only for the exercises that need them."
            : "Keep the main prescription up front and tuck progression details into each exercise as needed."
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollViewReader { scrollProxy in
                    ScrollView {
                        LazyVStack(spacing: 18) {
                            AppHeroCard(
                                eyebrow: existingTemplate == nil ? "New Template" : "Edit Template",
                                title: templateTitle,
                                subtitle: heroSubtitle,
                                systemImage: "rectangle.stack.badge.plus",
                                metrics: heroMetrics,
                                tone: .plans
                            )

                            TemplateEditorOverviewSectionView(
                                templateName: $templateName,
                                templateNote: $templateNote
                            )

                            TemplateEditorScheduleSectionView(selectedWeekdays: $selectedWeekdays)

                            TemplateEditorExercisesSectionView(
                                draftExercises: $draftExercises,
                                weightUnit: weightUnit,
                                scrollProxy: scrollProxy,
                                showingExercisePickerForBlockID: $showingExercisePickerForBlockID
                            )
                        }
                    }
                    .scrollIndicators(.hidden)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }
            .navigationTitle(existingTemplate == nil ? "New Template" : "Edit Template")
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
                    .disabled(templateName.nonEmptyTrimmed == nil || hasInvalidExercises)
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
            draftExercises = []
            return
        }

        draftExercises = existingTemplate.exercises.map { block in
            let profile = appStore.plansStore.profile(for: block.exerciseID)
            let previewTargets =
                block.progressionRule.kind == .percentageWave
                ? ProgressionEngine.resolvedTargets(for: block, profile: profile)
                : block.targets
            let targetWeight = previewTargets.first?.targetWeight
            let repRange = previewTargets.first?.repRange ?? TemplateExerciseDefaults.repRange

            return TemplateDraftExercise(
                id: block.id,
                exerciseID: block.exerciseID,
                exerciseName: block.exerciseNameSnapshot,
                restSeconds: block.restSeconds,
                setCount: max(1, previewTargets.count),
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
                setKind: previewTargets.first?.setKind ?? .working
            )
        }
    }

    private func assignExercise(_ exercise: ExerciseCatalogItem, to blockID: UUID) {
        guard let index = draftExercises.firstIndex(where: { $0.id == blockID }) else {
            return
        }

        let previousExerciseID = draftExercises[index].exerciseID
        let existingProfile = appStore.plansStore.profile(for: exercise.id)
        let defaultIncrement = appStore.settingsStore.preferredIncrement(for: exercise.name)
        let resolvedFields = TemplateExerciseSelectionResolver.resolvedFields(
            previousExerciseID: previousExerciseID,
            newExerciseID: exercise.id,
            newExerciseName: exercise.name,
            currentTrainingMaxText: draftExercises[index].trainingMaxText,
            currentPreferredIncrementText: draftExercises[index].preferredIncrementText,
            currentIncrementText: draftExercises[index].incrementText,
            progressionKind: draftExercises[index].progressionKind,
            existingProfile: existingProfile,
            defaultIncrement: defaultIncrement,
            weightUnit: weightUnit
        )

        draftExercises[index].exerciseID = exercise.id
        draftExercises[index].exerciseName = exercise.name
        draftExercises[index].trainingMaxText = resolvedFields.trainingMaxText
        draftExercises[index].preferredIncrementText = resolvedFields.preferredIncrementText
        draftExercises[index].incrementText = resolvedFields.incrementText
    }

    private func saveTemplate() {
        let trimmedName = templateName.nonEmptyTrimmed ?? ""
        guard !trimmedName.isEmpty else {
            return
        }

        var savedProfiles: [ExerciseProfile] = []
        let templateExercises: [TemplateExercise] = draftExercises.compactMap { block in
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

            let profile = TemplateProfileResolver.mergedProfile(
                existing: appStore.plansStore.profile(for: exerciseID),
                exerciseID: exerciseID,
                trainingMax: profileTrainingMax,
                preferredIncrement: preferredIncrement
            )
            if let profile {
                savedProfiles.append(profile)
            }

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
                        trainingMax: profile?.trainingMax,
                        currentWeekIndex: existingTemplate?.exercises.first(where: { $0.id == block.id })?.progressionRule.percentageWave?
                            .currentWeekIndex ?? 0,
                        cycle: existingTemplate?.exercises.first(where: { $0.id == block.id })?.progressionRule.percentageWave?.cycle ?? 1,
                        cycleIncrement: increment ?? appStore.settingsStore.preferredIncrement(for: exerciseName)
                    )
                )
            }

            var exerciseBlock = TemplateExercise(
                id: block.id,
                exerciseID: exerciseID,
                exerciseNameSnapshot: exerciseName,
                restSeconds: block.restSeconds,
                supersetGroup: block.supersetGroup.nonEmptyTrimmed,
                progressionRule: progressionRule,
                targets: [],
                allowsAutoWarmups: block.allowsAutoWarmups
            )

            if block.progressionKind == .percentageWave {
                exerciseBlock.targets = ProgressionEngine.resolvedTargets(for: exerciseBlock, profile: profile)
            } else {
                exerciseBlock.targets = (0..<max(1, block.setCount)).map { _ in
                    SetTarget(
                        setKind: block.setKind,
                        targetWeight: targetWeight,
                        repRange: repRange,
                        restSeconds: block.restSeconds
                    )
                }
            }

            return exerciseBlock
        }

        let template = WorkoutTemplate(
            id: existingTemplate?.id ?? UUID(),
            name: trimmedName,
            note: templateNote,
            scheduledWeekdays: Weekday.allCases.filter { selectedWeekdays.contains($0) },
            exercises: templateExercises,
            lastStartedAt: existingTemplate?.lastStartedAt
        )
        onSave(template, savedProfiles)
        dismiss()
    }
}
