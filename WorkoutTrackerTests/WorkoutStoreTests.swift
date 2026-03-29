import SwiftData
import XCTest

@testable import WorkoutTracker

final class WorkoutStoreTests: XCTestCase {
    private var defaultsSuiteName: String!
    private var testDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaultsSuiteName = "WorkoutStoreTests.\(name.replacingOccurrences(of: " ", with: "_")).\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: defaultsSuiteName)
        testDefaults.removePersistentDomain(forName: defaultsSuiteName)
        _ = WorkoutModelContainerFactory.consumeStartupIssue()
    }

    override func tearDown() {
        testDefaults?.removePersistentDomain(forName: defaultsSuiteName)
        testDefaults = nil
        defaultsSuiteName = nil
        _ = WorkoutModelContainerFactory.consumeStartupIssue()
        super.tearDown()
    }

    @MainActor
    func testSessionDraftPersistsAcrossStoreRehydration() async throws {
        let container = WorkoutModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let firstStore = makeStore(container: container)
        await firstStore.hydrateIfNeeded()
        firstStore.completeOnboarding(with: nil)

        let plan = makeSingleTemplatePlan(
            name: "Test Plan",
            templateName: "Upper 1",
            store: firstStore,
            weight: 185
        )
        firstStore.savePlan(plan)
        firstStore.startSession(planID: plan.id, templateID: try XCTUnwrap(plan.templates.first?.id))

        let rehydratedStore = makeStore(container: container)
        await rehydratedStore.hydrateIfNeeded()

        XCTAssertEqual(rehydratedStore.sessionStore.activeDraft?.templateNameSnapshot, "Upper 1")
        XCTAssertEqual(rehydratedStore.sessionStore.activeDraft?.blocks.count, 1)
    }

    @MainActor
    func testCompletedSessionHistoryLoadsOnDemandAfterStartupHydration() async throws {
        let container = WorkoutModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let seededStore = makeStore(container: container)
        await seededStore.hydrateIfNeeded()
        seededStore.completeOnboarding(with: nil)

        let plan = makeSingleTemplatePlan(
            name: "Test Plan",
            templateName: "Bench Day",
            store: seededStore,
            weight: 185
        )
        seededStore.savePlan(plan)
        seededStore.startSession(planID: plan.id, templateID: try XCTUnwrap(plan.templates.first?.id))

        let block = try XCTUnwrap(seededStore.sessionStore.activeDraft?.blocks.first)
        let workingRow = try XCTUnwrap(block.sets.first(where: { $0.target.setKind == .working }))
        seededStore.toggleSetCompletion(blockID: block.id, setID: workingRow.id)
        XCTAssertTrue(seededStore.finishActiveSession())
        seededStore.flushPendingSessionPersistence()

        let rehydratedStore = makeStore(container: container)
        await rehydratedStore.hydrateIfNeeded()

        XCTAssertFalse(rehydratedStore.sessionStore.hasLoadedCompletedSessionHistory)
        XCTAssertTrue(rehydratedStore.sessionStore.completedSessions.isEmpty)
        XCTAssertTrue(rehydratedStore.todayStore.recentSessions.isEmpty)
        XCTAssertEqual(rehydratedStore.progressStore.overview.totalSessions, 0)

        await rehydratedStore.hydrateCompletedSessionHistoryIfNeeded(priority: .userInitiated)

        XCTAssertTrue(rehydratedStore.sessionStore.hasLoadedCompletedSessionHistory)
        XCTAssertEqual(rehydratedStore.sessionStore.completedSessions.count, 1)
        XCTAssertEqual(rehydratedStore.todayStore.recentSessions.first?.templateNameSnapshot, "Bench Day")
        XCTAssertEqual(rehydratedStore.progressStore.overview.totalSessions, 1)
    }

    @MainActor
    func testStartupHydrationDefersFullPlanLibraryButKeepsReferencesUsable() async throws {
        let container = WorkoutModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let seededStore = makeStore(container: container)
        await seededStore.hydrateIfNeeded()
        seededStore.completeOnboarding(with: nil)

        let plan = makeSingleTemplatePlan(
            name: "Deferred Plan",
            templateName: "Upper 1",
            store: seededStore,
            weight: 185
        )
        seededStore.savePlan(plan)
        seededStore.flushPendingPlanPersistence()

        let rehydratedStore = makeStore(container: container)
        await rehydratedStore.hydrateIfNeeded()

        XCTAssertFalse(rehydratedStore.plansStore.hasLoadedPlanLibrary)
        XCTAssertEqual(rehydratedStore.plansStore.planCount, 1)
        XCTAssertEqual(rehydratedStore.plansStore.templateReferenceCount, 1)

        let loadedPlan = try XCTUnwrap(rehydratedStore.plansStore.plan(for: plan.id))
        let templateID = try XCTUnwrap(loadedPlan.templates.first?.id)
        rehydratedStore.startSession(planID: loadedPlan.id, templateID: templateID)

        XCTAssertEqual(rehydratedStore.sessionStore.activeDraft?.templateNameSnapshot, "Upper 1")
    }

    @MainActor
    func testEmptySessionDoesNotFinishOrPersist() async throws {
        let store = makeStore()
        await store.hydrateIfNeeded()
        store.completeOnboarding(with: nil)

        let plan = makeSingleTemplatePlan(
            name: "Test Plan",
            templateName: "Upper 1",
            store: store,
            weight: 185
        )
        store.savePlan(plan)
        let templateID = try XCTUnwrap(plan.templates.first?.id)

        store.startSession(planID: plan.id, templateID: templateID)

        XCTAssertFalse(store.finishActiveSession())
        XCTAssertNotNil(store.sessionStore.activeDraft)
        XCTAssertTrue(store.sessionStore.completedSessions.isEmpty)
    }

    @MainActor
    func testWarmupOnlySessionDoesNotFinishOrPersist() async throws {
        let store = makeStore()
        await store.hydrateIfNeeded()
        store.completeOnboarding(with: nil)

        let plan = makeSingleTemplatePlan(
            name: "Test Plan",
            templateName: "Upper 1",
            store: store,
            weight: 185
        )
        store.savePlan(plan)
        let templateID = try XCTUnwrap(plan.templates.first?.id)

        store.startSession(planID: plan.id, templateID: templateID)

        let block = try XCTUnwrap(store.sessionStore.activeDraft?.blocks.first)
        let warmupRow = try XCTUnwrap(block.sets.first(where: { $0.target.setKind == .warmup }))
        store.toggleSetCompletion(blockID: block.id, setID: warmupRow.id)

        XCTAssertFalse(store.finishActiveSession())
        XCTAssertNotNil(store.sessionStore.activeDraft)
        XCTAssertTrue(store.sessionStore.completedSessions.isEmpty)
    }

    @MainActor
    func testExerciseRenamePreservesAnalyticsContinuityAndSnapshots() async throws {
        let store = makeStore()
        await store.hydrateIfNeeded()
        store.completeOnboarding(with: nil)

        let plan = makeSingleTemplatePlan(
            name: "Pressing",
            templateName: "Bench Day",
            store: store,
            weight: 185
        )
        store.savePlan(plan)
        store.startSession(planID: plan.id, templateID: try XCTUnwrap(plan.templates.first?.id))

        let draft = try XCTUnwrap(store.sessionStore.activeDraft)
        let block = try XCTUnwrap(draft.blocks.first)
        let row = try XCTUnwrap(block.sets.first(where: { $0.target.setKind == .working }))

        store.toggleSetCompletion(blockID: block.id, setID: row.id)
        store.finishActiveSession()

        store.updateCatalogItem(
            itemID: CatalogSeed.benchPress,
            name: "Competition Bench Press",
            aliases: ["Barbell Bench"],
            category: .chest
        )
        await store.refreshDerivedStores()

        let summary = try XCTUnwrap(
            store.progressStore.exerciseSummaries.first(where: { $0.exerciseID == CatalogSeed.benchPress })
        )

        XCTAssertEqual(summary.displayName, "Competition Bench Press")
        XCTAssertEqual(summary.pointCount, 1)
        XCTAssertEqual(store.sessionStore.completedSessions.first?.blocks.first?.exerciseNameSnapshot, "Bench Press")
        XCTAssertTrue(store.plansStore.exerciseItem(for: CatalogSeed.benchPress)?.aliases.contains("Bench Press") == true)
    }

    @MainActor
    func testExerciseRenameUpdatesTemplateAndActiveDraftSnapshots() async throws {
        let store = makeStore()
        await store.hydrateIfNeeded()
        store.completeOnboarding(with: nil)

        let plan = makeSingleTemplatePlan(
            name: "Pressing",
            templateName: "Bench Day",
            store: store,
            weight: 185
        )
        store.savePlan(plan)
        let templateID = try XCTUnwrap(plan.templates.first?.id)

        store.startSession(planID: plan.id, templateID: templateID)
        store.updateCatalogItem(
            itemID: CatalogSeed.benchPress,
            name: "Competition Bench Press",
            aliases: ["Barbell Bench"],
            category: .chest
        )

        let updatedPlan = try XCTUnwrap(store.plansStore.plan(for: plan.id))

        XCTAssertEqual(updatedPlan.templates.first?.blocks.first?.exerciseNameSnapshot, "Competition Bench Press")
        XCTAssertEqual(store.sessionStore.activeDraft?.blocks.first?.exerciseNameSnapshot, "Competition Bench Press")
    }

    @MainActor
    func testRefreshDerivedStoresSkipsNoOpForegroundPass() async throws {
        let store = makeStore()
        await store.hydrateIfNeeded()
        store.plansStore.addPresetPack(.generalGym, settings: store.settingsStore)

        let firstRefresh = await store.refreshDerivedStores()
        let secondRefresh = await store.refreshDerivedStores()

        XCTAssertTrue(firstRefresh)
        XCTAssertFalse(secondRefresh)
    }

    @MainActor
    func testStartingAnotherTemplateResumesCurrentDraftUntilUserReplacesIt() async throws {
        let store = makeStore()
        await store.hydrateIfNeeded()
        store.completeOnboarding(with: nil)

        let firstPlan = makeSingleTemplatePlan(
            name: "Plan A",
            templateName: "Bench Day",
            store: store,
            weight: 185
        )
        let secondPlan = makeSingleTemplatePlan(
            name: "Plan B",
            templateName: "Press Day",
            store: store,
            weight: 135
        )
        store.savePlan(firstPlan)
        store.savePlan(secondPlan)

        let firstTemplateID = try XCTUnwrap(firstPlan.templates.first?.id)
        let secondTemplateID = try XCTUnwrap(secondPlan.templates.first?.id)

        store.startSession(planID: firstPlan.id, templateID: firstTemplateID)
        store.updateActiveSessionNotes("Keep me")
        store.startSession(planID: secondPlan.id, templateID: secondTemplateID)

        XCTAssertEqual(store.sessionStore.activeDraft?.templateID, firstTemplateID)
        XCTAssertEqual(store.sessionStore.activeDraft?.templateNameSnapshot, "Bench Day")
        XCTAssertEqual(store.sessionStore.activeDraft?.notes, "Keep me")
        XCTAssertNil(store.plansStore.plan(for: secondPlan.id)?.templates.first?.lastStartedAt)

        store.replaceActiveSessionAndStart(planID: secondPlan.id, templateID: secondTemplateID)

        XCTAssertEqual(store.sessionStore.activeDraft?.templateID, secondTemplateID)
        XCTAssertEqual(store.sessionStore.activeDraft?.templateNameSnapshot, "Press Day")
        XCTAssertEqual(store.sessionStore.activeDraft?.notes, "")
        XCTAssertNotNil(store.plansStore.plan(for: secondPlan.id)?.templates.first?.lastStartedAt)
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
            let waveBlock = try XCTUnwrap(template.blocks.first)

            XCTAssertNotNil(waveBlock.progressionRule.percentageWave?.trainingMax)
            XCTAssertFalse(waveBlock.targets.isEmpty)
            XCTAssertNotNil(waveBlock.targets.first?.targetWeight)

            store.startSession(planID: plan.id, templateID: template.id)
            XCTAssertNotNil(store.sessionStore.activeDraft?.blocks.first?.sets.first?.target.targetWeight)
            store.discardActiveSession()
        }
    }

    @MainActor
    func testNewPresetPacksGenerateExpectedTemplateStructures() throws {
        let settings = SettingsStore(defaults: testDefaults)

        let phul = try XCTUnwrap(PresetPackBuilder.makePlans(for: .phul, settings: settings).first)
        XCTAssertEqual(phul.templates.map(\.name), ["Upper Power", "Lower Power", "Upper Hypertrophy", "Lower Hypertrophy"])

        let strongLifts = try XCTUnwrap(PresetPackBuilder.makePlans(for: .strongLiftsFiveByFive, settings: settings).first)
        XCTAssertEqual(strongLifts.templates.count, 2)
        XCTAssertTrue(TemplateReferenceSelection.isAlternatingPlan(strongLifts))
        XCTAssertEqual(strongLifts.templates.first?.blocks.map(\.targets.count), [5, 5, 5])
        XCTAssertEqual(strongLifts.templates.last?.blocks.last?.targets.count, 1)

        let greyskull = try XCTUnwrap(PresetPackBuilder.makePlans(for: .greyskullLP, settings: settings).first)
        XCTAssertEqual(greyskull.templates.count, 2)
        XCTAssertEqual(greyskull.templates.first?.blocks.first?.targets.last?.note, "AMRAP+")
        XCTAssertEqual(greyskull.templates.last?.blocks.last?.targets.last?.note, "AMRAP+")

        let madcow = try XCTUnwrap(PresetPackBuilder.makePlans(for: .madcowFiveByFive, settings: settings).first)
        XCTAssertEqual(madcow.templates.map(\.name), ["Volume Day", "Recovery Day", "Intensity Day"])
        XCTAssertEqual(madcow.templates.last?.blocks.first?.targets.map(\.note), [nil, nil, nil, "Top triple", "Backoff set"])

        let gzclp = try XCTUnwrap(PresetPackBuilder.makePlans(for: .gzclp, settings: settings).first)
        XCTAssertEqual(gzclp.templates.count, 4)
        XCTAssertFalse(TemplateReferenceSelection.isAlternatingPlan(gzclp))
        XCTAssertEqual(gzclp.templates.first?.blocks.map(\.blockNote), ["T1 Main Lift", "T2 Secondary Lift", "T3 Accessories"])
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
                startedAt: completedAt.addingTimeInterval(-5_400),
                completedAt: completedAt,
                blocks: []
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
        let squatBlock = try XCTUnwrap(draft.blocks.first)
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
        XCTAssertEqual(updatedTemplate.blocks.first?.targets.compactMap(\.targetWeight), Array(repeating: 140, count: 5))

        let rehydratedStore = makeStore(container: container)
        await rehydratedStore.hydrateIfNeeded()

        let rehydratedPlan = try XCTUnwrap(rehydratedStore.plansStore.plan(for: pinnedTemplate.planID))
        let rehydratedTemplate = try XCTUnwrap(rehydratedPlan.templates.first(where: { $0.id == pinnedTemplate.templateID }))
        XCTAssertEqual(rehydratedTemplate.blocks.first?.targets.compactMap(\.targetWeight), Array(repeating: 140, count: 5))
    }

    @MainActor
    func testHydrateIfNeededWithUITestingEmptyStoreResetsPersistedData() async throws {
        let container = WorkoutModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let seededStore = makeStore(container: container)
        await seededStore.hydrateIfNeeded()
        seededStore.completeOnboarding(with: .generalGym)

        let pinnedTemplate = try XCTUnwrap(seededStore.todayStore.pinnedTemplate)
        seededStore.startSession(planID: pinnedTemplate.planID, templateID: pinnedTemplate.templateID)
        let firstBlock = try XCTUnwrap(seededStore.sessionStore.activeDraft?.blocks.first)
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
        let firstBlock = try XCTUnwrap(draft.blocks.first)
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

        let initialBlock = try XCTUnwrap(store.sessionStore.activeDraft?.blocks.first)
        let initialRow = try XCTUnwrap(initialBlock.sets.first(where: { $0.target.setKind == .working }))

        store.toggleSetCompletion(blockID: initialBlock.id, setID: initialRow.id)
        XCTAssertNotNil(store.sessionStore.activeDraft?.restTimerEndsAt)

        store.clearRestTimer()
        XCTAssertNil(store.sessionStore.activeDraft?.restTimerEndsAt)

        store.adjustSetWeight(blockID: initialBlock.id, setID: initialRow.id, delta: 5)
        store.adjustSetReps(blockID: initialBlock.id, setID: initialRow.id, delta: 1)
        store.addSet(to: initialBlock.id)
        store.copyLastSet(in: initialBlock.id)
        store.updateActiveBlockNotes(blockID: initialBlock.id, note: "Heavy top set")
        store.addExerciseToActiveSession(exerciseID: CatalogSeed.backSquat)

        let blockCountAfterCatalogExercise = try XCTUnwrap(store.sessionStore.activeDraft?.blocks.count)
        store.addCustomExerciseToActiveSession(name: "  Cable Row  ")
        XCTAssertEqual(store.sessionStore.activeDraft?.blocks.last?.exerciseNameSnapshot, "Cable Row")

        store.undoSessionMutation()

        let updatedDraft = try XCTUnwrap(store.sessionStore.activeDraft)
        let updatedPrimaryBlock = try XCTUnwrap(updatedDraft.blocks.first(where: { $0.id == initialBlock.id }))
        let updatedWorkingRows = updatedPrimaryBlock.sets.filter { $0.target.setKind == .working }

        XCTAssertEqual(updatedDraft.blocks.count, blockCountAfterCatalogExercise)
        XCTAssertFalse(updatedDraft.blocks.contains(where: { $0.exerciseNameSnapshot == "Cable Row" }))
        XCTAssertEqual(updatedPrimaryBlock.blockNote, "Heavy top set")
        XCTAssertEqual(updatedPrimaryBlock.sets.count, 5)
        XCTAssertEqual(updatedWorkingRows.count, 3)
        XCTAssertEqual(updatedWorkingRows[0].log.weight, 190)
        XCTAssertEqual(updatedWorkingRows[0].log.reps, 6)
        XCTAssertEqual(updatedWorkingRows[1].log.weight, 190)
        XCTAssertEqual(updatedWorkingRows[1].log.reps, 6)
        XCTAssertEqual(updatedWorkingRows[2].log.weight, 190)
        XCTAssertEqual(updatedWorkingRows[2].log.reps, 6)
        XCTAssertEqual(updatedDraft.blocks.last?.exerciseID, CatalogSeed.backSquat)

        store.flushPendingSessionPersistence()
        store.flushPendingPlanPersistence()

        let rehydratedStore = makeStore(container: container)
        await rehydratedStore.hydrateIfNeeded()
        let persistedDraft = try XCTUnwrap(rehydratedStore.sessionStore.activeDraft)
        let persistedPrimaryBlock = try XCTUnwrap(persistedDraft.blocks.first(where: { $0.id == initialBlock.id }))
        let persistedWorkingRows = persistedPrimaryBlock.sets.filter { $0.target.setKind == .working }

        XCTAssertEqual(persistedDraft.blocks.count, blockCountAfterCatalogExercise)
        XCTAssertEqual(persistedPrimaryBlock.blockNote, "Heavy top set")
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
            blocks: [
                ExerciseBlock(
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

        let benchBlock = ExerciseBlock(
            exerciseID: CatalogSeed.benchPress,
            exerciseNameSnapshot: store.plansStore.exerciseName(for: CatalogSeed.benchPress),
            restSeconds: 90,
            progressionRule: .manual,
            targets: [SetTarget(setKind: .working, targetWeight: 185, repRange: RepRange(5, 5))]
        )
        let pressBlock = ExerciseBlock(
            exerciseID: CatalogSeed.overheadPress,
            exerciseNameSnapshot: store.plansStore.exerciseName(for: CatalogSeed.overheadPress),
            restSeconds: 90,
            progressionRule: .manual,
            targets: [SetTarget(setKind: .working, targetWeight: 115, repRange: RepRange(5, 5))]
        )

        let firstTemplate = WorkoutTemplate(name: "Bench Day", blocks: [benchBlock])
        let secondTemplate = WorkoutTemplate(name: "Press Day", blocks: [pressBlock])
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

        let initialBlockCount = try XCTUnwrap(store.sessionStore.activeDraft?.blocks.count)
        let initialCatalogCount = store.plansStore.catalog.count

        store.addCustomExerciseToActiveSession(name: "   ")
        store.addCustomExerciseToActiveSession(name: "\n\t")

        XCTAssertEqual(store.sessionStore.activeDraft?.blocks.count, initialBlockCount)
        XCTAssertEqual(store.plansStore.catalog.count, initialCatalogCount)
        XCTAssertFalse(store.plansStore.catalog.contains(where: { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }))
    }

    func testAnalyticsSummariesHandleWarmupsAndVolume() {
        let analytics = AnalyticsRepository()
        let catalog = [
            CatalogSeed.backSquat: ExerciseCatalogItem(id: CatalogSeed.backSquat, name: "Back Squat", category: .legs)
        ]
        let sessions = [
            makeCompletedSession(
                date: .now.addingTimeInterval(-86_400),
                exerciseID: CatalogSeed.backSquat,
                exerciseName: "Back Squat",
                rows: [
                    makeRow(kind: .warmup, weight: 95, reps: 5),
                    makeRow(kind: .working, weight: 225, reps: 5),
                ]
            ),
            makeCompletedSession(
                date: .now,
                exerciseID: CatalogSeed.backSquat,
                exerciseName: "Back Squat",
                rows: [
                    makeRow(kind: .warmup, weight: 115, reps: 5),
                    makeRow(kind: .working, weight: 235, reps: 5),
                ]
            ),
        ]

        let snapshot = analytics.makeSessionAnalyticsSnapshot(sessions: sessions, catalogByID: catalog)
        let overview = snapshot.overview
        let summaries = snapshot.exerciseSummaries
        let records = snapshot.personalRecords

        XCTAssertEqual(overview.totalSessions, 2)
        XCTAssertGreaterThan(overview.totalVolume, 0)
        XCTAssertEqual(summaries.first?.pointCount, 2)
        XCTAssertGreaterThan(summaries.first?.totalVolume ?? 0, 0)
        XCTAssertEqual(records.last?.weight, 235)
    }

    func testAnalyticsIgnoreIncompleteRowsForProgressAndVolume() {
        let analytics = AnalyticsRepository()
        let session = makeCompletedSession(
            date: .now,
            exerciseID: CatalogSeed.benchPress,
            exerciseName: "Bench Press",
            rows: [
                makeRow(kind: .working, weight: 225, reps: 5),
                makeRow(kind: .working, weight: 315, reps: 1, completedAt: nil),
            ]
        )

        let records = analytics.finishSummary(
            for: session,
            previousBestByExerciseID: [:],
            catalogByID: [:]
        ).personalRecords
        let payload = analytics.sessionExercisePayloads(from: session).first

        XCTAssertEqual(analytics.volume(for: session), 1_125)
        XCTAssertEqual(records.last?.weight, 225)
        XCTAssertEqual(payload?.topWeight, 225)
    }

    func testAnalyticsPayloadPrefersHigherRepSetWhenTopWeightTies() throws {
        let analytics = AnalyticsRepository()
        let session = makeCompletedSession(
            date: .now,
            exerciseID: CatalogSeed.benchPress,
            exerciseName: "Bench Press",
            rows: [
                makeRow(kind: .working, weight: 225, reps: 5),
                makeRow(kind: .working, weight: 225, reps: 8),
            ]
        )

        let payload = try XCTUnwrap(analytics.sessionExercisePayloads(from: session).first)

        XCTAssertEqual(payload.topWeight, 225)
        XCTAssertEqual(payload.estimatedOneRepMax, analytics.estimateOneRepMax(weight: 225, reps: 8))
    }

    func testAnalyticsCurrentPRPrefersHigherEstimatedOneRepMaxOverHeavierSingle() throws {
        let analytics = AnalyticsRepository()
        let catalog = [
            CatalogSeed.benchPress: ExerciseCatalogItem(id: CatalogSeed.benchPress, name: "Bench Press", category: .chest)
        ]
        let sessions = [
            makeCompletedSession(
                date: .now.addingTimeInterval(-86_400),
                exerciseID: CatalogSeed.benchPress,
                exerciseName: "Bench Press",
                rows: [makeRow(kind: .working, weight: 225, reps: 1)]
            ),
            makeCompletedSession(
                date: .now,
                exerciseID: CatalogSeed.benchPress,
                exerciseName: "Bench Press",
                rows: [makeRow(kind: .working, weight: 215, reps: 5)]
            ),
        ]

        let snapshot = analytics.makeSessionAnalyticsSnapshot(sessions: sessions, catalogByID: catalog)
        let summary = try XCTUnwrap(snapshot.exerciseSummaries.first)
        let currentPR = try XCTUnwrap(summary.currentPR)

        XCTAssertEqual(currentPR.weight, 215)
        XCTAssertEqual(currentPR.reps, 5)
        XCTAssertGreaterThan(currentPR.estimatedOneRepMax, 225)
    }

    func testAnalyticsReserveRecordsAndProgressPointsForWorkingSets() {
        let analytics = AnalyticsRepository()
        let session = makeCompletedSession(
            date: .now,
            exerciseID: CatalogSeed.backSquat,
            exerciseName: "Back Squat",
            rows: [
                makeRow(kind: .warmup, weight: 315, reps: 1),
                makeRow(kind: .dropSet, weight: 185, reps: 12),
                makeRow(kind: .working, weight: 225, reps: 5),
            ]
        )

        let summary = analytics.finishSummary(
            for: session,
            previousBestByExerciseID: [:],
            catalogByID: [:]
        )
        let payload = analytics.sessionExercisePayloads(from: session).first

        XCTAssertEqual(summary.personalRecords.last?.weight, 225)
        XCTAssertEqual(payload?.topWeight, 225)
        XCTAssertEqual(summary.totalVolume, 3_660)
    }

    func testAnalyticsAggregateDuplicateExerciseBlocksIntoSingleProgressPointPerSession() throws {
        let analytics = AnalyticsRepository()
        let completedAt = Date(timeIntervalSince1970: 1_741_478_400)
        let session = CompletedSession(
            planID: UUID(),
            templateID: UUID(),
            templateNameSnapshot: "BBB Bench Day",
            startedAt: completedAt.addingTimeInterval(-3_600),
            completedAt: completedAt,
            blocks: [
                CompletedSessionBlock(
                    exerciseID: CatalogSeed.benchPress,
                    exerciseNameSnapshot: "Bench Press",
                    blockNote: "Main work",
                    restSeconds: 180,
                    supersetGroup: nil,
                    progressionRule: .manual,
                    sets: [makeRow(kind: .working, weight: 225, reps: 5)]
                ),
                CompletedSessionBlock(
                    exerciseID: CatalogSeed.benchPress,
                    exerciseNameSnapshot: "Bench Press",
                    blockNote: "Supplemental",
                    restSeconds: 120,
                    supersetGroup: nil,
                    progressionRule: .manual,
                    sets: [makeRow(kind: .working, weight: 185, reps: 10)]
                ),
            ]
        )

        let payloads = analytics.sessionExercisePayloads(from: session)
        let payload = try XCTUnwrap(payloads.first)
        let snapshot = analytics.makeSessionAnalyticsSnapshot(
            sessions: [session],
            catalogByID: [
                CatalogSeed.benchPress: ExerciseCatalogItem(
                    id: CatalogSeed.benchPress,
                    name: "Bench Press",
                    category: .chest
                )
            ],
            now: completedAt
        )
        let summary = try XCTUnwrap(
            snapshot.exerciseSummaries.first(where: { $0.exerciseID == CatalogSeed.benchPress })
        )

        XCTAssertEqual(payloads.count, 1)
        XCTAssertEqual(payload.topWeight, 225)
        XCTAssertEqual(payload.volume, 2_975)
        XCTAssertEqual(summary.pointCount, 1)
        XCTAssertEqual(summary.points.count, 1)
        XCTAssertEqual(summary.points.first?.topWeight, 225)
        XCTAssertEqual(summary.points.first?.volume, 2_975)
        XCTAssertEqual(summary.totalVolume, 2_975)
    }

    func testAnalyticsKeepsOnlyBestSessionPRPerExerciseAcrossDuplicateBlocks() throws {
        let analytics = AnalyticsRepository()
        let completedAt = Date(timeIntervalSince1970: 1_741_478_400)
        let session = CompletedSession(
            planID: UUID(),
            templateID: UUID(),
            templateNameSnapshot: "Bench Focus",
            startedAt: completedAt.addingTimeInterval(-3_600),
            completedAt: completedAt,
            blocks: [
                CompletedSessionBlock(
                    exerciseID: CatalogSeed.benchPress,
                    exerciseNameSnapshot: "Bench Press",
                    blockNote: "Main work",
                    restSeconds: 180,
                    supersetGroup: nil,
                    progressionRule: .manual,
                    sets: [makeRow(kind: .working, weight: 225, reps: 5)]
                ),
                CompletedSessionBlock(
                    exerciseID: CatalogSeed.benchPress,
                    exerciseNameSnapshot: "Bench Press",
                    blockNote: "Top set",
                    restSeconds: 180,
                    supersetGroup: nil,
                    progressionRule: .manual,
                    sets: [makeRow(kind: .working, weight: 230, reps: 5)]
                ),
            ]
        )

        let finishSummary = analytics.finishSummary(
            for: session,
            previousBestByExerciseID: [:],
            catalogByID: [:]
        )
        let snapshot = analytics.makeSessionAnalyticsSnapshot(
            sessions: [session],
            catalogByID: [
                CatalogSeed.benchPress: ExerciseCatalogItem(
                    id: CatalogSeed.benchPress,
                    name: "Bench Press",
                    category: .chest
                )
            ],
            now: completedAt
        )

        XCTAssertEqual(finishSummary.personalRecords.count, 1)
        XCTAssertEqual(finishSummary.personalRecords.first?.weight, 230)
        XCTAssertEqual(snapshot.personalRecords.count, 1)
        XCTAssertEqual(snapshot.personalRecords.first?.weight, 230)
    }

    func testDerivedStoreSnapshotMatchesStandaloneTodayAndProgressSnapshots() {
        let analytics = AnalyticsRepository()
        let now = Date(timeIntervalSince1970: 1_741_478_400)
        let benchTemplateID = UUID()
        let squatTemplateID = UUID()
        let plan = Plan(
            name: "Strength",
            pinnedTemplateID: benchTemplateID,
            templates: [
                WorkoutTemplate(
                    id: benchTemplateID,
                    name: "Bench Day",
                    scheduledWeekdays: [.monday],
                    blocks: [],
                    lastStartedAt: now.addingTimeInterval(-86_400)
                ),
                WorkoutTemplate(
                    id: squatTemplateID,
                    name: "Squat Day",
                    scheduledWeekdays: [.thursday],
                    blocks: [],
                    lastStartedAt: now.addingTimeInterval(-172_800)
                ),
            ]
        )
        let references = [
            TemplateReference(
                planID: plan.id,
                planName: plan.name,
                templateID: benchTemplateID,
                templateName: "Bench Day",
                scheduledWeekdays: [.monday],
                lastStartedAt: now.addingTimeInterval(-86_400)
            ),
            TemplateReference(
                planID: plan.id,
                planName: plan.name,
                templateID: squatTemplateID,
                templateName: "Squat Day",
                scheduledWeekdays: [.thursday],
                lastStartedAt: now.addingTimeInterval(-172_800)
            ),
        ]
        let sessions = [
            CompletedSession(
                planID: plan.id,
                templateID: benchTemplateID,
                templateNameSnapshot: "Bench Day",
                startedAt: now.addingTimeInterval(-180_000),
                completedAt: now.addingTimeInterval(-172_800),
                blocks: [
                    CompletedSessionBlock(
                        exerciseID: CatalogSeed.benchPress,
                        exerciseNameSnapshot: "Bench Press",
                        blockNote: "",
                        restSeconds: 90,
                        supersetGroup: nil,
                        progressionRule: .manual,
                        sets: [
                            makeRow(kind: .warmup, weight: 95, reps: 5),
                            makeRow(kind: .working, weight: 185, reps: 5),
                        ]
                    )
                ]
            ),
            CompletedSession(
                planID: plan.id,
                templateID: squatTemplateID,
                templateNameSnapshot: "Squat Day",
                startedAt: now.addingTimeInterval(-93_600),
                completedAt: now.addingTimeInterval(-86_400),
                blocks: [
                    CompletedSessionBlock(
                        exerciseID: CatalogSeed.backSquat,
                        exerciseNameSnapshot: "Back Squat",
                        blockNote: "",
                        restSeconds: 120,
                        supersetGroup: nil,
                        progressionRule: .manual,
                        sets: [
                            makeRow(kind: .working, weight: 225, reps: 5)
                        ]
                    )
                ]
            ),
        ]
        let catalog = [
            CatalogSeed.benchPress: ExerciseCatalogItem(id: CatalogSeed.benchPress, name: "Bench Press", category: .chest),
            CatalogSeed.backSquat: ExerciseCatalogItem(id: CatalogSeed.backSquat, name: "Back Squat", category: .legs),
        ]

        let sessionAnalytics = analytics.makeSessionAnalyticsSnapshot(
            sessions: sessions,
            catalogByID: catalog,
            now: now
        )
        let combined = analytics.makeDerivedStoreSnapshot(
            planSummaries: [PlanSummary(plan: plan)],
            references: references,
            sessions: sessions,
            sessionAnalytics: sessionAnalytics,
            selectedExerciseID: CatalogSeed.backSquat,
            now: now
        )
        let today = analytics.makeTodaySnapshot(
            planSummaries: [PlanSummary(plan: plan)],
            references: references,
            sessions: sessions,
            sessionAnalytics: sessionAnalytics,
            now: now
        )
        let progress = analytics.makeProgressSnapshot(
            sessionAnalytics: sessionAnalytics,
            selectedExerciseID: CatalogSeed.backSquat,
        )

        let recordSignature: (PersonalRecord) -> String = {
            [
                $0.sessionID.uuidString,
                $0.exerciseID.uuidString,
                $0.displayName,
                String($0.weight),
                String($0.reps),
                String($0.estimatedOneRepMax),
                String($0.achievedAt.timeIntervalSinceReferenceDate),
            ].joined(separator: "|")
        }
        let pointSignature: (ProgressPoint) -> String = {
            [
                $0.sessionID.uuidString,
                String($0.date.timeIntervalSinceReferenceDate),
                String($0.topWeight),
                String($0.estimatedOneRepMax),
                String($0.volume),
            ].joined(separator: "|")
        }
        let summarySignature: (ExerciseAnalyticsSummary) -> String = {
            [
                $0.exerciseID.uuidString,
                $0.displayName,
                String($0.pointCount),
                String($0.totalVolume),
                $0.currentPR.map(recordSignature) ?? "nil",
                $0.points.map(pointSignature).joined(separator: ","),
            ].joined(separator: "||")
        }

        XCTAssertEqual(combined.today.pinnedTemplate, today.pinnedTemplate)
        XCTAssertEqual(combined.today.quickStartTemplates, today.quickStartTemplates)
        XCTAssertEqual(combined.today.recentSessions, today.recentSessions)
        XCTAssertEqual(combined.today.recentPersonalRecords.map(recordSignature), today.recentPersonalRecords.map(recordSignature))

        XCTAssertEqual(combined.progress.overview, progress.overview)
        XCTAssertEqual(combined.progress.selectedExerciseID, progress.selectedExerciseID)
        XCTAssertEqual(combined.progress.personalRecords.map(recordSignature), progress.personalRecords.map(recordSignature))
        XCTAssertEqual(combined.progress.exerciseSummaries.map(summarySignature), progress.exerciseSummaries.map(summarySignature))
    }

    func testPinnedTemplateUsesStartingStrengthRotationInsteadOfStaticWeekdaySchedule() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let monday = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 9))
        )
        let completedAt = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 6))
        )

        let plan = makeStartingStrengthPlan()
        let references = plan.templates.map { template in
            makeReference(plan: plan, template: template)
        }
        let sessions = [
            CompletedSession(
                planID: plan.id,
                templateID: try XCTUnwrap(plan.templates.first(where: { $0.name == "Workout A" })?.id),
                templateNameSnapshot: "Workout A",
                startedAt: completedAt.addingTimeInterval(-5_400),
                completedAt: completedAt,
                blocks: []
            )
        ]

        let pinned = try XCTUnwrap(
            TemplateReferenceSelection.pinnedTemplate(
                from: [plan],
                references: references,
                sessions: sessions,
                now: monday,
                calendar: calendar
            )
        )

        XCTAssertEqual(pinned.templateName, "Workout B")
    }

    func testCustomWorkoutABNamesUseWeekdayScheduleInsteadOfAlternatingRotation() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let friday = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 13))
        )
        let completedAt = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 9))
        )

        let plan = makeCustomNamedWorkoutABPlan()
        let references = plan.templates.map { template in
            makeReference(plan: plan, template: template)
        }
        let sessions = [
            CompletedSession(
                planID: plan.id,
                templateID: try XCTUnwrap(plan.templates.first(where: { $0.name == "Workout A" })?.id),
                templateNameSnapshot: "Workout A",
                startedAt: completedAt.addingTimeInterval(-5_400),
                completedAt: completedAt,
                blocks: []
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

        XCTAssertFalse(TemplateReferenceSelection.isAlternatingPlan(plan))
        XCTAssertEqual(pinned.templateName, "Workout A")
    }

    @MainActor
    func testPinningTemplateMakesItTodayDefaultAndClearsOlderPins() async throws {
        let store = makeStore()
        await store.hydrateIfNeeded()
        store.completeOnboarding(with: nil)

        let firstPlan = makeSingleTemplatePlan(
            name: "Plan A",
            templateName: "Bench Day",
            store: store,
            weight: 185
        )
        let secondPlan = makeSingleTemplatePlan(
            name: "Plan B",
            templateName: "Press Day",
            store: store,
            weight: 135
        )
        store.savePlan(firstPlan)
        store.savePlan(secondPlan)

        let secondTemplateID = try XCTUnwrap(secondPlan.templates.first?.id)
        store.pinTemplate(planID: secondPlan.id, templateID: secondTemplateID)

        XCTAssertEqual(store.todayStore.pinnedTemplate?.templateID, secondTemplateID)
        XCTAssertNil(store.plansStore.plan(for: firstPlan.id)?.pinnedTemplateID)
        XCTAssertEqual(store.plansStore.plan(for: secondPlan.id)?.pinnedTemplateID, secondTemplateID)
    }

    @MainActor
    func testPlanRepositoryUpsertsExistingRecords() throws {
        let container = WorkoutModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let repository = PlanRepository(modelContext: context)

        var plan = Plan(name: "Starter", templates: [])
        repository.savePlans([plan])

        plan.name = "Starter Updated"
        repository.savePlans([plan])

        let records = try context.fetch(FetchDescriptor<StoredPlan>())
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(try XCTUnwrap(repository.loadPlans().first).name, "Starter Updated")
    }

    @MainActor
    func testSessionRepositoryKeepsSingleActiveDraftRecordAcrossUpdates() throws {
        let container = WorkoutModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let repository = SessionRepository(modelContext: context)

        var draft = SessionDraft(
            planID: nil,
            templateID: UUID(),
            templateNameSnapshot: "Upper",
            blocks: []
        )
        repository.saveActiveDraft(draft)

        draft.notes = "Felt strong"
        repository.saveActiveDraft(draft)

        let records = try context.fetch(FetchDescriptor<StoredActiveSession>())
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(repository.loadActiveDraft()?.notes, "Felt strong")
    }

    @MainActor
    func testPlanRepositoryDropsBlocksWithInvalidProgressionRulePayloads() throws {
        let container = WorkoutModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        context.autosaveEnabled = false

        let plan = StoredPlan(
            id: UUID(),
            name: "Starter",
            createdAt: .now,
            pinnedTemplateID: nil
        )
        let template = StoredTemplate(
            id: UUID(),
            name: "Bench Day",
            note: "",
            scheduledWeekdaysData: Data("[]".utf8),
            lastStartedAt: nil,
            orderIndex: 0
        )
        let block = StoredTemplateBlock(
            id: UUID(),
            exerciseID: CatalogSeed.benchPress,
            exerciseNameSnapshot: "Bench Press",
            blockNote: "",
            restSeconds: 90,
            supersetGroup: nil,
            allowsAutoWarmups: true,
            orderIndex: 0,
            progressionRuleData: Data("invalid".utf8)
        )

        template.plan = plan
        template.blocks = [block]
        block.template = template

        context.insert(plan)
        context.insert(template)
        context.insert(block)
        try context.save()

        let repository = PlanRepository(modelContext: context)
        let loadedPlan = try XCTUnwrap(repository.loadPlans().first)
        let loadedTemplate = try XCTUnwrap(loadedPlan.templates.first)

        XCTAssertEqual(loadedPlan.name, "Starter")
        XCTAssertEqual(loadedTemplate.name, "Bench Day")
        XCTAssertTrue(loadedTemplate.blocks.isEmpty)
    }

    @MainActor
    func testContainerFactoryFallsBackWithoutResetForInvalidPersistentStorePath() throws {
        let storeDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let storeURL = storeDirectory.appendingPathComponent("WorkoutTracker.store")

        try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: storeURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: storeDirectory)
            _ = WorkoutModelContainerFactory.consumeStartupIssue()
        }

        let container = WorkoutModelContainerFactory.makeContainer(storeURL: storeURL)
        let issue = try XCTUnwrap(WorkoutModelContainerFactory.consumeStartupIssue())
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let repository = PlanRepository(modelContext: context)
        let catalogItem = ExerciseCatalogItem(
            id: CatalogSeed.benchPress,
            name: "Bench Press",
            category: .chest
        )

        XCTAssertEqual(issue.title, "Storage Unavailable")
        XCTAssertNil(issue.recoveryDirectoryURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: storeURL.path))
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: storeDirectory.appendingPathComponent("Recovery").path
            )
        )
        XCTAssertTrue(repository.saveCatalog([catalogItem]))
        XCTAssertEqual(repository.loadCatalog().first?.name, "Bench Press")
    }

    @MainActor
    func testDeferredDraftMutationsPersistWhenFlushed() throws {
        let container = WorkoutModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let repository = SessionRepository(modelContext: context)
        let store = SessionStore(
            repository: repository,
            persistenceController: SessionPersistenceControllerRegistry.controller(for: container)
        )
        let row = SessionSetRow(
            target: SetTarget(
                setKind: .working,
                targetWeight: 185,
                repRange: RepRange(5, 5)
            )
        )
        let block = SessionBlock(
            exerciseID: CatalogSeed.benchPress,
            exerciseNameSnapshot: "Bench Press",
            restSeconds: 90,
            progressionRule: .manual,
            sets: [row]
        )
        let draft = SessionDraft(
            planID: nil,
            templateID: UUID(),
            templateNameSnapshot: "Bench Day",
            blocks: [block]
        )

        store.beginSession(draft)
        store.pushMutation(persistence: .deferred) { updatedDraft in
            SessionEngine.adjustWeight(by: 5, setID: row.id, in: block.id, draft: &updatedDraft)
        }

        XCTAssertEqual(store.activeDraft?.blocks.first?.sets.first?.log.weight, 190)
        XCTAssertNil(repository.loadActiveDraft()?.blocks.first?.sets.first?.log.weight)

        store.flushPendingDraftSave()

        XCTAssertEqual(repository.loadActiveDraft()?.blocks.first?.sets.first?.log.weight, 190)
    }

    @MainActor
    func testDeferredDraftMutationsPersistAfterDebounceWithoutManualFlush() async throws {
        let container = WorkoutModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let repository = SessionRepository(modelContext: context)
        let persistenceController = SessionPersistenceControllerRegistry.controller(for: container)
        let store = SessionStore(
            repository: repository,
            persistenceController: persistenceController
        )
        let draft = SessionDraft(
            planID: nil,
            templateID: UUID(),
            templateNameSnapshot: "Bench Day",
            blocks: []
        )

        store.beginSession(draft)
        persistenceController.flush()

        store.pushMutation(persistence: .deferred) { updatedDraft in
            SessionEngine.updateSessionNotes("Debounced note", draft: &updatedDraft)
        }

        XCTAssertEqual(repository.loadActiveDraft()?.notes, "")

        try await Task.sleep(nanoseconds: 700_000_000)
        persistenceController.flush()

        XCTAssertEqual(repository.loadActiveDraft()?.notes, "Debounced note")
    }

    @MainActor
    func testSessionStoreOnlyNotifiesLiveActivityObserverForTimerRelevantChanges() throws {
        let container = WorkoutModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let repository = SessionRepository(modelContext: context)
        let store = SessionStore(
            repository: repository,
            persistenceController: SessionPersistenceControllerRegistry.controller(for: container)
        )

        let target = SetTarget(
            setKind: .working,
            targetWeight: 185,
            repRange: RepRange(5, 5)
        )
        let row = SessionSetRow(target: target)
        let block = SessionBlock(
            exerciseID: CatalogSeed.benchPress,
            exerciseNameSnapshot: "Bench Press",
            restSeconds: 90,
            progressionRule: .manual,
            sets: [row]
        )
        let draft = SessionDraft(
            planID: nil,
            templateID: UUID(),
            templateNameSnapshot: "Bench Day",
            blocks: [block]
        )

        var observedDrafts: [SessionDraft?] = []
        store.onActiveDraftLiveActivityStateChanged = { observedDrafts.append($0) }

        store.beginSession(draft)
        observedDrafts.removeAll()

        store.pushMutation(persistence: .deferred) { updatedDraft in
            SessionEngine.adjustWeight(by: 5, setID: row.id, in: block.id, draft: &updatedDraft)
        }
        XCTAssertTrue(observedDrafts.isEmpty)

        let completedAt = Date(timeIntervalSince1970: 1_741_600_000)
        store.pushMutation(
            blockID: block.id,
            setID: row.id,
            undoStrategy: .block(block.id),
            persistence: .deferred
        ) { updatedDraft, context in
            SessionEngine.toggleCompletion(
                of: row.id,
                in: block.id,
                draft: &updatedDraft,
                context: context,
                completedAt: completedAt
            )
        }

        XCTAssertEqual(observedDrafts.count, 1)
        XCTAssertEqual(observedDrafts.last??.restTimerEndsAt, completedAt.addingTimeInterval(90))

        store.clearRestTimer()

        XCTAssertEqual(observedDrafts.count, 2)
        XCTAssertNil(observedDrafts.last??.restTimerEndsAt)
    }

    @MainActor
    func testCompletedSessionHistoryMergePrefersLocalCopiesAndResetsLoadingFlags() {
        let container = WorkoutModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let store = SessionStore(
            repository: SessionRepository(modelContext: context),
            persistenceController: SessionPersistenceControllerRegistry.controller(for: container)
        )
        let duplicateSessionID = UUID()
        let planID = UUID()
        let templateID = UUID()
        let earlierDate = Date(timeIntervalSince1970: 1_741_478_400)
        let laterDate = earlierDate.addingTimeInterval(86_400)
        let localSession = makeCompletedSession(
            id: duplicateSessionID,
            planID: planID,
            templateID: templateID,
            templateNameSnapshot: "Local Session",
            date: laterDate
        )
        let remoteDuplicate = makeCompletedSession(
            id: duplicateSessionID,
            planID: planID,
            templateID: templateID,
            templateNameSnapshot: "Remote Session",
            date: laterDate.addingTimeInterval(-60)
        )
        let earlierRemoteSession = makeCompletedSession(
            planID: UUID(),
            templateID: UUID(),
            templateNameSnapshot: "Earlier Session",
            date: earlierDate
        )

        store.hydrate(
            with: SessionStore.HydrationSnapshot(
                activeDraft: nil,
                completedSessions: [localSession],
                includesCompleteHistory: false
            )
        )

        let initialRevision = store.completedSessionsRevision
        XCTAssertFalse(store.hasLoadedCompletedSessionHistory)
        XCTAssertTrue(store.isLoadingCompletedSessionHistory)

        store.setCompletedSessionHistoryLoading(false)
        XCTAssertFalse(store.isLoadingCompletedSessionHistory)

        store.setCompletedSessionHistoryLoading(true)
        XCTAssertTrue(store.isLoadingCompletedSessionHistory)

        store.mergeCompletedSessionHistory([remoteDuplicate, earlierRemoteSession])

        XCTAssertTrue(store.hasLoadedCompletedSessionHistory)
        XCTAssertFalse(store.isLoadingCompletedSessionHistory)
        XCTAssertEqual(store.completedSessionsRevision, initialRevision + 1)
        XCTAssertEqual(store.completedSessions.map(\.templateNameSnapshot), ["Earlier Session", "Local Session"])
        XCTAssertEqual(store.completedSessions.last?.id, duplicateSessionID)
        XCTAssertEqual(store.completedSessions.last?.completedAt, laterDate)

        store.setCompletedSessionHistoryLoading(true)
        XCTAssertFalse(store.isLoadingCompletedSessionHistory)
    }

    @MainActor
    func testSessionStoreUndoRestoresBlockSessionAndFullDraftMutationsIncrementally() throws {
        let container = WorkoutModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let repository = SessionRepository(modelContext: context)
        let store = SessionStore(
            repository: repository,
            persistenceController: SessionPersistenceControllerRegistry.controller(for: container)
        )

        let target = SetTarget(
            setKind: .working,
            targetWeight: 185,
            repRange: RepRange(5, 5)
        )
        let row = SessionSetRow(
            target: target,
            log: SetLog(setTargetID: target.id, weight: 185, reps: 5)
        )
        let block = SessionBlock(
            exerciseID: CatalogSeed.benchPress,
            exerciseNameSnapshot: "Bench Press",
            restSeconds: 90,
            progressionRule: .manual,
            sets: [row]
        )
        let draft = SessionDraft(
            planID: nil,
            templateID: UUID(),
            templateNameSnapshot: "Bench Day",
            blocks: [block]
        )
        let accessory = ExerciseCatalogItem(
            id: CatalogSeed.backSquat,
            name: "Back Squat",
            category: .legs
        )

        store.beginSession(draft)
        XCTAssertFalse(store.canUndo)

        store.pushMutation(
            blockID: block.id,
            setID: row.id,
            undoStrategy: .block(block.id),
            persistence: .deferred
        ) { updatedDraft, context in
            SessionEngine.adjustWeight(by: 5, setID: row.id, in: block.id, draft: &updatedDraft, context: context)
        }
        store.pushMutation(
            blockID: block.id,
            undoStrategy: .block(block.id),
            persistence: .deferred
        ) { updatedDraft, context in
            SessionEngine.addSet(to: block.id, draft: &updatedDraft, context: context)
        }
        store.pushMutation(undoStrategy: .sessionMetadata, persistence: .deferred) { updatedDraft, _ in
            SessionEngine.updateSessionNotes("Focus cues", draft: &updatedDraft)
        }
        store.pushMutation(persistence: .deferred) { updatedDraft, _ in
            SessionEngine.addExerciseBlock(
                exercise: accessory,
                draft: &updatedDraft,
                defaultRestSeconds: 120
            )
        }

        let mutatedDraft = try XCTUnwrap(store.activeDraft)
        XCTAssertTrue(store.canUndo)
        XCTAssertEqual(mutatedDraft.blocks.count, 2)
        XCTAssertEqual(mutatedDraft.notes, "Focus cues")
        XCTAssertEqual(mutatedDraft.blocks.first?.sets.count, 2)
        XCTAssertEqual(mutatedDraft.blocks.first?.sets.first?.log.weight, 190)

        store.undoLastMutation()
        let afterFullDraftUndo = try XCTUnwrap(store.activeDraft)
        XCTAssertEqual(afterFullDraftUndo.blocks.count, 1)
        XCTAssertEqual(afterFullDraftUndo.notes, "Focus cues")
        XCTAssertEqual(afterFullDraftUndo.blocks.first?.sets.count, 2)
        XCTAssertEqual(afterFullDraftUndo.blocks.first?.sets.first?.log.weight, 190)

        store.undoLastMutation()
        let afterSessionMetadataUndo = try XCTUnwrap(store.activeDraft)
        XCTAssertEqual(afterSessionMetadataUndo.notes, "")
        XCTAssertEqual(afterSessionMetadataUndo.blocks.first?.sets.count, 2)
        XCTAssertEqual(afterSessionMetadataUndo.blocks.first?.sets.first?.log.weight, 190)

        store.undoLastMutation()
        let afterBlockStructureUndo = try XCTUnwrap(store.activeDraft)
        XCTAssertEqual(afterBlockStructureUndo.blocks.first?.sets.count, 1)
        XCTAssertEqual(afterBlockStructureUndo.blocks.first?.sets.first?.log.weight, 190)

        store.undoLastMutation()
        let afterBlockValueUndo = try XCTUnwrap(store.activeDraft)
        XCTAssertEqual(afterBlockValueUndo.blocks.first?.sets.count, 1)
        XCTAssertEqual(afterBlockValueUndo.blocks.first?.sets.first?.log.weight, 185)
        XCTAssertFalse(store.canUndo)

        store.flushPendingDraftSave()

        let rehydrationContext = ModelContext(container)
        rehydrationContext.autosaveEnabled = false
        let rehydrationRepository = SessionRepository(modelContext: rehydrationContext)
        let rehydratedStore = SessionStore(
            repository: rehydrationRepository,
            persistenceController: SessionPersistenceControllerRegistry.controller(for: container)
        )
        rehydratedStore.hydrate(
            with: SessionStore.HydrationSnapshot(
                activeDraft: rehydrationRepository.loadActiveDraft(),
                completedSessions: rehydrationRepository.loadCompletedSessions()
            )
        )

        let persistedDraft = try XCTUnwrap(rehydratedStore.activeDraft)
        XCTAssertEqual(persistedDraft.blocks.count, 1)
        XCTAssertEqual(persistedDraft.notes, "")
        XCTAssertEqual(persistedDraft.blocks.first?.sets.count, 1)
        XCTAssertEqual(persistedDraft.blocks.first?.sets.first?.log.weight, 185)
    }

    @MainActor
    func testProgressStoreCachesHistorySessionsBySelectedDay() {
        let analytics = AnalyticsRepository()
        let progressStore = ProgressStore()
        let dayOne = Date(timeIntervalSince1970: 1_741_478_400)
        let dayTwo = dayOne.addingTimeInterval(86_400)
        let sessions = [
            CompletedSession(
                planID: nil,
                templateID: UUID(),
                templateNameSnapshot: "Day One AM",
                startedAt: dayOne.addingTimeInterval(-3_600),
                completedAt: dayOne,
                blocks: []
            ),
            CompletedSession(
                planID: nil,
                templateID: UUID(),
                templateNameSnapshot: "Day One PM",
                startedAt: dayOne.addingTimeInterval(3_600),
                completedAt: dayOne.addingTimeInterval(7_200),
                blocks: []
            ),
            CompletedSession(
                planID: nil,
                templateID: UUID(),
                templateNameSnapshot: "Day Two",
                startedAt: dayTwo.addingTimeInterval(-3_600),
                completedAt: dayTwo,
                blocks: []
            ),
        ]

        let sessionAnalytics = analytics.makeSessionAnalyticsSnapshot(
            sessions: sessions,
            catalogByID: [:],
            now: dayTwo
        )

        progressStore.apply(
            analytics.makeProgressSnapshot(
                sessionAnalytics: sessionAnalytics,
                selectedExerciseID: nil
            ),
            completedSessions: sessions
        )

        XCTAssertEqual(progressStore.historySessions.map(\.templateNameSnapshot), ["Day Two", "Day One PM", "Day One AM"])
        XCTAssertEqual(progressStore.workoutDays.count, 2)

        progressStore.selectDay(dayOne)
        XCTAssertEqual(progressStore.historySessions.map(\.templateNameSnapshot), ["Day One PM", "Day One AM"])

        progressStore.selectDay(nil)
        XCTAssertEqual(progressStore.historySessions.map(\.templateNameSnapshot), ["Day Two", "Day One PM", "Day One AM"])
    }

    @MainActor
    func testProgressStoreSamplesDenseExerciseTrendCharts() throws {
        let analytics = AnalyticsRepository()
        let progressStore = ProgressStore()
        let start = Date(timeIntervalSince1970: 1_741_478_400)
        let sessions = (0..<240).map { index in
            makeCompletedSession(
                date: start.addingTimeInterval(Double(index) * 86_400),
                exerciseID: CatalogSeed.benchPress,
                exerciseName: "Bench Press",
                rows: [makeRow(kind: .working, weight: Double(135 + index), reps: 5)]
            )
        }
        let sessionAnalytics = analytics.makeSessionAnalyticsSnapshot(
            sessions: sessions,
            catalogByID: [
                CatalogSeed.benchPress: ExerciseCatalogItem(
                    id: CatalogSeed.benchPress,
                    name: "Bench Press",
                    category: .chest
                )
            ],
            now: start.addingTimeInterval(Double(sessions.count) * 86_400)
        )
        let snapshot = analytics.makeProgressSnapshot(
            sessionAnalytics: sessionAnalytics,
            selectedExerciseID: CatalogSeed.benchPress
        )

        progressStore.apply(snapshot, completedSessions: sessions)

        let chartSeries = try XCTUnwrap(progressStore.selectedExerciseChartSeries)
        XCTAssertTrue(chartSeries.isSampled)
        XCTAssertLessThanOrEqual(chartSeries.trendPoints.count, 160)
        XCTAssertLessThanOrEqual(chartSeries.markerPoints.count, 24)
        XCTAssertEqual(chartSeries.trendPoints.first?.sessionID, snapshot.exerciseSummaries.first?.points.first?.sessionID)
        XCTAssertEqual(chartSeries.trendPoints.last?.sessionID, snapshot.exerciseSummaries.first?.points.last?.sessionID)
    }

    @MainActor
    func testProgressStoreRecordCompletedSessionRebuildsCachesAndKeepsSelectedExerciseSeriesSorted() throws {
        let analytics = AnalyticsRepository()
        let progressStore = ProgressStore()
        let dayOne = Date(timeIntervalSince1970: 1_741_478_400)
        let dayTwo = dayOne.addingTimeInterval(86_400)
        let dayThree = dayTwo.addingTimeInterval(86_400)
        let olderBenchSession = makeCompletedSession(
            date: dayOne,
            exerciseID: CatalogSeed.benchPress,
            exerciseName: "Bench Press",
            rows: [makeRow(kind: .working, weight: 185, reps: 5)]
        )
        let newerBenchSession = makeCompletedSession(
            date: dayTwo,
            exerciseID: CatalogSeed.benchPress,
            exerciseName: "Bench Press",
            rows: [makeRow(kind: .working, weight: 205, reps: 5)]
        )
        let laterSquatSession = makeCompletedSession(
            date: dayThree,
            exerciseID: CatalogSeed.backSquat,
            exerciseName: "Back Squat",
            rows: [makeRow(kind: .working, weight: 275, reps: 5)]
        )
        let catalogByID = [
            CatalogSeed.backSquat: ExerciseCatalogItem(
                id: CatalogSeed.backSquat,
                name: "Back Squat",
                category: .legs
            ),
            CatalogSeed.benchPress: ExerciseCatalogItem(
                id: CatalogSeed.benchPress,
                name: "Bench Press",
                category: .chest
            ),
        ]
        let sessionAnalytics = analytics.makeSessionAnalyticsSnapshot(
            sessions: [newerBenchSession],
            catalogByID: catalogByID,
            now: dayThree
        )

        progressStore.apply(
            analytics.makeProgressSnapshot(
                sessionAnalytics: sessionAnalytics,
                selectedExerciseID: nil
            ),
            completedSessions: [newerBenchSession]
        )

        progressStore.selectExercise(CatalogSeed.benchPress)
        XCTAssertEqual(progressStore.selectedExerciseSummary?.points.map(\.date), [dayTwo])

        progressStore.recordCompletedSession(
            olderBenchSession,
            completedSessions: [olderBenchSession, newerBenchSession, laterSquatSession],
            analytics: analytics,
            catalogByID: catalogByID,
            finishSummary: nil,
            payloads: analytics.sessionExercisePayloads(from: olderBenchSession)
        )

        let summary = try XCTUnwrap(progressStore.selectedExerciseSummary)
        let chartSeries = try XCTUnwrap(progressStore.selectedExerciseChartSeries)

        XCTAssertEqual(progressStore.selectedExerciseID, CatalogSeed.benchPress)
        XCTAssertEqual(summary.displayName, "Bench Press")
        XCTAssertEqual(summary.pointCount, 2)
        XCTAssertEqual(summary.points.map(\.date), [dayOne, dayTwo])
        XCTAssertEqual(chartSeries.trendPoints.map(\.date), [dayOne, dayTwo])
        XCTAssertEqual(progressStore.workoutDays.count, 3)

        progressStore.selectDay(dayOne)
        XCTAssertEqual(progressStore.historySessions.map(\.completedAt), [dayOne])
    }

    func testExercisePickerSearchIndexMatchesAliasesAndDiacritics() {
        let catalog = [
            ExerciseCatalogItem(
                id: UUID(),
                name: "Bench Press",
                aliases: ["Barbell Bench"],
                category: .chest
            ),
            ExerciseCatalogItem(
                id: UUID(),
                name: "Développé Couché",
                aliases: ["Développé Couché", "Presse poitrine"],
                category: .chest
            ),
            ExerciseCatalogItem(
                id: UUID(),
                name: "Back Squat",
                aliases: ["High Bar"],
                category: .legs
            ),
        ]
        let index = ExercisePickerSearchIndex(catalog: catalog)

        XCTAssertEqual(index.filter(query: "barbell").map(\.name), ["Bench Press"])
        XCTAssertEqual(index.filter(query: "developpe").map(\.name), ["Développé Couché"])
        XCTAssertEqual(index.filter(query: "high bar").map(\.name), ["Back Squat"])
        XCTAssertEqual(index.filter(query: "   ").map(\.name), catalog.map(\.name))
    }

    func testCalendarMonthLayoutPrecomputesWorkoutDays() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        calendar.firstWeekday = 1

        let displayedMonth = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 15))
        )
        let workoutDay = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 9))
        )

        let layout = AppCalendarMonthLayout.make(
            for: displayedMonth,
            workoutDays: [workoutDay],
            calendar: calendar
        )

        XCTAssertEqual(layout.monthStart, calendar.date(from: DateComponents(year: 2026, month: 3, day: 1)))
        XCTAssertEqual(layout.dayEntries.count, 31)
        XCTAssertTrue(layout.dayEntries.contains(where: { $0.date == workoutDay && $0.hasWorkout }))
        XCTAssertEqual(layout.dayEntries.first?.dayNumber, 1)
        XCTAssertEqual(layout.dayEntries.last?.dayNumber, 31)
    }

    func testCalendarMonthLayoutWrapsLeadingDaysForMondayFirstCalendars() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        calendar.firstWeekday = 2

        let displayedMonth = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 15))
        )

        let layout = AppCalendarMonthLayout.make(
            for: displayedMonth,
            workoutDays: [],
            calendar: calendar
        )

        XCTAssertEqual(layout.dayEntries.count, 37)
        XCTAssertEqual(layout.dayEntries.prefix(6).compactMap(\.dayNumber), [])
        XCTAssertEqual(layout.dayEntries[6].dayNumber, 1)
    }

    func testCalendarMonthLayoutRotatesWeekdaySymbolsForMondayFirstCalendars() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        calendar.firstWeekday = 2

        let displayedMonth = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 15))
        )

        let layout = AppCalendarMonthLayout.make(
            for: displayedMonth,
            workoutDays: [],
            calendar: calendar
        )

        let symbols = calendar.shortStandaloneWeekdaySymbols
        XCTAssertEqual(layout.weekdaySymbols, Array(symbols[1...]) + Array(symbols[..<1]))
    }

    @MainActor
    func testFinishSessionIncrementallyUpdatesTodayAndProgressStores() async throws {
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

        let block = try XCTUnwrap(store.sessionStore.activeDraft?.blocks.first)
        let row = try XCTUnwrap(block.sets.first(where: { $0.target.setKind == .working }))
        store.toggleSetCompletion(blockID: block.id, setID: row.id)
        store.finishActiveSession()

        XCTAssertEqual(store.todayStore.recentSessions.first?.templateNameSnapshot, "Bench Day")
        XCTAssertEqual(store.todayStore.recentPersonalRecords.count, 1)
        XCTAssertEqual(store.progressStore.personalRecords.count, 1)
        XCTAssertEqual(store.progressStore.exerciseSummaries.first?.pointCount, 1)
        XCTAssertEqual(store.progressStore.overview.totalSessions, 1)
    }

    @MainActor
    func testDuplicateExerciseBlocksOnlyAdvanceMatchedTemplateProgressionOnce() async throws {
        let store = makeStore()
        await store.hydrateIfNeeded()
        store.completeOnboarding(with: nil)

        var plan = store.makePlan(name: "Duplicate Bench")
        let template = WorkoutTemplate(
            name: "Bench Day",
            blocks: [
                ExerciseBlock(
                    exerciseID: CatalogSeed.benchPress,
                    exerciseNameSnapshot: "Bench Press",
                    progressionRule: ProgressionRule(
                        kind: .percentageWave,
                        percentageWave: PercentageWaveRule.fiveThreeOne(trainingMax: 200, cycleIncrement: 5)
                    ),
                    targets: []
                ),
                ExerciseBlock(
                    exerciseID: CatalogSeed.benchPress,
                    exerciseNameSnapshot: "Bench Press",
                    progressionRule: .manual,
                    targets: [
                        SetTarget(targetWeight: 185, repRange: RepRange(10, 10))
                    ],
                    allowsAutoWarmups: false
                ),
            ]
        )
        plan.templates = [template]
        plan.pinnedTemplateID = template.id
        store.savePlan(plan)

        store.startSession(planID: plan.id, templateID: template.id)
        let activeBlocks = try XCTUnwrap(store.sessionStore.activeDraft?.blocks)
        let mainSessionBlock = try XCTUnwrap(activeBlocks.first)
        for row in mainSessionBlock.sets where row.target.setKind == .working {
            store.toggleSetCompletion(blockID: mainSessionBlock.id, setID: row.id)
        }
        store.finishActiveSession()

        let updatedTemplate = try XCTUnwrap(store.plansStore.plan(for: plan.id)?.templates.first)
        let mainBlock = try XCTUnwrap(updatedTemplate.blocks.first)
        let supplementalBlock = try XCTUnwrap(updatedTemplate.blocks.dropFirst().first)

        XCTAssertEqual(mainBlock.progressionRule.percentageWave?.currentWeekIndex, 1)
        XCTAssertEqual(mainBlock.progressionRule.percentageWave?.cycle, 1)
        XCTAssertEqual(supplementalBlock.progressionRule.kind, .manual)
        XCTAssertEqual(supplementalBlock.targets.first?.targetWeight, 185)
    }

    @MainActor
    func testAdHocDuplicateExerciseBlockDoesNotAdvanceTemplateProgressionTwice() async throws {
        let store = makeStore()
        await store.hydrateIfNeeded()
        store.completeOnboarding(with: nil)

        var plan = store.makePlan(name: "Ad Hoc Bench")
        let template = WorkoutTemplate(
            name: "Bench Day",
            blocks: [
                ExerciseBlock(
                    exerciseID: CatalogSeed.benchPress,
                    exerciseNameSnapshot: "Bench Press",
                    progressionRule: ProgressionRule(
                        kind: .percentageWave,
                        percentageWave: PercentageWaveRule.fiveThreeOne(trainingMax: 200, cycleIncrement: 5)
                    ),
                    targets: []
                )
            ]
        )
        plan.templates = [template]
        plan.pinnedTemplateID = template.id
        store.savePlan(plan)

        store.startSession(planID: plan.id, templateID: template.id)

        let startedBlock = try XCTUnwrap(store.sessionStore.activeDraft?.blocks.first)
        for row in startedBlock.sets where row.target.setKind == .working {
            store.toggleSetCompletion(blockID: startedBlock.id, setID: row.id)
        }

        store.addExerciseToActiveSession(exerciseID: CatalogSeed.benchPress)
        let addedBlock = try XCTUnwrap(store.sessionStore.activeDraft?.blocks.last)
        let addedRow = try XCTUnwrap(addedBlock.sets.first(where: { $0.target.setKind == .working }))
        store.toggleSetCompletion(blockID: addedBlock.id, setID: addedRow.id)

        XCTAssertTrue(store.finishActiveSession())

        let updatedTemplate = try XCTUnwrap(store.plansStore.plan(for: plan.id)?.templates.first)
        XCTAssertEqual(updatedTemplate.blocks.first?.progressionRule.percentageWave?.currentWeekIndex, 1)
        XCTAssertEqual(updatedTemplate.blocks.first?.progressionRule.percentageWave?.cycle, 1)
    }

    @MainActor
    func testFinishingStartingStrengthSessionPinsTheAlternateWorkout() async throws {
        let store = makeStore()
        await store.hydrateIfNeeded()
        store.completeOnboarding(with: .startingStrength)

        let initialPinned = try XCTUnwrap(store.todayStore.pinnedTemplate)
        XCTAssertEqual(initialPinned.templateName, "Workout A")

        store.startSession(planID: initialPinned.planID, templateID: initialPinned.templateID)
        let block = try XCTUnwrap(store.sessionStore.activeDraft?.blocks.first)
        let row = try XCTUnwrap(block.sets.first(where: { $0.target.setKind == .working }))
        store.toggleSetCompletion(blockID: block.id, setID: row.id)
        store.finishActiveSession()

        let rotatedPinned = try XCTUnwrap(store.todayStore.pinnedTemplate)
        let updatedPlan = try XCTUnwrap(store.plansStore.plan(for: initialPinned.planID))

        XCTAssertEqual(rotatedPinned.templateName, "Workout B")
        XCTAssertEqual(updatedPlan.pinnedTemplateID, rotatedPinned.templateID)
    }

    @MainActor
    func testFinishingStrongLiftsSessionPinsTheAlternateWorkout() async throws {
        let store = makeStore()
        await store.hydrateIfNeeded()
        store.completeOnboarding(with: .strongLiftsFiveByFive)

        let initialPinned = try XCTUnwrap(store.todayStore.pinnedTemplate)
        XCTAssertEqual(initialPinned.templateName, "Workout A")

        store.startSession(planID: initialPinned.planID, templateID: initialPinned.templateID)
        let block = try XCTUnwrap(store.sessionStore.activeDraft?.blocks.first)
        let row = try XCTUnwrap(block.sets.first(where: { $0.target.setKind == .working }))
        store.toggleSetCompletion(blockID: block.id, setID: row.id)
        store.finishActiveSession()

        let rotatedPinned = try XCTUnwrap(store.todayStore.pinnedTemplate)
        let updatedPlan = try XCTUnwrap(store.plansStore.plan(for: initialPinned.planID))

        XCTAssertEqual(rotatedPinned.templateName, "Workout B")
        XCTAssertEqual(updatedPlan.pinnedTemplateID, rotatedPinned.templateID)
    }

    @MainActor
    func testQuickStartsStayDeduplicatedAfterRepeatedTemplateCompletion() async throws {
        let store = makeStore()
        await store.hydrateIfNeeded()
        store.completeOnboarding(with: .generalGym)

        let reference = try XCTUnwrap(store.todayStore.quickStartTemplates.first)

        for _ in 0..<2 {
            store.startSession(planID: reference.planID, templateID: reference.templateID)
            let block = try XCTUnwrap(store.sessionStore.activeDraft?.blocks.first)
            let row = try XCTUnwrap(block.sets.first(where: { $0.target.setKind == .working }))
            store.toggleSetCompletion(blockID: block.id, setID: row.id)
            store.finishActiveSession()
        }

        let quickStartIDs = store.todayStore.quickStartTemplates.map(\.templateID)
        XCTAssertEqual(Set(quickStartIDs).count, quickStartIDs.count)
        XCTAssertEqual(store.todayStore.quickStartTemplates.first?.templateID, reference.templateID)
    }

    func testTemplateReferenceSelectionQuickStartsPreferRecentUniqueTemplatesThenBackfill() throws {
        let alternatingPlan = makeStartingStrengthPlan()
        let dayA = try XCTUnwrap(alternatingPlan.templates.first)
        let dayB = try XCTUnwrap(alternatingPlan.templates.last)
        let accessoryTemplate = WorkoutTemplate(
            name: "Accessory Day",
            blocks: []
        )
        let accessoryPlan = Plan(
            name: "Accessory",
            pinnedTemplateID: accessoryTemplate.id,
            templates: [accessoryTemplate]
        )
        let references = [
            makeReference(plan: alternatingPlan, template: dayA),
            makeReference(plan: alternatingPlan, template: dayB),
            makeReference(plan: accessoryPlan, template: accessoryTemplate),
        ]
        let start = Date(timeIntervalSince1970: 1_741_478_400)
        let sessions = [
            makeCompletedSession(
                planID: alternatingPlan.id,
                templateID: dayA.id,
                templateNameSnapshot: dayA.name,
                date: start
            ),
            makeCompletedSession(
                planID: alternatingPlan.id,
                templateID: dayA.id,
                templateNameSnapshot: dayA.name,
                date: start.addingTimeInterval(86_400)
            ),
            makeCompletedSession(
                planID: alternatingPlan.id,
                templateID: dayB.id,
                templateNameSnapshot: dayB.name,
                date: start.addingTimeInterval(172_800)
            ),
        ]

        let quickStarts = TemplateReferenceSelection.quickStarts(
            references: references,
            sessions: sessions,
            limit: 3
        )

        XCTAssertEqual(quickStarts.map(\.templateID), [dayB.id, dayA.id, accessoryTemplate.id])
    }

    @MainActor
    private func makeStore(
        container: ModelContainer = WorkoutModelContainerFactory.makeContainer(isStoredInMemoryOnly: true),
        launchArguments: Set<String> = []
    ) -> AppStore {
        AppStore(
            modelContainer: container,
            launchArguments: launchArguments,
            settingsStore: SettingsStore(defaults: testDefaults)
        )
    }

    @MainActor
    private func makeSingleTemplatePlan(
        name: String,
        templateName: String,
        store: AppStore,
        weight: Double
    ) -> Plan {
        var plan = store.makePlan(name: name)
        let block = ExerciseBlock(
            exerciseID: CatalogSeed.benchPress,
            exerciseNameSnapshot: store.plansStore.exerciseName(for: CatalogSeed.benchPress),
            restSeconds: 90,
            progressionRule: .manual,
            targets: [
                SetTarget(
                    setKind: .working,
                    targetWeight: weight,
                    repRange: RepRange(5, 5),
                    restSeconds: 90
                )
            ]
        )
        let template = WorkoutTemplate(name: templateName, blocks: [block])
        plan.templates = [template]
        plan.pinnedTemplateID = template.id
        return plan
    }

    private func makeStartingStrengthPlan() -> Plan {
        let dayA = WorkoutTemplate(
            name: "Workout A",
            scheduledWeekdays: [.monday, .friday],
            blocks: [
                makeStartingStrengthBlock(id: CatalogSeed.backSquat, name: "Back Squat"),
                makeStartingStrengthBlock(id: CatalogSeed.benchPress, name: "Bench Press"),
                makeStartingStrengthBlock(id: CatalogSeed.deadlift, name: "Deadlift"),
            ]
        )
        let dayB = WorkoutTemplate(
            name: "Workout B",
            scheduledWeekdays: [.wednesday],
            blocks: [
                makeStartingStrengthBlock(id: CatalogSeed.backSquat, name: "Back Squat"),
                makeStartingStrengthBlock(id: CatalogSeed.overheadPress, name: "Overhead Press"),
                makeStartingStrengthBlock(id: CatalogSeed.powerClean, name: "Power Clean"),
            ]
        )

        return Plan(
            name: PresetPack.startingStrength.displayName,
            pinnedTemplateID: dayA.id,
            templates: [dayA, dayB]
        )
    }

    private func makeCustomNamedWorkoutABPlan() -> Plan {
        let dayA = WorkoutTemplate(
            name: "Workout A",
            scheduledWeekdays: [.monday, .friday],
            blocks: [
                ExerciseBlock(
                    exerciseID: CatalogSeed.pullUp,
                    exerciseNameSnapshot: "Pull Up",
                    restSeconds: 90,
                    progressionRule: .manual,
                    targets: []
                )
            ]
        )
        let dayB = WorkoutTemplate(
            name: "Workout B",
            scheduledWeekdays: [.wednesday],
            blocks: [
                ExerciseBlock(
                    exerciseID: CatalogSeed.dips,
                    exerciseNameSnapshot: "Dips",
                    restSeconds: 90,
                    progressionRule: .manual,
                    targets: []
                )
            ]
        )

        return Plan(
            name: "Custom A/B",
            pinnedTemplateID: dayA.id,
            templates: [dayA, dayB]
        )
    }

    private func makeStartingStrengthBlock(id: UUID, name: String) -> ExerciseBlock {
        ExerciseBlock(
            exerciseID: id,
            exerciseNameSnapshot: name,
            restSeconds: 90,
            progressionRule: .manual,
            targets: []
        )
    }

    private func makeReference(plan: Plan, template: WorkoutTemplate) -> TemplateReference {
        TemplateReference(
            planID: plan.id,
            planName: plan.name,
            templateID: template.id,
            templateName: template.name,
            scheduledWeekdays: template.scheduledWeekdays,
            lastStartedAt: template.lastStartedAt
        )
    }

    private func makeCompletedSession(
        date: Date,
        exerciseID: UUID,
        exerciseName: String,
        rows: [SessionSetRow]
    ) -> CompletedSession {
        CompletedSession(
            planID: UUID(),
            templateID: UUID(),
            templateNameSnapshot: "Template",
            startedAt: date.addingTimeInterval(-3_600),
            completedAt: date,
            blocks: [
                CompletedSessionBlock(
                    exerciseID: exerciseID,
                    exerciseNameSnapshot: exerciseName,
                    blockNote: "",
                    restSeconds: 90,
                    supersetGroup: nil,
                    progressionRule: .manual,
                    sets: rows
                )
            ]
        )
    }

    private func makeCompletedSession(
        id: UUID = UUID(),
        planID: UUID? = UUID(),
        templateID: UUID,
        templateNameSnapshot: String,
        date: Date,
        blocks: [CompletedSessionBlock] = []
    ) -> CompletedSession {
        CompletedSession(
            id: id,
            planID: planID,
            templateID: templateID,
            templateNameSnapshot: templateNameSnapshot,
            startedAt: date.addingTimeInterval(-3_600),
            completedAt: date,
            blocks: blocks
        )
    }

    private func makeRow(
        kind: SetKind,
        weight: Double,
        reps: Int,
        completedAt: Date? = .now
    ) -> SessionSetRow {
        let target = SetTarget(setKind: kind, targetWeight: weight, repRange: RepRange(reps, reps))
        return SessionSetRow(
            target: target,
            log: SetLog(setTargetID: target.id, weight: weight, reps: reps, completedAt: completedAt)
        )
    }

}
