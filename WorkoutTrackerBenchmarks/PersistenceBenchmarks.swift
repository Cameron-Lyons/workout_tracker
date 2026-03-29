import SwiftData
import XCTest

@testable import WorkoutTracker

@MainActor
final class PersistenceBenchmarks: BenchmarkTestCase {
    private enum Thresholds {
        static let planRepositorySavePlansLargeLibrary = BenchmarkThreshold(
            measuredIterationCount: 3,
            averageSecondsUpperBound: 2.050,
            maxSecondsUpperBound: 2.250
        )
        static let planRepositoryLoadPlansLargeLibrary = BenchmarkThreshold(
            measuredIterationCount: 3,
            averageSecondsUpperBound: 2.200,
            maxSecondsUpperBound: 2.400
        )
        static let sessionRepositorySaveActiveDraftLargeSession = BenchmarkThreshold(
            measuredIterationCount: 3,
            averageSecondsUpperBound: 0.035,
            maxSecondsUpperBound: 0.045
        )
        static let sessionRepositoryLoadActiveDraftLargeSession = BenchmarkThreshold(
            measuredIterationCount: 3,
            averageSecondsUpperBound: 0.030,
            maxSecondsUpperBound: 0.040
        )
        static let sessionRepositoryPersistCompletedSessionLargeSession = BenchmarkThreshold(
            measuredIterationCount: 3,
            averageSecondsUpperBound: 0.035,
            maxSecondsUpperBound: 0.045
        )
        static let sessionRepositoryLoadCompletedSessions = BenchmarkThreshold(
            measuredIterationCount: 3,
            averageSecondsUpperBound: 0.950,
            maxSecondsUpperBound: 1.050
        )
    }

    func testPlanRepositorySavePlansLargeLibrary() {
        let plans = WorkoutBenchmarkFixtures.makePlans(
            planCount: 120,
            templatesPerPlan: 4,
            blocksPerTemplate: 5,
            targetsPerBlock: 6
        )

        benchmark(
            named: "Plan repository savePlans / large library",
            threshold: Thresholds.planRepositorySavePlansLargeLibrary,
            setup: {
                let container = WorkoutModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
                let context = ModelContext(container)
                context.autosaveEnabled = false
                let repository = PlanRepository(modelContext: context)
                XCTAssertTrue(repository.saveCatalog(WorkoutBenchmarkFixtures.catalog))
                return repository
            },
            operation: { repository in
                XCTAssertTrue(repository.savePlans(plans))
            }
        )
    }

    func testPlanRepositoryLoadPlansLargeLibrary() {
        let container = WorkoutModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let seedContext = ModelContext(container)
        seedContext.autosaveEnabled = false
        let seedRepository = PlanRepository(modelContext: seedContext)
        let plans = WorkoutBenchmarkFixtures.makePlans(
            planCount: 120,
            templatesPerPlan: 4,
            blocksPerTemplate: 5,
            targetsPerBlock: 6
        )

        XCTAssertTrue(seedRepository.savePlans(plans))

        var loadedPlans: [Plan] = []
        benchmark(
            named: "Plan repository loadPlans / large library",
            threshold: Thresholds.planRepositoryLoadPlansLargeLibrary
        ) {
            autoreleasepool {
                let context = ModelContext(container)
                context.autosaveEnabled = false
                loadedPlans = PlanRepository(modelContext: context).loadPlans()
            }
        }

        XCTAssertEqual(loadedPlans.count, plans.count)
        XCTAssertEqual(loadedPlans.reduce(0) { $0 + $1.templates.count }, plans.count * 4)
    }

    func testSessionRepositorySaveActiveDraftLargeSession() {
        let plan = WorkoutBenchmarkFixtures.makeProgressivePlan(
            blockCount: 18,
            targetsPerBlock: 6
        )
        let template = plan.templates[0]
        let profiles = WorkoutBenchmarkFixtures.makeProfiles()
        let draft = WorkoutBenchmarkFixtures.makeDraft(
            planID: plan.id,
            template: template,
            profiles: profiles
        )

        benchmark(
            named: "Session repository saveActiveDraft / large session",
            threshold: Thresholds.sessionRepositorySaveActiveDraftLargeSession,
            setup: {
                let container = WorkoutModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
                let context = ModelContext(container)
                context.autosaveEnabled = false
                let repository = SessionRepository(modelContext: context)
                return repository
            },
            operation: { repository in
                XCTAssertTrue(repository.saveActiveDraft(draft))
            }
        )
    }

