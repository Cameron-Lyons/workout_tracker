import Foundation
import Observation

struct SessionMutationContext {
    static let empty = SessionMutationContext(blockIndex: nil, setIndex: nil)

    let blockIndex: Int?
    let setIndex: Int?
}

enum SessionMutationResult {
    case unchanged
    case changed
    case structureChanged

    var didMutate: Bool {
        self != .unchanged
    }

    var invalidatesIndexCache: Bool {
        self == .structureChanged
    }
}

private struct SessionDraftMetadata {
    var notes: String
    var restTimerEndsAt: Date?
    var lastUpdatedAt: Date

    init(draft: SessionDraft) {
        notes = draft.notes
        restTimerEndsAt = draft.restTimerEndsAt
        lastUpdatedAt = draft.lastUpdatedAt
    }

    func applying(to draft: inout SessionDraft) {
        draft.notes = notes
        draft.restTimerEndsAt = restTimerEndsAt
        draft.lastUpdatedAt = lastUpdatedAt
    }
}

enum SessionUndoStrategy {
    case fullDraft
    case sessionMetadata
    case block(UUID)
}

struct ActiveSessionProgress: Equatable, Sendable {
    var blockCount = 0
    var completedSetCount = 0
    var canFinishWorkout = false

    init(draft: SessionDraft?) {
        guard let draft else {
            return
        }

        blockCount = draft.blocks.count
        for block in draft.blocks {
            for row in block.sets where row.log.isCompleted {
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
    case sessionMetadata(SessionDraftMetadata)
    case block(
        blockID: UUID,
        index: Int,
        block: SessionBlock,
        metadata: SessionDraftMetadata
    )
}

private struct ActiveDraftIndexCache {
    private var blockIndicesByID: [UUID: Int] = [:]
    private var setIndicesByBlockID: [UUID: [UUID: Int]] = [:]

    init(draft: SessionDraft?) {
        guard let draft else {
            return
        }

        blockIndicesByID.reserveCapacity(draft.blocks.count)
        setIndicesByBlockID.reserveCapacity(draft.blocks.count)

        for (blockIndex, block) in draft.blocks.enumerated() {
            blockIndicesByID[block.id] = blockIndex
            setIndicesByBlockID[block.id] = Dictionary(
                uniqueKeysWithValues: block.sets.enumerated().map { ($0.element.id, $0.offset) }
            )
        }
    }

    func context(blockID: UUID?, setID: UUID?) -> SessionMutationContext {
        guard let blockID else {
            return .empty
        }

        let blockIndex = blockIndicesByID[blockID]
        let setIndex = setID.flatMap { setIndicesByBlockID[blockID]?[$0] }
        return SessionMutationContext(blockIndex: blockIndex, setIndex: setIndex)
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
            return draft == previousDraft ? .unchanged : .changed
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
        updateActiveDraft(draft, invalidateIndexCache: result.invalidatesIndexCache)
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
        case .sessionMetadata(let metadata):
            guard var draft = activeDraft else {
                return
            }

            metadata.applying(to: &draft)
            replaceActiveDraft(draft)
        case .block(let blockID, let index, let block, let metadata):
            guard var draft = activeDraft else {
                return
            }

            if let currentIndex = resolvedBlockIndex(in: draft, blockID: blockID, suggested: index) {
                draft.blocks[currentIndex] = block
            } else {
                draft.blocks.insert(block, at: min(index, draft.blocks.count))
            }
            metadata.applying(to: &draft)
            replaceActiveDraft(draft)
        }
        persistActiveDraft(using: .immediate)
    }

    func clearRestTimer() {
        guard var activeDraft else {
            return
        }

        guard activeDraft.restTimerEndsAt != nil else {
            return
        }

        activeDraft.restTimerEndsAt = nil
        updateActiveDraft(activeDraft)
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

    func completeSession() -> CompletedSession? {
        guard let activeDraft else {
            return nil
        }

        guard
            activeDraft.blocks.contains(where: { block in
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
        for index in activeDraft.blocks.indices where activeDraft.blocks[index].exerciseID == exerciseID {
            guard activeDraft.blocks[index].exerciseNameSnapshot != name else {
                continue
            }

            activeDraft.blocks[index].exerciseNameSnapshot = name
            didUpdate = true
        }

        guard didUpdate else {
            return
        }

        updateActiveDraft(activeDraft)
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
        case .sessionMetadata:
            entry = .sessionMetadata(SessionDraftMetadata(draft: snapshot))
        case .block(let blockID):
            guard let blockIndex = resolvedBlockIndex(in: snapshot, blockID: blockID, suggested: context.blockIndex) else {
                entry = .fullDraft(snapshot)
                break
            }

            entry = .block(
                blockID: blockID,
                index: blockIndex,
                block: snapshot.blocks[blockIndex],
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

    private func updateActiveDraft(_ draft: SessionDraft?, invalidateIndexCache: Bool = false) {
        let previousDraft = activeDraft
        activeDraft = draft
        activeDraftProgress = ActiveSessionProgress(draft: draft)
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

    private func liveActivityState(for draft: SessionDraft?) -> (UUID?, String?, Date?) {
        (
            draft?.id,
            draft?.templateNameSnapshot,
            draft?.restTimerEndsAt
        )
    }

    private func resolvedBlockIndex(
        in draft: SessionDraft,
        blockID: UUID,
        suggested: Int?
    ) -> Int? {
        if let suggested, draft.blocks.indices.contains(suggested), draft.blocks[suggested].id == blockID {
            return suggested
        }

        return draft.blocks.firstIndex(where: { $0.id == blockID })
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
