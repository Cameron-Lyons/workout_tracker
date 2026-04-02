import SwiftData
import XCTest

@testable import WorkoutTracker

@MainActor
final class AppFlowBenchmarks: BenchmarkTestCase {
    private enum Thresholds {
        static let sessionEngineStartSessionLargeTemplate = BenchmarkThreshold(
            measuredIterationCount: 5,
            averageSecondsUpperBound: 0.001,
            maxSecondsUpperBound: 0.002
        )
        static let appStoreStartSessionAfterStartupHydrationLargeLibrary = BenchmarkThreshold(
            measuredIterationCount: 5,
            averageSecondsUpperBound: 0.080,
            maxSecondsUpperBound: 0.100
        )
        static let appStoreFinishActiveSessionLargeProgressionSession = BenchmarkThreshold(
            measuredIterationCount: 3,
            averageSecondsUpperBound: 0.080,
            maxSecondsUpperBound: 0.100
        )
        static let appStorePreloadDeferredTabDataLargeLibraryAndHistory = BenchmarkThreshold(
            measuredIterationCount: 3,
            averageSecondsUpperBound: 2.300,
            maxSecondsUpperBound: 2.450
        )
        static let persistenceHydrationLoaderLoadStartupSnapshotLargeLibrary = BenchmarkThreshold(
            measuredIterationCount: 3,
            averageSecondsUpperBound: 0.120,
            maxSecondsUpperBound: 0.150
        )
        static let persistenceHydrationLoaderLoadCompletedSessionHistoryLargeHistory = BenchmarkThreshold(
            measuredIterationCount: 3,
            averageSecondsUpperBound: 0.950,
            maxSecondsUpperBound: 1.050
        )
        static let appDerivedStateControllerRefreshDerivedStoresLargeLibraryAndHistory = BenchmarkThreshold(
            measuredIterationCount: 3,
            averageSecondsUpperBound: 0.035,
            maxSecondsUpperBound: 0.045
        )
        static let sessionStoreMutateAndFlushActiveDraftLargeSession = BenchmarkThreshold(
            measuredIterationCount: 5,
            averageSecondsUpperBound: 0.120,
            maxSecondsUpperBound: 0.150
        )
        static let sessionStoreUndoLastMutationsLargeSession = BenchmarkThreshold(
            measuredIterationCount: 5,
            averageSecondsUpperBound: 0.380,
            maxSecondsUpperBound: 0.420
        )
        static let appDerivedStateControllerRecordCompletedSessionLargeLibraryAndHistory = BenchmarkThreshold(
            measuredIterationCount: 5,
            averageSecondsUpperBound: 0.015,
            maxSecondsUpperBound: 0.020
        )
    }

    private struct SessionMutationBenchmarkFixture {
        let sessionStore: SessionStore
        let mutationTargets: [(blockID: UUID, setID: UUID)]
        let firstBlockID: UUID
        let expansionBlockID: UUID
    }

    private struct IncrementalDerivedStateBenchmarkFixture {
        let controller: AppDerivedStateController
        let plansStore: PlansStore
        let sessionStore: SessionStore
        let todayStore: TodayStore
        let progressStore: ProgressStore
        let completedSession: CompletedSession
        let finishSummary: SessionFinishSummary
        let payloads: [SessionExercisePayload]
        let expectedSessionCount: Int
    }

    func testSessionEngineStartSessionLargeTemplate() {
        let plan = WorkoutBenchmarkFixtures.makeProgressivePlan(
            blockCount: 18,
            targetsPerBlock: 6
        )
        let template = plan.templates[0]
        let profiles = WorkoutBenchmarkFixtures.makeProfiles()
        let profilesByExerciseID = Dictionary(uniqueKeysWithValues: profiles.map { ($0.exerciseID, $0) })
        var draft: SessionDraft?

        benchmark(
            named: "Session engine startSession / large template",
            threshold: Thresholds.sessionEngineStartSessionLargeTemplate
        ) {
            draft = SessionEngine.startSession(
                planID: plan.id,
                template: template,
                profilesByExerciseID: profilesByExerciseID,
                warmupRamp: WarmupDefaults.ramp,
                startedAt: WorkoutBenchmarkFixtures.referenceNow
            )
        }

        XCTAssertEqual(draft?.blocks.count, template.blocks.count)
        XCTAssertFalse(draft?.blocks.isEmpty ?? true)
    }

