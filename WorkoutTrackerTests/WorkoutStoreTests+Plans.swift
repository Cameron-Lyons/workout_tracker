import SwiftData
import XCTest

@testable import WorkoutTracker

extension WorkoutStoreTests {
    func testTemplateEditorContextKeepsStableIdentityForNewTemplateSheet() {
        let context = TemplateEditorContext(planID: UUID(), template: nil)

        XCTAssertEqual(context.id, context.id)
    }

    @MainActor
    func testPresetSetupStateDoesNotPersistOnboardingCompletion() async {
        let store = makeStore()
        await store.hydrateIfNeeded()

        XCTAssertTrue(store.shouldShowOnboarding)

        store.isCompletingOnboarding = true

        XCTAssertFalse(store.settingsStore.hasCompletedOnboarding)
        XCTAssertTrue(store.shouldShowOnboarding)
    }

    @MainActor
    func testWavePresetPacksSeedDefaultTrainingMaxTargets() async throws {
        let store = makeStore()
        await store.hydrateIfNeeded()
        store.completeOnboarding(with: nil)

        store.plansStore.addPresetPack(.fiveThreeOne, settings: store.settingsStore)
        store.plansStore.addPresetPack(.boringButBig, settings: store.settingsStore)
        await store.refreshDerivedStores()

        for planName in [PresetPack.fiveThreeOne.displayName, PresetPack.boringButBig.displayName] {
            let plan = try XCTUnwrap(store.plansStore.plans.first(where: { $0.name == planName }))
            let template = try XCTUnwrap(plan.templates.first)
            let waveBlock = try XCTUnwrap(template.exercises.first)

            XCTAssertNotNil(waveBlock.progressionRule.percentageWave?.trainingMax)
            XCTAssertFalse(waveBlock.targets.isEmpty)
            XCTAssertNotNil(waveBlock.targets.first?.targetWeight)

            store.startSession(planID: plan.id, templateID: template.id)
            XCTAssertNotNil(store.sessionStore.activeDraft?.exercises.first?.sets.first?.target.targetWeight)
            store.discardActiveSession()
        }
    }

    @MainActor
    func testWavePresetPacksUseRecommendedFallbackWeightsAndAdjustableIncrements() throws {
        let settings = SettingsStore(defaults: testDefaults)
        settings.upperBodyIncrement = 5
        settings.lowerBodyIncrement = 12.5

        let plan = try XCTUnwrap(PresetPackBuilder.makePlans(for: .fiveThreeOne, settings: settings).first)

        let squatDay = try XCTUnwrap(plan.templates.first(where: { $0.name == "Squat Day" }))
        let benchDay = try XCTUnwrap(plan.templates.first(where: { $0.name == "Bench Day" }))
        let deadliftDay = try XCTUnwrap(plan.templates.first(where: { $0.name == "Deadlift Day" }))

        XCTAssertEqual(squatDay.exercises.first?.progressionRule.percentageWave?.trainingMax, 135)
        XCTAssertEqual(squatDay.exercises.first?.progressionRule.percentageWave?.cycleIncrement, 12.5)
        XCTAssertEqual(benchDay.exercises.first?.progressionRule.percentageWave?.trainingMax, 135)
        XCTAssertEqual(benchDay.exercises.first?.progressionRule.percentageWave?.cycleIncrement, 5)
        XCTAssertEqual(deadliftDay.exercises.first?.progressionRule.percentageWave?.trainingMax, 135)
        XCTAssertEqual(deadliftDay.exercises.first?.progressionRule.percentageWave?.cycleIncrement, 12.5)
    }

