import Foundation
import SwiftData

@MainActor
enum PlanPersistenceControllerRegistry {
    nonisolated(unsafe) private static var controllers: [ObjectIdentifier: PlanPersistenceController] = [:]

    static func controller(for modelContainer: ModelContainer) -> PlanPersistenceController {
        let key = ObjectIdentifier(modelContainer)
        if let existing = controllers[key] {
            return existing
        }

        let controller = PlanPersistenceController(modelContainer: modelContainer)
        controllers[key] = controller
        return controller
    }
}

final class PlanPersistenceController: @unchecked Sendable {
    private let modelContainer: ModelContainer
    private let queue = DispatchQueue(label: "com.cam.workouttracker.plan-persistence", qos: .utility)

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
    }

    func scheduleSaveCatalog(_ catalog: [ExerciseCatalogItem]) {
        queue.async { [modelContainer] in
            let interval = PerformanceSignpost.begin("Catalog Persistence")
            defer { PerformanceSignpost.end(interval) }

            let context = ModelContext(modelContainer)
            context.autosaveEnabled = false
            let repository = PlanRepository(modelContext: context)
            repository.saveCatalog(catalog)
        }
    }

    func scheduleUpsertCatalogItems(_ items: [ExerciseCatalogItem]) {
        queue.async { [modelContainer] in
            let interval = PerformanceSignpost.begin("Catalog Persistence")
            defer { PerformanceSignpost.end(interval) }

            let context = ModelContext(modelContainer)
            context.autosaveEnabled = false
            let repository = PlanRepository(modelContext: context)
            repository.upsertCatalogItems(items)
        }
    }

    func scheduleUpsertPlans(_ plans: [Plan]) {
        queue.async { [modelContainer] in
            let interval = PerformanceSignpost.begin("Plan Persistence")
            defer { PerformanceSignpost.end(interval) }

            let context = ModelContext(modelContainer)
            context.autosaveEnabled = false
            let repository = PlanRepository(modelContext: context)
            repository.upsertPlans(plans)
        }
    }

    func scheduleDeletePlans(_ planIDs: [UUID]) {
        queue.async { [modelContainer] in
            let interval = PerformanceSignpost.begin("Plan Persistence")
            defer { PerformanceSignpost.end(interval) }

            let context = ModelContext(modelContainer)
            context.autosaveEnabled = false
            let repository = PlanRepository(modelContext: context)
            repository.deletePlans(planIDs)
        }
    }

    func scheduleMarkTemplateStarted(planID: UUID, templateID: UUID, startedAt: Date) {
        queue.async { [modelContainer] in
            let interval = PerformanceSignpost.begin("Template Start Persistence")
            defer { PerformanceSignpost.end(interval) }

            let context = ModelContext(modelContainer)
            context.autosaveEnabled = false
            let repository = PlanRepository(modelContext: context)
            repository.markTemplateStarted(planID: planID, templateID: templateID, startedAt: startedAt)
        }
    }

    func schedulePersistProgression(plan: Plan, updatedProfiles: [ExerciseProfile]) {
        queue.async { [modelContainer] in
            let interval = PerformanceSignpost.begin("Plan Progression Persistence")
            defer { PerformanceSignpost.end(interval) }

            let context = ModelContext(modelContainer)
            context.autosaveEnabled = false
            let repository = PlanRepository(modelContext: context)
            if !updatedProfiles.isEmpty {
                repository.upsertProfiles(updatedProfiles)
            }
            repository.upsertPlans([plan])
        }
    }

    func scheduleUpsertProfiles(_ profiles: [ExerciseProfile]) {
        queue.async { [modelContainer] in
            let interval = PerformanceSignpost.begin("Profile Persistence")
            defer { PerformanceSignpost.end(interval) }

            let context = ModelContext(modelContainer)
            context.autosaveEnabled = false
            let repository = PlanRepository(modelContext: context)
            repository.upsertProfiles(profiles)
        }
    }

    func scheduleDeleteEverything() {
        queue.async { [modelContainer] in
            let interval = PerformanceSignpost.begin("Plan Reset Persistence")
            defer { PerformanceSignpost.end(interval) }

            let context = ModelContext(modelContainer)
            context.autosaveEnabled = false
            let repository = PlanRepository(modelContext: context)
            repository.deleteEverything()
        }
    }

    func flush() {
        queue.sync {}
    }
}