    func testAppStoreStartSessionAfterStartupHydrationLargeLibrary() async {
        let plans = WorkoutBenchmarkFixtures.makePlans(
            planCount: 120,
            templatesPerPlan: 4,
            blocksPerTemplate: 5,
            targetsPerBlock: 6
        )
        let profiles = WorkoutBenchmarkFixtures.makeProfiles()
        let progressivePlan = WorkoutBenchmarkFixtures.makeProgressivePlan(
            blockCount: 18,
            targetsPerBlock: 6,
            name: "Deferred Session Plan",
            templateName: "Deferred Session Day"
        )
        let template = progressivePlan.templates[0]
        let seededPlans = plans + [progressivePlan]

        await benchmark(
            named: "App store startSession after startup hydration / deferred plan library",
            threshold: Thresholds.appStoreStartSessionAfterStartupHydrationLargeLibrary,
            setup: {
                let container = WorkoutModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
                XCTAssertTrue(
                    WorkoutBenchmarkFixtures.seedContainer(
                        container,
                        plans: seededPlans,
                        profiles: profiles
                    )
                )

                let store = self.makeBenchmarkAppStore(container: container)
                await store.hydrateIfNeeded()
                store.completeOnboarding(with: nil)
                XCTAssertFalse(store.plansStore.hasLoadedPlanLibrary)
                XCTAssertEqual(store.plansStore.profiles.count, profiles.count)
                return store
            },
            operation: { store in
                store.startSession(planID: progressivePlan.id, templateID: template.id)
                store.flushPendingSessionPersistence()

                XCTAssertEqual(store.sessionStore.activeDraft?.blocks.count, template.blocks.count)
                XCTAssertEqual(store.plansStore.profiles.count, profiles.count)
            }
        )
    }

    func testAppStoreFinishActiveSessionLargeProgressionSession() async {
        let plan = WorkoutBenchmarkFixtures.makeProgressivePlan(
            blockCount: 12,
            targetsPerBlock: 5
        )
        let template = plan.templates[0]
        let profiles = WorkoutBenchmarkFixtures.makeProfiles()

        await benchmark(
            named: "App store finishActiveSession / large progression session",
            threshold: Thresholds.appStoreFinishActiveSessionLargeProgressionSession,
            setup: {
                let store = self.makeBenchmarkAppStore()
                await store.hydrateIfNeeded()
                store.completeOnboarding(with: nil)
                store.savePlan(plan)
                store.saveProfiles(profiles)
                store.flushPendingPlanPersistence()

                let draft = WorkoutBenchmarkFixtures.completedDraft(
                    from: WorkoutBenchmarkFixtures.makeDraft(
                        planID: plan.id,
                        template: template,
                        profiles: profiles
                    )
                )
                store.sessionStore.beginSession(draft)
                store.flushPendingSessionPersistence()
                return store
            },
            operation: { store in
                XCTAssertTrue(store.finishActiveSession())
                store.flushPendingPlanPersistence()
                store.flushPendingSessionPersistence()
            }
        )
    }

