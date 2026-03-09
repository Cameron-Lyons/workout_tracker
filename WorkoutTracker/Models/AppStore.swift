import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class AppStore {
    private enum Compatibility {
        static let storageVersion = 3
        static let storageVersionKey = "workout_tracker_storage_version_v3"
    }

    @ObservationIgnored private let modelContainer: ModelContainer
    @ObservationIgnored private let launchArguments: Set<String>
    @ObservationIgnored private let analytics = AnalyticsRepository()
    @ObservationIgnored private var hasHydrated = false

    let settingsStore: SettingsStore
    let plansStore: PlansStore
    let sessionStore: SessionStore
    let todayStore = TodayStore()
    let progressStore = ProgressStore()

    var isHydrated = false

    init(
        modelContainer: ModelContainer = WorkoutModelContainerFactory.makeContainer(),
        launchArguments: Set<String> = Set(ProcessInfo.processInfo.arguments)
    ) {
        Self.performCompatibilityResetIfNeeded(modelContainer: modelContainer)

        self.modelContainer = modelContainer
        self.launchArguments = launchArguments
        let context = ModelContext(modelContainer)
        context.autosaveEnabled = false

        self.settingsStore = SettingsStore()
        self.plansStore = PlansStore(repository: PlanRepository(modelContext: context))
        self.sessionStore = SessionStore(repository: SessionRepository(modelContext: context))
    }

    var shouldShowOnboarding: Bool {
        !settingsStore.hasCompletedOnboarding
    }

    func hydrateIfNeeded() {
        guard hasHydrated == false else {
            return
        }

        hasHydrated = true

        if launchArguments.contains("--uitesting-empty-store") {
            resetAllDataForFreshStart()
        }

        plansStore.hydrate()
        sessionStore.hydrate()
        refreshDerivedStores()
        isHydrated = true
    }

    func resetAllDataForFreshStart() {
        plansStore.resetAllData()
        sessionStore.resetAllData()
        settingsStore.hasCompletedOnboarding = false
    }

    func completeOnboarding(with presetPack: PresetPack?) {
        if let presetPack {
            plansStore.addPresetPack(presetPack, settings: settingsStore)
        }

        settingsStore.hasCompletedOnboarding = true
        refreshTodayStore()
    }

    func startSession(planID: UUID, templateID: UUID) {
        guard let plan = plansStore.plan(for: planID),
              let template = plan.templates.first(where: { $0.id == templateID }) else {
            return
        }

        let draft = SessionEngine.startSession(
            planID: planID,
            template: template,
            profilesByExerciseID: plansStore.profileLookupByExerciseID,
            warmupRamp: settingsStore.warmupRamp
        )
        sessionStore.beginSession(draft)
        plansStore.markTemplateStarted(planID: planID, templateID: templateID, startedAt: draft.startedAt)
        refreshTodayStore()
    }

    func resumeActiveSession() {
        sessionStore.presentActiveSession()
    }

    func toggleSetCompletion(blockID: UUID, setID: UUID) {
        sessionStore.pushMutation {
            SessionEngine.toggleCompletion(of: setID, in: blockID, draft: $0)
        }
    }

    func adjustSetWeight(blockID: UUID, setID: UUID, delta: Double) {
        sessionStore.pushMutation {
            SessionEngine.adjustWeight(by: delta, setID: setID, in: blockID, draft: $0)
        }
    }

    func adjustSetReps(blockID: UUID, setID: UUID, delta: Int) {
        sessionStore.pushMutation {
            SessionEngine.adjustReps(by: delta, setID: setID, in: blockID, draft: $0)
        }
    }

    func addSet(to blockID: UUID) {
        sessionStore.pushMutation {
            SessionEngine.addSet(to: blockID, draft: $0)
        }
    }

    func copyLastSet(in blockID: UUID) {
        sessionStore.pushMutation {
            SessionEngine.copyLastSet(in: blockID, draft: $0)
        }
    }

    func addExerciseToActiveSession(exerciseID: UUID) {
        guard let exercise = plansStore.exerciseItem(for: exerciseID) else {
            return
        }

        sessionStore.pushMutation {
            SessionEngine.addExerciseBlock(
                exercise: exercise,
                draft: $0,
                defaultRestSeconds: settingsStore.defaultRestSeconds
            )
        }
    }

    func addCustomExerciseToActiveSession(name: String) {
        guard let trimmedName = name.nonEmptyTrimmed else {
            return
        }

        let exercise = plansStore.addCustomExercise(name: trimmedName)
        addExerciseToActiveSession(exerciseID: exercise.id)
    }

    func updateActiveBlockNotes(blockID: UUID, note: String) {
        sessionStore.pushMutation(persistence: .deferred) {
            SessionEngine.updateNotes(in: blockID, note: note, draft: $0)
        }
    }

    func updateActiveSessionNotes(_ notes: String) {
        sessionStore.pushMutation(persistence: .deferred) {
            SessionEngine.updateSessionNotes(notes, draft: $0)
        }
    }

    func clearRestTimer() {
        sessionStore.clearRestTimer()
    }

    func finishActiveSession() {
        let catalogByID = plansStore.catalogByID
        guard let completedSession = sessionStore.completeSession(
            analytics: analytics,
            catalogByID: catalogByID
        ) else {
            return
        }

        if let planID = completedSession.planID {
            plansStore.updatePlanProgression(
                planID: planID,
                templateID: completedSession.templateID,
                completedSession: completedSession,
                settings: settingsStore
            )
        }

        let finishSummary = sessionStore.lastFinishedSummary
        todayStore.recordCompletedSession(
            completedSession,
            plansStore: plansStore,
            sessionStore: sessionStore,
            finishSummary: finishSummary
        )
        progressStore.recordCompletedSession(
            completedSession,
            sessionStore: sessionStore,
            analytics: analytics,
            catalogByID: catalogByID,
            finishSummary: finishSummary
        )
    }

    func discardActiveSession() {
        sessionStore.discardActiveSession()
        refreshTodayStore()
    }

    func undoSessionMutation() {
        sessionStore.undoLastMutation()
    }

    func savePlan(_ plan: Plan) {
        plansStore.savePlan(plan)
        refreshTodayStore()
    }

    func deletePlan(_ planID: UUID) {
        plansStore.deletePlan(planID)
        refreshTodayStore()
    }

    func saveTemplate(planID: UUID, template: WorkoutTemplate) {
        plansStore.updateTemplate(planID: planID, template: template)
        refreshTodayStore()
    }

    func deleteTemplate(planID: UUID, templateID: UUID) {
        plansStore.deleteTemplate(planID: planID, templateID: templateID)
        refreshTodayStore()
    }

    func saveProfile(_ profile: ExerciseProfile) {
        plansStore.saveProfile(profile)
    }

    func saveProfiles(_ profiles: [ExerciseProfile]) {
        plansStore.saveProfiles(profiles)
    }

    func updateCatalogItem(
        itemID: UUID,
        name: String,
        aliases: [String],
        category: ExerciseCategory
    ) {
        plansStore.updateExerciseCatalogItem(
            itemID,
            name: name,
            aliases: aliases,
            category: category
        )
        refreshTodayStore()
        refreshProgressStore()
    }

    func makePlan(name: String) -> Plan {
        Plan(name: name, templates: [])
    }

    func makeTemplate(
        name: String,
        note: String = "",
        scheduledWeekdays: [Weekday] = [],
        blocks: [ExerciseBlock]
    ) -> WorkoutTemplate {
        WorkoutTemplate(
            name: name,
            note: note,
            scheduledWeekdays: scheduledWeekdays,
            blocks: blocks
        )
    }

    func makeBlock(
        exerciseID: UUID,
        setCount: Int,
        repRange: RepRange,
        targetWeight: Double?,
        restSeconds: Int,
        progressionRule: ProgressionRule,
        setKind: SetKind = .working,
        supersetGroup: String? = nil,
        note: String = ""
    ) -> ExerciseBlock {
        let name = plansStore.exerciseName(for: exerciseID)
        let targets = (0..<setCount).map { _ in
            SetTarget(
                setKind: setKind,
                targetWeight: targetWeight,
                repRange: repRange,
                restSeconds: restSeconds
            )
        }

        return ExerciseBlock(
            exerciseID: exerciseID,
            exerciseNameSnapshot: name,
            blockNote: note,
            restSeconds: restSeconds,
            supersetGroup: supersetGroup,
            progressionRule: progressionRule,
            targets: targets,
            allowsAutoWarmups: setKind == .working
        )
    }

    func refreshDerivedStores() {
        refreshTodayStore()
        refreshProgressStore()
    }

    func refreshTodayStore() {
        todayStore.refresh(plansStore: plansStore, sessionStore: sessionStore, analytics: analytics)
    }

    func refreshProgressStore() {
        progressStore.refresh(plansStore: plansStore, sessionStore: sessionStore, analytics: analytics)
    }

    private static func performCompatibilityResetIfNeeded(modelContainer: ModelContainer) {
        let defaults = UserDefaults.standard
        let storedVersion = defaults.integer(forKey: Compatibility.storageVersionKey)
        guard storedVersion < Compatibility.storageVersion else {
            return
        }

        let resetContext = ModelContext(modelContainer)
        resetContext.autosaveEnabled = false

        deleteAll(StoredRoutine.self, in: resetContext)
        deleteAll(StoredExercise.self, in: resetContext)
        deleteAll(StoredWorkoutSession.self, in: resetContext)
        deleteAll(StoredWorkoutEntry.self, in: resetContext)
        deleteAll(StoredWorkoutSet.self, in: resetContext)
        deleteAll(StoredPlanRecord.self, in: resetContext)
        deleteAll(StoredExerciseCatalogRecord.self, in: resetContext)
        deleteAll(StoredExerciseProfileRecord.self, in: resetContext)
        deleteAll(StoredActiveSessionRecord.self, in: resetContext)
        deleteAll(StoredCompletedSessionRecord.self, in: resetContext)

        try? resetContext.save()
        SettingsStore.resetPersistedSettings(defaults: defaults)
        defaults.set(Compatibility.storageVersion, forKey: Compatibility.storageVersionKey)
    }

    private static func deleteAll<Model: PersistentModel>(_ modelType: Model.Type, in context: ModelContext) {
        let records = (try? context.fetch(FetchDescriptor<Model>())) ?? []
        for record in records {
            context.delete(record)
        }
    }
}
