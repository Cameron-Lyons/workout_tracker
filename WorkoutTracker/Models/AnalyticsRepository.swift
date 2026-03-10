import Foundation

struct AnalyticsRepository: Sendable {
    struct TodaySnapshot: Equatable, Sendable {
        var pinnedTemplate: TemplateReference?
        var quickStartTemplates: [TemplateReference]
        var recentPersonalRecords: [PersonalRecord]
        var recentSessions: [CompletedSession]
    }

    struct ProgressSnapshot: Equatable, Sendable {
        var overview: ProgressOverview
        var personalRecords: [PersonalRecord]
        var exerciseSummaries: [ExerciseAnalyticsSummary]
        var selectedExerciseID: UUID?
    }

    struct DerivedStoreSnapshot: Equatable, Sendable {
        var today: TodaySnapshot
        var progress: ProgressSnapshot
    }

    struct SessionAnalyticsSnapshot: Equatable, Sendable {
        var overview: ProgressOverview
        var personalRecords: [PersonalRecord]
        var exerciseSummaries: [ExerciseAnalyticsSummary]
        var recentPersonalRecords: [PersonalRecord]
        var recentSessions: [CompletedSession]
    }

    private struct ExerciseAnalyticsAccumulator {
        var exerciseID: UUID
        var fallbackDisplayName: String
        var totalVolume: Double
        var currentPR: PersonalRecord?
        var points: [ProgressPoint]

        init(exerciseID: UUID, fallbackDisplayName: String) {
            self.exerciseID = exerciseID
            self.fallbackDisplayName = fallbackDisplayName
            self.totalVolume = 0
            self.currentPR = nil
            self.points = []
        }
    }

    private struct BlockAnalysis {
        var payload: SessionExercisePayload?
        var newRecords: [PersonalRecord]
    }

    func finishSummary(
        for session: CompletedSession,
        previousBestByExerciseID: [UUID: Double],
        catalogByID: [UUID: ExerciseCatalogItem]
    ) -> SessionFinishSummary {
        var bestOneRepMaxByExerciseID = previousBestByExerciseID
        let newRecords = session.blocks.flatMap { block in
            analyze(
                block,
                in: session,
                displayName: catalogByID[block.exerciseID]?.name ?? block.exerciseNameSnapshot,
                bestOneRepMaxByExerciseID: &bestOneRepMaxByExerciseID
            ).newRecords
        }

        return SessionFinishSummary(
            templateName: session.templateNameSnapshot,
            completedAt: session.completedAt,
            completedSetCount: completedSetCount(for: session),
            totalVolume: volume(for: session),
            personalRecords: newRecords
        )
    }

    func makeSessionAnalyticsSnapshot(
        sessions: [CompletedSession],
        catalogByID: [UUID: ExerciseCatalogItem],
        now: Date = .now
    ) -> SessionAnalyticsSnapshot {
        guard !sessions.isEmpty else {
            return SessionAnalyticsSnapshot(
                overview: .empty,
                personalRecords: [],
                exerciseSummaries: [],
                recentPersonalRecords: [],
                recentSessions: []
            )
        }

        let chronologicalSessions = sessions.sorted(by: { $0.completedAt < $1.completedAt })
        let calendar = Calendar.autoupdatingCurrent
        let startOfToday = calendar.startOfDay(for: now)
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: startOfToday)?.start ?? startOfToday
        let last30Days = AnalyticsDefaults.rollingWindowStart(from: startOfToday, calendar: calendar)
        let firstSessionDate = sessions.first?.completedAt ?? startOfToday

        var totalVolume = 0.0
        var sessionsThisWeek = 0
        var sessionsLast30Days = 0
        var bestOneRepMaxByExerciseID: [UUID: Double] = [:]
        var personalRecords: [PersonalRecord] = []
        var exerciseAccumulatorsByID: [UUID: ExerciseAnalyticsAccumulator] = [:]