    func testSessionRepositoryLoadActiveDraftLargeSession() {
        let container = WorkoutModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let plan = WorkoutBenchmarkFixtures.makeProgressivePlan(
            blockCount: 18,
            targetsPerBlock: 6
        )
        let template = plan.templates[0]
        let profiles = WorkoutBenchmarkFixtures.makeProfiles()
        let draft = WorkoutBenchmarkFixtures.makeDraft(
            planID: plan.id,
            template: template,
            profiles: profiles
        )

        XCTAssertTrue(
            WorkoutBenchmarkFixtures.seedContainer(
                container,
                plans: [plan],
                profiles: profiles,
                activeDraft: draft
            )
        )

        var loadedDraft: SessionDraft?
        benchmark(
            named: "Session repository loadActiveDraft / large session",
            threshold: Thresholds.sessionRepositoryLoadActiveDraftLargeSession,
            setup: {
                let context = ModelContext(container)
                context.autosaveEnabled = false
                return SessionRepository(modelContext: context)
            },
            operation: { repository in
                autoreleasepool {
                    loadedDraft = repository.loadActiveDraft()
                }
            }
        )

        XCTAssertEqual(loadedDraft?.blocks.count, draft.blocks.count)
        XCTAssertEqual(
            loadedDraft?.blocks.reduce(0) { partialResult, block in partialResult + block.sets.count },
            draft.blocks.reduce(0) { partialResult, block in partialResult + block.sets.count }
        )
    }

    func testSessionRepositoryPersistCompletedSessionLargeSession() {
        let plan = WorkoutBenchmarkFixtures.makeProgressivePlan(
            blockCount: 18,
            targetsPerBlock: 6
        )
        let template = plan.templates[0]
        let profiles = WorkoutBenchmarkFixtures.makeProfiles()
        let draft = WorkoutBenchmarkFixtures.completedDraft(
            from: WorkoutBenchmarkFixtures.makeDraft(
                planID: plan.id,
                template: template,
                profiles: profiles
            )
        )
        let completedSession = SessionEngine.finishSession(
            draft: draft,
            completedAt: WorkoutBenchmarkFixtures.referenceNow
        )

        benchmark(
            named: "Session repository persistCompletedSession / large session",
            threshold: Thresholds.sessionRepositoryPersistCompletedSessionLargeSession,
            setup: {
                let container = WorkoutModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
                let context = ModelContext(container)
                context.autosaveEnabled = false
                let repository = SessionRepository(modelContext: context)
                return repository
            },
            operation: { repository in
                XCTAssertTrue(repository.persistCompletedSessionAndClearActiveDraft(completedSession))
            }
        )
    }

    func testSessionRepositoryLoadCompletedSessionsLargeHistory() {
        let container = WorkoutModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let seedContext = ModelContext(container)
        seedContext.autosaveEnabled = false
        let seedRepository = SessionRepository(modelContext: seedContext)
        let sessions = WorkoutBenchmarkFixtures.makeCompletedSessions(
            sessionCount: 240,
            blocksPerSession: 4,
            setsPerBlock: 6
        )

        for session in sessions {
            XCTAssertTrue(seedRepository.persistCompletedSessionAndClearActiveDraft(session))
        }

        var loadedSessions: [CompletedSession] = []
        benchmark(
            named: "Session repository loadCompletedSessions / large history",
            threshold: Thresholds.sessionRepositoryLoadCompletedSessions
        ) {
            autoreleasepool {
                let context = ModelContext(container)
                context.autosaveEnabled = false
                loadedSessions = SessionRepository(modelContext: context).loadCompletedSessions()
            }
        }

        XCTAssertEqual(loadedSessions.count, sessions.count)
        XCTAssertEqual(loadedSessions.first?.completedAt, sessions.first?.completedAt)
    }
}