    @MainActor
    func testNewPresetPacksGenerateExpectedTemplateStructures() throws {
        let settings = SettingsStore(defaults: testDefaults)

        let phul = try XCTUnwrap(PresetPackBuilder.makePlans(for: .phul, settings: settings).first)
        XCTAssertEqual(phul.templates.map(\.name), ["Upper Power", "Lower Power", "Upper Hypertrophy", "Lower Hypertrophy"])

        let strongLifts = try XCTUnwrap(PresetPackBuilder.makePlans(for: .strongLiftsFiveByFive, settings: settings).first)
        XCTAssertEqual(strongLifts.templates.count, 2)
        XCTAssertTrue(TemplateReferenceSelection.isAlternatingPlan(strongLifts))
        XCTAssertEqual(strongLifts.templates.first?.exercises.map(\.targets.count), [5, 5, 5])
        XCTAssertEqual(strongLifts.templates.last?.exercises.last?.targets.count, 1)

        let greyskull = try XCTUnwrap(PresetPackBuilder.makePlans(for: .greyskullLP, settings: settings).first)
        XCTAssertEqual(greyskull.templates.count, 2)
        XCTAssertEqual(greyskull.templates.first?.exercises.first?.targets.last?.note, "AMRAP+")
        XCTAssertEqual(greyskull.templates.last?.exercises.last?.targets.last?.note, "AMRAP+")

        let madcow = try XCTUnwrap(PresetPackBuilder.makePlans(for: .madcowFiveByFive, settings: settings).first)
        XCTAssertEqual(madcow.templates.map(\.name), ["Volume Day", "Recovery Day", "Intensity Day"])
        XCTAssertEqual(madcow.templates.last?.exercises.first?.targets.map(\.note), [nil, nil, nil, "Top triple", "Backoff set"])

        let gzclp = try XCTUnwrap(PresetPackBuilder.makePlans(for: .gzclp, settings: settings).first)
        XCTAssertEqual(gzclp.templates.count, 4)
        XCTAssertFalse(TemplateReferenceSelection.isAlternatingPlan(gzclp))
        XCTAssertEqual(gzclp.templates.first?.exercises.count, 3)
    }

