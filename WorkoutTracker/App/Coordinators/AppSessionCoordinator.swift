import Foundation

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
        guard sessionStore.activeDraft == nil else {
            sessionStore.presentActiveSession()
            return
        }

        beginSession(planID: planID, templateID: templateID)
    }

    func replaceActiveSessionAndStart(planID: UUID, templateID: UUID) {
        beginSession(planID: planID, templateID: templateID, discardingActiveSession: true)
    }

    private func beginSession(
        planID: UUID,
        templateID: UUID,
        discardingActiveSession: Bool = false
    ) {
        let signpost = PerformanceSignpost.begin("Session Start")
        defer { PerformanceSignpost.end(signpost) }

        guard let plan = plansStore.plan(for: planID),
            let template = plan.templates.first(where: { $0.id == templateID })
        else {
            return
        }

        if discardingActiveSession {
            sessionStore.discardActiveSession()
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
        sessionStore.pushMutation(
            blockID: blockID,
            setID: setID,
            undoStrategy: .exercise(blockID),
            persistence: .deferred
        ) { draft, context in
            SessionEngine.toggleCompletion(of: setID, in: blockID, draft: &draft, context: context)
        }
    }

    func adjustSetWeight(blockID: UUID, setID: UUID, delta: Double) {
        sessionStore.pushMutation(
            blockID: blockID,
            setID: setID,
            undoStrategy: .exercise(blockID),
            persistence: .deferred
        ) { draft, context in
            SessionEngine.adjustWeight(by: delta, setID: setID, in: blockID, draft: &draft, context: context)
        }
    }

    func adjustSetReps(blockID: UUID, setID: UUID, delta: Int) {
        sessionStore.pushMutation(
            blockID: blockID,
            setID: setID,
            undoStrategy: .exercise(blockID),
            persistence: .deferred
        ) { draft, context in
            SessionEngine.adjustReps(by: delta, setID: setID, in: blockID, draft: &draft, context: context)
        }
    }

    func updateSetWeight(blockID: UUID, setID: UUID, weight: Double) {
        sessionStore.pushMutation(
            blockID: blockID,
            setID: setID,
            undoStrategy: .exercise(blockID),
            persistence: .deferred
        ) { draft, context in
            SessionEngine.updateWeight(to: weight, setID: setID, in: blockID, draft: &draft, context: context)
        }
    }

    func updateSetReps(blockID: UUID, setID: UUID, reps: Int) {
        sessionStore.pushMutation(
            blockID: blockID,
            setID: setID,
            undoStrategy: .exercise(blockID),
            persistence: .deferred
        ) { draft, context in
            SessionEngine.updateReps(to: reps, setID: setID, in: blockID, draft: &draft, context: context)
        }
    }

    func addSet(to blockID: UUID) {
        sessionStore.pushMutation(
            blockID: blockID,
            undoStrategy: .exercise(blockID),
            persistence: .deferred
        ) { draft, context in
            SessionEngine.addSet(to: blockID, draft: &draft, context: context)
        }
    }

    func copyLastSet(in blockID: UUID) {
        sessionStore.pushMutation(
            blockID: blockID,
            undoStrategy: .exercise(blockID),
            persistence: .deferred
        ) { draft, context in
            SessionEngine.copyLastSet(in: blockID, draft: &draft, context: context)
        }
    }

    func addExerciseToActiveSession(exerciseID: UUID) {
        guard let exercise = plansStore.exerciseItem(for: exerciseID) else {
            return
        }

        sessionStore.pushMutation(persistence: .deferred) { draft, _ in
            SessionEngine.addSessionExercise(
                exercise: exercise,
                draft: &draft,
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

    func clearRestTimer() {
        sessionStore.clearRestTimer()
    }

    @discardableResult
    func finishActiveSession() -> Bool {
        let signpost = PerformanceSignpost.begin("Session Finish")
        defer { PerformanceSignpost.end(signpost) }

        let catalogByID = plansStore.catalogByID
        let finishedBlocks = sessionStore.activeDraft?.exercises
        guard let completedSession = sessionStore.completeSession() else {
            return false
        }

        let completedSessionResult = derivedStateController.completedSessionResult(
            for: completedSession,
            catalogByID: catalogByID
        )
        let finishSummary = completedSessionResult.finishSummary
        sessionStore.lastFinishedSummary = finishSummary

        if let planID = completedSession.planID,
            let finishedBlocks
        {
            plansStore.updatePlanProgression(
                planID: planID,
                templateID: completedSession.templateID,
                finishedBlocks: finishedBlocks,
                settings: settingsStore
            )
        }

        let sessionAnalyticsSnapshot = derivedStateController.recordCompletedSession(
            completedSession,
            plansStore: plansStore,
            sessionStore: sessionStore,
            finishSummary: finishSummary,
            payloads: completedSessionResult.payloads
        )
        sessionStore.persistSessionAnalyticsSnapshot(sessionAnalyticsSnapshot)
        return true
    }

    func discardActiveSession() {
        sessionStore.discardActiveSession()
        derivedStateController.refreshToday(plansStore: plansStore, sessionStore: sessionStore)
    }

    func undoSessionMutation() {
        sessionStore.undoLastMutation()
    }

    func flushPendingDraftPersistence() {
        sessionStore.flushPendingDraftSave()
    }
}
