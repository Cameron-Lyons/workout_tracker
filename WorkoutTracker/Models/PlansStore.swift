import Foundation
import Observation

@MainActor
@Observable
final class PlansStore {
    @ObservationIgnored private let repository: PlanRepository
    @ObservationIgnored private(set) var catalogByID: [UUID: ExerciseCatalogItem] = [:]
    @ObservationIgnored private(set) var catalogRevision = 0
    @ObservationIgnored private var plansByID: [UUID: Plan] = [:]
    @ObservationIgnored private var profilesByExerciseID: [UUID: ExerciseProfile] = [:]
    @ObservationIgnored private var cachedTemplateReferences: [TemplateReference] = []

    var catalog: [ExerciseCatalogItem] = []
    var plans: [Plan] = []
    var profiles: [ExerciseProfile] = []

    init(repository: PlanRepository) {
        self.repository = repository
    }

    func hydrate() {
        catalog = repository.loadCatalog()
        if catalog.isEmpty {
            catalog = CatalogSeed.defaultCatalog()
            repository.saveCatalog(catalog)
        }

        plans = repository.loadPlans().sorted(by: { $0.createdAt < $1.createdAt })
        profiles = repository.loadProfiles()
        rebuildCaches()
        bumpCatalogRevision()
    }

    func resetAllData() {
        repository.deleteEverything()
        catalog = CatalogSeed.defaultCatalog()
        plans = []
        profiles = []
        rebuildCaches()
        bumpCatalogRevision()
        repository.saveCatalog(catalog)
    }

    func savePlan(_ plan: Plan) {
        if let index = plans.firstIndex(where: { $0.id == plan.id }) {
            plans[index] = plan
        } else {
            plans.append(plan)
        }

        plans.sort(by: { $0.createdAt < $1.createdAt })
        rebuildPlanCaches()
        repository.savePlans(plans)
    }

    func deletePlan(_ planID: UUID) {
        plans.removeAll(where: { $0.id == planID })
        rebuildPlanCaches()
        repository.savePlans(plans)
    }

    func addPresetPack(_ pack: PresetPack, settings: SettingsStore) {
        let generatedPlans = PresetPackBuilder.makePlans(for: pack, settings: settings)
        guard !generatedPlans.isEmpty else {
            return
        }

        for plan in generatedPlans {
            if let index = plans.firstIndex(where: { $0.id == plan.id }) {
                plans[index] = plan
            } else {
                plans.append(plan)
            }
        }

        plans.sort(by: { $0.createdAt < $1.createdAt })
        rebuildPlanCaches()
        repository.savePlans(plans)
    }

    func exerciseName(for exerciseID: UUID) -> String {
        catalogByID[exerciseID]?.name ?? "Unknown Exercise"
    }

    func exerciseItem(for exerciseID: UUID) -> ExerciseCatalogItem? {
        catalogByID[exerciseID]
    }

    func plan(for planID: UUID) -> Plan? {
        plansByID[planID]
    }

    func template(planID: UUID, templateID: UUID) -> WorkoutTemplate? {
        plan(for: planID)?.templates.first(where: { $0.id == templateID })
    }

    func templateReferences() -> [TemplateReference] {
        cachedTemplateReferences
    }

    var templateReferenceCount: Int {
        cachedTemplateReferences.count
    }

    func markTemplateStarted(planID: UUID, templateID: UUID, startedAt: Date) {
        guard var plan = plan(for: planID),
              let templateIndex = plan.templates.firstIndex(where: { $0.id == templateID }) else {
            return
        }

        plan.templates[templateIndex].lastStartedAt = startedAt
        savePlan(plan)
    }

    func updateTemplate(
        planID: UUID,
        template: WorkoutTemplate
    ) {
        guard var plan = plan(for: planID) else {
            return
        }

        if let templateIndex = plan.templates.firstIndex(where: { $0.id == template.id }) {
            plan.templates[templateIndex] = template
        } else {
            plan.templates.append(template)
        }

        if plan.pinnedTemplateID == nil {
            plan.pinnedTemplateID = template.id
        }

        savePlan(plan)
    }

    func deleteTemplate(planID: UUID, templateID: UUID) {
        guard var plan = plan(for: planID) else {
            return
        }

        plan.templates.removeAll(where: { $0.id == templateID })
        if plan.pinnedTemplateID == templateID {
            plan.pinnedTemplateID = plan.templates.first?.id
        }
        savePlan(plan)
    }

