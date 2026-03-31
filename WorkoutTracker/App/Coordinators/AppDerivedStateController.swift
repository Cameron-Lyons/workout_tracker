import Foundation

@MainActor
final class AppDerivedStateController {
    private struct SessionAnalyticsCacheKey: Equatable {
        var completedSessionsRevision: Int
        var catalogRevision: Int
    }

    private struct TodayStateKey: Equatable {
        var sessionAnalytics: SessionAnalyticsCacheKey
        var planRevision: Int
        var dayBucket: Date
    }

    private struct ProgressStateKey: Equatable {
        var sessionAnalytics: SessionAnalyticsCacheKey
        var dayBucket: Date
    }

    private let analytics: AnalyticsRepository
    private let todayStore: TodayStore
    private let progressStore: ProgressStore
    private var progressRefreshTask: Task<Void, Never>?
    private var progressRefreshGeneration = 0
    private var cachedSessionAnalytics: AnalyticsRepository.SessionAnalyticsSnapshot?
    private var cachedSessionAnalyticsKey: SessionAnalyticsCacheKey?
    private var cachedSessionAnalyticsDayBucket: Date?
    private var lastAppliedTodayStateKey: TodayStateKey?
    private var lastAppliedProgressStateKey: ProgressStateKey?

    init(
        analytics: AnalyticsRepository = AnalyticsRepository(),
        todayStore: TodayStore,
        progressStore: ProgressStore
    ) {
        self.analytics = analytics
        self.todayStore = todayStore
        self.progressStore = progressStore
    }

    func hydrate(plansStore: PlansStore, sessionStore: SessionStore) async {
        await refreshDerivedStores(plansStore: plansStore, sessionStore: sessionStore)
    }

    @discardableResult
    func refreshDerivedStores(
        plansStore: PlansStore,
        sessionStore: SessionStore,
        now: Date = .now
    ) async -> Bool {
        let sessionAnalyticsKey = sessionAnalyticsCacheKey(plansStore: plansStore, sessionStore: sessionStore)
        let dayBucket = dayBucket(for: now)
        let todayKey = TodayStateKey(
            sessionAnalytics: sessionAnalyticsKey,
            planRevision: plansStore.planRevision,
            dayBucket: dayBucket
        )
        let progressKey = ProgressStateKey(sessionAnalytics: sessionAnalyticsKey, dayBucket: dayBucket)
        let shouldRefreshToday = lastAppliedTodayStateKey != todayKey
        let shouldRefreshProgress = lastAppliedProgressStateKey != progressKey

        guard shouldRefreshToday || shouldRefreshProgress else {
            PerformanceSignpost.event("Derived Refresh Skipped")
            return false
        }

        let interval = PerformanceSignpost.begin("Derived Store Refresh")
        defer { PerformanceSignpost.end(interval) }

        let planSummaries = plansStore.planSummaries
        let references = plansStore.templateReferences()
        let sessions = sessionStore.completedSessions
        let selectedExerciseID = progressStore.selectedExerciseID
        let selectedDay = progressStore.selectedDay

        let sessionAnalytics = await sessionAnalyticsSnapshot(
            plansStore: plansStore,
            sessionStore: sessionStore,
            now: now
        )

        if shouldRefreshToday {
            let todaySnapshot = analytics.makeTodaySnapshot(
                planSummaries: planSummaries,
                references: references,
                sessions: sessions,
                sessionAnalytics: sessionAnalytics,
                now: now
            )
            todayStore.apply(todaySnapshot)
            lastAppliedTodayStateKey = todayKey
        }

        if shouldRefreshProgress {
            let progressState = await preparedProgressState(
                sessionAnalytics: sessionAnalytics,
                completedSessions: sessions,
                selectedExerciseID: selectedExerciseID,
                selectedDay: selectedDay
            )
            progressStore.apply(progressState)
            lastAppliedProgressStateKey = progressKey
        }

        return true
    }

    @discardableResult
    func refreshToday(plansStore: PlansStore, sessionStore: SessionStore, now: Date = .now) -> Bool {
        let sessions = sessionStore.completedSessions
        let sessionAnalyticsKey = sessionAnalyticsCacheKey(plansStore: plansStore, sessionStore: sessionStore)
        let todayKey = TodayStateKey(
            sessionAnalytics: sessionAnalyticsKey,
            planRevision: plansStore.planRevision,
            dayBucket: dayBucket(for: now)
        )

        guard lastAppliedTodayStateKey != todayKey else {
            PerformanceSignpost.event("Today Refresh Skipped")
            return false
        }

        let interval = PerformanceSignpost.begin("Today Refresh")
        defer { PerformanceSignpost.end(interval) }

        let sessionAnalytics = resolvedSessionAnalyticsSnapshot(
            plansStore: plansStore,
            sessionStore: sessionStore,
            now: now
        )

        todayStore.apply(
            analytics.makeTodaySnapshot(
                planSummaries: plansStore.planSummaries,
                references: plansStore.templateReferences(),
                sessions: sessions,
                sessionAnalytics: sessionAnalytics,
                now: now
            )
        )
        lastAppliedTodayStateKey = todayKey
        return true
    }

