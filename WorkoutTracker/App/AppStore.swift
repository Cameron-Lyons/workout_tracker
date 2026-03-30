import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class AppStore {
    private enum UITestingLaunchArguments {
        static let emptyStore = "--uitesting-empty-store"
        static let completeOnboarding = "--uitesting-complete-onboarding"
        static let seedFinishableSession = "--uitesting-seed-finishable-session"
    }

    @ObservationIgnored private let launchArguments: Set<String>
    @ObservationIgnored private var hasHydrated = false
    @ObservationIgnored private var completedSessionHistoryLoadGeneration = 0
    @ObservationIgnored private var completedSessionHistoryTask: Task<[CompletedSession], Never>?
    @ObservationIgnored private let hydrationLoader: PersistenceHydrationLoader
    @ObservationIgnored private let derivedStateController: AppDerivedStateController
    @ObservationIgnored private let planCoordinator: AppPlanCoordinator
    @ObservationIgnored private let sessionCoordinator: AppSessionCoordinator
    @ObservationIgnored private let restTimerLiveActivityManager: RestTimerLiveActivityManager

    let settingsStore: SettingsStore
    let plansStore: PlansStore
    let sessionStore: SessionStore
    let todayStore: TodayStore
    let progressStore: ProgressStore

    var isHydrated = false
    var persistenceStartupIssue: PersistenceStartupIssue?

    init(
        modelContainer: ModelContainer = WorkoutModelContainerFactory.makeContainer(),
        launchArguments: Set<String> = Set(ProcessInfo.processInfo.arguments),
        settingsStore: SettingsStore? = nil
    ) {
        self.launchArguments = launchArguments
        let context = ModelContext(modelContainer)
        context.autosaveEnabled = false
        let planPersistenceController = PlanPersistenceControllerRegistry.controller(for: modelContainer)
        let sessionPersistenceController = SessionPersistenceControllerRegistry.controller(for: modelContainer)
        let hydrationLoader = PersistenceHydrationLoader(
            modelContainer: modelContainer,
            planPersistenceController: planPersistenceController,
            sessionPersistenceController: sessionPersistenceController
        )

        let settingsStore = settingsStore ?? SettingsStore()
        let plansStore = PlansStore(
            persistenceController: planPersistenceController
        )
        let sessionStore = SessionStore(
            repository: SessionRepository(modelContext: context),
            persistenceController: sessionPersistenceController
        )
        let todayStore = TodayStore()
        let progressStore = ProgressStore()
        let derivedStateController = AppDerivedStateController(
            todayStore: todayStore,
            progressStore: progressStore
        )
        let restTimerLiveActivityManager = RestTimerLiveActivityManager()
        sessionStore.onActiveDraftLiveActivityStateChanged = { [restTimerLiveActivityManager] draft in
            Task { @MainActor in
                await restTimerLiveActivityManager.sync(with: draft)
            }
        }

        self.settingsStore = settingsStore
        self.plansStore = plansStore
        self.sessionStore = sessionStore
        self.todayStore = todayStore
        self.progressStore = progressStore
        self.hydrationLoader = hydrationLoader
        persistenceStartupIssue = WorkoutModelContainerFactory.consumeStartupIssue()
        self.derivedStateController = derivedStateController
        self.restTimerLiveActivityManager = restTimerLiveActivityManager
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
        let isEmptyStoreLaunch = launchArguments.contains(UITestingLaunchArguments.emptyStore)

        if isEmptyStoreLaunch {
            resetAllDataForFreshStart()
        }

        if launchArguments.contains(UITestingLaunchArguments.completeOnboarding) {
            settingsStore.hasCompletedOnboarding = true
        }

        let hydrationSnapshot = await hydrationLoader.loadStartupSnapshot()
        plansStore.hydrate(with: hydrationSnapshot.plans)
        sessionStore.hydrate(
            with: SessionStore.HydrationSnapshot(
                activeDraft: hydrationSnapshot.sessions.activeDraft,
                completedSessions: hydrationSnapshot.sessions.completedSessions,
                includesCompleteHistory: isEmptyStoreLaunch
            )
        )
        await derivedStateController.hydrate(plansStore: plansStore, sessionStore: sessionStore)
        applyUITestingFixturesIfNeeded()
        isHydrated = true
    }

    func resetAllDataForFreshStart() {
        cancelCompletedSessionHistoryLoad()
        planCoordinator.resetAllDataForFreshStart()
    }

    func hydrateCompletedSessionHistoryIfNeeded(priority: TaskPriority = .utility) async {
        guard isHydrated, sessionStore.hasLoadedCompletedSessionHistory == false else {
            return
        }

        let generation = completedSessionHistoryLoadGeneration

        if let existingTask = completedSessionHistoryTask {
            let sessions = await existingTask.value
            guard generation == completedSessionHistoryLoadGeneration else {
                return
            }

            await applyCompletedSessionHistoryIfNeeded(sessions)
            return
        }

        sessionStore.setCompletedSessionHistoryLoading(true)
        let task = Task(priority: priority) { [hydrationLoader] in
            await hydrationLoader.loadCompletedSessionHistory()
        }
        completedSessionHistoryTask = task
        let sessions = await task.value
        guard generation == completedSessionHistoryLoadGeneration else {
            return
        }

        completedSessionHistoryTask = nil
        await applyCompletedSessionHistoryIfNeeded(sessions)
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

    func updateSetWeight(blockID: UUID, setID: UUID, weight: Double) {
        sessionCoordinator.updateSetWeight(blockID: blockID, setID: setID, weight: weight)
    }

    func updateSetReps(blockID: UUID, setID: UUID, reps: Int) {
        sessionCoordinator.updateSetReps(blockID: blockID, setID: setID, reps: reps)
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

    @discardableResult
    func refreshDerivedStores() async -> Bool {
        guard isHydrated else {
            return false
        }

        return await derivedStateController.refreshDerivedStores(
            plansStore: plansStore,
            sessionStore: sessionStore
        )
    }

    @discardableResult
    func loadPlanLibraryIfNeeded(priority: TaskPriority = .userInitiated) async -> Bool {
        await plansStore.loadPlanLibraryIfNeeded(priority: priority)
    }

    func preloadDeferredTabDataIfNeeded(priority: TaskPriority = .utility) async {
        guard isHydrated else {
            return
        }

        let needsCompletedHistory = sessionStore.hasLoadedCompletedSessionHistory == false
        guard needsCompletedHistory else {
            return
        }

        await preloadCompletedSessionHistoryIfNeeded(
            needsCompletedHistory,
            priority: priority
        )
    }

    func refreshTodayStore() {
        derivedStateController.refreshToday(plansStore: plansStore, sessionStore: sessionStore)
    }

    func flushPendingSessionPersistence() {
        sessionCoordinator.flushPendingDraftPersistence()
    }

    func flushPendingPlanPersistence() {
        plansStore.flushPendingPersistence()
    }

    func syncRestTimerLiveActivity() {
        let draft = sessionStore.activeDraft
        Task { @MainActor in
            await restTimerLiveActivityManager.sync(with: draft)
        }
    }

    private func applyCompletedSessionHistoryIfNeeded(_ sessions: [CompletedSession]) async {
        guard sessionStore.hasLoadedCompletedSessionHistory == false else {
            return
        }

        sessionStore.mergeCompletedSessionHistory(sessions)
        await derivedStateController.refreshDerivedStores(
            plansStore: plansStore,
            sessionStore: sessionStore
        )
    }

    private func applyUITestingFixturesIfNeeded() {
        guard launchArguments.contains(UITestingLaunchArguments.seedFinishableSession) else {
            return
        }

        if shouldShowOnboarding {
            completeOnboarding(with: .generalGym)
        }

        if sessionStore.activeDraft == nil,
            let pinnedTemplate = todayStore.pinnedTemplate
        {
            startSession(planID: pinnedTemplate.planID, templateID: pinnedTemplate.templateID)
        }

        guard let block = sessionStore.activeDraft?.blocks.first,
            let workingRow = block.sets.first(where: { $0.target.setKind == .working })
        else {
            return
        }

        if workingRow.log.isCompleted == false {
            toggleSetCompletion(blockID: block.id, setID: workingRow.id)
        }
        clearRestTimer()
    }

    private func cancelCompletedSessionHistoryLoad() {
        completedSessionHistoryLoadGeneration &+= 1
        completedSessionHistoryTask?.cancel()
        completedSessionHistoryTask = nil
    }

    private func preloadCompletedSessionHistoryIfNeeded(
        _ shouldLoad: Bool,
        priority: TaskPriority
    ) async {
        guard shouldLoad else {
            return
        }

        await hydrateCompletedSessionHistoryIfNeeded(priority: priority)
    }
}
