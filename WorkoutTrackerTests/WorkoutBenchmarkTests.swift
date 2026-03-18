import SwiftData
import XCTest

@testable import WorkoutTracker

final class WorkoutBenchmarkTests: XCTestCase {
    private let analytics = AnalyticsRepository()

    func testBenchmarkSessionAnalyticsSnapshotLargeHistory() {
        let sessions = WorkoutBenchmarkFixtures.makeCompletedSessions(
            sessionCount: 500,
            blocksPerSession: 4,
            setsPerBlock: 6
        )
        var snapshot: AnalyticsRepository.SessionAnalyticsSnapshot?

        measure(metrics: [XCTClockMetric()], options: benchmarkOptions()) {
            snapshot = analytics.makeSessionAnalyticsSnapshot(
                sessions: sessions,
                catalogByID: WorkoutBenchmarkFixtures.catalogByID,
                now: WorkoutBenchmarkFixtures.referenceNow
            )
        }

        XCTAssertEqual(snapshot?.overview.totalSessions, sessions.count)
        XCTAssertEqual(snapshot?.exerciseSummaries.count, WorkoutBenchmarkFixtures.catalog.count)
        XCTAssertFalse(snapshot?.personalRecords.isEmpty ?? true)
    }

    func testBenchmarkProgressStorePrepareStateLargeHistory() {
        let sessions = WorkoutBenchmarkFixtures.makeCompletedSessions(
            sessionCount: 500,
            blocksPerSession: 4,
            setsPerBlock: 6
        )
        let sessionAnalytics = analytics.makeSessionAnalyticsSnapshot(
            sessions: sessions,
            catalogByID: WorkoutBenchmarkFixtures.catalogByID,
            now: WorkoutBenchmarkFixtures.referenceNow
        )
        let progressSnapshot = analytics.makeProgressSnapshot(
            sessionAnalytics: sessionAnalytics,
            selectedExerciseID: WorkoutBenchmarkFixtures.catalog.first?.id
        )
        let selectedDay = sessions[sessions.count / 2].completedAt
        var preparedState: ProgressStore.PreparedState?

        measure(metrics: [XCTClockMetric()], options: benchmarkOptions()) {
            preparedState = ProgressStore.prepareState(
                progressSnapshot,
                completedSessions: sessions,
                selectedDay: selectedDay
            )
        }

        XCTAssertEqual(preparedState?.overview.totalSessions, sessions.count)
        XCTAssertFalse(preparedState?.historySessions.isEmpty ?? true)
        XCTAssertEqual(preparedState?.exerciseSummaries.count, WorkoutBenchmarkFixtures.catalog.count)
    }

    func testBenchmarkPlanRepositoryLoadPlansLargeLibrary() {
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
        measure(metrics: [XCTClockMetric()], options: benchmarkOptions(iterationCount: 3)) {
            autoreleasepool {
                let context = ModelContext(container)
                context.autosaveEnabled = false
                loadedPlans = PlanRepository(modelContext: context).loadPlans()
            }
        }

        XCTAssertEqual(loadedPlans.count, plans.count)
        XCTAssertEqual(loadedPlans.reduce(0) { $0 + $1.templates.count }, plans.count * 4)
    }

    func testBenchmarkSessionRepositoryLoadCompletedSessionsLargeHistory() {
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
        measure(metrics: [XCTClockMetric()], options: benchmarkOptions(iterationCount: 3)) {
            autoreleasepool {
                let context = ModelContext(container)
                context.autosaveEnabled = false
                loadedSessions = SessionRepository(modelContext: context).loadCompletedSessions()
            }
        }

        XCTAssertEqual(loadedSessions.count, sessions.count)
        XCTAssertEqual(loadedSessions.first?.completedAt, sessions.first?.completedAt)
    }

    private func benchmarkOptions(iterationCount: Int = 5) -> XCTMeasureOptions {
        let options = XCTMeasureOptions()
        options.iterationCount = iterationCount
        return options
    }
}

