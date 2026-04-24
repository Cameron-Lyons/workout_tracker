import Foundation
import Observation
import SwiftData

enum AppCommand {
    case dismissPersistenceStartupIssue
    case resetAllDataForFreshStart
    case completeOnboarding(PresetPack?)
    case startSession(planID: UUID, templateID: UUID)
    case replaceActiveSessionAndStart(planID: UUID, templateID: UUID)
    case resumeActiveSession
    case toggleSetCompletion(blockID: UUID, setID: UUID)
    case adjustSetWeight(blockID: UUID, setID: UUID, delta: Double)
    case adjustSetReps(blockID: UUID, setID: UUID, delta: Int)
    case updateSetWeight(blockID: UUID, setID: UUID, weight: Double)
    case updateSetReps(blockID: UUID, setID: UUID, reps: Int)
    case addSet(blockID: UUID)
    case copyLastSet(blockID: UUID)
    case addExerciseToActiveSession(exerciseID: UUID)
    case addCustomExerciseToActiveSession(name: String)
    case clearRestTimer
    case finishActiveSession
    case discardActiveSession
    case undoSessionMutation
    case savePlan(Plan)
    case deletePlan(UUID)
    case saveTemplate(planID: UUID, template: WorkoutTemplate)
    case deleteTemplate(planID: UUID, templateID: UUID)
    case pinTemplate(planID: UUID, templateID: UUID)
    case saveProfiles([ExerciseProfile])
    case addPresetPack(PresetPack)
    case updateCatalogItem(itemID: UUID, name: String, aliases: [String], category: ExerciseCategory)
    case refreshTodayStore
    case flushPendingSessionPersistence
    case flushPendingPlanPersistence
    case syncRestTimerLiveActivity
}

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
    var isCompletingOnboarding = false
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

    var shouldShowOnboarding: Bool {
        !settingsStore.hasCompletedOnboarding
    }

    @discardableResult
    func send(_ command: AppCommand) -> Bool {
        switch command {
        case .dismissPersistenceStartupIssue:
            persistenceStartupIssue = nil
            return true
        case .resetAllDataForFreshStart:
            cancelCompletedSessionHistoryLoad()
            planCoordinator.resetAllDataForFreshStart()
            return true
        case let .completeOnboarding(presetPack):
            planCoordinator.completeOnboarding(with: presetPack)
            return true
        case let .startSession(planID, templateID):
            sessionCoordinator.startSession(planID: planID, templateID: templateID)
            return true
        case let .replaceActiveSessionAndStart(planID, templateID):
            sessionCoordinator.replaceActiveSessionAndStart(planID: planID, templateID: templateID)
            return true
        case .resumeActiveSession:
            sessionCoordinator.resumeActiveSession()
            return true
        case let .toggleSetCompletion(blockID, setID):
            sessionCoordinator.toggleSetCompletion(blockID: blockID, setID: setID)
            return true
        case let .adjustSetWeight(blockID, setID, delta):
            sessionCoordinator.adjustSetWeight(blockID: blockID, setID: setID, delta: delta)
            return true
        case let .adjustSetReps(blockID, setID, delta):
            sessionCoordinator.adjustSetReps(blockID: blockID, setID: setID, delta: delta)
            return true
        case let .updateSetWeight(blockID, setID, weight):
            sessionCoordinator.updateSetWeight(blockID: blockID, setID: setID, weight: weight)
            return true
        case let .updateSetReps(blockID, setID, reps):
            sessionCoordinator.updateSetReps(blockID: blockID, setID: setID, reps: reps)
            return true
        case let .addSet(blockID):
            sessionCoordinator.addSet(to: blockID)
            return true
        case let .copyLastSet(blockID):
            sessionCoordinator.copyLastSet(in: blockID)
            return true
        case let .addExerciseToActiveSession(exerciseID):
            sessionCoordinator.addExerciseToActiveSession(exerciseID: exerciseID)
            return true
        case let .addCustomExerciseToActiveSession(name):
            sessionCoordinator.addCustomExerciseToActiveSession(name: name)
            return true
        case .clearRestTimer:
            sessionCoordinator.clearRestTimer()
            return true
        case .finishActiveSession:
            return sessionCoordinator.finishActiveSession()
        case .discardActiveSession:
            sessionCoordinator.discardActiveSession()
            return true
        case .undoSessionMutation:
            sessionCoordinator.undoSessionMutation()
            return true
        case let .savePlan(plan):
            planCoordinator.savePlan(plan)
            return true
        case let .deletePlan(planID):
            planCoordinator.deletePlan(planID)
            return true
        case let .saveTemplate(planID, template):
            planCoordinator.saveTemplate(planID: planID, template: template)
            return true
        case let .deleteTemplate(planID, templateID):
            planCoordinator.deleteTemplate(planID: planID, templateID: templateID)
            return true
        case let .pinTemplate(planID, templateID):
            planCoordinator.pinTemplate(planID: planID, templateID: templateID)
            return true
        case let .saveProfiles(profiles):
            planCoordinator.saveProfiles(profiles)
            return true
        case let .addPresetPack(presetPack):
            plansStore.addPresetPack(presetPack, settings: settingsStore)
            derivedStateController.refreshToday(plansStore: plansStore, sessionStore: sessionStore)
            return true
        case let .updateCatalogItem(itemID, name, aliases, category):
            planCoordinator.updateCatalogItem(itemID: itemID, name: name, aliases: aliases, category: category)
            return true
        case .refreshTodayStore:
            derivedStateController.refreshToday(plansStore: plansStore, sessionStore: sessionStore)
            return true
        case .flushPendingSessionPersistence:
            Task { @MainActor in
                sessionCoordinator.flushPendingDraftPersistence()
            }
            return true
        case .flushPendingPlanPersistence:
            Task { @MainActor in
                await plansStore.flushPendingPersistence()
            }
            return true
        case .syncRestTimerLiveActivity:
            let draft = sessionStore.activeDraft
            Task { @MainActor in
                await restTimerLiveActivityManager.sync(with: draft)
            }
            return true
        }
    }

    func hydrateIfNeeded() async {
        guard hasHydrated == false else {
            return
        }

        hasHydrated = true
        let isEmptyStoreLaunch = launchArguments.contains(UITestingLaunchArguments.emptyStore)

        if isEmptyStoreLaunch {
            send(.resetAllDataForFreshStart)
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

    func beginPresetOnboarding(_ presetPack: PresetPack) async {
        guard isCompletingOnboarding == false else {
            return
        }

        isCompletingOnboarding = true
        await Task.yield()
        defer {
            isCompletingOnboarding = false
        }

        send(.completeOnboarding(presetPack))
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

    @discardableResult
    func loadProfilesIfNeeded(priority: TaskPriority = .userInitiated) async -> Bool {
        await plansStore.loadProfilesIfNeeded(priority: priority)
    }

    func preparePlanInteractionDataIfNeeded(priority: TaskPriority = .userInitiated) async {
        async let loadedPlanLibrary = plansStore.loadPlanLibraryIfNeeded(priority: priority)
        async let loadedProfiles = plansStore.loadProfilesIfNeeded(priority: priority)
        _ = await loadedPlanLibrary
        _ = await loadedProfiles
    }

    func preloadDeferredTabDataIfNeeded(priority: TaskPriority = .utility) async {
        guard isHydrated else {
            return
        }

        let needsCompletedHistory = sessionStore.hasLoadedCompletedSessionHistory == false
        if needsCompletedHistory {
            await preloadCompletedSessionHistoryIfNeeded(
                needsCompletedHistory,
                priority: priority
            )
        }
    }

    func flushPendingSessionPersistence() async {
        sessionCoordinator.flushPendingDraftPersistence()
    }

    func flushPendingPlanPersistence() async {
        await plansStore.flushPendingPersistence()
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
            send(.completeOnboarding(.generalGym))
        }

        if sessionStore.activeDraft == nil,
            let pinnedTemplate = todayStore.pinnedTemplate
        {
            send(.startSession(planID: pinnedTemplate.planID, templateID: pinnedTemplate.templateID))
        }

        guard let sessionExercise = sessionStore.activeDraft?.exercises.first,
            let workingRow = sessionExercise.sets.first(where: { $0.target.setKind == .working })
        else {
            return
        }

        if workingRow.log.isCompleted == false {
            send(.toggleSetCompletion(blockID: sessionExercise.id, setID: workingRow.id))
        }
        send(.clearRestTimer)
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
