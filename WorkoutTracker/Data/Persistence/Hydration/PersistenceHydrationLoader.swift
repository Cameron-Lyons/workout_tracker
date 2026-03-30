import SwiftData

struct AppHydrationSnapshot: Sendable {
    var plans: PlansStore.HydrationSnapshot
    var sessions: SessionStore.HydrationSnapshot
}

actor PersistenceHydrationLoader {
    private let modelContainer: ModelContainer
    private let planPersistenceController: PlanPersistenceController
    private let sessionPersistenceController: SessionPersistenceController

    init(
        modelContainer: ModelContainer,
        planPersistenceController: PlanPersistenceController,
        sessionPersistenceController: SessionPersistenceController
    ) {
        self.modelContainer = modelContainer
        self.planPersistenceController = planPersistenceController
        self.sessionPersistenceController = sessionPersistenceController
    }

    func loadStartupSnapshot() -> AppHydrationSnapshot {
        planPersistenceController.flush()
        sessionPersistenceController.flush()

        let context = ModelContext(modelContainer)
        context.autosaveEnabled = false

        let planRepository = PlanRepository(modelContext: context)
        let sessionRepository = SessionRepository(modelContext: context)

        var catalog = planRepository.loadCatalog()
        if catalog.isEmpty {
            catalog = CatalogSeed.defaultCatalog()
            planRepository.saveCatalog(catalog)
        }
        let profiles = planRepository.loadProfiles()

        return AppHydrationSnapshot(
            plans: PlansStore.HydrationSnapshot(
                catalog: catalog,
                plans: [],
                profiles: profiles,
                includesProfiles: true,
                profileCount: profiles.count,
                planSummaries: planRepository.loadPlanSummaries(),
                includesFullPlanLibrary: false
            ),
            sessions: SessionStore.HydrationSnapshot(
                activeDraft: sessionRepository.loadActiveDraft(),
                completedSessions: [],
                includesCompleteHistory: false
            )
        )
    }

    func loadCompletedSessionHistory() -> [CompletedSession] {
        sessionPersistenceController.flush()

        let context = ModelContext(modelContainer)
        context.autosaveEnabled = false
        return SessionRepository(modelContext: context).loadCompletedSessions()
    }
}
