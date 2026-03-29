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

    struct CompletedSessionResult: Sendable {
        var finishSummary: SessionFinishSummary
        var payloads: [SessionExercisePayload]
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
        var volume: Double
        var payload: SessionExercisePayload?
        var newRecords: [PersonalRecord]
    }

    private struct SessionAnalysis {
        var completedSetCount = 0
        var totalVolume = 0.0
        var trackedVolume = 0.0
        var newRecords: [PersonalRecord] = []
        var fallbackDisplayNamesByExerciseID: [UUID: String] = [:]
        var totalVolumeByExerciseID: [UUID: Double] = [:]
        var payloadsByExerciseID: [UUID: SessionExercisePayload] = [:]
        var orderedExerciseIDs: [UUID] = []

        var payloads: [SessionExercisePayload] {
            orderedExerciseIDs.compactMap { payloadsByExerciseID[$0] }
        }
    }

    func makeOverview(sessions: [CompletedSession], now: Date = .now) -> ProgressOverview {
        guard !sessions.isEmpty else {
            return .empty
        }

        let calendar = Calendar.autoupdatingCurrent
        let startOfToday = calendar.startOfDay(for: now)
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: startOfToday)?.start ?? startOfToday
        let last30Days = AnalyticsDefaults.rollingWindowStart(from: startOfToday, calendar: calendar)
        let firstSessionDate = sessions.first?.completedAt ?? startOfToday

        var totalVolume = 0.0
        var sessionsThisWeek = 0
        var sessionsLast30Days = 0

        for session in sessions {
            if session.completedAt >= startOfWeek {
                sessionsThisWeek += 1
            }

            if session.completedAt >= last30Days {
                sessionsLast30Days += 1
            }

            for block in session.blocks {
                totalVolume += block.sets.reduce(0) { partialResult, row in
                    guard row.log.isCompleted else {
                        return partialResult
                    }

                    return partialResult + ((row.log.weight ?? 0) * Double(row.log.reps ?? 0))
                }
            }
        }

        let weeksSpan = AnalyticsDefaults.weeksSpan(from: firstSessionDate, to: startOfToday)
        return ProgressOverview(
            totalSessions: sessions.count,
            sessionsThisWeek: sessionsThisWeek,
            sessionsLast30Days: sessionsLast30Days,
            totalVolume: totalVolume,
            averageSessionsPerWeek: Double(sessions.count) / weeksSpan
        )
    }

    func updatingOverview(
        of snapshot: SessionAnalyticsSnapshot,
        sessions: [CompletedSession],
        now: Date = .now
    ) -> SessionAnalyticsSnapshot {
        var updatedSnapshot = snapshot
        updatedSnapshot.overview = makeOverview(sessions: sessions, now: now)
        return updatedSnapshot
    }

    func finishSummary(
        for session: CompletedSession,
        previousBestByExerciseID: [UUID: Double],
        catalogByID: [UUID: ExerciseCatalogItem]
    ) -> SessionFinishSummary {
        completedSessionResult(
            for: session,
            previousBestByExerciseID: previousBestByExerciseID,
            catalogByID: catalogByID
        ).finishSummary
    }

    func completedSessionResult(
        for session: CompletedSession,
        previousBestByExerciseID: [UUID: Double],
        catalogByID: [UUID: ExerciseCatalogItem]
    ) -> CompletedSessionResult {
        var bestOneRepMaxByExerciseID = previousBestByExerciseID
        let analysis = analyzeSession(
            session,
            displayNameForBlock: { block in
                catalogByID[block.exerciseID]?.name ?? block.exerciseNameSnapshot
            },
            bestOneRepMaxByExerciseID: &bestOneRepMaxByExerciseID
        )

        return CompletedSessionResult(
            finishSummary: SessionFinishSummary(
                templateName: session.templateNameSnapshot,
                completedAt: session.completedAt,
                completedSetCount: analysis.completedSetCount,
                totalVolume: analysis.trackedVolume,
                personalRecords: analysis.newRecords
            ),
            payloads: analysis.payloads
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
        var totalVolume = 0.0
        var bestOneRepMaxByExerciseID: [UUID: Double] = [:]
        var personalRecords: [PersonalRecord] = []
        var exerciseAccumulatorsByID: [UUID: ExerciseAnalyticsAccumulator] = [:]

        for session in chronologicalSessions {
            let analysis = analyzeSession(
                session,
                displayNameForBlock: { block in
                    catalogByID[block.exerciseID]?.name ?? block.exerciseNameSnapshot
                },
                bestOneRepMaxByExerciseID: &bestOneRepMaxByExerciseID
            )
            personalRecords.append(contentsOf: analysis.newRecords)

            for (exerciseID, fallbackDisplayName) in analysis.fallbackDisplayNamesByExerciseID {
                var accumulator =
                    exerciseAccumulatorsByID[exerciseID]
                    ?? ExerciseAnalyticsAccumulator(
                        exerciseID: exerciseID,
                        fallbackDisplayName: fallbackDisplayName
                    )
                accumulator.fallbackDisplayName = fallbackDisplayName
                accumulator.totalVolume += analysis.totalVolumeByExerciseID[exerciseID] ?? 0
                exerciseAccumulatorsByID[exerciseID] = accumulator
            }

            for record in analysis.newRecords {
                guard var accumulator = exerciseAccumulatorsByID[record.exerciseID] else {
                    continue
                }

                accumulator.currentPR = record
                exerciseAccumulatorsByID[record.exerciseID] = accumulator
            }

            for payload in analysis.payloads {
                guard var accumulator = exerciseAccumulatorsByID[payload.exerciseID] else {
                    continue
                }

                accumulator.points.append(
                    ProgressPoint(
                        sessionID: payload.sessionID,
                        date: payload.date,
                        topWeight: payload.topWeight,
                        estimatedOneRepMax: payload.estimatedOneRepMax,
                        volume: payload.volume
                    )
                )
                exerciseAccumulatorsByID[payload.exerciseID] = accumulator
            }

            totalVolume += analysis.totalVolume
        }
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
            overview: makeOverview(sessions: chronologicalSessions, now: now),
            personalRecords: personalRecords,
            exerciseSummaries: exerciseSummaries,
            recentPersonalRecords: Array(personalRecords.suffix(AnalyticsDefaults.recentActivityLimit).reversed()),
            recentSessions: Array(chronologicalSessions.suffix(AnalyticsDefaults.recentActivityLimit).reversed())
        )
    }

    func makeDerivedStoreSnapshot(
        planSummaries: [PlanSummary],
        references: [TemplateReference],
        sessions: [CompletedSession],
        sessionAnalytics: SessionAnalyticsSnapshot,
        selectedExerciseID: UUID?,
        now: Date = .now
    ) -> DerivedStoreSnapshot {
        return DerivedStoreSnapshot(
            today: makeTodaySnapshot(
                planSummaries: planSummaries,
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
        planSummaries: [PlanSummary],
        references: [TemplateReference],
        sessions: [CompletedSession],
        sessionAnalytics: SessionAnalyticsSnapshot,
        now: Date = .now
    ) -> TodaySnapshot {
        let selection = TemplateReferenceSelection.todaySelection(
            planSummaries: planSummaries,
            references: references,
            sessions: sessions,
            now: now
        )

        return TodaySnapshot(
            pinnedTemplate: selection.pinnedTemplate,
            quickStartTemplates: selection.quickStartTemplates,
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
        var bestOneRepMaxByExerciseID: [UUID: Double] = [:]
        return analyzeSession(
            session,
            displayNameForBlock: { $0.exerciseNameSnapshot },
            bestOneRepMaxByExerciseID: &bestOneRepMaxByExerciseID
        ).trackedVolume
    }

    func estimateOneRepMax(weight: Double, reps: Int) -> Double {
        guard reps > 0 else {
            return weight
        }

        return weight * (1 + Double(reps) / AnalyticsDefaults.oneRepMaxDivisor)
    }

    func sessionExercisePayloads(from session: CompletedSession) -> [SessionExercisePayload] {
        var bestOneRepMaxByExerciseID: [UUID: Double] = [:]
        return analyzeSession(
            session,
            displayNameForBlock: { $0.exerciseNameSnapshot },
            bestOneRepMaxByExerciseID: &bestOneRepMaxByExerciseID
        ).payloads
    }

    private func analyzeSession(
        _ session: CompletedSession,
        displayNameForBlock: (CompletedSessionBlock) -> String,
        bestOneRepMaxByExerciseID: inout [UUID: Double]
    ) -> SessionAnalysis {
        var sessionAnalysis = SessionAnalysis()

        for block in session.blocks {
            let displayName = displayNameForBlock(block)
            let blockAnalysis = analyze(
                block,
                in: session,
                displayName: displayName,
                bestOneRepMaxByExerciseID: &bestOneRepMaxByExerciseID
            )

            sessionAnalysis.completedSetCount += block.sets.reduce(0) { partialResult, row in
                partialResult + (row.log.isCompleted ? 1 : 0)
            }
            sessionAnalysis.totalVolume += blockAnalysis.volume
            sessionAnalysis.newRecords.append(contentsOf: blockAnalysis.newRecords)
            sessionAnalysis.fallbackDisplayNamesByExerciseID[block.exerciseID] = block.exerciseNameSnapshot
            sessionAnalysis.totalVolumeByExerciseID[block.exerciseID, default: 0] += blockAnalysis.volume

            guard let payload = blockAnalysis.payload else {
                continue
            }

            sessionAnalysis.trackedVolume += blockAnalysis.volume
            if let existingPayload = sessionAnalysis.payloadsByExerciseID[payload.exerciseID] {
                sessionAnalysis.payloadsByExerciseID[payload.exerciseID] = mergedSessionPayload(existingPayload, with: payload)
            } else {
                sessionAnalysis.payloadsByExerciseID[payload.exerciseID] = payload
                sessionAnalysis.orderedExerciseIDs.append(payload.exerciseID)
            }
        }

        sessionAnalysis.newRecords = deduplicatedSessionRecords(sessionAnalysis.newRecords)
        return sessionAnalysis
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
        var hasProgressRow = false
        var newRecords: [PersonalRecord] = []

        for row in block.sets {
            guard row.log.isCompleted,
                let weight = row.log.weight,
                let reps = row.log.reps,
                reps > 0
            else {
                continue
            }

            guard weight > 0 else {
                continue
            }

            let rowVolume = weight * Double(reps)
            blockVolume += rowVolume

            guard row.target.setKind == .working else {
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

            if !hasProgressRow
                || weight > topWeight
                || (weight == topWeight && reps > topReps)
            {
                topWeight = weight
                topReps = reps
                hasProgressRow = true
            }
        }

        let payload =
            hasProgressRow
            ? SessionExercisePayload(
                sessionID: session.id,
                exerciseID: block.exerciseID,
                displayName: displayName,
                date: session.completedAt,
                topWeight: topWeight,
                estimatedOneRepMax: estimateOneRepMax(weight: topWeight, reps: topReps),
                volume: blockVolume
            ) : nil

        return BlockAnalysis(volume: blockVolume, payload: payload, newRecords: newRecords)
    }

    private func mergedSessionPayload(
        _ currentPayload: SessionExercisePayload,
        with nextPayload: SessionExercisePayload
    ) -> SessionExercisePayload {
        let preferredPayload: SessionExercisePayload
        if nextPayload.topWeight > currentPayload.topWeight {
            preferredPayload = nextPayload
        } else if nextPayload.topWeight == currentPayload.topWeight,
            nextPayload.estimatedOneRepMax > currentPayload.estimatedOneRepMax
        {
            preferredPayload = nextPayload
        } else {
            preferredPayload = currentPayload
        }

        var mergedPayload = preferredPayload
        mergedPayload.volume = currentPayload.volume + nextPayload.volume
        return mergedPayload
    }

    private func deduplicatedSessionRecords(_ records: [PersonalRecord]) -> [PersonalRecord] {
        var bestRecordIndexByExerciseID: [UUID: Int] = [:]
        var bestRecords: [PersonalRecord] = []

        for record in records {
            if let existingIndex = bestRecordIndexByExerciseID[record.exerciseID] {
                if record.estimatedOneRepMax >= bestRecords[existingIndex].estimatedOneRepMax {
                    bestRecords[existingIndex] = record
                }
            } else {
                bestRecordIndexByExerciseID[record.exerciseID] = bestRecords.count
                bestRecords.append(record)
            }
        }

        return bestRecords
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
