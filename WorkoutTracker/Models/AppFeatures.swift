import Foundation

@MainActor
final class AppDerivedStateController {
    private struct SessionAnalyticsCacheKey: Equatable {
        var completedSessionsRevision: Int
        var catalogRevision: Int
        var dayBucket: Date
    }

    private let analytics: AnalyticsRepository
    private let todayStore: TodayStore
    private let progressStore: ProgressStore
    private var progressRefreshTask: Task<Void, Never>?
    private var progressRefreshGeneration = 0
    private var cachedSessionAnalytics: AnalyticsRepository.SessionAnalyticsSnapshot?
    private var cachedSessionAnalyticsKey: SessionAnalyticsCacheKey?

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

    func refreshDerivedStores(
        plansStore: PlansStore,
        sessionStore: SessionStore,
        now: Date = .now
    ) async {
        let plans = plansStore.plans
        let references = plansStore.templateReferences()
        let sessions = sessionStore.completedSessions
        let selectedExerciseID = progressStore.selectedExerciseID

        let sessionAnalytics = await sessionAnalyticsSnapshot(
            plansStore: plansStore,
            sessionStore: sessionStore,
            now: now
        )

        let snapshot = analytics.makeDerivedStoreSnapshot(
            plans: plans,
            references: references,
            sessions: sessions,
            sessionAnalytics: sessionAnalytics,
            selectedExerciseID: selectedExerciseID,
            now: now
        )

        apply(snapshot)
    }

    func refreshToday(plansStore: PlansStore, sessionStore: SessionStore, now: Date = .now) {
        let sessions = sessionStore.completedSessions
        let sessionAnalytics = resolvedSessionAnalyticsSnapshot(
            plansStore: plansStore,
            sessionStore: sessionStore,
            now: now
        )

        todayStore.apply(
            analytics.makeTodaySnapshot(
                plans: plansStore.plans,
                references: plansStore.templateReferences(),
                sessions: sessions,
                sessionAnalytics: sessionAnalytics,
                now: now
            )
        )
    }

    func scheduleProgressRefresh(
        plansStore: PlansStore,
        sessionStore: SessionStore,
        priority: TaskPriority = .utility
    ) {
        let selectedExerciseID = progressStore.selectedExerciseID
        progressRefreshGeneration += 1
        let generation = progressRefreshGeneration

        progressRefreshTask?.cancel()

        if let sessionAnalytics = cachedSessionAnalyticsSnapshot(
            plansStore: plansStore,
            sessionStore: sessionStore
        ) {
            progressStore.apply(
                analytics.makeProgressSnapshot(
                    sessionAnalytics: sessionAnalytics,
                    selectedExerciseID: selectedExerciseID
                )
            )
            progressRefreshTask = nil
            return
        }

        progressRefreshTask = Task { [weak self, analytics] in
            guard let self else {
                return
            }

            let sessionAnalytics = await self.sessionAnalyticsSnapshot(
                plansStore: plansStore,
                sessionStore: sessionStore,
                priority: priority
            )
            let snapshot = analytics.makeProgressSnapshot(
                sessionAnalytics: sessionAnalytics,
                selectedExerciseID: selectedExerciseID
            )

            guard !Task.isCancelled else {
                return
            }

            await MainActor.run {
                guard generation == self.progressRefreshGeneration else {
                    return
                }

                self.progressStore.apply(snapshot)
                self.progressRefreshTask = nil
            }
        }
    }

    func refreshProgress(plansStore: PlansStore, sessionStore: SessionStore) async {
        progressRefreshGeneration += 1
        let generation = progressRefreshGeneration
        progressRefreshTask?.cancel()
        progressRefreshTask = nil

        let selectedExerciseID = progressStore.selectedExerciseID
        let sessionAnalytics = await sessionAnalyticsSnapshot(
            plansStore: plansStore,
            sessionStore: sessionStore
        )
        let snapshot = analytics.makeProgressSnapshot(
            sessionAnalytics: sessionAnalytics,
            selectedExerciseID: selectedExerciseID
        )

        guard generation == progressRefreshGeneration else {
            return
        }

        progressStore.apply(snapshot)
    }

    func recordCompletedSession(
        _ session: CompletedSession,
        plansStore: PlansStore,
        sessionStore: SessionStore,
        finishSummary: SessionFinishSummary?
    ) {
        progressRefreshTask?.cancel()
        progressRefreshTask = nil

        let references = plansStore.templateReferences()
        todayStore.recordCompletedSession(
            session,
            plans: plansStore.plans,
            references: references,
            allSessions: sessionStore.completedSessions,
            finishSummary: finishSummary
        )
        progressStore.recordCompletedSession(
            session,
            completedSessions: sessionStore.completedSessions,
            analytics: analytics,
            catalogByID: plansStore.catalogByID,
            finishSummary: finishSummary
        )
    }

