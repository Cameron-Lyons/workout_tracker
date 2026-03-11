import Foundation
import Observation

@MainActor
@Observable
final class SessionStore {
    enum DraftPersistenceBehavior {
        case immediate
        case deferred
    }

    @ObservationIgnored private let repository: SessionRepository
    @ObservationIgnored private var draftSaveTask: Task<Void, Never>?
    @ObservationIgnored private let draftSaveDebounceNanoseconds: UInt64 = 400_000_000
    @ObservationIgnored private let maxUndoSnapshots = 50
    @ObservationIgnored private(set) var completedSessionsRevision = 0

    var activeDraft: SessionDraft?
    var completedSessions: [CompletedSession] = []
    var isPresentingSession = false
    var lastFinishedSummary: SessionFinishSummary?
    var undoStack: [SessionDraft] = []

    init(repository: SessionRepository) {
        self.repository = repository
    }

    deinit {
        draftSaveTask?.cancel()
    }

    func hydrate() {
        activeDraft = repository.loadActiveDraft()
        completedSessions = repository.loadCompletedSessions().sorted(by: { $0.completedAt < $1.completedAt })
        bumpCompletedSessionsRevision()
    }

    func resetAllData() {
        cancelPendingDraftSave()
        repository.deleteEverything()
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
        repository.saveActiveDraft(draft)
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
        repository.saveActiveDraft(previousDraft)
    }

    func clearRestTimer() {
        guard var activeDraft else {
            return
        }

        activeDraft.restTimerEndsAt = nil
        self.activeDraft = activeDraft
        cancelPendingDraftSave()
        repository.saveActiveDraft(activeDraft)
    }

    func flushPendingDraftSave() {
        guard draftSaveTask != nil else {
            return
        }

        cancelPendingDraftSave()
        repository.saveActiveDraft(activeDraft)
    }

    func completeSession() -> CompletedSession? {
        guard let activeDraft else {
            return nil
        }

        cancelPendingDraftSave()
        let completedSession = SessionEngine.finishSession(draft: activeDraft)
        completedSessions.append(completedSession)
        completedSessions.sort(by: { $0.completedAt < $1.completedAt })
        bumpCompletedSessionsRevision()
        repository.saveCompletedSession(completedSession)
        repository.saveActiveDraft(nil)
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
        repository.saveActiveDraft(nil)
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
        repository.saveActiveDraft(activeDraft)
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

    private func persistActiveDraft(using behavior: DraftPersistenceBehavior) {
        switch behavior {
        case .immediate:
            cancelPendingDraftSave()
            repository.saveActiveDraft(activeDraft)
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
        repository.saveActiveDraft(activeDraft)
    }
}