    func testAppStorePreloadDeferredTabDataLargeLibraryAndHistory() async {
        let plans = WorkoutBenchmarkFixtures.makePlans(
            planCount: 120,
            templatesPerPlan: 4,
            blocksPerTemplate: 5,
            targetsPerBlock: 6
        )
        let profiles = WorkoutBenchmarkFixtures.makeProfiles()
        let completedSessions = WorkoutBenchmarkFixtures.makeCompletedSessions(
            from: plans,
            profiles: profiles,
            sessionCount: 500
        )

        await benchmark(
            named: "App store preloadDeferredTabDataIfNeeded / deferred history with summary-backed plans",
            threshold: Thresholds.appStorePreloadDeferredTabDataLargeLibraryAndHistory,
            setup: {
                let container = WorkoutModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
                XCTAssertTrue(
                    WorkoutBenchmarkFixtures.seedContainer(
                        container,
                        plans: plans,
                        profiles: profiles,
                        completedSessions: completedSessions
                    )
                )

                let store = self.makeBenchmarkAppStore(container: container)
                await store.hydrateIfNeeded()
                store.completeOnboarding(with: nil)
                XCTAssertFalse(store.plansStore.hasLoadedPlanLibrary)
                XCTAssertFalse(store.sessionStore.hasLoadedCompletedSessionHistory)
                return store
            },
            operation: { store in
                await store.preloadDeferredTabDataIfNeeded(priority: .utility)

                XCTAssertFalse(store.plansStore.hasLoadedPlanLibrary)
                XCTAssertEqual(store.plansStore.planSummaries.count, plans.count)
                XCTAssertTrue(store.sessionStore.hasLoadedCompletedSessionHistory)
                XCTAssertEqual(store.sessionStore.completedSessions.count, completedSessions.count)
                XCTAssertEqual(store.progressStore.overview.totalSessions, completedSessions.count)
            }
        )
    }

    func testPersistenceHydrationLoaderLoadStartupSnapshotLargeLibrary() async {
        let container = WorkoutModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let plans = WorkoutBenchmarkFixtures.makePlans(
            planCount: 120,
            templatesPerPlan: 4,
            blocksPerTemplate: 5,
            targetsPerBlock: 6
        )
        let profiles = WorkoutBenchmarkFixtures.makeProfiles()
        let progressivePlan = WorkoutBenchmarkFixtures.makeProgressivePlan(
            blockCount: 18,
            targetsPerBlock: 6
        )
        let draft = WorkoutBenchmarkFixtures.makeDraft(
            planID: progressivePlan.id,
            template: progressivePlan.templates[0],
            profiles: profiles
        )
        let seededPlans = plans + [progressivePlan]

        XCTAssertTrue(
            WorkoutBenchmarkFixtures.seedContainer(
                container,
                plans: seededPlans,
                profiles: profiles,
                activeDraft: draft
            )
        )

        await benchmark(
            named: "Persistence hydration loader loadStartupSnapshot / large library",
            threshold: Thresholds.persistenceHydrationLoaderLoadStartupSnapshotLargeLibrary,
            setup: {
                let planController = PlanPersistenceControllerRegistry.controller(for: container)
                let sessionController = SessionPersistenceControllerRegistry.controller(for: container)
                return PersistenceHydrationLoader(
                    modelContainer: container,
                    planPersistenceController: planController,
                    sessionPersistenceController: sessionController
                )
            },
            operation: { loader in
                let snapshot = await loader.loadStartupSnapshot()
                XCTAssertEqual(snapshot.plans.planSummaries?.count, seededPlans.count)
                XCTAssertFalse(snapshot.plans.includesFullPlanLibrary)
                XCTAssertTrue(snapshot.plans.plans.isEmpty)
                XCTAssertEqual(snapshot.sessions.activeDraft?.blocks.count, draft.blocks.count)
            }
        )
    }

    func testPersistenceHydrationLoaderLoadCompletedSessionHistoryLargeHistory() async {
        let container = WorkoutModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let completedSessions = WorkoutBenchmarkFixtures.makeCompletedSessions(
            sessionCount: 240,
            blocksPerSession: 4,
            setsPerBlock: 6
        )

        XCTAssertTrue(
            WorkoutBenchmarkFixtures.seedContainer(
                container,
                completedSessions: completedSessions
            )
        )

        await benchmark(
            named: "Persistence hydration loader loadCompletedSessionHistory / large history",
            threshold: Thresholds.persistenceHydrationLoaderLoadCompletedSessionHistoryLargeHistory,
            setup: {
                let planController = PlanPersistenceControllerRegistry.controller(for: container)
                let sessionController = SessionPersistenceControllerRegistry.controller(for: container)
                return PersistenceHydrationLoader(
                    modelContainer: container,
                    planPersistenceController: planController,
                    sessionPersistenceController: sessionController
                )
            },
            operation: { loader in
                let sessions = await loader.loadCompletedSessionHistory()
                XCTAssertEqual(sessions.count, completedSessions.count)
            }
        )
    }