    func finishSummary(
        for session: CompletedSession,
        catalogByID: [UUID: ExerciseCatalogItem]
    ) -> SessionFinishSummary {
        analytics.finishSummary(
            for: session,
            previousBestByExerciseID: progressStore.personalBestOneRepMaxByExerciseID,
            catalogByID: catalogByID
        )
    }

    private func apply(_ snapshot: AnalyticsRepository.DerivedStoreSnapshot) {
        todayStore.apply(snapshot.today)
        progressStore.apply(snapshot.progress)
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
            key: sessionAnalyticsCacheKey(
                plansStore: plansStore,
                sessionStore: sessionStore,
                now: now
            )
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
        let key = sessionAnalyticsCacheKey(plansStore: plansStore, sessionStore: sessionStore, now: now)
        let snapshot = await Task.detached(priority: priority) { [analytics] in
            analytics.makeSessionAnalyticsSnapshot(
                sessions: sessions,
                catalogByID: catalogByID,
                now: now
            )
        }.value
        cacheSessionAnalytics(snapshot, key: key)
        return snapshot
    }

    private func cachedSessionAnalyticsSnapshot(
        plansStore: PlansStore,
        sessionStore: SessionStore,
        now: Date = .now
    ) -> AnalyticsRepository.SessionAnalyticsSnapshot? {
        let key = sessionAnalyticsCacheKey(plansStore: plansStore, sessionStore: sessionStore, now: now)
        guard cachedSessionAnalyticsKey == key else {
            return nil
        }

        return cachedSessionAnalytics
    }

    private func cacheSessionAnalytics(
        _ snapshot: AnalyticsRepository.SessionAnalyticsSnapshot,
        key: SessionAnalyticsCacheKey
    ) {
        cachedSessionAnalytics = snapshot
        cachedSessionAnalyticsKey = key
    }

    private func sessionAnalyticsCacheKey(
        plansStore: PlansStore,
        sessionStore: SessionStore,
        now: Date = .now
    ) -> SessionAnalyticsCacheKey {
        SessionAnalyticsCacheKey(
            completedSessionsRevision: sessionStore.completedSessionsRevision,
            catalogRevision: plansStore.catalogRevision,
            dayBucket: Calendar.autoupdatingCurrent.startOfDay(for: now)
        )
    }
}

@MainActor
final class AppPlanCoordinator {
    private let settingsStore: SettingsStore
    private let plansStore: PlansStore
    private let sessionStore: SessionStore
    private let derivedStateController: AppDerivedStateController

    init(
        settingsStore: SettingsStore,
        plansStore: PlansStore,
        sessionStore: SessionStore,
        derivedStateController: AppDerivedStateController
    ) {
        self.settingsStore = settingsStore
        self.plansStore = plansStore
        self.sessionStore = sessionStore
        self.derivedStateController = derivedStateController
    }

    func resetAllDataForFreshStart() {
        plansStore.resetAllData()
        sessionStore.resetAllData()
        settingsStore.hasCompletedOnboarding = false
        derivedStateController.refreshToday(plansStore: plansStore, sessionStore: sessionStore)
        derivedStateController.scheduleProgressRefresh(plansStore: plansStore, sessionStore: sessionStore)
    }

    func completeOnboarding(with presetPack: PresetPack?) {
        if let presetPack {
            plansStore.addPresetPack(presetPack, settings: settingsStore)
        }

        settingsStore.hasCompletedOnboarding = true
        derivedStateController.refreshToday(plansStore: plansStore, sessionStore: sessionStore)
    }

    func savePlan(_ plan: Plan) {
        plansStore.savePlan(plan)
        derivedStateController.refreshToday(plansStore: plansStore, sessionStore: sessionStore)
    }

    func deletePlan(_ planID: UUID) {
        plansStore.deletePlan(planID)
        derivedStateController.refreshToday(plansStore: plansStore, sessionStore: sessionStore)
    }

    func saveTemplate(planID: UUID, template: WorkoutTemplate) {
        plansStore.updateTemplate(planID: planID, template: template)
        derivedStateController.refreshToday(plansStore: plansStore, sessionStore: sessionStore)
    }

    func deleteTemplate(planID: UUID, templateID: UUID) {
        plansStore.deleteTemplate(planID: planID, templateID: templateID)
        derivedStateController.refreshToday(plansStore: plansStore, sessionStore: sessionStore)
    }

    func saveProfile(_ profile: ExerciseProfile) {
        plansStore.saveProfile(profile)
    }

    func saveProfiles(_ profiles: [ExerciseProfile]) {
        plansStore.saveProfiles(profiles)
    }

