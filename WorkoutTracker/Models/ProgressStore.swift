import Foundation
import Observation

@MainActor
@Observable
final class ProgressStore {
    @ObservationIgnored private let calendar = Calendar.autoupdatingCurrent
    @ObservationIgnored private var allSessionsDescending: [CompletedSession] = []
    @ObservationIgnored private var sessionsByDay: [Date: [CompletedSession]] = [:]

    var overview: ProgressOverview = .empty
    var personalRecords: [PersonalRecord] = []
    var exerciseSummaries: [ExerciseAnalyticsSummary] = []
    var selectedExerciseID: UUID?
    var selectedDay: Date?
    var historySessions: [CompletedSession] = []
    var workoutDays: Set<Date> = []

    var personalBestOneRepMaxByExerciseID: [UUID: Double] {
        Dictionary(
            uniqueKeysWithValues: exerciseSummaries.compactMap { summary in
                guard let currentPR = summary.currentPR else {
                    return nil
                }

                return (summary.exerciseID, currentPR.estimatedOneRepMax)
            }
        )
    }

    func apply(
        _ snapshot: AnalyticsRepository.ProgressSnapshot,
        completedSessions: [CompletedSession]
    ) {
        overview = snapshot.overview
        personalRecords = snapshot.personalRecords
        exerciseSummaries = snapshot.exerciseSummaries
        selectedExerciseID = snapshot.selectedExerciseID
        rebuildHistoryCaches(from: completedSessions)
    }

    func recordCompletedSession(
        _ session: CompletedSession,
        completedSessions: [CompletedSession],
        analytics: AnalyticsRepository,
        catalogByID: [UUID: ExerciseCatalogItem],
        finishSummary: SessionFinishSummary?
    ) {
        overview = overview.recording(
            session,
            sessionCount: completedSessions.count,
            firstSessionDate: completedSessions.first?.completedAt,
            addedVolume: analytics.volume(for: session)
        )

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
        self.selectedExerciseID = resolvedSelectedExerciseID(
            selectedExerciseID,
            summaries: exerciseSummaries
        )
        rebuildHistoryCaches(from: completedSessions)
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
        selectedDay = day.map { calendar.startOfDay(for: $0) }
        historySessions = resolvedHistorySessions(for: selectedDay)
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

    private func rebuildHistoryCaches(from completedSessions: [CompletedSession]) {
        allSessionsDescending = Array(completedSessions.reversed())
        workoutDays = Set(allSessionsDescending.map { calendar.startOfDay(for: $0.completedAt) })

        var groupedSessions: [Date: [CompletedSession]] = [:]
        for session in allSessionsDescending {
            let day = calendar.startOfDay(for: session.completedAt)
            groupedSessions[day, default: []].append(session)
        }

        sessionsByDay = groupedSessions
        historySessions = resolvedHistorySessions(for: selectedDay)
    }

    private func resolvedHistorySessions(for selectedDay: Date?) -> [CompletedSession] {
        guard let selectedDay else {
            return allSessionsDescending
        }

        return sessionsByDay[selectedDay] ?? []
    }
}

private extension ProgressOverview {
    func recording(
        _ session: CompletedSession,
        sessionCount: Int,
        firstSessionDate: Date?,
        addedVolume: Double,
        now: Date = .now
    ) -> ProgressOverview {
        let calendar = Calendar.autoupdatingCurrent
        let startOfToday = calendar.startOfDay(for: now)
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: startOfToday)?.start ?? startOfToday
        let last30Days = calendar.date(byAdding: .day, value: -30, to: startOfToday) ?? startOfToday
        let resolvedFirstSessionDate = firstSessionDate ?? session.completedAt
        let weeksSpan = max(1.0, startOfToday.timeIntervalSince(resolvedFirstSessionDate) / (60 * 60 * 24 * 7))

        return ProgressOverview(
            totalSessions: sessionCount,
            sessionsThisWeek: sessionsThisWeek + (session.completedAt >= startOfWeek ? 1 : 0),
            sessionsLast30Days: sessionsLast30Days + (session.completedAt >= last30Days ? 1 : 0),
            totalVolume: totalVolume + addedVolume,
            averageSessionsPerWeek: Double(sessionCount) / weeksSpan
        )
    }
}