        for session in chronologicalSessions {
            if session.completedAt >= startOfWeek {
                sessionsThisWeek += 1
            }

            if session.completedAt >= last30Days {
                sessionsLast30Days += 1
            }

            var sessionVolume = 0.0

            for block in session.blocks {
                let displayName = catalogByID[block.exerciseID]?.name ?? block.exerciseNameSnapshot
                let blockAnalysis = analyze(
                    block,
                    in: session,
                    displayName: displayName,
                    bestOneRepMaxByExerciseID: &bestOneRepMaxByExerciseID
                )
                personalRecords.append(contentsOf: blockAnalysis.newRecords)

                var accumulator = exerciseAccumulatorsByID[block.exerciseID]
                    ?? ExerciseAnalyticsAccumulator(
                        exerciseID: block.exerciseID,
                        fallbackDisplayName: block.exerciseNameSnapshot
                    )
                accumulator.fallbackDisplayName = block.exerciseNameSnapshot
                for record in blockAnalysis.newRecords {
                    accumulator.currentPR = record
                }
                if let payload = blockAnalysis.payload {
                    sessionVolume += payload.volume
                    accumulator.totalVolume += payload.volume
                    accumulator.points.append(
                        ProgressPoint(
                            sessionID: payload.sessionID,
                            date: payload.date,
                            topWeight: payload.topWeight,
                            estimatedOneRepMax: payload.estimatedOneRepMax,
                            volume: payload.volume
                        )
                    )
                }
                exerciseAccumulatorsByID[block.exerciseID] = accumulator
            }

            totalVolume += sessionVolume
        }

        let weeksSpan = AnalyticsDefaults.weeksSpan(from: firstSessionDate, to: startOfToday)
        let exerciseSummaries = exerciseAccumulatorsByID.values
            .map { accumulator in
                ExerciseAnalyticsSummary(
                    exerciseID: accumulator.exerciseID,
                    displayName: catalogByID[accumulator.exerciseID]?.name ?? accumulator.fallbackDisplayName,
                    pointCount: accumulator.points.count,
                    totalVolume: accumulator.totalVolume,
                    currentPR: accumulator.currentPR,
                    points: accumulator.points
                )
            }
            .sorted(by: { $0.displayName < $1.displayName })