    func ensureProfile(for exerciseID: UUID) -> ExerciseProfile {
        if let existing = profiles.first(where: { $0.exerciseID == exerciseID }) {
            return existing
        }

        let profile = ExerciseProfile(exerciseID: exerciseID)
        profiles.append(profile)
        rebuildProfileCaches()
        repository.saveProfiles(profiles)
        return profile
    }

    func profile(for exerciseID: UUID) -> ExerciseProfile? {
        profilesByExerciseID[exerciseID]
    }

    func saveProfile(_ profile: ExerciseProfile) {
        saveProfiles([profile])
    }

    func saveProfiles(_ updatedProfiles: [ExerciseProfile]) {
        guard !updatedProfiles.isEmpty else {
            return
        }

        for profile in updatedProfiles {
            if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
                profiles[index] = profile
            } else {
                profiles.append(profile)
            }
        }

        rebuildProfileCaches()
        repository.saveProfiles(profiles)
    }

    func updateExerciseCatalogItem(
        _ itemID: UUID,
        name: String,
        aliases: [String],
        category: ExerciseCategory
    ) {
        guard let index = catalog.firstIndex(where: { $0.id == itemID }) else {
            return
        }

        let previousName = catalog[index].name
        var updatedItem = catalog[index]
        updatedItem.name = name
        updatedItem.aliases = Array(Set(aliases + [previousName]).subtracting([name])).sorted()
        updatedItem.category = category
        catalog[index] = updatedItem
        rebuildCatalogCaches()
        bumpCatalogRevision()
        repository.saveCatalog(catalog)
    }

    func addCustomExercise(name: String, category: ExerciseCategory = .custom) -> ExerciseCatalogItem {
        let item = ExerciseCatalogItem(
            name: name,
            aliases: [],
            category: category,
            equipment: nil,
            isCustom: true
        )
        catalog.append(item)
        catalog.sort(by: { $0.name < $1.name })
        rebuildCatalogCaches()
        bumpCatalogRevision()
        repository.saveCatalog(catalog)
        return item
    }

    var profileLookupByExerciseID: [UUID: ExerciseProfile] {
        profilesByExerciseID
    }

    private func rebuildCaches() {
        rebuildCatalogCaches()
        rebuildPlanCaches()
        rebuildProfileCaches()
    }

    private func rebuildCatalogCaches() {
        catalogByID = Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, $0) })
    }

    private func rebuildPlanCaches() {
        plansByID = Dictionary(uniqueKeysWithValues: plans.map { ($0.id, $0) })
        cachedTemplateReferences = plans.flatMap { plan in
            plan.templates.map {
                TemplateReference(
                    planID: plan.id,
                    planName: plan.name,
                    templateID: $0.id,
                    templateName: $0.name,
                    scheduledWeekdays: $0.scheduledWeekdays,
                    lastStartedAt: $0.lastStartedAt
                )
            }
        }
    }

    private func rebuildProfileCaches() {
        profilesByExerciseID = Dictionary(uniqueKeysWithValues: profiles.map { ($0.exerciseID, $0) })
    }

    private func bumpCatalogRevision() {
        catalogRevision &+= 1
    }

    func updatePlanProgression(
        planID: UUID,
        templateID: UUID,
        completedSession: CompletedSession,
        settings: SettingsStore
    ) {
        guard var plan = plan(for: planID),
              let templateIndex = plan.templates.firstIndex(where: { $0.id == templateID }) else {
            return
        }

        var template = plan.templates[templateIndex]
        var updatedProfiles: [ExerciseProfile] = []

        for completedBlock in completedSession.blocks {
            guard let blockIndex = template.blocks.firstIndex(where: {
                $0.exerciseID == completedBlock.exerciseID && $0.exerciseNameSnapshot == completedBlock.exerciseNameSnapshot
            }) else {
                continue
            }

            let block = template.blocks[blockIndex]
            let increment = settings.preferredIncrement(for: completedBlock.exerciseNameSnapshot)
            let updated = ProgressionEngine.applyCompletion(
                to: block,
                using: completedBlock,
                profile: profile(for: completedBlock.exerciseID),
                fallbackIncrement: increment
            )
            template.blocks[blockIndex] = updated.block

            if let updatedProfile = updated.profile,
               updatedProfiles.contains(where: { $0.id == updatedProfile.id }) == false {
                updatedProfiles.append(updatedProfile)
            }
        }

        saveProfiles(updatedProfiles)
        plan.templates[templateIndex] = template
        savePlan(plan)
    }
}