private enum WorkoutBenchmarkFixtures {
    static let referenceNow = Date(timeIntervalSinceReferenceDate: 765_432_100)
    static let catalog = Array(CatalogSeed.defaultCatalog().prefix(12))
    static let catalogByID = Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, $0) })

    private static let weekdayPatterns: [[Weekday]] = [
        [.monday, .thursday],
        [.tuesday, .friday],
        [.wednesday, .saturday],
        [.monday, .wednesday, .friday],
    ]

    static func makeCompletedSessions(
        sessionCount: Int,
        blocksPerSession: Int,
        setsPerBlock: Int
    ) -> [CompletedSession] {
        var sessions: [CompletedSession] = []
        sessions.reserveCapacity(sessionCount)

        for sessionIndex in 0..<sessionCount {
            let completedAt = referenceNow.addingTimeInterval(TimeInterval(sessionIndex - sessionCount) * 86_400)
            let blocks = (0..<blocksPerSession).map { blockIndex in
                makeCompletedBlock(
                    sessionIndex: sessionIndex,
                    blockIndex: blockIndex,
                    setsPerBlock: setsPerBlock,
                    completedAt: completedAt
                )
            }

            sessions.append(
                CompletedSession(
                    planID: UUID(),
                    templateID: UUID(),
                    templateNameSnapshot: "Benchmark Template \(sessionIndex % 8)",
                    startedAt: completedAt.addingTimeInterval(-3_600),
                    completedAt: completedAt,
                    blocks: blocks
                )
            )
        }

        return sessions
    }

    static func makePlans(
        planCount: Int,
        templatesPerPlan: Int,
        blocksPerTemplate: Int,
        targetsPerBlock: Int
    ) -> [Plan] {
        (0..<planCount).map { planIndex in
            let templates = (0..<templatesPerPlan).map { templateIndex in
                WorkoutTemplate(
                    name: "Benchmark Template \(planIndex)-\(templateIndex)",
                    scheduledWeekdays: weekdayPatterns[(planIndex + templateIndex) % weekdayPatterns.count],
                    blocks: (0..<blocksPerTemplate).map { blockIndex in
                        makeExerciseBlock(
                            planIndex: planIndex,
                            templateIndex: templateIndex,
                            blockIndex: blockIndex,
                            targetsPerBlock: targetsPerBlock
                        )
                    },
                    lastStartedAt: referenceNow.addingTimeInterval(
                        TimeInterval(-((planIndex * templatesPerPlan) + templateIndex) * 86_400)
                    )
                )
            }

            return Plan(
                name: "Benchmark Plan \(planIndex)",
                createdAt: referenceNow.addingTimeInterval(TimeInterval(-planIndex * 86_400)),
                pinnedTemplateID: templates.first?.id,
                templates: templates
            )
        }
    }

    private static func makeCompletedBlock(
        sessionIndex: Int,
        blockIndex: Int,
        setsPerBlock: Int,
        completedAt: Date
    ) -> CompletedSessionBlock {
        let exercise = catalog[(sessionIndex + blockIndex) % catalog.count]
        let baseWeight = 95.0 + Double(((sessionIndex * 3) + blockIndex) % 20) * 5
        let sets = (0..<setsPerBlock).map { setIndex in
            makeCompletedRow(
                sessionIndex: sessionIndex,
                setIndex: setIndex,
                baseWeight: baseWeight,
                completedAt: completedAt
            )
        }

        return CompletedSessionBlock(
            exerciseID: exercise.id,
            exerciseNameSnapshot: exercise.name,
            blockNote: "",
            restSeconds: 90,
            supersetGroup: nil,
            progressionRule: .manual,
            sets: sets
        )
    }

    private static func makeCompletedRow(
        sessionIndex: Int,
        setIndex: Int,
        baseWeight: Double,
        completedAt: Date
    ) -> SessionSetRow {
        let setKind: SetKind = setIndex == 0 ? .warmup : .working
        let targetWeight = setKind == .warmup ? baseWeight * 0.6 : baseWeight + Double(setIndex - 1) * 5
        let reps = setKind == .warmup ? 8 : 5 + ((sessionIndex + setIndex) % 4)
        let target = SetTarget(
            setKind: setKind,
            targetWeight: targetWeight,
            repRange: RepRange(reps, reps),
            restSeconds: 90
        )

        return SessionSetRow(
            target: target,
            log: SetLog(
                setTargetID: target.id,
                weight: targetWeight,
                reps: reps,
                completedAt: completedAt
            )
        )
    }

    private static func makeExerciseBlock(
        planIndex: Int,
        templateIndex: Int,
        blockIndex: Int,
        targetsPerBlock: Int
    ) -> ExerciseBlock {
        let exercise = catalog[(planIndex + templateIndex + blockIndex) % catalog.count]
        let baseWeight = 115.0 + Double(((planIndex + templateIndex + blockIndex) % 16) * 5)
        let targets = (0..<targetsPerBlock).map { targetIndex in
            let targetWeight = baseWeight + Double(targetIndex) * 5
            let reps = 5 + ((planIndex + targetIndex) % 3)

            return SetTarget(
                targetWeight: targetWeight,
                repRange: RepRange(reps, reps + 1),
                restSeconds: 90
            )
        }

        return ExerciseBlock(
            exerciseID: exercise.id,
            exerciseNameSnapshot: exercise.name,
            restSeconds: 90,
            progressionRule: .manual,
            targets: targets
        )
    }
}
