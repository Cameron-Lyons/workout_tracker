import Foundation
import Observation

struct SessionMutationContext {
    static let empty = SessionMutationContext(exerciseIndex: nil, setIndex: nil)

    let exerciseIndex: Int?
    let setIndex: Int?
}

struct SessionMutationResult {
    let didMutate: Bool
    let invalidatesIndexCache: Bool
    let requiresProgressRebuild: Bool

    static let unchanged = SessionMutationResult(
        didMutate: false,
        invalidatesIndexCache: false,
        requiresProgressRebuild: false
    )
    static let changed = SessionMutationResult(
        didMutate: true,
        invalidatesIndexCache: false,
        requiresProgressRebuild: false
    )
    static let progressChanged = SessionMutationResult(
        didMutate: true,
        invalidatesIndexCache: false,
        requiresProgressRebuild: true
    )
    static let structureChanged = SessionMutationResult(
        didMutate: true,
        invalidatesIndexCache: true,
        requiresProgressRebuild: false
    )
    static let structureAndProgressChanged = SessionMutationResult(
        didMutate: true,
        invalidatesIndexCache: true,
        requiresProgressRebuild: true
    )
}

private struct SessionDraftMetadata {
    var restTimerEndsAt: Date?
    var restTimerBeganAt: Date?
    var lastUpdatedAt: Date

    init(draft: SessionDraft) {
        restTimerEndsAt = draft.restTimerEndsAt
        restTimerBeganAt = draft.restTimerBeganAt
        lastUpdatedAt = draft.lastUpdatedAt
    }

    func applying(to draft: inout SessionDraft) {
        draft.restTimerEndsAt = restTimerEndsAt
        draft.restTimerBeganAt = restTimerBeganAt
        draft.lastUpdatedAt = lastUpdatedAt
    }
}

enum SessionUndoStrategy {
    case fullDraft
    case exercise(UUID)
}

struct ActiveSessionProgress: Equatable, Sendable {
    var exerciseCount = 0
    var completedSetCount = 0
    var canFinishWorkout = false

    init(draft: SessionDraft?) {
        guard let draft else {
            return
        }

        exerciseCount = draft.exercises.count
        for exercise in draft.exercises {
            for row in exercise.sets where row.log.isCompleted {
                completedSetCount += 1
                if row.target.setKind == .working {
                    canFinishWorkout = true
                }
            }
        }
    }
}

private enum SessionUndoEntry {
    case fullDraft(SessionDraft)
    case exercise(
        sessionExerciseID: UUID,
        index: Int,
        exercise: SessionExercise,
        metadata: SessionDraftMetadata
    )
}

private struct ActiveDraftIndexCache {
    private var exerciseIndicesByID: [UUID: Int] = [:]
    private var setIndicesBySessionExerciseID: [UUID: [UUID: Int]] = [:]

    init(draft: SessionDraft?) {
        guard let draft else {
            return
        }

        exerciseIndicesByID.reserveCapacity(draft.exercises.count)
        setIndicesBySessionExerciseID.reserveCapacity(draft.exercises.count)

        for (exerciseIndex, exercise) in draft.exercises.enumerated() {
            exerciseIndicesByID[exercise.id] = exerciseIndex
            setIndicesBySessionExerciseID[exercise.id] = Dictionary(
                uniqueKeysWithValues: exercise.sets.enumerated().map { ($0.element.id, $0.offset) }
            )
        }
    }

    func context(blockID: UUID?, setID: UUID?) -> SessionMutationContext {
        guard let blockID else {
            return .empty
        }

        let exerciseIndex = exerciseIndicesByID[blockID]
        let setIndex = setID.flatMap { setIndicesBySessionExerciseID[blockID]?[$0] }
        return SessionMutationContext(exerciseIndex: exerciseIndex, setIndex: setIndex)
    }
}

@MainActor
@Observable
final class SessionStore {
    private enum Defaults {
        static let draftSaveDebounceNanoseconds: UInt64 = 400_000_000
        static let maxUndoSnapshots = 50
    }

