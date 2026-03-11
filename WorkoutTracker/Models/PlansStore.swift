import Foundation
import Observation

@MainActor
@Observable
final class PlansStore {
    struct HydrationSnapshot: Sendable {
        var catalog: [ExerciseCatalogItem]
        var plans: [Plan]
        var profiles: [ExerciseProfile]
    }

    @ObservationIgnored private let repository: PlanRepository
    @ObservationIgnored private let persistenceController: PlanPersistenceController
    @ObservationIgnored private(set) var catalogByID: [UUID: ExerciseCatalogItem] = [:]
    @ObservationIgnored private(set) var catalogRevision = 0
    @ObservationIgnored private var plansByID: [UUID: Plan] = [:]
    @ObservationIgnored private var profilesByExerciseID: [UUID: ExerciseProfile] = [:]
    @ObservationIgnored private var cachedTemplateReferences: [TemplateReference] = []

    var catalog: [ExerciseCatalogItem] = []
    var plans: [Plan] = []
    var profiles: [ExerciseProfile] = []

    init(repository: PlanRepository, persistenceController: PlanPersistenceController) {
        self.repository = repository
        self.persistenceController = persistenceController
    }

    func hydrate() {
        hydrate(
            with: HydrationSnapshot(
                catalog: repository.loadCatalog(),
                plans: repository.loadPlans(),
                profiles: repository.loadProfiles()
            )
        )
    }

    func hydrate(with snapshot: HydrationSnapshot) {
        catalog = snapshot.catalog
        plans = snapshot.plans
        profiles = snapshot.profiles
        rebuildCaches()
        bumpCatalogRevision()
    }

    func resetAllData() {
        persistenceController.scheduleDeleteEverything()
        persistenceController.flush()
        catalog = CatalogSeed.defaultCatalog()
        plans = []
        profiles = []
        rebuildCaches()
        bumpCatalogRevision()
        repository.saveCatalog(catalog)
    }

    func savePlan(_ plan: Plan) {
        upsertPlan(plan)
        rebuildPlanCaches()
        flushPendingPlanPersistence()
        repository.savePlans(plans)
    }

    func deletePlan(_ planID: UUID) {
        plans.removeAll(where: { $0.id == planID })
        rebuildPlanCaches()
        flushPendingPlanPersistence()
        repository.savePlans(plans)
    }