    @MainActor
    func testGreyskullPresetUsesAlternatingRotation() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let friday = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 13))
        )
        let completedAt = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 9))
        )

        let settings = SettingsStore(defaults: testDefaults)
        let plan = try XCTUnwrap(PresetPackBuilder.makePlans(for: .greyskullLP, settings: settings).first)
        let references = plan.templates.map { template in
            makeReference(plan: plan, template: template)
        }
        let sessions = [
            CompletedSession(
                planID: plan.id,
                templateID: try XCTUnwrap(plan.templates.first(where: { $0.name == "Workout A" })?.id),
                templateNameSnapshot: "Workout A",
                completedAt: completedAt,
                exercises: []
            )
        ]

        let pinned = try XCTUnwrap(
            TemplateReferenceSelection.pinnedTemplate(
                from: [plan],
                references: references,
                sessions: sessions,
                now: friday,
                calendar: calendar
            )
        )

        XCTAssertTrue(TemplateReferenceSelection.isAlternatingPlan(plan))
        XCTAssertEqual(pinned.templateName, "Workout B")
    }

    @MainActor
    func testStrongLiftsCarriesForwardSeededWorkingWeightsAfterCompletionAndRehydration() async throws {
        let container = WorkoutModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let store = makeStore(container: container)
        await store.hydrateIfNeeded()
        store.completeOnboarding(with: .strongLiftsFiveByFive)

        let pinnedTemplate = try XCTUnwrap(store.todayStore.pinnedTemplate)
        XCTAssertEqual(pinnedTemplate.templateName, "Workout A")

        store.startSession(planID: pinnedTemplate.planID, templateID: pinnedTemplate.templateID)
        let draft = try XCTUnwrap(store.sessionStore.activeDraft)
        let squatBlock = try XCTUnwrap(draft.exercises.first)
        let workingRows = squatBlock.sets.filter { $0.target.setKind == .working }
        XCTAssertEqual(workingRows.count, 5)
        XCTAssertTrue(workingRows.allSatisfy { $0.target.targetWeight == nil })

        for row in workingRows {
            store.adjustSetWeight(blockID: squatBlock.id, setID: row.id, delta: 135)
            store.toggleSetCompletion(blockID: squatBlock.id, setID: row.id)
        }

        XCTAssertTrue(store.finishActiveSession())
        store.flushPendingSessionPersistence()
        store.flushPendingPlanPersistence()

        let updatedPlan = try XCTUnwrap(store.plansStore.plan(for: pinnedTemplate.planID))
        let updatedTemplate = try XCTUnwrap(updatedPlan.templates.first(where: { $0.id == pinnedTemplate.templateID }))
        XCTAssertEqual(updatedTemplate.exercises.first?.targets.compactMap(\.targetWeight), Array(repeating: 140, count: 5))

        let rehydratedStore = makeStore(container: container)
        await rehydratedStore.hydrateIfNeeded()

        let rehydratedPlan = try XCTUnwrap(rehydratedStore.plansStore.plan(for: pinnedTemplate.planID))
        let rehydratedTemplate = try XCTUnwrap(rehydratedPlan.templates.first(where: { $0.id == pinnedTemplate.templateID }))
        XCTAssertEqual(rehydratedTemplate.exercises.first?.targets.compactMap(\.targetWeight), Array(repeating: 140, count: 5))
    }

    @MainActor
    func testHydrateIfNeededWithUITestingEmptyStoreResetsPersistedData() async throws {
        let container = WorkoutModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let seededStore = makeStore(container: container)
        await seededStore.hydrateIfNeeded()
        seededStore.completeOnboarding(with: .generalGym)

        let pinnedTemplate = try XCTUnwrap(seededStore.todayStore.pinnedTemplate)
        seededStore.startSession(planID: pinnedTemplate.planID, templateID: pinnedTemplate.templateID)
        let firstBlock = try XCTUnwrap(seededStore.sessionStore.activeDraft?.exercises.first)
        let firstRow = try XCTUnwrap(firstBlock.sets.first(where: { $0.target.setKind == .working }))
        seededStore.toggleSetCompletion(blockID: firstBlock.id, setID: firstRow.id)
        XCTAssertTrue(seededStore.finishActiveSession())

        seededStore.startSession(planID: pinnedTemplate.planID, templateID: pinnedTemplate.templateID)
        seededStore.flushPendingSessionPersistence()
        seededStore.flushPendingPlanPersistence()

        XCTAssertFalse(seededStore.plansStore.plans.isEmpty)
        XCTAssertNotNil(seededStore.sessionStore.activeDraft)
        XCTAssertEqual(seededStore.sessionStore.completedSessions.count, 1)
        XCTAssertFalse(seededStore.shouldShowOnboarding)

        let resetStore = makeStore(
            container: container,
            launchArguments: ["--uitesting-empty-store"]
        )
        await resetStore.hydrateIfNeeded()

        XCTAssertTrue(resetStore.shouldShowOnboarding)
        XCTAssertTrue(resetStore.plansStore.plans.isEmpty)
        XCTAssertNil(resetStore.sessionStore.activeDraft)
        XCTAssertTrue(resetStore.sessionStore.completedSessions.isEmpty)
        XCTAssertEqual(resetStore.plansStore.catalog.count, CatalogSeed.defaultCatalog().count)

        let rehydratedStore = makeStore(container: container)
        await rehydratedStore.hydrateIfNeeded()

        XCTAssertTrue(rehydratedStore.plansStore.plans.isEmpty)
        XCTAssertNil(rehydratedStore.sessionStore.activeDraft)
        XCTAssertTrue(rehydratedStore.sessionStore.completedSessions.isEmpty)
        XCTAssertTrue(rehydratedStore.shouldShowOnboarding)
    }

    @MainActor
    func testHydrateIfNeededWithUITestingFinishableSessionSeedCreatesReadyToFinishDraft() async throws {
        let store = makeStore(
            launchArguments: [
                "--uitesting-empty-store",
                "--uitesting-seed-finishable-session",
            ]
        )

        await store.hydrateIfNeeded()

        let draft = try XCTUnwrap(store.sessionStore.activeDraft)
        let firstBlock = try XCTUnwrap(draft.exercises.first)
        let firstWorkingRow = try XCTUnwrap(firstBlock.sets.first(where: { $0.target.setKind == .working }))

        XCTAssertFalse(store.shouldShowOnboarding)
        XCTAssertTrue(store.sessionStore.isPresentingSession)
        XCTAssertTrue(store.sessionStore.activeDraftProgress.canFinishWorkout)
        XCTAssertEqual(store.sessionStore.activeDraftProgress.completedSetCount, 1)
        XCTAssertTrue(firstWorkingRow.log.isCompleted)
        XCTAssertNil(store.sessionStore.activeDraft?.restTimerEndsAt)
        XCTAssertTrue(store.finishActiveSession())
        XCTAssertEqual(store.sessionStore.completedSessions.count, 1)
        XCTAssertEqual(store.progressStore.overview.totalSessions, 1)
    }

    @MainActor
    func testSessionMutationCommandsUndoAndPersistDraftChanges() async throws {
        let container = WorkoutModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let store = makeStore(container: container)
        await store.hydrateIfNeeded()
        store.completeOnboarding(with: nil)

        let plan = makeSingleTemplatePlan(
            name: "Bench Focus",
            templateName: "Bench Day",
            store: store,
            weight: 185
        )
        store.savePlan(plan)
        store.startSession(planID: plan.id, templateID: try XCTUnwrap(plan.templates.first?.id))

        store.sessionStore.dismissSessionPresentation()
        store.resumeActiveSession()
        XCTAssertTrue(store.sessionStore.isPresentingSession)

        let initialBlock = try XCTUnwrap(store.sessionStore.activeDraft?.exercises.first)
        let initialRow = try XCTUnwrap(initialBlock.sets.first(where: { $0.target.setKind == .working }))

        store.toggleSetCompletion(blockID: initialBlock.id, setID: initialRow.id)
        XCTAssertNotNil(store.sessionStore.activeDraft?.restTimerEndsAt)

        store.clearRestTimer()
        XCTAssertNil(store.sessionStore.activeDraft?.restTimerEndsAt)

        store.adjustSetWeight(blockID: initialBlock.id, setID: initialRow.id, delta: 5)
        store.adjustSetReps(blockID: initialBlock.id, setID: initialRow.id, delta: 1)
        store.addSet(to: initialBlock.id)
        store.copyLastSet(in: initialBlock.id)
        store.addExerciseToActiveSession(exerciseID: CatalogSeed.backSquat)

        let blockCountAfterCatalogExercise = try XCTUnwrap(store.sessionStore.activeDraft?.exercises.count)
        store.addCustomExerciseToActiveSession(name: "  Cable Row  ")
        XCTAssertEqual(store.sessionStore.activeDraft?.exercises.last?.exerciseNameSnapshot, "Cable Row")

        store.undoSessionMutation()

        let updatedDraft = try XCTUnwrap(store.sessionStore.activeDraft)
        let updatedPrimaryBlock = try XCTUnwrap(updatedDraft.exercises.first(where: { $0.id == initialBlock.id }))
        let updatedWorkingRows = updatedPrimaryBlock.sets.filter { $0.target.setKind == .working }

        XCTAssertEqual(updatedDraft.exercises.count, blockCountAfterCatalogExercise)
        XCTAssertFalse(updatedDraft.exercises.contains(where: { $0.exerciseNameSnapshot == "Cable Row" }))
        XCTAssertEqual(updatedPrimaryBlock.sets.count, 5)
        XCTAssertEqual(updatedWorkingRows.count, 3)
        XCTAssertEqual(updatedWorkingRows[0].log.weight, 190)
        XCTAssertEqual(updatedWorkingRows[0].log.reps, 6)
        XCTAssertEqual(updatedWorkingRows[1].log.weight, 190)
        XCTAssertEqual(updatedWorkingRows[1].log.reps, 6)
        XCTAssertEqual(updatedWorkingRows[2].log.weight, 190)
        XCTAssertEqual(updatedWorkingRows[2].log.reps, 6)
        XCTAssertEqual(updatedDraft.exercises.last?.exerciseID, CatalogSeed.backSquat)

        store.flushPendingSessionPersistence()
        store.flushPendingPlanPersistence()

        let rehydratedStore = makeStore(container: container)
        await rehydratedStore.hydrateIfNeeded()
        let persistedDraft = try XCTUnwrap(rehydratedStore.sessionStore.activeDraft)
        let persistedPrimaryBlock = try XCTUnwrap(persistedDraft.exercises.first(where: { $0.id == initialBlock.id }))
        let persistedWorkingRows = persistedPrimaryBlock.sets.filter { $0.target.setKind == .working }

        XCTAssertEqual(persistedDraft.exercises.count, blockCountAfterCatalogExercise)
        XCTAssertEqual(persistedPrimaryBlock.sets.count, 5)
        XCTAssertEqual(persistedWorkingRows.count, 3)
        XCTAssertEqual(persistedWorkingRows[0].log.weight, 190)
        XCTAssertEqual(persistedWorkingRows[0].log.reps, 6)
        XCTAssertTrue(rehydratedStore.plansStore.catalog.contains(where: { $0.name == "Cable Row" }))
    }

    @MainActor
    func testTemplateCrudAndProfilesPersistThroughFlushes() async throws {
        let container = WorkoutModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let store = makeStore(container: container)
        await store.hydrateIfNeeded()
        store.completeOnboarding(with: nil)

        let primaryPlan = store.makePlan(name: "Editable Plan")
        store.savePlan(primaryPlan)

        let template = WorkoutTemplate(
            name: "Upper Builder",
            exercises: [
                TemplateExercise(
                    exerciseID: CatalogSeed.benchPress,
                    exerciseNameSnapshot: store.plansStore.exerciseName(for: CatalogSeed.benchPress),
                    progressionRule: .manual,
                    targets: [
                        SetTarget(
                            setKind: .working,
                            targetWeight: 185,
                            repRange: RepRange(5, 5)
                        )
                    ]
                )
            ]
        )
        store.saveTemplate(planID: primaryPlan.id, template: template)

        let throwawayPlan = store.makePlan(name: "Throwaway Plan")
        store.savePlan(throwawayPlan)

        let profile = ExerciseProfile(
            exerciseID: CatalogSeed.benchPress,
            trainingMax: 235,
            preferredIncrement: 5
        )
        store.saveProfiles([profile])
        store.refreshTodayStore()

        XCTAssertEqual(store.plansStore.plan(for: primaryPlan.id)?.pinnedTemplateID, template.id)
        XCTAssertEqual(store.todayStore.pinnedTemplate?.templateID, template.id)
        XCTAssertEqual(store.plansStore.profile(for: CatalogSeed.benchPress)?.trainingMax, 235)

        store.deleteTemplate(planID: primaryPlan.id, templateID: template.id)
        XCTAssertTrue(store.plansStore.plan(for: primaryPlan.id)?.templates.isEmpty == true)

        store.deletePlan(throwawayPlan.id)
        XCTAssertNil(store.plansStore.plan(for: throwawayPlan.id))

        store.flushPendingPlanPersistence()

        let rehydratedStore = makeStore(container: container)
        await rehydratedStore.hydrateIfNeeded()

        XCTAssertTrue(rehydratedStore.plansStore.plan(for: primaryPlan.id)?.templates.isEmpty == true)
        XCTAssertNil(rehydratedStore.plansStore.plan(for: throwawayPlan.id))
        XCTAssertEqual(rehydratedStore.plansStore.profile(for: CatalogSeed.benchPress)?.trainingMax, 235)
        XCTAssertEqual(rehydratedStore.plansStore.profile(for: CatalogSeed.benchPress)?.preferredIncrement, 5)
    }

    @MainActor
    func testDeletingPinnedTemplateFallsBackToRemainingTemplateAndRefreshesToday() async throws {
        let store = makeStore()
        await store.hydrateIfNeeded()
        store.completeOnboarding(with: nil)

        let benchBlock = TemplateExercise(
            exerciseID: CatalogSeed.benchPress,
            exerciseNameSnapshot: store.plansStore.exerciseName(for: CatalogSeed.benchPress),
            restSeconds: 90,
            progressionRule: .manual,
            targets: [SetTarget(setKind: .working, targetWeight: 185, repRange: RepRange(5, 5))]
        )
        let pressBlock = TemplateExercise(
            exerciseID: CatalogSeed.overheadPress,
            exerciseNameSnapshot: store.plansStore.exerciseName(for: CatalogSeed.overheadPress),
            restSeconds: 90,
            progressionRule: .manual,
            targets: [SetTarget(setKind: .working, targetWeight: 115, repRange: RepRange(5, 5))]
        )

        let firstTemplate = WorkoutTemplate(name: "Bench Day", exercises: [benchBlock])
        let secondTemplate = WorkoutTemplate(name: "Press Day", exercises: [pressBlock])
        let plan = Plan(
            name: "Push Plan",
            pinnedTemplateID: firstTemplate.id,
            templates: [firstTemplate, secondTemplate]
        )

        store.savePlan(plan)
        store.refreshTodayStore()

        XCTAssertEqual(store.todayStore.pinnedTemplate?.templateID, firstTemplate.id)

        store.deleteTemplate(planID: plan.id, templateID: firstTemplate.id)

        let updatedPlan = try XCTUnwrap(store.plansStore.plan(for: plan.id))
        XCTAssertEqual(updatedPlan.pinnedTemplateID, secondTemplate.id)
        XCTAssertEqual(updatedPlan.templates.map(\.id), [secondTemplate.id])
        XCTAssertEqual(store.todayStore.pinnedTemplate?.templateID, secondTemplate.id)
        XCTAssertEqual(store.todayStore.pinnedTemplate?.templateName, "Press Day")
    }

    @MainActor
    func testBlankCustomExerciseNameIsIgnoredForActiveSession() async throws {
        let store = makeStore()
        await store.hydrateIfNeeded()
        store.completeOnboarding(with: nil)

        let plan = makeSingleTemplatePlan(
            name: "Bench Focus",
            templateName: "Bench Day",
            store: store,
            weight: 185
        )
        store.savePlan(plan)
        store.startSession(planID: plan.id, templateID: try XCTUnwrap(plan.templates.first?.id))

        let initialBlockCount = try XCTUnwrap(store.sessionStore.activeDraft?.exercises.count)
        let initialCatalogCount = store.plansStore.catalog.count

        store.addCustomExerciseToActiveSession(name: "   ")
        store.addCustomExerciseToActiveSession(name: "\n\t")

        XCTAssertEqual(store.sessionStore.activeDraft?.exercises.count, initialBlockCount)
        XCTAssertEqual(store.plansStore.catalog.count, initialCatalogCount)
        XCTAssertFalse(store.plansStore.catalog.contains(where: { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }))
    }

}
