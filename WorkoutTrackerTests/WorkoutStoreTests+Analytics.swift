import SwiftData
import XCTest

@testable import WorkoutTracker

extension WorkoutStoreTests {
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
            completedAt: completedAt,
            blocks: [
                CompletedSessionBlock(
                    exerciseID: CatalogSeed.benchPress,
                    exerciseNameSnapshot: "Bench Press",
                    sets: [makeRow(kind: .working, weight: 225, reps: 5)]
                ),
                CompletedSessionBlock(
                    exerciseID: CatalogSeed.benchPress,
                    exerciseNameSnapshot: "Bench Press",
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
            completedAt: completedAt,
            blocks: [
                CompletedSessionBlock(
                    exerciseID: CatalogSeed.benchPress,
                    exerciseNameSnapshot: "Bench Press",
                    sets: [makeRow(kind: .working, weight: 225, reps: 5)]
                ),
                CompletedSessionBlock(
                    exerciseID: CatalogSeed.benchPress,
                    exerciseNameSnapshot: "Bench Press",
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
                completedAt: now.addingTimeInterval(-172_800),
                blocks: [
                    CompletedSessionBlock(
                        exerciseID: CatalogSeed.benchPress,
                        exerciseNameSnapshot: "Bench Press",
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
                completedAt: now.addingTimeInterval(-86_400),
                blocks: [
                    CompletedSessionBlock(
                        exerciseID: CatalogSeed.backSquat,
                        exerciseNameSnapshot: "Back Squat",
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

}