    func updateCatalogItem(
        itemID: UUID,
        name: String,
        aliases: [String],
        category: ExerciseCategory
    ) {
        plansStore.updateExerciseCatalogItem(
            itemID,
            name: name,
            aliases: aliases,
            category: category
        )
        derivedStateController.refreshToday(plansStore: plansStore, sessionStore: sessionStore)
        derivedStateController.scheduleProgressRefresh(plansStore: plansStore, sessionStore: sessionStore)
    }
}

@MainActor
final class AppSessionCoordinator {
    private let settingsStore: SettingsStore
    private let plansStore: PlansStore
    private let sessionStore: SessionStore
    private let derivedStateController: AppDerivedStateController

    init(
        settingsStore: SettingsStore,
        plansStore: PlansStore,
        sessionStore: SessionStore,
        derivedStateController: AppDerivedStateController
    ) {
        self.settingsStore = settingsStore
        self.plansStore = plansStore
        self.sessionStore = sessionStore
        self.derivedStateController = derivedStateController
    }

    func startSession(planID: UUID, templateID: UUID) {
        guard let plan = plansStore.plan(for: planID),
              let template = plan.templates.first(where: { $0.id == templateID }) else {
            return
        }

        let draft = SessionEngine.startSession(
            planID: planID,
            template: template,
            profilesByExerciseID: plansStore.profileLookupByExerciseID,
            warmupRamp: settingsStore.warmupRamp
        )
        sessionStore.beginSession(draft)
        plansStore.markTemplateStarted(planID: planID, templateID: templateID, startedAt: draft.startedAt)
        derivedStateController.refreshToday(plansStore: plansStore, sessionStore: sessionStore)
    }

    func resumeActiveSession() {
        sessionStore.presentActiveSession()
    }

    func toggleSetCompletion(blockID: UUID, setID: UUID) {
        sessionStore.pushMutation {
            SessionEngine.toggleCompletion(of: setID, in: blockID, draft: $0)
        }
    }

    func adjustSetWeight(blockID: UUID, setID: UUID, delta: Double) {
        sessionStore.pushMutation {
            SessionEngine.adjustWeight(by: delta, setID: setID, in: blockID, draft: $0)
        }
    }

    func adjustSetReps(blockID: UUID, setID: UUID, delta: Int) {
        sessionStore.pushMutation {
            SessionEngine.adjustReps(by: delta, setID: setID, in: blockID, draft: $0)
        }
    }

    func addSet(to blockID: UUID) {
        sessionStore.pushMutation {
            SessionEngine.addSet(to: blockID, draft: $0)
        }
    }

    func copyLastSet(in blockID: UUID) {
        sessionStore.pushMutation {
            SessionEngine.copyLastSet(in: blockID, draft: $0)
        }
    }

    func addExerciseToActiveSession(exerciseID: UUID) {
        guard let exercise = plansStore.exerciseItem(for: exerciseID) else {
            return
        }

        sessionStore.pushMutation {
            SessionEngine.addExerciseBlock(
                exercise: exercise,
                draft: $0,
                defaultRestSeconds: settingsStore.defaultRestSeconds
            )
        }
    }

    func addCustomExerciseToActiveSession(name: String) {
        guard let trimmedName = name.nonEmptyTrimmed else {
            return
        }

        let exercise = plansStore.addCustomExercise(name: trimmedName)
        addExerciseToActiveSession(exerciseID: exercise.id)
    }

    func updateActiveBlockNotes(blockID: UUID, note: String) {
        sessionStore.pushMutation(persistence: .deferred) {
            SessionEngine.updateNotes(in: blockID, note: note, draft: $0)
        }
    }

    func updateActiveSessionNotes(_ notes: String) {
        sessionStore.pushMutation(persistence: .deferred) {
            SessionEngine.updateSessionNotes(notes, draft: $0)
        }
    }

    func clearRestTimer() {
        sessionStore.clearRestTimer()
    }

    func finishActiveSession() {
        let catalogByID = plansStore.catalogByID
        guard let completedSession = sessionStore.completeSession() else {
            return
        }

        let finishSummary = derivedStateController.finishSummary(
            for: completedSession,
            catalogByID: catalogByID
        )
        sessionStore.lastFinishedSummary = finishSummary

        if let planID = completedSession.planID {
            plansStore.updatePlanProgression(
                planID: planID,
                templateID: completedSession.templateID,
                completedSession: completedSession,
                settings: settingsStore
            )
        }

        derivedStateController.recordCompletedSession(
            completedSession,
            plansStore: plansStore,
            sessionStore: sessionStore,
            finishSummary: finishSummary
        )
    }

    func discardActiveSession() {
        sessionStore.discardActiveSession()
        derivedStateController.refreshToday(plansStore: plansStore, sessionStore: sessionStore)
    }

    func undoSessionMutation() {
        sessionStore.undoLastMutation()
    }
}
