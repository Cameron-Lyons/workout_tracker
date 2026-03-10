import Foundation
import Observation

struct ExerciseChartSeries: Equatable, Sendable {
    var trendPoints: [ProgressPoint]
    var markerPoints: [ProgressPoint]
    var isSampled: Bool
}

private enum ExerciseChartDefaults {
    static let maxTrendPointCount = 160
    static let maxMarkerPointCount = 24
}

@MainActor
@Observable
final class ProgressStore {
    @ObservationIgnored private let calendar = Calendar.autoupdatingCurrent
    @ObservationIgnored private var allSessionsDescending: [CompletedSession] = []
    @ObservationIgnored private var sessionsByDay: [Date: [CompletedSession]] = [:]
    @ObservationIgnored private var exerciseSummariesByID: [UUID: ExerciseAnalyticsSummary] = [:]
    @ObservationIgnored private var exerciseChartSeriesByID: [UUID: ExerciseChartSeries] = [:]
    @ObservationIgnored private var personalBestByExerciseID: [UUID: Double] = [:]

    var overview: ProgressOverview = .empty
    var personalRecords: [PersonalRecord] = []
    var exerciseSummaries: [ExerciseAnalyticsSummary] = []
    var selectedExerciseID: UUID?
    var selectedDay: Date?
    var historySessions: [CompletedSession] = []
    var workoutDays: Set<Date> = []

    var personalBestOneRepMaxByExerciseID: [UUID: Double] {
        personalBestByExerciseID
    }

    func apply(
        _ snapshot: AnalyticsRepository.ProgressSnapshot,
        completedSessions: [CompletedSession]
    ) {
        overview = snapshot.overview
        personalRecords = snapshot.personalRecords
        exerciseSummaries = snapshot.exerciseSummaries
        rebuildExerciseSummaryCache()
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
            personalRecords = PersonalRecordSelection.mergedNewestFirst(
                finishSummary.personalRecords,
                existingRecords: personalRecords
            )
        }

        let payloadsByExerciseID = Dictionary(grouping: analytics.sessionExercisePayloads(from: session), by: \.exerciseID)
        var summariesByExerciseID = exerciseSummariesByID
        let newPersonalRecordsByExerciseID = Dictionary(grouping: finishSummary?.personalRecords ?? [], by: \.exerciseID)

