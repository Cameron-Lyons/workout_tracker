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

    func buildOverview(from sessions: [CompletedSession]) -> ProgressOverview {
        guard !sessions.isEmpty else {
            return .empty
        }

        let calendar = Calendar.autoupdatingCurrent
        let startOfToday = calendar.startOfDay(for: .now)
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: startOfToday)?.start ?? startOfToday
        let last30Days = calendar.date(byAdding: .day, value: -30, to: startOfToday) ?? startOfToday
        let totalVolume = sessions.reduce(0) { $0 + volume(for: $1) }
        let sessionsThisWeek = sessions.filter { $0.completedAt >= startOfWeek }.count
        let sessionsLast30Days = sessions.filter { $0.completedAt >= last30Days }.count
        let firstSessionDate = sessions.first?.completedAt ?? startOfToday
        let weeksSpan = max(1.0, startOfToday.timeIntervalSince(firstSessionDate) / (60 * 60 * 24 * 7))

        return ProgressOverview(
            totalSessions: sessions.count,
            sessionsThisWeek: sessionsThisWeek,
            sessionsLast30Days: sessionsLast30Days,
            totalVolume: totalVolume,
            averageSessionsPerWeek: Double(sessions.count) / weeksSpan
        )
    }

    func personalRecords(
        from sessions: [CompletedSession],
        catalogByID: [UUID: ExerciseCatalogItem]
    ) -> [PersonalRecord] {
        var bestOneRepMaxByExerciseID: [UUID: Double] = [:]
        var records: [PersonalRecord] = []

        for session in sessions.sorted(by: { $0.completedAt < $1.completedAt }) {
            for block in session.blocks {
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
                        records.append(
                            PersonalRecord(
                                sessionID: session.id,
                                exerciseID: block.exerciseID,
                                displayName: catalogByID[block.exerciseID]?.name ?? block.exerciseNameSnapshot,
                                weight: weight,
                                reps: reps,
                                estimatedOneRepMax: estimatedOneRepMax,
                                achievedAt: session.completedAt
                            )
                        )
                    }
                }
            }
        }

        return records
    }

    func recentPersonalRecords(
        from sessions: [CompletedSession],
        catalogByID: [UUID: ExerciseCatalogItem],
        limit: Int = 5
    ) -> [PersonalRecord] {
        Array(personalRecords(from: sessions, catalogByID: catalogByID).suffix(limit).reversed())
    }

    func exerciseSummaries(
        from sessions: [CompletedSession],
        catalogByID: [UUID: ExerciseCatalogItem]
    ) -> [ExerciseAnalyticsSummary] {
        let grouped = Dictionary(grouping: sessions.flatMap(sessionExercisePayloads), by: \.exerciseID)
        let records = personalRecords(from: sessions, catalogByID: catalogByID)
        let recordByExerciseID = Dictionary(grouping: records, by: \.exerciseID)

        return grouped.map { exerciseID, payloads in
            let points = payloads.map {
                ProgressPoint(
                    sessionID: $0.sessionID,
                    date: $0.date,
                    topWeight: $0.topWeight,
                    estimatedOneRepMax: $0.estimatedOneRepMax,
                    volume: $0.volume
                )
            }
            .sorted(by: { $0.date < $1.date })

            let currentPR = recordByExerciseID[exerciseID]?.max(by: {
                $0.estimatedOneRepMax < $1.estimatedOneRepMax
            })

            return ExerciseAnalyticsSummary(
                exerciseID: exerciseID,
                displayName: catalogByID[exerciseID]?.name ?? payloads.last?.displayName ?? "Unknown Exercise",
                pointCount: points.count,
                totalVolume: payloads.reduce(0) { $0 + $1.volume },
                currentPR: currentPR,
                points: points
            )
        }
        .sorted(by: { $0.displayName < $1.displayName })
    }

    func finishSummary(
        for session: CompletedSession,
        previousBestByExerciseID: [UUID: Double],
        catalogByID: [UUID: ExerciseCatalogItem]
    ) -> SessionFinishSummary {
        var bestOneRepMaxByExerciseID = previousBestByExerciseID
        var newRecords: [PersonalRecord] = []

        for block in session.blocks {
            for row in block.sets {
                guard let weight = row.log.weight,
                      let reps = row.log.reps,
                      reps > 0 else {
                    continue
                }

                let estimatedOneRepMax = estimateOneRepMax(weight: weight, reps: reps)
                let previousBest = bestOneRepMaxByExerciseID[block.exerciseID] ?? .zero
                guard estimatedOneRepMax > previousBest else {
                    continue
                }

                bestOneRepMaxByExerciseID[block.exerciseID] = estimatedOneRepMax
                newRecords.append(
                    PersonalRecord(
                        sessionID: session.id,
                        exerciseID: block.exerciseID,
                        displayName: catalogByID[block.exerciseID]?.name ?? block.exerciseNameSnapshot,
                        weight: weight,
                        reps: reps,
                        estimatedOneRepMax: estimatedOneRepMax,
                        achievedAt: session.completedAt
                    )
                )
            }
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
        let last30Days = calendar.date(byAdding: .day, value: -30, to: startOfToday) ?? startOfToday
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
                var blockVolume = 0.0
                var topWeight = 0.0
                var topReps = 0
                var hasWeightedRow = false

                for row in block.sets {
                    guard let weight = row.log.weight,
                          let reps = row.log.reps,
                          reps > 0,
                          weight > 0 else {
                        continue
                    }

                    let rowVolume = weight * Double(reps)
                    sessionVolume += rowVolume
                    blockVolume += rowVolume

                    if !hasWeightedRow || weight > topWeight {
                        topWeight = weight
                        topReps = reps
                        hasWeightedRow = true
                    }

                    let estimatedOneRepMax = estimateOneRepMax(weight: weight, reps: reps)
                    let previousBest = bestOneRepMaxByExerciseID[block.exerciseID] ?? .zero

                    if estimatedOneRepMax > previousBest {
                        let record = PersonalRecord(
                            sessionID: session.id,
                            exerciseID: block.exerciseID,
                            displayName: displayName,
                            weight: weight,
                            reps: reps,
                            estimatedOneRepMax: estimatedOneRepMax,
                            achievedAt: session.completedAt
                        )

                        bestOneRepMaxByExerciseID[block.exerciseID] = estimatedOneRepMax
                        personalRecords.append(record)

                        var accumulator = exerciseAccumulatorsByID[block.exerciseID]
                            ?? ExerciseAnalyticsAccumulator(
                                exerciseID: block.exerciseID,
                                fallbackDisplayName: block.exerciseNameSnapshot
                            )
                        accumulator.currentPR = record
                        accumulator.fallbackDisplayName = block.exerciseNameSnapshot
                        exerciseAccumulatorsByID[block.exerciseID] = accumulator
                    }
                }

                guard hasWeightedRow else {
                    continue
                }

                var accumulator = exerciseAccumulatorsByID[block.exerciseID]
                    ?? ExerciseAnalyticsAccumulator(
                        exerciseID: block.exerciseID,
                        fallbackDisplayName: block.exerciseNameSnapshot
                    )
                accumulator.fallbackDisplayName = block.exerciseNameSnapshot
                accumulator.totalVolume += blockVolume
                accumulator.points.append(
                    ProgressPoint(
                        sessionID: session.id,
                        date: session.completedAt,
                        topWeight: topWeight,
                        estimatedOneRepMax: estimateOneRepMax(weight: topWeight, reps: topReps),
                        volume: blockVolume
                    )
                )
                exerciseAccumulatorsByID[block.exerciseID] = accumulator
            }

            totalVolume += sessionVolume
        }

        let weeksSpan = max(1.0, startOfToday.timeIntervalSince(firstSessionDate) / (60 * 60 * 24 * 7))
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
            recentPersonalRecords: Array(personalRecords.suffix(5).reversed()),
            recentSessions: Array(sessions.suffix(5).reversed())
        )
    }

    func makeDerivedStoreSnapshot(
        plans: [Plan],
        references: [TemplateReference],
        sessions: [CompletedSession],
        catalogByID: [UUID: ExerciseCatalogItem],
        selectedExerciseID: UUID?,
        now: Date = .now
    ) -> DerivedStoreSnapshot {
        let sessionAnalytics = makeSessionAnalyticsSnapshot(
            sessions: sessions,
            catalogByID: catalogByID,
            now: now
        )

        return makeDerivedStoreSnapshot(
            plans: plans,
            references: references,
            sessions: sessions,
            sessionAnalytics: sessionAnalytics,
            selectedExerciseID: selectedExerciseID,
            now: now
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
            pinnedTemplate: resolvePinnedTemplate(from: plans, references: references, now: now),
            quickStartTemplates: resolveQuickStarts(references: references, sessions: sessions),
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
            selectedExerciseID: resolvedSelectedExerciseID(
                selectedExerciseID,
                summaries: sessionAnalytics.exerciseSummaries
            )
        )
    }

    func makeTodaySnapshot(
        plans: [Plan],
        references: [TemplateReference],
        sessions: [CompletedSession],
        catalogByID: [UUID: ExerciseCatalogItem],
        now: Date = .now
    ) -> TodaySnapshot {
        makeTodaySnapshot(
            plans: plans,
            references: references,
            sessions: sessions,
            sessionAnalytics: makeSessionAnalyticsSnapshot(
                sessions: sessions,
                catalogByID: catalogByID,
                now: now
            ),
            now: now
        )
    }

    func makeProgressSnapshot(
        sessions: [CompletedSession],
        catalogByID: [UUID: ExerciseCatalogItem],
        selectedExerciseID: UUID?,
        now: Date = .now
    ) -> ProgressSnapshot {
        makeProgressSnapshot(
            sessionAnalytics: makeSessionAnalyticsSnapshot(
                sessions: sessions,
                catalogByID: catalogByID,
                now: now
            ),
            selectedExerciseID: selectedExerciseID
        )
    }

    func volume(for session: CompletedSession) -> Double {
        session.blocks.reduce(0) { partialResult, block in
            partialResult + block.sets.reduce(0) { total, row in
                let weight = row.log.weight ?? 0
                let reps = row.log.reps ?? 0
                return total + weight * Double(reps)
            }
        }
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

        return weight * (1 + Double(reps) / 30)
    }

    func sessionExercisePayloads(from session: CompletedSession) -> [SessionExercisePayload] {
        session.blocks.compactMap { block in
            let weightedRows = block.sets.filter {
                ($0.log.weight ?? 0) > 0 && ($0.log.reps ?? 0) > 0
            }

            guard let topRow = weightedRows.max(by: { ($0.log.weight ?? 0) < ($1.log.weight ?? 0) }) else {
                return nil
            }

            let topWeight = topRow.log.weight ?? 0
            let reps = topRow.log.reps ?? 0
            let volume = weightedRows.reduce(0) { total, row in
                total + (row.log.weight ?? 0) * Double(row.log.reps ?? 0)
            }

            return SessionExercisePayload(
                sessionID: session.id,
                exerciseID: block.exerciseID,
                displayName: block.exerciseNameSnapshot,
                date: session.completedAt,
                topWeight: topWeight,
                estimatedOneRepMax: estimateOneRepMax(weight: topWeight, reps: reps),
                volume: volume
            )
        }
    }

    private func resolvePinnedTemplate(
        from plans: [Plan],
        references: [TemplateReference],
        now: Date
    ) -> TemplateReference? {
        let referencesByTemplateID = Dictionary(uniqueKeysWithValues: references.map { ($0.templateID, $0) })
        let weekday = Weekday(rawValue: Calendar.autoupdatingCurrent.component(.weekday, from: now))

        if let weekday,
           let scheduledToday = references.first(where: { $0.scheduledWeekdays.contains(weekday) }) {
            return scheduledToday
        }

        for plan in plans {
            if let pinnedTemplateID = plan.pinnedTemplateID,
               let pinned = referencesByTemplateID[pinnedTemplateID] {
                return pinned
            }
        }

        return references.max(by: {
            ($0.lastStartedAt ?? .distantPast) < ($1.lastStartedAt ?? .distantPast)
        }) ?? references.first
    }

    private func resolveQuickStarts(
        references: [TemplateReference],
        sessions: [CompletedSession]
    ) -> [TemplateReference] {
        let referencesByTemplateID = Dictionary(uniqueKeysWithValues: references.map { ($0.templateID, $0) })
        let recentTemplateIDs = sessions.reversed().map(\.templateID)
        var resolved: [TemplateReference] = []
        var seenTemplateIDs: Set<UUID> = []

        for templateID in recentTemplateIDs {
            guard let match = referencesByTemplateID[templateID],
                  seenTemplateIDs.insert(match.templateID).inserted else {
                continue
            }

            resolved.append(match)
            if resolved.count == 4 {
                return resolved
            }
        }

        for reference in references where seenTemplateIDs.insert(reference.templateID).inserted {
            resolved.append(reference)
            if resolved.count == 4 {
                break
            }
        }

        return resolved
    }

    private func resolvedSelectedExerciseID(
        _ selectedExerciseID: UUID?,
        summaries: [ExerciseAnalyticsSummary]
    ) -> UUID? {
        guard !summaries.isEmpty else {
            return nil
        }

        if let selectedExerciseID,
           summaries.contains(where: { $0.exerciseID == selectedExerciseID }) {
            return selectedExerciseID
        }

        return summaries.first?.exerciseID
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