    func testAppDerivedStateControllerRefreshDerivedStoresLargeLibraryAndHistory() async {
        let plans = WorkoutBenchmarkFixtures.makePlans(
            planCount: 120,
            templatesPerPlan: 4,
            blocksPerTemplate: 5,
            targetsPerBlock: 6
        )
        let profiles = WorkoutBenchmarkFixtures.makeProfiles()
        let completedSessions = WorkoutBenchmarkFixtures.makeCompletedSessions(
            from: plans,
            profiles: profiles,
            sessionCount: 500
        )

        await benchmark(
            named: "App derived state controller refreshDerivedStores / large library and history",
            threshold: Thresholds.appDerivedStateControllerRefreshDerivedStoresLargeLibraryAndHistory,
            setup: {
                let container = WorkoutModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
                let planController = PlanPersistenceControllerRegistry.controller(for: container)
                let sessionController = SessionPersistenceControllerRegistry.controller(for: container)
                let plansStore = PlansStore(persistenceController: planController)
                plansStore.hydrate(
                    with: PlansStore.HydrationSnapshot(
                        catalog: WorkoutBenchmarkFixtures.catalog,
                        plans: plans,
                        profiles: profiles
                    )
                )
                let context = ModelContext(container)
                context.autosaveEnabled = false
                let sessionStore = SessionStore(
                    repository: SessionRepository(modelContext: context),
                    persistenceController: sessionController
                )
                sessionStore.hydrate(
                    with: SessionStore.HydrationSnapshot(
                        activeDraft: nil,
                        completedSessions: completedSessions,
                        includesCompleteHistory: true
                    )
                )
                let todayStore = TodayStore()
                let progressStore = ProgressStore()
                let controller = AppDerivedStateController(
                    todayStore: todayStore,
                    progressStore: progressStore
                )
                return (controller, plansStore, sessionStore, todayStore, progressStore)
            },
            operation: { fixture in
                let (controller, plansStore, sessionStore, todayStore, progressStore) = fixture
                let didRefresh = await controller.refreshDerivedStores(
                    plansStore: plansStore,
                    sessionStore: sessionStore,
                    now: WorkoutBenchmarkFixtures.referenceNow
                )
                XCTAssertTrue(didRefresh)
                XCTAssertEqual(todayStore.recentSessions.count, AnalyticsDefaults.recentActivityLimit)
                XCTAssertEqual(progressStore.overview.totalSessions, completedSessions.count)
            }
        )
    }

    func testSessionStoreMutateAndFlushActiveDraftLargeSession() {
        benchmark(
            named: "Session store mutateActiveDraft + flush / large session",
            threshold: Thresholds.sessionStoreMutateAndFlushActiveDraftLargeSession,
            setup: {
                self.makeSessionMutationBenchmarkFixture()
            },
            operation: { fixture in
                let mutationCount = self.applyMutationBatch(to: fixture)
                fixture.sessionStore.flushPendingDraftSave()

                XCTAssertGreaterThan(mutationCount, 0)
                XCTAssertTrue(fixture.sessionStore.canUndo)
                XCTAssertNotNil(fixture.sessionStore.activeDraft)
            }
        )
    }

    func testSessionStoreUndoLastMutationsLargeSession() {
        benchmark(
            named: "Session store undoLastMutation + flush / large session",
            threshold: Thresholds.sessionStoreUndoLastMutationsLargeSession,
            setup: {
                let fixture = self.makeSessionMutationBenchmarkFixture()
                let mutationCount = self.applyMutationBatch(to: fixture)
                return (fixture, mutationCount)
            },
            operation: { fixture in
                let (sessionFixture, mutationCount) = fixture

                for _ in 0..<mutationCount {
                    sessionFixture.sessionStore.undoLastMutation()
                }
                sessionFixture.sessionStore.flushPendingDraftSave()

                XCTAssertFalse(sessionFixture.sessionStore.canUndo)
                XCTAssertNotNil(sessionFixture.sessionStore.activeDraft)
            }
        )
    }

