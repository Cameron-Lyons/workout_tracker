import Foundation
import Observation

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

    var activeDraft: SessionDraft?
    var completedSessions: [CompletedSession] = []
    var isPresentingSession = false
    var lastFinishedSummary: SessionFinishSummary?
    var undoStack: [SessionDraft] = []

    init(repository: SessionRepository, persistenceController: SessionPersistenceController) {
        self.repository = repository
        self.persistenceController = persistenceController
    }

    deinit {
        draftSaveTask?.cancel()
    }

    func hydrate(with snapshot: HydrationSnapshot) {
        activeDraft = snapshot.activeDraft
        completedSessions = snapshot.completedSessions
        bumpCompletedSessionsRevision()
    }

    func resetAllData() {
        cancelPendingDraftSave()
        persistenceController.scheduleDeleteEverything()
        activeDraft = nil
        completedSessions = []
        bumpCompletedSessionsRevision()
        isPresentingSession = false
        lastFinishedSummary = nil
        undoStack = []
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
        activeDraft = draft
        undoStack = []
        persistActiveDraft(using: .immediate)
        isPresentingSession = true
    }

    func pushMutation(
        persistence: DraftPersistenceBehavior = .immediate,
        _ mutation: (inout SessionDraft) -> Void
    ) {
        guard let activeDraft else {
            return
        }

        var updatedDraft = activeDraft
        mutation(&updatedDraft)
        guard updatedDraft != activeDraft else {
            return
        }

        appendUndoSnapshot(activeDraft)
        self.activeDraft = updatedDraft
        persistActiveDraft(using: persistence)
    }

    func undoLastMutation() {
        guard let previousDraft = undoStack.popLast() else {
            return
        }

        cancelPendingDraftSave()
        activeDraft = previousDraft
        persistActiveDraft(using: .immediate)
    }

    func clearRestTimer() {
        guard var activeDraft else {
            return
        }

        activeDraft.restTimerEndsAt = nil
        self.activeDraft = activeDraft
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
        self.activeDraft = nil
        isPresentingSession = false
        undoStack = []
        return completedSession
    }

    func discardActiveSession() {
        cancelPendingDraftSave()
        activeDraft = nil
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

        self.activeDraft = activeDraft
        cancelPendingDraftSave()
        persistActiveDraft(using: .immediate)
    }

    private func appendUndoSnapshot(_ draft: SessionDraft) {
        undoStack.append(draft)

        if undoStack.count > maxUndoSnapshots {
            undoStack.removeFirst(undoStack.count - maxUndoSnapshots)
        }
    }

    private func bumpCompletedSessionsRevision() {
        completedSessionsRevision &+= 1
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
