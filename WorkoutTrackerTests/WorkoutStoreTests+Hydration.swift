import SwiftData
import XCTest

@testable import WorkoutTracker

extension WorkoutStoreTests {
    @MainActor
    func testSessionDraftPersistsAcrossStoreRehydration() async throws {
        let container = WorkoutModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let firstStore = makeStore(container: container)
        await firstStore.hydrateIfNeeded()
        firstStore.send(.completeOnboarding(nil))

        let plan = makeSingleTemplatePlan(
            name: "Test Plan",
            templateName: "Upper 1",
            store: firstStore,
            weight: 185
        )
        firstStore.send(.savePlan(plan))
        firstStore.send(.startSession(planID: plan.id, templateID: try XCTUnwrap(plan.templates.first?.id)))

        let rehydratedStore = makeStore(container: container)
        await rehydratedStore.hydrateIfNeeded()

        XCTAssertEqual(rehydratedStore.sessionStore.activeDraft?.templateNameSnapshot, "Upper 1")
        XCTAssertEqual(rehydratedStore.sessionStore.activeDraft?.exercises.count, 1)
    }

    @MainActor
    func testCompletedSessionHistoryLoadsOnDemandAfterStartupHydration() async throws {
        let container = WorkoutModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let seededStore = makeStore(container: container)
        await seededStore.hydrateIfNeeded()
        seededStore.send(.completeOnboarding(nil))

        let plan = makeSingleTemplatePlan(
            name: "Test Plan",
            templateName: "Bench Day",
            store: seededStore,
            weight: 185
        )
        seededStore.send(.savePlan(plan))
        seededStore.send(.startSession(planID: plan.id, templateID: try XCTUnwrap(plan.templates.first?.id)))

        let block = try XCTUnwrap(seededStore.sessionStore.activeDraft?.exercises.first)
        let workingRow = try XCTUnwrap(block.sets.first(where: { $0.target.setKind == .working }))
        seededStore.send(.toggleSetCompletion(blockID: block.id, setID: workingRow.id))
        XCTAssertTrue(seededStore.send(.finishActiveSession))
        await seededStore.flushPendingSessionPersistence()

        let rehydratedStore = makeStore(container: container)
        await rehydratedStore.hydrateIfNeeded()

        XCTAssertFalse(rehydratedStore.sessionStore.hasLoadedCompletedSessionHistory)
        XCTAssertTrue(rehydratedStore.sessionStore.completedSessions.isEmpty)
        XCTAssertEqual(rehydratedStore.todayStore.recentSessions.first?.templateNameSnapshot, "Bench Day")
        XCTAssertEqual(rehydratedStore.progressStore.overview.totalSessions, 1)
        XCTAssertEqual(rehydratedStore.progressStore.personalRecords.count, 1)
        XCTAssertTrue(rehydratedStore.progressStore.historySessions.isEmpty)

        await rehydratedStore.hydrateCompletedSessionHistoryIfNeeded(priority: .userInitiated)

        XCTAssertTrue(rehydratedStore.sessionStore.hasLoadedCompletedSessionHistory)
        XCTAssertEqual(rehydratedStore.sessionStore.completedSessions.count, 1)
        XCTAssertEqual(rehydratedStore.todayStore.recentSessions.first?.templateNameSnapshot, "Bench Day")
        XCTAssertEqual(rehydratedStore.progressStore.overview.totalSessions, 1)
    }

    @MainActor
    func testPreloadDeferredTabDataWarmsProgressWithoutLoadingFullPlanLibrary() async throws {
        let container = WorkoutModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let seededStore = makeStore(container: container)
        await seededStore.hydrateIfNeeded()
        seededStore.send(.completeOnboarding(nil))

        let plan = makeSingleTemplatePlan(
            name: "Deferred Plan",
            templateName: "Bench Day",
            store: seededStore,
            weight: 185
        )
        seededStore.send(.savePlan(plan))
        seededStore.send(.startSession(planID: plan.id, templateID: try XCTUnwrap(plan.templates.first?.id)))

        let block = try XCTUnwrap(seededStore.sessionStore.activeDraft?.exercises.first)
        let workingRow = try XCTUnwrap(block.sets.first(where: { $0.target.setKind == .working }))
        seededStore.send(.toggleSetCompletion(blockID: block.id, setID: workingRow.id))
        XCTAssertTrue(seededStore.send(.finishActiveSession))
        await seededStore.flushPendingSessionPersistence()
        await seededStore.flushPendingPlanPersistence()

        let rehydratedStore = makeStore(container: container)
        await rehydratedStore.hydrateIfNeeded()

        XCTAssertFalse(rehydratedStore.plansStore.hasLoadedPlanLibrary)
        XCTAssertFalse(rehydratedStore.sessionStore.hasLoadedCompletedSessionHistory)

        await rehydratedStore.preloadDeferredTabDataIfNeeded(priority: .utility)

        XCTAssertFalse(rehydratedStore.plansStore.hasLoadedPlanLibrary)
        XCTAssertEqual(rehydratedStore.plansStore.planSummaries.count, 1)
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
        seededStore.send(.completeOnboarding(nil))

        let plan = makeSingleTemplatePlan(
            name: "Deferred Plan",
            templateName: "Upper 1",
            store: seededStore,
            weight: 185
        )
        seededStore.send(.savePlan(plan))
        await seededStore.flushPendingPlanPersistence()

        let rehydratedStore = makeStore(container: container)
        await rehydratedStore.hydrateIfNeeded()

        XCTAssertFalse(rehydratedStore.plansStore.hasLoadedPlanLibrary)
        XCTAssertEqual(rehydratedStore.plansStore.planCount, 1)
        XCTAssertEqual(rehydratedStore.plansStore.templateReferenceCount, 1)

        let loadedPlan = try XCTUnwrap(rehydratedStore.plansStore.plan(for: plan.id))
        let templateID = try XCTUnwrap(loadedPlan.templates.first?.id)
        rehydratedStore.send(.startSession(planID: loadedPlan.id, templateID: templateID))

        XCTAssertEqual(rehydratedStore.sessionStore.activeDraft?.templateNameSnapshot, "Upper 1")
    }