    func testAppDerivedStateControllerRecordCompletedSessionLargeLibraryAndHistory() async {
        await benchmark(
            named: "App derived state controller recordCompletedSession / large library and history",
            threshold: Thresholds.appDerivedStateControllerRecordCompletedSessionLargeLibraryAndHistory,
            setup: {
                await self.makeIncrementalDerivedStateBenchmarkFixture()
            },
            operation: { fixture in
                fixture.controller.recordCompletedSession(
                    fixture.completedSession,
                    plansStore: fixture.plansStore,
                    sessionStore: fixture.sessionStore,
                    finishSummary: fixture.finishSummary,
                    payloads: fixture.payloads
                )

                XCTAssertEqual(fixture.progressStore.overview.totalSessions, fixture.expectedSessionCount)
                XCTAssertEqual(fixture.todayStore.recentSessions.first?.id, fixture.completedSession.id)
            }
        )
    }

    private func makeSessionMutationBenchmarkFixture() -> SessionMutationBenchmarkFixture {
        let container = WorkoutModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let sessionStore = SessionStore(
            repository: SessionRepository(modelContext: context),
            persistenceController: SessionPersistenceControllerRegistry.controller(for: container)
        )
        let plan = WorkoutBenchmarkFixtures.makeProgressivePlan(
            blockCount: 18,
            targetsPerBlock: 6
        )
        let draft = WorkoutBenchmarkFixtures.makeDraft(
            planID: plan.id,
            template: plan.templates[0],
            profiles: WorkoutBenchmarkFixtures.makeProfiles()
        )
        sessionStore.beginSession(draft)
        sessionStore.flushPendingDraftSave()

        let mutationTargets =
            sessionStore.activeDraft?.blocks.prefix(4).compactMap { block in
                block.sets.first(where: { $0.target.setKind == .working }).map { (block.id, $0.id) }
            } ?? []

        return SessionMutationBenchmarkFixture(
            sessionStore: sessionStore,
            mutationTargets: mutationTargets,
            firstBlockID: draft.blocks[0].id,
            expansionBlockID: draft.blocks[draft.blocks.count - 1].id
        )
    }

    @discardableResult
    private func applyMutationBatch(to fixture: SessionMutationBenchmarkFixture) -> Int {
        var mutationCount = 0

        for (index, target) in fixture.mutationTargets.enumerated() {
            let mutationDate = WorkoutBenchmarkFixtures.referenceNow.addingTimeInterval(Double(index))
            fixture.sessionStore.pushMutation(
                blockID: target.blockID,
                setID: target.setID,
                undoStrategy: .block(target.blockID),
                persistence: .deferred
            ) { draft, context in
                SessionEngine.adjustWeight(
                    by: 5,
                    setID: target.setID,
                    in: target.blockID,
                    draft: &draft,
                    context: context,
                    now: mutationDate
                )
            }
            mutationCount += 1

            fixture.sessionStore.pushMutation(
                blockID: target.blockID,
                setID: target.setID,
                undoStrategy: .block(target.blockID),
                persistence: .deferred
            ) { draft, context in
                SessionEngine.adjustReps(
                    by: 1,
                    setID: target.setID,
                    in: target.blockID,
                    draft: &draft,
                    context: context,
                    now: mutationDate
                )
            }
            mutationCount += 1

            fixture.sessionStore.pushMutation(
                blockID: target.blockID,
                setID: target.setID,
                undoStrategy: .block(target.blockID),
                persistence: .deferred
            ) { draft, context in
                SessionEngine.toggleCompletion(
                    of: target.setID,
                    in: target.blockID,
                    draft: &draft,
                    context: context,
                    completedAt: mutationDate
                )
            }
            mutationCount += 1
        }

        fixture.sessionStore.pushMutation(
            blockID: fixture.expansionBlockID,
            undoStrategy: .block(fixture.expansionBlockID),
            persistence: .deferred
        ) { draft, context in
            SessionEngine.addSet(
                to: fixture.expansionBlockID,
                draft: &draft,
                context: context,
                now: WorkoutBenchmarkFixtures.referenceNow
            )
        }
        mutationCount += 1

        fixture.sessionStore.pushMutation(
            blockID: fixture.expansionBlockID,
            undoStrategy: .block(fixture.expansionBlockID),
            persistence: .deferred
        ) { draft, context in
            SessionEngine.copyLastSet(
                in: fixture.expansionBlockID,
                draft: &draft,
                context: context,
                now: WorkoutBenchmarkFixtures.referenceNow
            )
        }
        mutationCount += 1

        fixture.sessionStore.pushMutation(
            blockID: fixture.firstBlockID,
            undoStrategy: .block(fixture.firstBlockID),
            persistence: .deferred
        ) { draft, context in
            SessionEngine.addSet(
                to: fixture.firstBlockID,
                draft: &draft,
                context: context,
                now: WorkoutBenchmarkFixtures.referenceNow
            )
        }
        mutationCount += 1

        return mutationCount
    }

