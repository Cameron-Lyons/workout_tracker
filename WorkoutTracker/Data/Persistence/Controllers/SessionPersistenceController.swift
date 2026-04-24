import Foundation
import SwiftData

@MainActor
enum SessionPersistenceControllerRegistry {
    nonisolated(unsafe) private static var controllers: [ObjectIdentifier: SessionPersistenceController] = [:]

    static func controller(for modelContainer: ModelContainer) -> SessionPersistenceController {
        let key = ObjectIdentifier(modelContainer)
        if let existing = controllers[key] {
            return existing
        }

        let controller = SessionPersistenceController(modelContainer: modelContainer)
        controllers[key] = controller
        return controller
    }
}

final class SessionPersistenceController: @unchecked Sendable {
    private let modelContainer: ModelContainer
    private let queue = DispatchQueue(label: "com.cam.workouttracker.session-persistence", qos: .utility)

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    func scheduleSaveActiveDraft(_ draft: SessionDraft?) {
        queue.async { [modelContainer] in
            let interval = PerformanceSignpost.begin("Draft Persistence")
            defer { PerformanceSignpost.end(interval) }

            let context = ModelContext(modelContainer)
            context.autosaveEnabled = false
            let repository = SessionRepository(modelContext: context)
            repository.saveActiveDraft(draft)
        }
    }

    func schedulePersistCompletedSession(_ session: CompletedSession) {
        queue.async { [modelContainer] in
            let interval = PerformanceSignpost.begin("Completed Session Persistence")
            defer { PerformanceSignpost.end(interval) }

            let context = ModelContext(modelContainer)
            context.autosaveEnabled = false
            let repository = SessionRepository(modelContext: context)
            repository.persistCompletedSessionAndClearActiveDraft(session)
        }
    }

    func scheduleSaveSessionAnalyticsSnapshot(
        _ snapshot: AnalyticsRepository.SessionAnalyticsSnapshot,
        completedSessionsRevision: Int
    ) {
        queue.async { [modelContainer] in
            let interval = PerformanceSignpost.begin("Analytics Snapshot Persistence")
            defer { PerformanceSignpost.end(interval) }

            let context = ModelContext(modelContainer)
            context.autosaveEnabled = false
            let repository = SessionRepository(modelContext: context)
            repository.saveSessionAnalyticsSnapshot(
                snapshot,
                completedSessionsRevision: completedSessionsRevision
            )
        }
    }

    func scheduleDeleteEverything() {
        queue.async { [modelContainer] in
            let interval = PerformanceSignpost.begin("Session Reset Persistence")
            defer { PerformanceSignpost.end(interval) }

            let context = ModelContext(modelContainer)
            context.autosaveEnabled = false
            let repository = SessionRepository(modelContext: context)
            repository.deleteEverything()
        }
    }

    func flush() {
        queue.sync {}
    }
}
