import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class AppStore {
    @ObservationIgnored private let launchArguments: Set<String>
    @ObservationIgnored private var hasHydrated = false
    @ObservationIgnored private let derivedStateController: AppDerivedStateController
    @ObservationIgnored private let planCoordinator: AppPlanCoordinator
    @ObservationIgnored private let sessionCoordinator: AppSessionCoordinator

    let settingsStore: SettingsStore
    let plansStore: PlansStore
    let sessionStore: SessionStore
    let todayStore: TodayStore
    let progressStore: ProgressStore

    var isHydrated = false
    var persistenceStartupIssue: PersistenceStartupIssue?

    init(
        modelContainer: ModelContainer = WorkoutModelContainerFactory.makeContainer(),
        launchArguments: Set<String> = Set(ProcessInfo.processInfo.arguments)
    ) {
        PersistenceMigrationCoordinator.prepareIfNeeded(modelContainer: modelContainer)

        self.launchArguments = launchArguments
        let context = ModelContext(modelContainer)
        context.autosaveEnabled = false

        let settingsStore = SettingsStore()
        let plansStore = PlansStore(repository: PlanRepository(modelContext: context))
        let sessionStore = SessionStore(repository: SessionRepository(modelContext: context))
        let todayStore = TodayStore()
        let progressStore = ProgressStore()
        let derivedStateController = AppDerivedStateController(
            todayStore: todayStore,
            progressStore: progressStore
        )

        self.settingsStore = settingsStore
        self.plansStore = plansStore
        self.sessionStore = sessionStore
        self.todayStore = todayStore
        self.progressStore = progressStore
        persistenceStartupIssue = WorkoutModelContainerFactory.consumeStartupIssue()
        self.derivedStateController = derivedStateController
        self.planCoordinator = AppPlanCoordinator(
            settingsStore: settingsStore,
            plansStore: plansStore,
            sessionStore: sessionStore,
            derivedStateController: derivedStateController
        )
        self.sessionCoordinator = AppSessionCoordinator(
            settingsStore: settingsStore,
            plansStore: plansStore,
            sessionStore: sessionStore,
            derivedStateController: derivedStateController
        )
    }

    func dismissPersistenceStartupIssue() {
        persistenceStartupIssue = nil
    }

    var shouldShowOnboarding: Bool {
        !settingsStore.hasCompletedOnboarding
    }

    func hydrateIfNeeded() async {
        guard hasHydrated == false else {
            return
        }

        hasHydrated = true

        if launchArguments.contains("--uitesting-empty-store") {
            resetAllDataForFreshStart()
        }

        plansStore.hydrate()
        sessionStore.hydrate()
        await derivedStateController.hydrate(plansStore: plansStore, sessionStore: sessionStore)
        isHydrated = true
    }

    func resetAllDataForFreshStart() {
        planCoordinator.resetAllDataForFreshStart()
    }

    func completeOnboarding(with presetPack: PresetPack?) {
        planCoordinator.completeOnboarding(with: presetPack)
    }

    func startSession(planID: UUID, templateID: UUID) {
        sessionCoordinator.startSession(planID: planID, templateID: templateID)
    }

    func replaceActiveSessionAndStart(planID: UUID, templateID: UUID) {
        sessionCoordinator.replaceActiveSessionAndStart(planID: planID, templateID: templateID)
    }

    func resumeActiveSession() {
        sessionCoordinator.resumeActiveSession()
    }

    func toggleSetCompletion(blockID: UUID, setID: UUID) {
        sessionCoordinator.toggleSetCompletion(blockID: blockID, setID: setID)
    }

    func adjustSetWeight(blockID: UUID, setID: UUID, delta: Double) {
        sessionCoordinator.adjustSetWeight(blockID: blockID, setID: setID, delta: delta)
    }

    func adjustSetReps(blockID: UUID, setID: UUID, delta: Int) {
        sessionCoordinator.adjustSetReps(blockID: blockID, setID: setID, delta: delta)
    }

    func addSet(to blockID: UUID) {
        sessionCoordinator.addSet(to: blockID)
    }

    func copyLastSet(in blockID: UUID) {
        sessionCoordinator.copyLastSet(in: blockID)
    }

    func addExerciseToActiveSession(exerciseID: UUID) {
        sessionCoordinator.addExerciseToActiveSession(exerciseID: exerciseID)
    }

    func addCustomExerciseToActiveSession(name: String) {
        sessionCoordinator.addCustomExerciseToActiveSession(name: name)
    }

    func updateActiveBlockNotes(blockID: UUID, note: String) {
        sessionCoordinator.updateActiveBlockNotes(blockID: blockID, note: note)
    }

    func updateActiveSessionNotes(_ notes: String) {
        sessionCoordinator.updateActiveSessionNotes(notes)
    }

    func clearRestTimer() {
        sessionCoordinator.clearRestTimer()
    }

    @discardableResult
    func finishActiveSession() -> Bool {
        sessionCoordinator.finishActiveSession()
    }

    func discardActiveSession() {
        sessionCoordinator.discardActiveSession()
    }

    func undoSessionMutation() {
        sessionCoordinator.undoSessionMutation()
    }

    func savePlan(_ plan: Plan) {
        planCoordinator.savePlan(plan)
    }

    func deletePlan(_ planID: UUID) {
        planCoordinator.deletePlan(planID)
    }

    func saveTemplate(planID: UUID, template: WorkoutTemplate) {
        planCoordinator.saveTemplate(planID: planID, template: template)
    }

    func deleteTemplate(planID: UUID, templateID: UUID) {
        planCoordinator.deleteTemplate(planID: planID, templateID: templateID)
    }

    func pinTemplate(planID: UUID, templateID: UUID) {
        planCoordinator.pinTemplate(planID: planID, templateID: templateID)
    }

    func saveProfiles(_ profiles: [ExerciseProfile]) {
        planCoordinator.saveProfiles(profiles)
    }

    func updateCatalogItem(
        itemID: UUID,
        name: String,
        aliases: [String],
        category: ExerciseCategory
    ) {
        planCoordinator.updateCatalogItem(
            itemID: itemID,
            name: name,
            aliases: aliases,
            category: category
        )
    }

    func makePlan(name: String) -> Plan {
        Plan(name: name, templates: [])
    }

    func refreshDerivedStores() async {
        await derivedStateController.refreshDerivedStores(
            plansStore: plansStore,
            sessionStore: sessionStore
        )
    }

    func refreshTodayStore() {
        derivedStateController.refreshToday(plansStore: plansStore, sessionStore: sessionStore)
    }

    func flushPendingSessionPersistence() {
        sessionCoordinator.flushPendingDraftPersistence()
    }
}