    @discardableResult
    func scheduleProgressRefresh(
        plansStore: PlansStore,
        sessionStore: SessionStore,
        priority: TaskPriority = .utility
    ) -> Bool {
        let progressKey = ProgressStateKey(
            sessionAnalytics: sessionAnalyticsCacheKey(plansStore: plansStore, sessionStore: sessionStore),
            dayBucket: dayBucket()
        )
        guard lastAppliedProgressStateKey != progressKey else {
            PerformanceSignpost.event("Progress Refresh Skipped")
            return false
        }

        let selectedExerciseID = progressStore.selectedExerciseID
        let selectedDay = progressStore.selectedDay
        let completedSessions = sessionStore.completedSessions
        progressRefreshGeneration += 1
        let generation = progressRefreshGeneration

        progressRefreshTask?.cancel()

        progressRefreshTask = Task { [weak self, analytics] in
            guard let self else {
                return
            }

            let interval = PerformanceSignpost.begin("Progress Refresh")
            defer { PerformanceSignpost.end(interval) }

            let sessionAnalytics: AnalyticsRepository.SessionAnalyticsSnapshot
            if let cachedSessionAnalytics = self.cachedSessionAnalyticsSnapshot(
                plansStore: plansStore,
                sessionStore: sessionStore
            ) {
                sessionAnalytics = cachedSessionAnalytics
            } else {
                sessionAnalytics = await self.sessionAnalyticsSnapshot(
                    plansStore: plansStore,
                    sessionStore: sessionStore,
                    priority: priority
                )
            }

            let progressSnapshot = analytics.makeProgressSnapshot(
                sessionAnalytics: sessionAnalytics,
                selectedExerciseID: selectedExerciseID
            )
            let progressState = await Task.detached(priority: priority) {
                ProgressStore.prepareState(
                    progressSnapshot,
                    completedSessions: completedSessions,
                    selectedDay: selectedDay
                )
            }.value

            guard !Task.isCancelled else {
                return
            }

            await MainActor.run {
                guard generation == self.progressRefreshGeneration else {
                    return
                }

                self.progressStore.apply(progressState)
                self.lastAppliedProgressStateKey = progressKey
                self.progressRefreshTask = nil
            }
        }

        return true
    }

    func recordCompletedSession(
        _ session: CompletedSession,
        plansStore: PlansStore,
        sessionStore: SessionStore,
        finishSummary: SessionFinishSummary?,
        payloads: [SessionExercisePayload]? = nil
    ) {
        progressRefreshTask?.cancel()
        progressRefreshTask = nil

        let references = plansStore.templateReferences()
        todayStore.recordCompletedSession(
            session,
            planSummaries: plansStore.planSummaries,
            references: references,
            allSessions: sessionStore.completedSessions,
            finishSummary: finishSummary
        )
        progressStore.recordCompletedSession(
            session,
            completedSessions: sessionStore.completedSessions,
            analytics: analytics,
            catalogByID: plansStore.catalogByID,
            finishSummary: finishSummary,
            payloads: payloads
        )
        cacheSessionAnalytics(
            AnalyticsRepository.SessionAnalyticsSnapshot(
                overview: progressStore.overview,
                personalRecords: Array(progressStore.personalRecords.reversed()),
                exerciseSummaries: progressStore.exerciseSummaries,
                recentPersonalRecords: todayStore.recentPersonalRecords,
                recentSessions: todayStore.recentSessions
            ),
            key: sessionAnalyticsCacheKey(plansStore: plansStore, sessionStore: sessionStore),
            dayBucket: dayBucket()
        )
        let sessionAnalyticsKey = sessionAnalyticsCacheKey(plansStore: plansStore, sessionStore: sessionStore)
        lastAppliedTodayStateKey = TodayStateKey(
            sessionAnalytics: sessionAnalyticsKey,
            planRevision: plansStore.planRevision,
            dayBucket: dayBucket()
        )
        lastAppliedProgressStateKey = ProgressStateKey(sessionAnalytics: sessionAnalyticsKey, dayBucket: dayBucket())
    }