    struct HydrationSnapshot: Sendable {
        var activeDraft: SessionDraft?
        var completedSessions: [CompletedSession]
        var includesCompleteHistory = true
    }

    enum DraftPersistenceBehavior {
        case immediate
        case deferred
    }

    @ObservationIgnored private let repository: SessionRepository
    @ObservationIgnored private let persistenceController: SessionPersistenceController
    @ObservationIgnored private var draftSaveTask: Task<Void, Never>?
    @ObservationIgnored private let draftSaveDebounceNanoseconds = Defaults.draftSaveDebounceNanoseconds
    @ObservationIgnored private let maxUndoSnapshots = Defaults.maxUndoSnapshots
    @ObservationIgnored private(set) var completedSessionsRevision = 0
    @ObservationIgnored private var activeDraftIndexCache = ActiveDraftIndexCache(draft: nil)

    var activeDraft: SessionDraft?
    private(set) var activeDraftProgress = ActiveSessionProgress(draft: nil)
    @ObservationIgnored var onActiveDraftLiveActivityStateChanged: ((SessionDraft?) -> Void)?
    var completedSessions: [CompletedSession] = []
    private(set) var hasLoadedCompletedSessionHistory = true
    private(set) var isLoadingCompletedSessionHistory = false
    var isPresentingSession = false
    var lastFinishedSummary: SessionFinishSummary?
    private var undoStack: [SessionUndoEntry] = []

    var canUndo: Bool {
        !undoStack.isEmpty
    }

    init(repository: SessionRepository, persistenceController: SessionPersistenceController) {
        self.repository = repository
        self.persistenceController = persistenceController
    }

    deinit {
        draftSaveTask?.cancel()
    }

    func hydrate(with snapshot: HydrationSnapshot) {
        replaceActiveDraft(snapshot.activeDraft)
        completedSessions = snapshot.completedSessions
        hasLoadedCompletedSessionHistory = snapshot.includesCompleteHistory
        isLoadingCompletedSessionHistory = snapshot.includesCompleteHistory == false
        bumpCompletedSessionsRevision()
    }

    func resetAllData() {
        cancelPendingDraftSave()
        persistenceController.scheduleDeleteEverything()
        replaceActiveDraft(nil)
        completedSessions = []
        hasLoadedCompletedSessionHistory = true
        isLoadingCompletedSessionHistory = false
        bumpCompletedSessionsRevision()
        isPresentingSession = false
        lastFinishedSummary = nil
        undoStack = []
    }

    func setCompletedSessionHistoryLoading(_ isLoading: Bool) {
        guard hasLoadedCompletedSessionHistory == false else {
            isLoadingCompletedSessionHistory = false
            return
        }

        isLoadingCompletedSessionHistory = isLoading
    }

    func mergeCompletedSessionHistory(_ sessions: [CompletedSession]) {
        if completedSessions.isEmpty {
            completedSessions = sessions
            hasLoadedCompletedSessionHistory = true
            isLoadingCompletedSessionHistory = false
            bumpCompletedSessionsRevision()
            return
        }

        var sessionsByID = Dictionary(uniqueKeysWithValues: sessions.map { ($0.id, $0) })
        sessionsByID.reserveCapacity(max(sessionsByID.count, completedSessions.count))

        for session in completedSessions {
            sessionsByID[session.id] = session
        }

        completedSessions = sessionsByID.values.sorted(by: { $0.completedAt < $1.completedAt })
        hasLoadedCompletedSessionHistory = true
        isLoadingCompletedSessionHistory = false
        bumpCompletedSessionsRevision()
    }

    func presentActiveSession() {
        guard activeDraft != nil else {
            return
        }

        isPresentingSession = true
    }

    func dismissSessionPresentation() {
        isPresentingSession = false
    }

    func beginSession(_ draft: SessionDraft) {
        cancelPendingDraftSave()
        replaceActiveDraft(draft)
        undoStack = []
        persistActiveDraft(using: .immediate)
        isPresentingSession = true
    }