        return SessionAnalyticsSnapshot(
            overview: ProgressOverview(
                totalSessions: sessions.count,
                sessionsThisWeek: sessionsThisWeek,
                sessionsLast30Days: sessionsLast30Days,
                totalVolume: totalVolume,
                averageSessionsPerWeek: Double(sessions.count) / weeksSpan
            ),
            personalRecords: personalRecords,
            exerciseSummaries: exerciseSummaries,
            recentPersonalRecords: Array(personalRecords.suffix(AnalyticsDefaults.recentActivityLimit).reversed()),
            recentSessions: Array(sessions.suffix(AnalyticsDefaults.recentActivityLimit).reversed())
        )
    }

    func makeDerivedStoreSnapshot(
        plans: [Plan],
        references: [TemplateReference],
        sessions: [CompletedSession],
        sessionAnalytics: SessionAnalyticsSnapshot,
        selectedExerciseID: UUID?,
        now: Date = .now
    ) -> DerivedStoreSnapshot {
        return DerivedStoreSnapshot(
            today: makeTodaySnapshot(
                plans: plans,
                references: references,
                sessions: sessions,
                sessionAnalytics: sessionAnalytics,
                now: now
            ),
            progress: makeProgressSnapshot(
                sessionAnalytics: sessionAnalytics,
                selectedExerciseID: selectedExerciseID
            )
        )
    }

    func makeTodaySnapshot(
        plans: [Plan],
        references: [TemplateReference],
        sessions: [CompletedSession],
        sessionAnalytics: SessionAnalyticsSnapshot,
        now: Date = .now
    ) -> TodaySnapshot {
        TodaySnapshot(
            pinnedTemplate: TemplateReferenceSelection.pinnedTemplate(
                from: plans,
                references: references,
                now: now
            ),
            quickStartTemplates: TemplateReferenceSelection.quickStarts(
                references: references,
                sessions: sessions
            ),
            recentPersonalRecords: sessionAnalytics.recentPersonalRecords,
            recentSessions: sessionAnalytics.recentSessions
        )
    }

    func makeProgressSnapshot(
        sessionAnalytics: SessionAnalyticsSnapshot,
        selectedExerciseID: UUID?
    ) -> ProgressSnapshot {
        ProgressSnapshot(
            overview: sessionAnalytics.overview,
            personalRecords: Array(sessionAnalytics.personalRecords.reversed()),
            exerciseSummaries: sessionAnalytics.exerciseSummaries,
            selectedExerciseID: ExerciseAnalyticsSelection.selectedExerciseID(
                selectedExerciseID,
                summaries: sessionAnalytics.exerciseSummaries
            )
        )
    }

    func volume(for session: CompletedSession) -> Double {
        sessionExercisePayloads(from: session).reduce(0) { $0 + $1.volume }
    }

    func completedSetCount(for session: CompletedSession) -> Int {
        session.blocks.reduce(0) { partialResult, block in
            partialResult + block.sets.filter(\.log.isCompleted).count
        }
    }

    func estimateOneRepMax(weight: Double, reps: Int) -> Double {
        guard reps > 0 else {
            return weight
        }

        return weight * (1 + Double(reps) / AnalyticsDefaults.oneRepMaxDivisor)
    }

    func sessionExercisePayloads(from session: CompletedSession) -> [SessionExercisePayload] {
        var bestOneRepMaxByExerciseID: [UUID: Double] = [:]
        return session.blocks.compactMap { block in
            analyze(
                block,
                in: session,
                displayName: block.exerciseNameSnapshot,
                bestOneRepMaxByExerciseID: &bestOneRepMaxByExerciseID
            ).payload
        }
    }

    private func analyze(
        _ block: CompletedSessionBlock,
        in session: CompletedSession,
        displayName: String,
        bestOneRepMaxByExerciseID: inout [UUID: Double]
    ) -> BlockAnalysis {
        var blockVolume = 0.0
        var topWeight = 0.0
        var topReps = 0
        var hasWeightedRow = false
        var newRecords: [PersonalRecord] = []

        for row in block.sets {
            guard let weight = row.log.weight,
                  let reps = row.log.reps,
                  reps > 0 else {
                continue
            }

            let estimatedOneRepMax = estimateOneRepMax(weight: weight, reps: reps)
            let previousBest = bestOneRepMaxByExerciseID[block.exerciseID] ?? .zero

            if estimatedOneRepMax > previousBest {
                bestOneRepMaxByExerciseID[block.exerciseID] = estimatedOneRepMax
                newRecords.append(
                    PersonalRecord(
                        sessionID: session.id,
                        exerciseID: block.exerciseID,
                        displayName: displayName,
                        weight: weight,
                        reps: reps,
                        estimatedOneRepMax: estimatedOneRepMax,
                        achievedAt: session.completedAt
                    )
                )
            }

            guard weight > 0 else {
                continue
            }

            let rowVolume = weight * Double(reps)
            blockVolume += rowVolume

            if !hasWeightedRow || weight > topWeight {
                topWeight = weight
                topReps = reps
                hasWeightedRow = true
            }
        }

        let payload = hasWeightedRow ? SessionExercisePayload(
            sessionID: session.id,
            exerciseID: block.exerciseID,
            displayName: displayName,
            date: session.completedAt,
            topWeight: topWeight,
            estimatedOneRepMax: estimateOneRepMax(weight: topWeight, reps: topReps),
            volume: blockVolume
        ) : nil

        return BlockAnalysis(payload: payload, newRecords: newRecords)
    }

}

struct SessionExercisePayload: Sendable {
    var sessionID: UUID
    var exerciseID: UUID
    var displayName: String
    var date: Date
    var topWeight: Double
    var estimatedOneRepMax: Double
    var volume: Double
}
