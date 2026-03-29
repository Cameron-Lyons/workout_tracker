import XCTest

@testable import WorkoutTracker

@MainActor
final class AnalyticsBenchmarks: BenchmarkTestCase {
    private enum Thresholds {
        static let sessionAnalyticsSnapshotLargeHistory = BenchmarkThreshold(
            measuredIterationCount: 5,
            averageSecondsUpperBound: 0.030,
            maxSecondsUpperBound: 0.040
        )
        static let progressStorePrepareStateLargeHistory = BenchmarkThreshold(
            measuredIterationCount: 5,
            averageSecondsUpperBound: 0.005,
            maxSecondsUpperBound: 0.008
        )
    }

    private let analytics = AnalyticsRepository()

    func testSessionAnalyticsSnapshotLargeHistory() {
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

    func testProgressStorePrepareStateLargeHistory() {
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
}