    func completedSessionResult(
        for session: CompletedSession,
        catalogByID: [UUID: ExerciseCatalogItem]
    ) -> AnalyticsRepository.CompletedSessionResult {
        analytics.completedSessionResult(
            for: session,
            previousBestByExerciseID: progressStore.personalBestOneRepMaxByExerciseID,
            catalogByID: catalogByID
        )
    }

    private func preparedProgressState(
        sessionAnalytics: AnalyticsRepository.SessionAnalyticsSnapshot,
        completedSessions: [CompletedSession],
        selectedExerciseID: UUID?,
        selectedDay: Date?,
        priority: TaskPriority = .utility
    ) async -> ProgressStore.PreparedState {
        let snapshot = analytics.makeProgressSnapshot(
            sessionAnalytics: sessionAnalytics,
            selectedExerciseID: selectedExerciseID
        )

        return await Task.detached(priority: priority) {
            ProgressStore.prepareState(
                snapshot,
                completedSessions: completedSessions,
                selectedDay: selectedDay
            )
        }.value
    }

    private func resolvedSessionAnalyticsSnapshot(
        plansStore: PlansStore,
        sessionStore: SessionStore,
        now: Date = .now
    ) -> AnalyticsRepository.SessionAnalyticsSnapshot {
        if let cached = cachedSessionAnalyticsSnapshot(
            plansStore: plansStore,
            sessionStore: sessionStore,
            now: now
        ) {
            return cached
        }

        let snapshot = analytics.makeSessionAnalyticsSnapshot(
            sessions: sessionStore.completedSessions,
            catalogByID: plansStore.catalogByID,
            now: now
        )
        cacheSessionAnalytics(
            snapshot,
            key: sessionAnalyticsCacheKey(plansStore: plansStore, sessionStore: sessionStore),
            dayBucket: dayBucket(for: now)
        )
        return snapshot
    }

    private func sessionAnalyticsSnapshot(
        plansStore: PlansStore,
        sessionStore: SessionStore,
        now: Date = .now,
        priority: TaskPriority = .utility
    ) async -> AnalyticsRepository.SessionAnalyticsSnapshot {
        if let cached = cachedSessionAnalyticsSnapshot(
            plansStore: plansStore,
            sessionStore: sessionStore,
            now: now
        ) {
            return cached
        }

        let sessions = sessionStore.completedSessions
        let catalogByID = plansStore.catalogByID
        let key = sessionAnalyticsCacheKey(plansStore: plansStore, sessionStore: sessionStore)
        let snapshot = await Task.detached(priority: priority) { [analytics] in
            analytics.makeSessionAnalyticsSnapshot(
                sessions: sessions,
                catalogByID: catalogByID,
                now: now
            )
        }.value
        cacheSessionAnalytics(snapshot, key: key, dayBucket: dayBucket(for: now))
        return snapshot
    }

    private func cachedSessionAnalyticsSnapshot(
        plansStore: PlansStore,
        sessionStore: SessionStore,
        now: Date = .now
    ) -> AnalyticsRepository.SessionAnalyticsSnapshot? {
        let key = sessionAnalyticsCacheKey(plansStore: plansStore, sessionStore: sessionStore)
        guard cachedSessionAnalyticsKey == key else {
            return nil
        }

        guard let cachedSessionAnalytics else {
            return nil
        }

        let dayBucket = dayBucket(for: now)
        guard cachedSessionAnalyticsDayBucket != dayBucket else {
            return cachedSessionAnalytics
        }

        let updatedSnapshot = analytics.updatingOverview(
            of: cachedSessionAnalytics,
            sessions: sessionStore.completedSessions,
            now: now
        )
        cacheSessionAnalytics(updatedSnapshot, key: key, dayBucket: dayBucket)
        return updatedSnapshot
    }

    private func cacheSessionAnalytics(
        _ snapshot: AnalyticsRepository.SessionAnalyticsSnapshot,
        key: SessionAnalyticsCacheKey,
        dayBucket: Date
    ) {
        cachedSessionAnalytics = snapshot
        cachedSessionAnalyticsKey = key
        cachedSessionAnalyticsDayBucket = dayBucket
    }

    private func sessionAnalyticsCacheKey(
        plansStore: PlansStore,
        sessionStore: SessionStore
    ) -> SessionAnalyticsCacheKey {
        SessionAnalyticsCacheKey(
            completedSessionsRevision: sessionStore.completedSessionsRevision,
            catalogRevision: plansStore.catalogRevision
        )
    }

    private func dayBucket(for now: Date = .now) -> Date {
        Calendar.autoupdatingCurrent.startOfDay(for: now)
    }
}
