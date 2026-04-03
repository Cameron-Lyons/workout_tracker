import SwiftData
import XCTest

@testable import WorkoutTracker

extension WorkoutStoreTests {
    @MainActor
    func testDeferredDraftMutationsPersistWhenFlushed() throws {
        let container = WorkoutModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let repository = SessionRepository(modelContext: context)
        let store = SessionStore(
            repository: repository,
            persistenceController: SessionPersistenceControllerRegistry.controller(for: container)
        )
        let row = SessionSetRow(
            target: SetTarget(
                setKind: .working,
                targetWeight: 185,
                repRange: RepRange(5, 5)
            )
        )
        let block = SessionExercise(
            exerciseID: CatalogSeed.benchPress,
            exerciseNameSnapshot: "Bench Press",
            restSeconds: 90,
            progressionRule: .manual,
            sets: [row]
        )
        let draft = SessionDraft(
            planID: nil,
            templateID: UUID(),
            templateNameSnapshot: "Bench Day",
            exercises: [block]
        )

        store.beginSession(draft)
        store.pushMutation(persistence: .deferred) { updatedDraft in
            SessionEngine.adjustWeight(by: 5, setID: row.id, in: block.id, draft: &updatedDraft)
        }

        XCTAssertEqual(store.activeDraft?.exercises.first?.sets.first?.log.weight, 190)
        XCTAssertNil(repository.loadActiveDraft()?.exercises.first?.sets.first?.log.weight)

        store.flushPendingDraftSave()

        XCTAssertEqual(repository.loadActiveDraft()?.exercises.first?.sets.first?.log.weight, 190)
    }

    @MainActor
    func testDeferredDraftMutationsPersistAfterDebounceWithoutManualFlush() async throws {
        let container = WorkoutModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let repository = SessionRepository(modelContext: context)
        let persistenceController = SessionPersistenceControllerRegistry.controller(for: container)
        let store = SessionStore(
            repository: repository,
            persistenceController: persistenceController
        )
        let draft = SessionDraft(
            planID: nil,
            templateID: UUID(),
            templateNameSnapshot: "Bench Day",
            exercises: []
        )

        store.beginSession(draft)
        persistenceController.flush()

        store.pushMutation(persistence: .deferred) { updatedDraft in
            updatedDraft.templateNameSnapshot = "Updated day"
        }

        XCTAssertEqual(repository.loadActiveDraft()?.templateNameSnapshot, "Bench Day")

        try await Task.sleep(nanoseconds: 700_000_000)
        persistenceController.flush()

        XCTAssertEqual(repository.loadActiveDraft()?.templateNameSnapshot, "Updated day")
    }

    @MainActor
    func testSessionStoreOnlyNotifiesLiveActivityObserverForTimerRelevantChanges() throws {
        let container = WorkoutModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let repository = SessionRepository(modelContext: context)
        let store = SessionStore(
            repository: repository,
            persistenceController: SessionPersistenceControllerRegistry.controller(for: container)
        )

        let target = SetTarget(
            setKind: .working,
            targetWeight: 185,
            repRange: RepRange(5, 5)
        )
        let row = SessionSetRow(target: target)
        let block = SessionExercise(
            exerciseID: CatalogSeed.benchPress,
            exerciseNameSnapshot: "Bench Press",
            restSeconds: 90,
            progressionRule: .manual,
            sets: [row]
        )
        let draft = SessionDraft(
            planID: nil,
            templateID: UUID(),
            templateNameSnapshot: "Bench Day",
            exercises: [block]
        )

        var observedDrafts: [SessionDraft?] = []
        store.onActiveDraftLiveActivityStateChanged = { observedDrafts.append($0) }

        store.beginSession(draft)
        observedDrafts.removeAll()

        store.pushMutation(persistence: .deferred) { updatedDraft in
            SessionEngine.adjustWeight(by: 5, setID: row.id, in: block.id, draft: &updatedDraft)
        }
        XCTAssertTrue(observedDrafts.isEmpty)

        let completedAt = Date(timeIntervalSince1970: 1_741_600_000)
        store.pushMutation(
            blockID: block.id,
            setID: row.id,
            undoStrategy: .exercise(block.id),
            persistence: .deferred
        ) { updatedDraft, context in
            SessionEngine.toggleCompletion(
                of: row.id,
                in: block.id,
                draft: &updatedDraft,
                context: context,
                completedAt: completedAt
            )
        }

        XCTAssertEqual(observedDrafts.count, 1)
        XCTAssertEqual(observedDrafts.last??.restTimerEndsAt, completedAt.addingTimeInterval(90))

        store.clearRestTimer()

        XCTAssertEqual(observedDrafts.count, 2)
        XCTAssertNil(observedDrafts.last??.restTimerEndsAt)
    }