    func pushMutation(
        persistence: DraftPersistenceBehavior = .immediate,
        _ mutation: (inout SessionDraft) -> Void
    ) {
        pushMutation(persistence: persistence) { draft, _ in
            let previousDraft = draft
            mutation(&draft)
            return draft == previousDraft ? .unchanged : .progressChanged
        }
    }

    func pushMutation(
        blockID: UUID? = nil,
        setID: UUID? = nil,
        undoStrategy: SessionUndoStrategy = .fullDraft,
        persistence: DraftPersistenceBehavior = .immediate,
        _ mutation: (inout SessionDraft, SessionMutationContext) -> SessionMutationResult
    ) {
        guard var draft = activeDraft else {
            return
        }

        let interval = PerformanceSignpost.begin("Session Mutation")
        defer { PerformanceSignpost.end(interval) }

        let snapshot = draft
        let context = activeDraftIndexCache.context(blockID: blockID, setID: setID)
        let result = mutation(&draft, context)
        guard result.didMutate else {
            return
        }

        appendUndoEntry(snapshot, strategy: undoStrategy, context: context)
        updateActiveDraft(
            draft,
            invalidateIndexCache: result.invalidatesIndexCache,
            recomputeProgress: result.requiresProgressRebuild
        )
        persistActiveDraft(using: persistence)
    }

    func undoLastMutation() {
        guard let entry = undoStack.popLast() else {
            return
        }

        let interval = PerformanceSignpost.begin("Session Undo")
        defer { PerformanceSignpost.end(interval) }

        cancelPendingDraftSave()
        switch entry {
        case .fullDraft(let previousDraft):
            replaceActiveDraft(previousDraft)
        case .exercise(let sessionExerciseID, let index, let exercise, let metadata):
            guard var draft = activeDraft else {
                return
            }

            if let currentIndex = resolvedExerciseIndex(in: draft, blockID: sessionExerciseID, suggested: index) {
                draft.exercises[currentIndex] = exercise
            } else {
                draft.exercises.insert(exercise, at: min(index, draft.exercises.count))
            }
            metadata.applying(to: &draft)
            replaceActiveDraft(draft)
        }
        persistActiveDraft(using: .deferred)
    }

    func clearRestTimer() {
        guard var activeDraft else {
            return
        }

        guard activeDraft.restTimerEndsAt != nil else {
            return
        }

        activeDraft.restTimerEndsAt = nil
        activeDraft.restTimerBeganAt = nil
        updateActiveDraft(activeDraft, recomputeProgress: false)
        cancelPendingDraftSave()
        persistActiveDraft(using: .immediate)
    }

    func flushPendingDraftSave() {
        if draftSaveTask != nil {
            cancelPendingDraftSave()
            persistenceController.scheduleSaveActiveDraft(activeDraft)
        }

        persistenceController.flush()
    }

    func persistSessionAnalyticsSnapshot(_ snapshot: AnalyticsRepository.SessionAnalyticsSnapshot) {
        persistenceController.scheduleSaveSessionAnalyticsSnapshot(
            snapshot,
            completedSessionsRevision: completedSessionsRevision
        )
    }

    func completeSession() -> CompletedSession? {
        guard let activeDraft else {
            return nil
        }

        guard
            activeDraft.exercises.contains(where: { block in
                block.sets.contains(where: { row in
                    row.target.setKind == .working && row.log.isCompleted
                })
            })
        else {
            return nil
        }

        cancelPendingDraftSave()
        let completedSession = SessionEngine.finishSession(draft: activeDraft)
        insertCompletedSession(completedSession)
        bumpCompletedSessionsRevision()
        persistenceController.schedulePersistCompletedSession(completedSession)
        replaceActiveDraft(nil)
        isPresentingSession = false
        undoStack = []
        return completedSession
    }

    func discardActiveSession() {
        cancelPendingDraftSave()
        replaceActiveDraft(nil)
        undoStack = []
        isPresentingSession = false
        persistenceController.scheduleSaveActiveDraft(nil)
    }

