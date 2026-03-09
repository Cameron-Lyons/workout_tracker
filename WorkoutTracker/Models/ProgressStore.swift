import Foundation
import Observation

@MainActor
@Observable
final class ProgressStore {
    var overview: ProgressOverview = .empty
    var personalRecords: [PersonalRecord] = []
    var exerciseSummaries: [ExerciseAnalyticsSummary] = []
    var selectedExerciseID: UUID?
    var selectedDay: Date?

    func refresh(
        plansStore: PlansStore,
        sessionStore: SessionStore,
        analytics: AnalyticsRepository
    ) {
        overview = analytics.buildOverview(from: sessionStore.completedSessions)
        personalRecords = analytics.personalRecords(
            from: sessionStore.completedSessions,
            catalogByID: plansStore.catalogByID
        )
        .reversed()
        exerciseSummaries = analytics.exerciseSummaries(
            from: sessionStore.completedSessions,
            catalogByID: plansStore.catalogByID
        )

        if let selectedExerciseID,
           exerciseSummaries.contains(where: { $0.exerciseID == selectedExerciseID }) == false {
            self.selectedExerciseID = exerciseSummaries.first?.exerciseID
        } else if self.selectedExerciseID == nil {
            self.selectedExerciseID = exerciseSummaries.first?.exerciseID
        }
    }

    func recordCompletedSession(
        _ session: CompletedSession,
        sessionStore: SessionStore,
        analytics: AnalyticsRepository,
        catalogByID: [UUID: ExerciseCatalogItem],
        finishSummary: SessionFinishSummary?
    ) {
        overview = analytics.buildOverview(from: sessionStore.completedSessions)

        if let finishSummary, !finishSummary.personalRecords.isEmpty {
            let mergedRecords = finishSummary.personalRecords.reversed() + personalRecords
            var seenRecordIDs: Set<UUID> = []
            personalRecords = mergedRecords.filter { record in
                seenRecordIDs.insert(record.id).inserted
            }
        }

        let payloadsByExerciseID = Dictionary(grouping: analytics.sessionExercisePayloads(from: session), by: \.exerciseID)
        var summariesByExerciseID = Dictionary(uniqueKeysWithValues: exerciseSummaries.map { ($0.exerciseID, $0) })
        let newPersonalRecordsByExerciseID = Dictionary(grouping: finishSummary?.personalRecords ?? [], by: \.exerciseID)

        for (exerciseID, payloads) in payloadsByExerciseID {
            var summary = summariesByExerciseID[exerciseID] ?? ExerciseAnalyticsSummary(
                exerciseID: exerciseID,
                displayName: catalogByID[exerciseID]?.name ?? payloads.last?.displayName ?? "Unknown Exercise",
                pointCount: 0,
                totalVolume: 0,
                currentPR: nil,
                points: []
            )

            let newPoints = payloads.map {
                ProgressPoint(
                    sessionID: $0.sessionID,
                    date: $0.date,
                    topWeight: $0.topWeight,
                    estimatedOneRepMax: $0.estimatedOneRepMax,
                    volume: $0.volume
                )
            }

            summary.displayName = catalogByID[exerciseID]?.name ?? summary.displayName
            summary.points.append(contentsOf: newPoints)
            summary.points.sort(by: { $0.date < $1.date })
            summary.pointCount = summary.points.count
            summary.totalVolume += payloads.reduce(0) { $0 + $1.volume }

            if let newPR = newPersonalRecordsByExerciseID[exerciseID]?.max(by: {
                $0.estimatedOneRepMax < $1.estimatedOneRepMax
            }) {
                if let currentPR = summary.currentPR {
                    summary.currentPR = newPR.estimatedOneRepMax > currentPR.estimatedOneRepMax ? newPR : currentPR
                } else {
                    summary.currentPR = newPR
                }
            }

            summariesByExerciseID[exerciseID] = summary
        }

        exerciseSummaries = summariesByExerciseID.values.sorted(by: { $0.displayName < $1.displayName })

        if let selectedExerciseID,
           exerciseSummaries.contains(where: { $0.exerciseID == selectedExerciseID }) == false {
            self.selectedExerciseID = exerciseSummaries.first?.exerciseID
        } else if self.selectedExerciseID == nil {
            self.selectedExerciseID = exerciseSummaries.first?.exerciseID
        }
    }

    var selectedExerciseSummary: ExerciseAnalyticsSummary? {
        guard let selectedExerciseID else {
            return nil
        }

        return exerciseSummaries.first(where: { $0.exerciseID == selectedExerciseID })
    }

    func selectExercise(_ exerciseID: UUID?) {
        selectedExerciseID = exerciseID
    }

    func selectDay(_ day: Date?) {
        selectedDay = day
    }

    func filteredSessions(from sessions: [CompletedSession]) -> [CompletedSession] {
        guard let selectedDay else {
            return sessions.reversed()
        }

        let calendar = Calendar.autoupdatingCurrent
        return sessions.reversed().filter {
            calendar.isDate($0.completedAt, inSameDayAs: selectedDay)
        }
    }
}
