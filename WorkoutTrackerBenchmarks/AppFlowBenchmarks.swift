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
        static let appStoreFinishActiveSessionLargeProgressionSession = BenchmarkThreshold(
            measuredIterationCount: 3,
            averageSecondsUpperBound: 0.080,
            maxSecondsUpperBound: 0.100
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
            sessionCount: 500,
            blocksPerSession: 4,
            setsPerBlock: 6
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
}