    func updateExerciseNameSnapshots(exerciseID: UUID, name: String) {
        guard var activeDraft else {
            return
        }

        var didUpdate = false
        for index in activeDraft.exercises.indices where activeDraft.exercises[index].exerciseID == exerciseID {
            guard activeDraft.exercises[index].exerciseNameSnapshot != name else {
                continue
            }

            activeDraft.exercises[index].exerciseNameSnapshot = name
            didUpdate = true
        }

        guard didUpdate else {
            return
        }

        updateActiveDraft(activeDraft, recomputeProgress: false)
        cancelPendingDraftSave()
        persistActiveDraft(using: .immediate)
    }

    private func appendUndoEntry(
        _ snapshot: SessionDraft,
        strategy: SessionUndoStrategy,
        context: SessionMutationContext
    ) {
        let entry: SessionUndoEntry
        switch strategy {
        case .fullDraft:
            entry = .fullDraft(snapshot)
        case .exercise(let sessionExerciseID):
            guard let exerciseIndex = resolvedExerciseIndex(in: snapshot, blockID: sessionExerciseID, suggested: context.exerciseIndex) else {
                entry = .fullDraft(snapshot)
                break
            }

            entry = .exercise(
                sessionExerciseID: sessionExerciseID,
                index: exerciseIndex,
                exercise: snapshot.exercises[exerciseIndex],
                metadata: SessionDraftMetadata(draft: snapshot)
            )
        }

        undoStack.append(entry)

        if undoStack.count > maxUndoSnapshots {
            undoStack.removeFirst(undoStack.count - maxUndoSnapshots)
        }
    }

    private func bumpCompletedSessionsRevision() {
        completedSessionsRevision &+= 1
    }

    private func replaceActiveDraft(_ draft: SessionDraft?) {
        updateActiveDraft(draft, invalidateIndexCache: true)
    }

    private func updateActiveDraft(
        _ draft: SessionDraft?,
        invalidateIndexCache: Bool = false,
        recomputeProgress: Bool = true
    ) {
        let previousDraft = activeDraft
        activeDraft = draft
        if recomputeProgress || draft == nil {
            activeDraftProgress = ActiveSessionProgress(draft: draft)
        }
        if invalidateIndexCache {
            rebuildActiveDraftIndexCache()
        }

        guard liveActivityState(for: previousDraft) != liveActivityState(for: draft) else {
            return
        }

        onActiveDraftLiveActivityStateChanged?(draft)
    }

    private func rebuildActiveDraftIndexCache() {
        activeDraftIndexCache = ActiveDraftIndexCache(draft: activeDraft)
    }

    private func liveActivityState(for draft: SessionDraft?) -> (UUID?, String?, Date?, Date?) {
        (
            draft?.id,
            draft?.templateNameSnapshot,
            draft?.restTimerEndsAt,
            draft?.restTimerBeganAt
        )
    }

    private func resolvedExerciseIndex(
        in draft: SessionDraft,
        blockID: UUID,
        suggested: Int?
    ) -> Int? {
        if let suggested, draft.exercises.indices.contains(suggested), draft.exercises[suggested].id == blockID {
            return suggested
        }

        return draft.exercises.firstIndex(where: { $0.id == blockID })
    }

    private func insertCompletedSession(_ session: CompletedSession) {
        if let index = completedSessions.firstIndex(where: { $0.completedAt > session.completedAt }) {
            completedSessions.insert(session, at: index)
        } else {
            completedSessions.append(session)
        }
    }

    private func persistActiveDraft(using behavior: DraftPersistenceBehavior) {
        switch behavior {
        case .immediate:
            cancelPendingDraftSave()
            persistenceController.scheduleSaveActiveDraft(activeDraft)
        case .deferred:
            scheduleDraftSave()
        }
    }

    private func scheduleDraftSave() {
        cancelPendingDraftSave()
        draftSaveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: self?.draftSaveDebounceNanoseconds ?? 0)
            guard !Task.isCancelled else {
                return
            }

            await MainActor.run {
                self?.persistDeferredDraft()
            }
        }
    }

    private func cancelPendingDraftSave() {
        draftSaveTask?.cancel()
        draftSaveTask = nil
    }

    private func persistDeferredDraft() {
        draftSaveTask = nil
        persistenceController.scheduleSaveActiveDraft(activeDraft)
    }
}