    private func makeIncrementalDerivedStateBenchmarkFixture() async -> IncrementalDerivedStateBenchmarkFixture {
        let plans = WorkoutBenchmarkFixtures.makePlans(
            planCount: 120,
            templatesPerPlan: 4,
            blocksPerTemplate: 5,
            targetsPerBlock: 6
        )
        let profiles = WorkoutBenchmarkFixtures.makeProfiles()
        let baseSessions = WorkoutBenchmarkFixtures.makeCompletedSessions(
            from: plans,
            profiles: profiles,
            sessionCount: 500
        )
        let targetPlan = plans[0]
        let targetTemplate = targetPlan.templates[0]
        let completedAt = WorkoutBenchmarkFixtures.referenceNow.addingTimeInterval(3_600)
        let appendedSession = SessionEngine.finishSession(
            draft: WorkoutBenchmarkFixtures.completedDraft(
                from: WorkoutBenchmarkFixtures.makeDraft(
                    planID: targetPlan.id,
                    template: targetTemplate,
                    profiles: profiles,
                    startedAt: completedAt.addingTimeInterval(-3_600)
                ),
                completedAt: completedAt
            ),
            completedAt: completedAt
        )

        let container = WorkoutModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let planController = PlanPersistenceControllerRegistry.controller(for: container)
        let sessionController = SessionPersistenceControllerRegistry.controller(for: container)
        let plansStore = PlansStore(persistenceController: planController)
        plansStore.hydrate(
            with: PlansStore.HydrationSnapshot(
                catalog: WorkoutBenchmarkFixtures.catalog,
                plans: plans,
                profiles: profiles
            )
        )

        let context = ModelContext(container)
        context.autosaveEnabled = false
        let sessionStore = SessionStore(
            repository: SessionRepository(modelContext: context),
            persistenceController: sessionController
        )
        sessionStore.hydrate(
            with: SessionStore.HydrationSnapshot(
                activeDraft: nil,
                completedSessions: baseSessions,
                includesCompleteHistory: true
            )
        )

        let todayStore = TodayStore()
        let progressStore = ProgressStore()
        let controller = AppDerivedStateController(
            todayStore: todayStore,
            progressStore: progressStore
        )
        _ = await controller.refreshDerivedStores(
            plansStore: plansStore,
            sessionStore: sessionStore,
            now: WorkoutBenchmarkFixtures.referenceNow
        )

        let completedSessionResult = controller.completedSessionResult(
            for: appendedSession,
            catalogByID: plansStore.catalogByID
        )
        sessionStore.hydrate(
            with: SessionStore.HydrationSnapshot(
                activeDraft: nil,
                completedSessions: baseSessions + [appendedSession],
                includesCompleteHistory: true
            )
        )

        return IncrementalDerivedStateBenchmarkFixture(
            controller: controller,
            plansStore: plansStore,
            sessionStore: sessionStore,
            todayStore: todayStore,
            progressStore: progressStore,
            completedSession: appendedSession,
            finishSummary: completedSessionResult.finishSummary,
            payloads: completedSessionResult.payloads,
            expectedSessionCount: baseSessions.count + 1
        )
    }
}
