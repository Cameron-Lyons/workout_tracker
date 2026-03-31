import Foundation

@MainActor
final class AppPlanCoordinator {
    private let settingsStore: SettingsStore
    private let plansStore: PlansStore
    private let sessionStore: SessionStore
    private let derivedStateController: AppDerivedStateController

    init(
        settingsStore: SettingsStore,
        plansStore: PlansStore,
        sessionStore: SessionStore,
        derivedStateController: AppDerivedStateController
    ) {
        self.settingsStore = settingsStore
        self.plansStore = plansStore
        self.sessionStore = sessionStore
        self.derivedStateController = derivedStateController
    }

    func resetAllDataForFreshStart() {
        plansStore.resetAllData()
        sessionStore.resetAllData()
        settingsStore.hasCompletedOnboarding = false
        derivedStateController.refreshToday(plansStore: plansStore, sessionStore: sessionStore)
        derivedStateController.scheduleProgressRefresh(plansStore: plansStore, sessionStore: sessionStore)
    }

    func completeOnboarding(with presetPack: PresetPack?) {
        if let presetPack {
            let signpost = PerformanceSignpost.begin("Onboarding Preset Application")
            plansStore.addPresetPack(presetPack, settings: settingsStore)
            PerformanceSignpost.end(signpost)
        }

        settingsStore.hasCompletedOnboarding = true
        derivedStateController.refreshToday(plansStore: plansStore, sessionStore: sessionStore)
    }

    func savePlan(_ plan: Plan) {
        plansStore.savePlan(plan)
        derivedStateController.refreshToday(plansStore: plansStore, sessionStore: sessionStore)
    }

    func deletePlan(_ planID: UUID) {
        plansStore.deletePlan(planID)
        derivedStateController.refreshToday(plansStore: plansStore, sessionStore: sessionStore)
    }

    func saveTemplate(planID: UUID, template: WorkoutTemplate) {
        plansStore.updateTemplate(planID: planID, template: template)
        derivedStateController.refreshToday(plansStore: plansStore, sessionStore: sessionStore)
    }

    func deleteTemplate(planID: UUID, templateID: UUID) {
        plansStore.deleteTemplate(planID: planID, templateID: templateID)
        derivedStateController.refreshToday(plansStore: plansStore, sessionStore: sessionStore)
    }

    func pinTemplate(planID: UUID, templateID: UUID) {
        plansStore.pinTemplate(planID: planID, templateID: templateID)
        derivedStateController.refreshToday(plansStore: plansStore, sessionStore: sessionStore)
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
        sessionStore.updateExerciseNameSnapshots(exerciseID: itemID, name: name)
        derivedStateController.refreshToday(plansStore: plansStore, sessionStore: sessionStore)
        derivedStateController.scheduleProgressRefresh(plansStore: plansStore, sessionStore: sessionStore)
    }
}