    func addPresetPack(_ pack: PresetPack, settings: SettingsStore) {
        let existingPinnedPlanIDs = Set(
            plans.compactMap { plan in
                plan.pinnedTemplateID == nil ? nil : plan.id
            })
        let generatedPlans = PresetPackBuilder.makePlans(for: pack, settings: settings).map { generatedPlan in
            guard !existingPinnedPlanIDs.isEmpty,
                existingPinnedPlanIDs.contains(generatedPlan.id) == false
            else {
                return generatedPlan
            }

            var updatedPlan = generatedPlan
            updatedPlan.pinnedTemplateID = nil
            return updatedPlan
        }
        guard !generatedPlans.isEmpty else {
            return
        }

        for plan in generatedPlans {
            upsertPlan(plan)
        }

        rebuildPlanCaches()
        persistenceController.scheduleUpsertPlans(generatedPlans)
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

    func templateReferences() -> [TemplateReference] {
        cachedTemplateReferences
    }

    var templateReferenceCount: Int {
        cachedTemplateReferences.count
    }

    func markTemplateStarted(planID: UUID, templateID: UUID, startedAt: Date) {
        guard let planIndex = plans.firstIndex(where: { $0.id == planID }),
            let templateIndex = plans[planIndex].templates.firstIndex(where: { $0.id == templateID })
        else {
            return
        }

        guard plans[planIndex].templates[templateIndex].lastStartedAt != startedAt else {
            return
        }

        plans[planIndex].templates[templateIndex].lastStartedAt = startedAt
        rebuildPlanCaches()
        persistenceController.scheduleMarkTemplateStarted(planID: planID, templateID: templateID, startedAt: startedAt)
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

        if plan.pinnedTemplateID == nil,
            hasPinnedTemplate(excluding: plan.id) == false
        {
            plan.pinnedTemplateID = template.id
        }

        savePlan(plan)
    }

    func pinTemplate(planID: UUID, templateID: UUID) {
        guard
            plans.contains(where: { plan in
                plan.id == planID && plan.templates.contains(where: { $0.id == templateID })
            })
        else {
            return
        }

        var didUpdate = false

        for index in plans.indices {
            if plans[index].id == planID {
                guard plans[index].pinnedTemplateID != templateID else {
                    continue
                }

                plans[index].pinnedTemplateID = templateID
                didUpdate = true
            } else if plans[index].pinnedTemplateID != nil {
                plans[index].pinnedTemplateID = nil
                didUpdate = true
            }
        }

        guard didUpdate else {
            return
        }

        rebuildPlanCaches()
        flushPendingPlanPersistence()
        repository.savePlans(plans)
    }

    func deleteTemplate(planID: UUID, templateID: UUID) {
        guard var plan = plan(for: planID) else {
            return
        }

        plan.templates.removeAll(where: { $0.id == templateID })
        if plan.pinnedTemplateID == templateID {
            plan.pinnedTemplateID = hasPinnedTemplate(excluding: plan.id) ? nil : plan.templates.first?.id
        }
        savePlan(plan)
    }

    func profile(for exerciseID: UUID) -> ExerciseProfile? {
        profilesByExerciseID[exerciseID]
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
        flushPendingPlanPersistence()
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
        synchronizeExerciseNameSnapshots(exerciseID: itemID, name: name)
        rebuildCatalogCaches()
        bumpCatalogRevision()
        flushPendingPlanPersistence()
        repository.saveCatalog(catalog)
    }

    func addCustomExercise(name: String, category: ExerciseCategory = .custom) -> ExerciseCatalogItem {
        let item = ExerciseCatalogItem(
            name: name,
            aliases: [],
            category: category
        )
        catalog.append(item)
        catalog.sort(by: { $0.name < $1.name })
        rebuildCatalogCaches()
        bumpCatalogRevision()
        flushPendingPlanPersistence()
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

    private func upsertPlan(_ plan: Plan) {
        if let existingIndex = plans.firstIndex(where: { $0.id == plan.id }) {
            let createdAt = plans[existingIndex].createdAt
            plans.remove(at: existingIndex)

            if createdAt == plan.createdAt {
                plans.insert(plan, at: min(existingIndex, plans.endIndex))
                return
            }
        }

        let insertionIndex = plans.firstIndex(where: { $0.createdAt > plan.createdAt }) ?? plans.endIndex
        plans.insert(plan, at: insertionIndex)
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

    private func hasPinnedTemplate(excluding planID: UUID? = nil) -> Bool {
        plans.contains { plan in
            guard plan.id != planID else {
                return false
            }

            return plan.pinnedTemplateID != nil
        }
    }

    private func synchronizeExerciseNameSnapshots(exerciseID: UUID, name: String) {
        var didUpdatePlans = false

        for planIndex in plans.indices {
            for templateIndex in plans[planIndex].templates.indices {
                for blockIndex in plans[planIndex].templates[templateIndex].blocks.indices
                where plans[planIndex].templates[templateIndex].blocks[blockIndex].exerciseID == exerciseID {
                    guard plans[planIndex].templates[templateIndex].blocks[blockIndex].exerciseNameSnapshot != name else {
                        continue
                    }

                    plans[planIndex].templates[templateIndex].blocks[blockIndex].exerciseNameSnapshot = name
                    didUpdatePlans = true
                }
            }
        }

        guard didUpdatePlans else {
            return
        }

        rebuildPlanCaches()
        flushPendingPlanPersistence()
        repository.savePlans(plans)
    }

    func updatePlanProgression(
        planID: UUID,
        templateID: UUID,
        finishedBlocks: [SessionBlock],
        settings: SettingsStore
    ) {
        guard var plan = plan(for: planID),
            let templateIndex = plan.templates.firstIndex(where: { $0.id == templateID })
        else {
            return
        }

        var template = plan.templates[templateIndex]
        var updatedProfiles: [ExerciseProfile] = []

        for finishedBlock in finishedBlocks {
            guard let blockIndex = templateBlockIndex(in: template, matching: finishedBlock) else {
                continue
            }

            let completedBlock = completedSnapshot(from: finishedBlock)
            let block = template.blocks[blockIndex]
            let increment = settings.preferredIncrement(for: finishedBlock.exerciseNameSnapshot)
            let updated = ProgressionEngine.applyCompletion(
                to: block,
                using: completedBlock,
                profile: profile(for: finishedBlock.exerciseID),
                fallbackIncrement: increment
            )
            template.blocks[blockIndex] = updated.block

            if let updatedProfile = updated.profile,
                updatedProfiles.contains(where: { $0.id == updatedProfile.id }) == false
            {
                updatedProfiles.append(updatedProfile)
            }
        }

        mergeProfilesInMemory(updatedProfiles)

        if let nextStartingStrengthTemplateID = TemplateReferenceSelection.nextStartingStrengthTemplateID(
            in: plan,
            after: templateID
        ) {
            plan.pinnedTemplateID = nextStartingStrengthTemplateID
        }

        plan.templates[templateIndex] = template
        upsertPlan(plan)
        rebuildPlanCaches()
        persistenceController.schedulePersistProgression(plan: plan, updatedProfiles: updatedProfiles)
    }

    private func templateBlockIndex(in template: WorkoutTemplate, matching finishedBlock: SessionBlock) -> Int? {
        if let blockIndex = template.blocks.firstIndex(where: { $0.id == finishedBlock.id }) {
            return blockIndex
        }

        return template.blocks.firstIndex(where: {
            $0.exerciseID == finishedBlock.exerciseID && $0.exerciseNameSnapshot == finishedBlock.exerciseNameSnapshot
        })
    }

    private func completedSnapshot(from finishedBlock: SessionBlock) -> CompletedSessionBlock {
        CompletedSessionBlock(
            id: finishedBlock.id,
            exerciseID: finishedBlock.exerciseID,
            exerciseNameSnapshot: finishedBlock.exerciseNameSnapshot,
            blockNote: finishedBlock.blockNote,
            restSeconds: finishedBlock.restSeconds,
            supersetGroup: finishedBlock.supersetGroup,
            progressionRule: finishedBlock.progressionRule,
            sets: finishedBlock.sets
        )
    }

    private func mergeProfilesInMemory(_ updatedProfiles: [ExerciseProfile]) {
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
    }

    func flushPendingPersistence() {
        flushPendingPlanPersistence()
    }

    private func flushPendingPlanPersistence() {
        persistenceController.flush()
    }
}
