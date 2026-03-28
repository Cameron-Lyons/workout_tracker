import SwiftData
import XCTest

@testable import WorkoutTracker

@MainActor
final class WorkoutBenchmarkTests: XCTestCase {
    private enum Thresholds {
        static let sessionAnalyticsSnapshotLargeHistory = BenchmarkThreshold(
            iterationCount: 5,
            averageSecondsUpperBound: 0.040,
            maxSecondsUpperBound: 0.055
        )
        static let progressStorePrepareStateLargeHistory = BenchmarkThreshold(
            iterationCount: 5,
            averageSecondsUpperBound: 0.010,
            maxSecondsUpperBound: 0.020
        )
        static let planRepositoryLoadPlansLargeLibrary = BenchmarkThreshold(
            iterationCount: 3,
            averageSecondsUpperBound: 2.350,
            maxSecondsUpperBound: 2.700
        )
        static let sessionRepositoryLoadCompletedSessions = BenchmarkThreshold(
            iterationCount: 3,
            averageSecondsUpperBound: 1.100,
            maxSecondsUpperBound: 1.200
        )
    }

    private let analytics = AnalyticsRepository()

    func testBenchmarkSessionAnalyticsSnapshotLargeHistory() {
        let sessions = WorkoutBenchmarkFixtures.makeCompletedSessions(
            sessionCount: 500,
            blocksPerSession: 4,
            setsPerBlock: 6
        )
        var snapshot: AnalyticsRepository.SessionAnalyticsSnapshot?

        benchmark(
            named: "Session analytics snapshot / large history",
            threshold: Thresholds.sessionAnalyticsSnapshotLargeHistory
        ) {
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

        benchmark(
            named: "Progress store prepareState / large history",
            threshold: Thresholds.progressStorePrepareStateLargeHistory
        ) {
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

    @discardableResult
    private func benchmark(
        named name: String,
        threshold: BenchmarkThreshold,
        operation: () -> Void
    ) -> BenchmarkResult {
        operation()

        var samples: [TimeInterval] = []
        samples.reserveCapacity(threshold.iterationCount)

        for _ in 0..<threshold.iterationCount {
            let start = DispatchTime.now().uptimeNanoseconds
            operation()
            let elapsedNanoseconds = DispatchTime.now().uptimeNanoseconds - start
            samples.append(Double(elapsedNanoseconds) / 1_000_000_000)
        }

        let result = BenchmarkResult(samples: samples)
        let report = result.report(named: name, threshold: threshold)
        XCTContext.runActivity(named: "Benchmark: \(name)") { activity in
            let attachment = XCTAttachment(string: report)
            attachment.lifetime = .keepAlways
            activity.add(attachment)
        }
        print(report)

        XCTAssertLessThanOrEqual(
            result.averageSeconds,
            threshold.averageSecondsUpperBound,
            "\(name) average \(result.formattedAverage) exceeded threshold \(threshold.formattedAverageUpperBound)"
        )
        XCTAssertLessThanOrEqual(
            result.maxSeconds,
            threshold.maxSecondsUpperBound,
            "\(name) max sample \(result.formattedMax) exceeded threshold \(threshold.formattedMaxUpperBound)"
        )

        return result
    }
}

private struct BenchmarkThreshold {
    let iterationCount: Int
    let averageSecondsUpperBound: TimeInterval
    let maxSecondsUpperBound: TimeInterval

    var formattedAverageUpperBound: String {
        String(format: "%.3fs", averageSecondsUpperBound)
    }

    var formattedMaxUpperBound: String {
        String(format: "%.3fs", maxSecondsUpperBound)
    }
}

private struct BenchmarkResult {
    let samples: [TimeInterval]

    var averageSeconds: TimeInterval {
        guard !samples.isEmpty else {
            return 0
        }

        return samples.reduce(0, +) / Double(samples.count)
    }

    var maxSeconds: TimeInterval {
        samples.max() ?? 0
    }

    var relativeStandardDeviation: Double {
        guard samples.count > 1, averageSeconds > 0 else {
            return 0
        }

        let variance =
            samples.reduce(0) { partialResult, sample in
                partialResult + ((sample - averageSeconds) * (sample - averageSeconds))
            } / Double(samples.count)
        return variance.squareRoot() / averageSeconds
    }

    var formattedAverage: String {
        String(format: "%.3fs", averageSeconds)
    }

    var formattedMax: String {
        String(format: "%.3fs", maxSeconds)
    }

    func report(named name: String, threshold: BenchmarkThreshold) -> String {
        let formattedSamples =
            samples
            .map { String(format: "%.4f", $0) }
            .joined(separator: ", ")

        return """
            BENCHMARK: \(name)
            benchmark.iterations: \(samples.count)
            benchmark.average: \(formattedAverage) (threshold: \(threshold.formattedAverageUpperBound))
            benchmark.max: \(formattedMax) (threshold: \(threshold.formattedMaxUpperBound))
            benchmark.rsd: \(String(format: "%.2f%%", relativeStandardDeviation * 100))
            benchmark.samples: [\(formattedSamples)]

            """
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
