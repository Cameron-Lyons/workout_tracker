import Foundation

struct AnalyticsRepository {
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
        previousSessions: [CompletedSession],
        catalogByID: [UUID: ExerciseCatalogItem]
    ) -> SessionFinishSummary {
        let allRecords = personalRecords(from: previousSessions + [session], catalogByID: catalogByID)
        let newRecordSessionIDs = Set(
            allRecords.filter { $0.sessionID == session.id }.map(\.id)
        )
        let newRecords = allRecords.filter { newRecordSessionIDs.contains($0.id) }

        return SessionFinishSummary(
            templateName: session.templateNameSnapshot,
            completedAt: session.completedAt,
            completedSetCount: completedSetCount(for: session),
            totalVolume: volume(for: session),
            personalRecords: newRecords
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
}

struct SessionExercisePayload {
    var sessionID: UUID
    var exerciseID: UUID
    var displayName: String
    var date: Date
    var topWeight: Double
    var estimatedOneRepMax: Double
    var volume: Double
}