    @MainActor
    func testStartupHydrationLoadsProfilesAlongsidePlanSummaries() async throws {
        let container = WorkoutModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let seededStore = makeStore(container: container)
        await seededStore.hydrateIfNeeded()
        seededStore.send(.completeOnboarding(nil))

        let profile = ExerciseProfile(
            exerciseID: CatalogSeed.benchPress,
            trainingMax: 235,
            preferredIncrement: 5
        )
        seededStore.send(.saveProfiles([profile]))
        await seededStore.flushPendingPlanPersistence()

        let rehydratedStore = makeStore(container: container)
        await rehydratedStore.hydrateIfNeeded()

        XCTAssertEqual(rehydratedStore.plansStore.profiles.count, 1)
        XCTAssertEqual(rehydratedStore.plansStore.profileCount, 1)

        let loadedProfile = try XCTUnwrap(rehydratedStore.plansStore.profile(for: CatalogSeed.benchPress))

        XCTAssertEqual(loadedProfile.trainingMax, 235)
        XCTAssertEqual(loadedProfile.preferredIncrement, 5)
        XCTAssertEqual(rehydratedStore.plansStore.profiles.count, 1)
        XCTAssertEqual(rehydratedStore.plansStore.profileCount, 1)
    }

    @MainActor
    func testStartingSessionAfterStartupHydrationUsesHydratedProfiles() async throws {
        let container = WorkoutModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let seededStore = makeStore(container: container)
        await seededStore.hydrateIfNeeded()
        seededStore.send(.completeOnboarding(nil))

        var plan = seededStore.makePlan(name: "Wave Bench")
        let template = WorkoutTemplate(
            name: "Bench Day",
            exercises: [
                TemplateExercise(
                    exerciseID: CatalogSeed.benchPress,
                    exerciseNameSnapshot: seededStore.plansStore.exerciseName(for: CatalogSeed.benchPress),
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

        let profile = ExerciseProfile(
            exerciseID: CatalogSeed.benchPress,
            trainingMax: 235,
            preferredIncrement: 5
        )

        seededStore.send(.savePlan(plan))
        seededStore.send(.saveProfiles([profile]))
        await seededStore.flushPendingPlanPersistence()

        let rehydratedStore = makeStore(container: container)
        await rehydratedStore.hydrateIfNeeded()

        XCTAssertEqual(rehydratedStore.plansStore.profiles.count, 1)
        XCTAssertEqual(rehydratedStore.plansStore.profileCount, 1)

        rehydratedStore.send(.startSession(planID: plan.id, templateID: template.id))

        let startedBlock = try XCTUnwrap(rehydratedStore.sessionStore.activeDraft?.exercises.first)
        let workingTargets = startedBlock.sets
            .filter { $0.target.setKind == .working }
            .compactMap(\.target.targetWeight)

        XCTAssertEqual(workingTargets, [152.5, 177.5, 200])
        XCTAssertEqual(rehydratedStore.plansStore.profiles.count, 1)
    }

    @MainActor
    func testEmptySessionDoesNotFinishOrPersist() async throws {
        let store = makeStore()
        await store.hydrateIfNeeded()
        store.send(.completeOnboarding(nil))

        let plan = makeSingleTemplatePlan(
            name: "Test Plan",
            templateName: "Upper 1",
            store: store,
            weight: 185
        )
        store.send(.savePlan(plan))
        let templateID = try XCTUnwrap(plan.templates.first?.id)

        store.send(.startSession(planID: plan.id, templateID: templateID))

        XCTAssertFalse(store.send(.finishActiveSession))
        XCTAssertNotNil(store.sessionStore.activeDraft)
        XCTAssertTrue(store.sessionStore.completedSessions.isEmpty)
    }

    @MainActor
    func testWarmupOnlySessionDoesNotFinishOrPersist() async throws {
        let store = makeStore()
        await store.hydrateIfNeeded()
        store.send(.completeOnboarding(nil))

        let plan = makeSingleTemplatePlan(
            name: "Test Plan",
            templateName: "Upper 1",
            store: store,
            weight: 185
        )
        store.send(.savePlan(plan))
        let templateID = try XCTUnwrap(plan.templates.first?.id)

        store.send(.startSession(planID: plan.id, templateID: templateID))

        let block = try XCTUnwrap(store.sessionStore.activeDraft?.exercises.first)
        let warmupRow = try XCTUnwrap(block.sets.first(where: { $0.target.setKind == .warmup }))
        store.send(.toggleSetCompletion(blockID: block.id, setID: warmupRow.id))

        XCTAssertFalse(store.send(.finishActiveSession))
        XCTAssertNotNil(store.sessionStore.activeDraft)
        XCTAssertTrue(store.sessionStore.completedSessions.isEmpty)
    }

    @MainActor
    func testExerciseRenamePreservesAnalyticsContinuityAndSnapshots() async throws {
        let store = makeStore()
        await store.hydrateIfNeeded()
        store.send(.completeOnboarding(nil))

        let plan = makeSingleTemplatePlan(
            name: "Pressing",
            templateName: "Bench Day",
            store: store,
            weight: 185
        )
        store.send(.savePlan(plan))
        store.send(.startSession(planID: plan.id, templateID: try XCTUnwrap(plan.templates.first?.id)))

        let draft = try XCTUnwrap(store.sessionStore.activeDraft)
        let block = try XCTUnwrap(draft.exercises.first)
        let row = try XCTUnwrap(block.sets.first(where: { $0.target.setKind == .working }))

        store.send(.toggleSetCompletion(blockID: block.id, setID: row.id))
        store.send(.finishActiveSession)

        store.send(.updateCatalogItem(
            itemID: CatalogSeed.benchPress,
            name: "Competition Bench Press",
            aliases: ["Barbell Bench"],
            category: .chest
        ))
        await store.refreshDerivedStores()

        let summary = try XCTUnwrap(
            store.progressStore.exerciseSummaries.first(where: { $0.exerciseID == CatalogSeed.benchPress })
        )

        XCTAssertEqual(summary.displayName, "Competition Bench Press")
        XCTAssertEqual(summary.pointCount, 1)
        XCTAssertEqual(store.sessionStore.completedSessions.first?.exercises.first?.exerciseNameSnapshot, "Bench Press")
        XCTAssertTrue(store.plansStore.exerciseItem(for: CatalogSeed.benchPress)?.aliases.contains("Bench Press") == true)
    }

    @MainActor
    func testExerciseRenameUpdatesTemplateAndActiveDraftSnapshots() async throws {
        let store = makeStore()
        await store.hydrateIfNeeded()
        store.send(.completeOnboarding(nil))

        let plan = makeSingleTemplatePlan(
            name: "Pressing",
            templateName: "Bench Day",
            store: store,
            weight: 185
        )
        store.send(.savePlan(plan))
        let templateID = try XCTUnwrap(plan.templates.first?.id)

        store.send(.startSession(planID: plan.id, templateID: templateID))
        store.send(.updateCatalogItem(
            itemID: CatalogSeed.benchPress,
            name: "Competition Bench Press",
            aliases: ["Barbell Bench"],
            category: .chest
        ))

        let updatedPlan = try XCTUnwrap(store.plansStore.plan(for: plan.id))

        XCTAssertEqual(updatedPlan.templates.first?.exercises.first?.exerciseNameSnapshot, "Competition Bench Press")
        XCTAssertEqual(store.sessionStore.activeDraft?.exercises.first?.exerciseNameSnapshot, "Competition Bench Press")
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
        store.send(.completeOnboarding(nil))

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
        store.send(.savePlan(firstPlan))
        store.send(.savePlan(secondPlan))

        let firstTemplateID = try XCTUnwrap(firstPlan.templates.first?.id)
        let secondTemplateID = try XCTUnwrap(secondPlan.templates.first?.id)

        store.send(.startSession(planID: firstPlan.id, templateID: firstTemplateID))
        store.send(.startSession(planID: secondPlan.id, templateID: secondTemplateID))

        XCTAssertEqual(store.sessionStore.activeDraft?.templateID, firstTemplateID)
        XCTAssertEqual(store.sessionStore.activeDraft?.templateNameSnapshot, "Bench Day")
        XCTAssertNil(store.plansStore.plan(for: secondPlan.id)?.templates.first?.lastStartedAt)

        store.send(.replaceActiveSessionAndStart(planID: secondPlan.id, templateID: secondTemplateID))

        XCTAssertEqual(store.sessionStore.activeDraft?.templateID, secondTemplateID)
        XCTAssertEqual(store.sessionStore.activeDraft?.templateNameSnapshot, "Press Day")
        XCTAssertNotNil(store.plansStore.plan(for: secondPlan.id)?.templates.first?.lastStartedAt)
    }
}