    @MainActor
    func testCompletedSessionHistoryMergePrefersLocalCopiesAndResetsLoadingFlags() {
        let container = WorkoutModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let store = SessionStore(
            repository: SessionRepository(modelContext: context),
            persistenceController: SessionPersistenceControllerRegistry.controller(for: container)
        )
        let duplicateSessionID = UUID()
        let planID = UUID()
        let templateID = UUID()
        let earlierDate = Date(timeIntervalSince1970: 1_741_478_400)
        let laterDate = earlierDate.addingTimeInterval(86_400)
        let localSession = makeCompletedSession(
            id: duplicateSessionID,
            planID: planID,
            templateID: templateID,
            templateNameSnapshot: "Local Session",
            date: laterDate
        )
        let remoteDuplicate = makeCompletedSession(
            id: duplicateSessionID,
            planID: planID,
            templateID: templateID,
            templateNameSnapshot: "Remote Session",
            date: laterDate.addingTimeInterval(-60)
        )
        let earlierRemoteSession = makeCompletedSession(
            planID: UUID(),
            templateID: UUID(),
            templateNameSnapshot: "Earlier Session",
            date: earlierDate
        )

        store.hydrate(
            with: SessionStore.HydrationSnapshot(
                activeDraft: nil,
                completedSessions: [localSession],
                includesCompleteHistory: false
            )
        )

        let initialRevision = store.completedSessionsRevision
        XCTAssertFalse(store.hasLoadedCompletedSessionHistory)
        XCTAssertTrue(store.isLoadingCompletedSessionHistory)

        store.setCompletedSessionHistoryLoading(false)
        XCTAssertFalse(store.isLoadingCompletedSessionHistory)

        store.setCompletedSessionHistoryLoading(true)
        XCTAssertTrue(store.isLoadingCompletedSessionHistory)

        store.mergeCompletedSessionHistory([remoteDuplicate, earlierRemoteSession])

        XCTAssertTrue(store.hasLoadedCompletedSessionHistory)
        XCTAssertFalse(store.isLoadingCompletedSessionHistory)
        XCTAssertEqual(store.completedSessionsRevision, initialRevision + 1)
        XCTAssertEqual(store.completedSessions.map(\.templateNameSnapshot), ["Earlier Session", "Local Session"])
        XCTAssertEqual(store.completedSessions.last?.id, duplicateSessionID)
        XCTAssertEqual(store.completedSessions.last?.completedAt, laterDate)

        store.setCompletedSessionHistoryLoading(true)
        XCTAssertFalse(store.isLoadingCompletedSessionHistory)
    }