        for (exerciseID, payloads) in payloadsByExerciseID {
            var summary =
                summariesByExerciseID[exerciseID]
                ?? ExerciseAnalyticsSummary(
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
            appendPoints(newPoints, to: &summary)
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
        rebuildExerciseSummaryCache(
            summariesByID: summariesByExerciseID,
            changedExerciseIDs: Set(payloadsByExerciseID.keys)
        )
        self.selectedExerciseID = ExerciseAnalyticsSelection.selectedExerciseID(
            selectedExerciseID,
            summaries: exerciseSummaries
        )

        if completedSessions.count == allSessionsDescending.count + 1 {
            appendHistoryCaches(with: session)
        } else {
            rebuildHistoryCaches(from: completedSessions)
        }
    }

    var selectedExerciseSummary: ExerciseAnalyticsSummary? {
        guard let selectedExerciseID else {
            return nil
        }

        return exerciseSummariesByID[selectedExerciseID]
    }

    var selectedExerciseChartSeries: ExerciseChartSeries? {
        guard let selectedExerciseID else {
            return nil
        }

        return exerciseChartSeriesByID[selectedExerciseID]
    }

    func selectExercise(_ exerciseID: UUID?) {
        selectedExerciseID = exerciseID
    }

    func selectDay(_ day: Date?) {
        selectedDay = day.map { calendar.startOfDay(for: $0) }
        historySessions = resolvedHistorySessions(for: selectedDay)
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

    private func appendHistoryCaches(with session: CompletedSession) {
        let day = calendar.startOfDay(for: session.completedAt)
        allSessionsDescending.insert(session, at: 0)
        sessionsByDay[day, default: []].insert(session, at: 0)
        workoutDays.insert(day)
        historySessions = resolvedHistorySessions(for: selectedDay)
    }

    private func resolvedHistorySessions(for selectedDay: Date?) -> [CompletedSession] {
        guard let selectedDay else {
            return allSessionsDescending
        }

        return sessionsByDay[selectedDay] ?? []
    }

    private func rebuildExerciseSummaryCache(
        summariesByID: [UUID: ExerciseAnalyticsSummary]? = nil,
        changedExerciseIDs: Set<UUID>? = nil
    ) {
        let summariesByID =
            summariesByID
            ?? Dictionary(
                uniqueKeysWithValues: exerciseSummaries.map { ($0.exerciseID, $0) }
            )
        exerciseSummariesByID = summariesByID

        if let changedExerciseIDs {
            for exerciseID in changedExerciseIDs {
                guard let summary = summariesByID[exerciseID] else {
                    exerciseChartSeriesByID.removeValue(forKey: exerciseID)
                    personalBestByExerciseID.removeValue(forKey: exerciseID)
                    continue
                }

                exerciseChartSeriesByID[exerciseID] = Self.makeChartSeries(from: summary.points)

                if let currentPR = summary.currentPR {
                    personalBestByExerciseID[exerciseID] = currentPR.estimatedOneRepMax
                } else {
                    personalBestByExerciseID.removeValue(forKey: exerciseID)
                }
            }
            return
        }

        exerciseChartSeriesByID = Dictionary(
            uniqueKeysWithValues: summariesByID.map { exerciseID, summary in
                (exerciseID, Self.makeChartSeries(from: summary.points))
            }
        )
        personalBestByExerciseID = Dictionary(
            uniqueKeysWithValues: summariesByID.compactMap { exerciseID, summary in
                guard let currentPR = summary.currentPR else {
                    return nil
                }

                return (exerciseID, currentPR.estimatedOneRepMax)
            }
        )
    }

    private func appendPoints(_ newPoints: [ProgressPoint], to summary: inout ExerciseAnalyticsSummary) {
        guard !newPoints.isEmpty else {
            return
        }

        if let lastDate = summary.points.last?.date,
            let firstNewDate = newPoints.first?.date,
            lastDate > firstNewDate
        {
            summary.points.append(contentsOf: newPoints)
            summary.points.sort(by: { $0.date < $1.date })
            return
        }

        summary.points.append(contentsOf: newPoints)
    }

    private static func makeChartSeries(from points: [ProgressPoint]) -> ExerciseChartSeries {
        let trendPoints = sampledPoints(from: points, maxCount: ExerciseChartDefaults.maxTrendPointCount)
        return ExerciseChartSeries(
            trendPoints: trendPoints,
            markerPoints: sampledPoints(from: trendPoints, maxCount: ExerciseChartDefaults.maxMarkerPointCount),
            isSampled: trendPoints.count != points.count
        )
    }

    private static func sampledPoints(
        from points: [ProgressPoint],
        maxCount: Int
    ) -> [ProgressPoint] {
        guard points.count > maxCount, maxCount > 1 else {
            return points
        }

        let lastIndex = points.count - 1
        var indexes: [Int] = [0]
        indexes.reserveCapacity(maxCount)

        for position in 1..<(maxCount - 1) {
            let rawIndex = Int(
                (Double(position) * Double(lastIndex) / Double(maxCount - 1))
                    .rounded(.down)
            )
            let nextIndex = min(lastIndex - 1, max(indexes[indexes.count - 1] + 1, rawIndex))
            indexes.append(nextIndex)
        }

        indexes.append(lastIndex)
        return indexes.map { points[$0] }
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
        let last30Days = AnalyticsDefaults.rollingWindowStart(from: startOfToday, calendar: calendar)
        let resolvedFirstSessionDate = firstSessionDate ?? session.completedAt
        let weeksSpan = AnalyticsDefaults.weeksSpan(from: resolvedFirstSessionDate, to: startOfToday)

        return ProgressOverview(
            totalSessions: sessionCount,
            sessionsThisWeek: sessionsThisWeek + (session.completedAt >= startOfWeek ? 1 : 0),
            sessionsLast30Days: sessionsLast30Days + (session.completedAt >= last30Days ? 1 : 0),
            totalVolume: totalVolume + addedVolume,
            averageSessionsPerWeek: Double(sessionCount) / weeksSpan
        )
    }
}