    @MainActor
    func testSessionStoreUndoRestoresBlockSessionAndFullDraftMutationsIncrementally() throws {
        let container = WorkoutModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let repository = SessionRepository(modelContext: context)
        let store = SessionStore(
            repository: repository,
            persistenceController: SessionPersistenceControllerRegistry.controller(for: container)
        )

        let target = SetTarget(
            setKind: .working,
            targetWeight: 185,
            repRange: RepRange(5, 5)
        )
        let row = SessionSetRow(
            target: target,
            log: SetLog(setTargetID: target.id, weight: 185, reps: 5)
        )
        let block = SessionExercise(
            exerciseID: CatalogSeed.benchPress,
            exerciseNameSnapshot: "Bench Press",
            restSeconds: 90,
            progressionRule: .manual,
            sets: [row]
        )
        let draft = SessionDraft(
            planID: nil,
            templateID: UUID(),
            templateNameSnapshot: "Bench Day",
            exercises: [block]
        )
        let accessory = ExerciseCatalogItem(
            id: CatalogSeed.backSquat,
            name: "Back Squat",
            category: .legs
        )

        store.beginSession(draft)
        XCTAssertFalse(store.canUndo)

        store.pushMutation(
            blockID: block.id,
            setID: row.id,
            undoStrategy: .exercise(block.id),
            persistence: .deferred
        ) { updatedDraft, context in
            SessionEngine.adjustWeight(by: 5, setID: row.id, in: block.id, draft: &updatedDraft, context: context)
        }
        store.pushMutation(
            blockID: block.id,
            undoStrategy: .exercise(block.id),
            persistence: .deferred
        ) { updatedDraft, context in
            SessionEngine.addSet(to: block.id, draft: &updatedDraft, context: context)
        }
        store.pushMutation(persistence: .deferred) { updatedDraft, _ in
            SessionEngine.addSessionExercise(
                exercise: accessory,
                draft: &updatedDraft,
                defaultRestSeconds: 120
            )
        }

        let mutatedDraft = try XCTUnwrap(store.activeDraft)
        XCTAssertTrue(store.canUndo)
        XCTAssertEqual(mutatedDraft.exercises.count, 2)
        XCTAssertEqual(mutatedDraft.exercises.first?.sets.count, 2)
        XCTAssertEqual(mutatedDraft.exercises.first?.sets.first?.log.weight, 190)

        store.undoLastMutation()
        let afterFullDraftUndo = try XCTUnwrap(store.activeDraft)
        XCTAssertEqual(afterFullDraftUndo.exercises.count, 1)
        XCTAssertEqual(afterFullDraftUndo.exercises.first?.sets.count, 2)
        XCTAssertEqual(afterFullDraftUndo.exercises.first?.sets.first?.log.weight, 190)

        store.undoLastMutation()
        let afterBlockStructureUndo = try XCTUnwrap(store.activeDraft)
        XCTAssertEqual(afterBlockStructureUndo.exercises.first?.sets.count, 1)
        XCTAssertEqual(afterBlockStructureUndo.exercises.first?.sets.first?.log.weight, 190)

        store.undoLastMutation()
        let afterBlockValueUndo = try XCTUnwrap(store.activeDraft)
        XCTAssertEqual(afterBlockValueUndo.exercises.first?.sets.count, 1)
        XCTAssertEqual(afterBlockValueUndo.exercises.first?.sets.first?.log.weight, 185)
        XCTAssertFalse(store.canUndo)

        store.flushPendingDraftSave()

        let rehydrationContext = ModelContext(container)
        rehydrationContext.autosaveEnabled = false
        let rehydrationRepository = SessionRepository(modelContext: rehydrationContext)
        let rehydratedStore = SessionStore(
            repository: rehydrationRepository,
            persistenceController: SessionPersistenceControllerRegistry.controller(for: container)
        )
        rehydratedStore.hydrate(
            with: SessionStore.HydrationSnapshot(
                activeDraft: rehydrationRepository.loadActiveDraft(),
                completedSessions: rehydrationRepository.loadCompletedSessions()
            )
        )

        let persistedDraft = try XCTUnwrap(rehydratedStore.activeDraft)
        XCTAssertEqual(persistedDraft.exercises.count, 1)
        XCTAssertEqual(persistedDraft.exercises.first?.sets.count, 1)
        XCTAssertEqual(persistedDraft.exercises.first?.sets.first?.log.weight, 185)
    }
}
