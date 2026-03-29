import Foundation
import Observation

@MainActor
@Observable
final class PlansStore {
    struct HydrationSnapshot: Sendable {
        var catalog: [ExerciseCatalogItem]
        var plans: [Plan]
        var profiles: [ExerciseProfile]
        var includesProfiles = true
        var profileCount: Int? = nil
        var planSummaries: [PlanSummary]? = nil
        var includesFullPlanLibrary = true
    }

    @ObservationIgnored private let persistenceController: PlanPersistenceController
    @ObservationIgnored private(set) var catalogByID: [UUID: ExerciseCatalogItem] = [:]
    @ObservationIgnored private(set) var catalogRevision = 0
    @ObservationIgnored private(set) var planRevision = 0
    @ObservationIgnored private var planSummariesByID: [UUID: PlanSummary] = [:]
    @ObservationIgnored private var loadedPlansByID: [UUID: Plan] = [:]
    @ObservationIgnored private var profilesByExerciseID: [UUID: ExerciseProfile] = [:]
    @ObservationIgnored private var cachedTemplateReferences: [TemplateReference] = []
    @ObservationIgnored private var fullPlanLibraryLoadTask: Task<[Plan], Never>?
    @ObservationIgnored private var hasLoadedProfiles = true

    var catalog: [ExerciseCatalogItem] = []
    var planSummaries: [PlanSummary] = []
    var plans: [Plan] = []
    var profiles: [ExerciseProfile] = []
    var profileCount = 0
    var hasLoadedPlanLibrary = true
    var isLoadingPlanLibrary = false

    init(persistenceController: PlanPersistenceController) {
        self.persistenceController = persistenceController
    }

    func hydrate(with snapshot: HydrationSnapshot) {
        catalog = snapshot.catalog
        plans = snapshot.plans
        profiles = snapshot.profiles
        profileCount = snapshot.profileCount ?? snapshot.profiles.count
        planSummaries = snapshot.planSummaries ?? snapshot.plans.map(PlanSummary.init)
        loadedPlansByID = Dictionary(uniqueKeysWithValues: snapshot.plans.map { ($0.id, $0) })
        hasLoadedProfiles = snapshot.includesProfiles
        hasLoadedPlanLibrary = snapshot.includesFullPlanLibrary
        isLoadingPlanLibrary = false
        fullPlanLibraryLoadTask = nil
        rebuildCaches()
        bumpCatalogRevision()
    }

    func resetAllData() {
        persistenceController.scheduleDeleteEverything()
        fullPlanLibraryLoadTask?.cancel()
        fullPlanLibraryLoadTask = nil
        catalog = CatalogSeed.defaultCatalog()
        planSummaries = []
        plans = []
        profiles = []
        profileCount = 0
        loadedPlansByID = [:]
        hasLoadedProfiles = true
        hasLoadedPlanLibrary = true
        isLoadingPlanLibrary = false
        rebuildCaches()
        bumpCatalogRevision()
        persistenceController.scheduleSaveCatalog(catalog)
    }

    @discardableResult
    func loadPlanLibraryIfNeeded(priority: TaskPriority = .userInitiated) async -> Bool {
        guard hasLoadedPlanLibrary == false else {
            return false
        }

        if let existingTask = fullPlanLibraryLoadTask {
            let loadedPlans = await existingTask.value
            applyLoadedPlanLibrary(loadedPlans)
            return true
        }

        isLoadingPlanLibrary = true
        let task = Task(priority: priority) { [persistenceController] in
            persistenceController.loadPlans()
        }
        fullPlanLibraryLoadTask = task
        let loadedPlans = await task.value
        fullPlanLibraryLoadTask = nil
        applyLoadedPlanLibrary(loadedPlans)
        return true
    }

    func savePlan(_ plan: Plan) {
        cacheLoadedPlan(plan)
        persistenceController.scheduleUpsertPlans([plan])
    }

    func deletePlan(_ planID: UUID) {
        guard planSummariesByID[planID] != nil else {
            return
        }

        loadedPlansByID.removeValue(forKey: planID)
        plans.removeAll(where: { $0.id == planID })
        planSummaries.removeAll(where: { $0.id == planID })
        rebuildPlanCaches()
        persistenceController.scheduleDeletePlans([planID])
    }

    func addPresetPack(_ pack: PresetPack, settings: SettingsStore) {
        let existingPinnedPlanIDs = Set(
            planSummaries.compactMap { plan in
                plan.pinnedTemplateID == nil ? nil : plan.id
            }
        )
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
            cacheLoadedPlan(plan)
        }

        persistenceController.scheduleUpsertPlans(generatedPlans)
    }

    func exerciseName(for exerciseID: UUID) -> String {
        catalogByID[exerciseID]?.name ?? "Unknown Exercise"
    }

    func exerciseItem(for exerciseID: UUID) -> ExerciseCatalogItem? {
        catalogByID[exerciseID]
    }

    func plan(for planID: UUID) -> Plan? {
        if let loadedPlan = loadedPlansByID[planID] {
            return loadedPlan
        }

        guard let loadedPlan = persistenceController.loadPlan(planID) else {
            return nil
        }

        cacheLoadedPlan(loadedPlan)
        return loadedPlan
    }

    func planSummary(for planID: UUID) -> PlanSummary? {
        planSummariesByID[planID]
    }

    func templateReferences() -> [TemplateReference] {
        cachedTemplateReferences
    }

    var templateReferenceCount: Int {
        cachedTemplateReferences.count
    }

    var planCount: Int {
        planSummaries.count
    }

    func markTemplateStarted(planID: UUID, templateID: UUID, startedAt: Date) {
        guard var plan = plan(for: planID),
            let templateIndex = plan.templates.firstIndex(where: { $0.id == templateID })
        else {
            return
        }

        guard plan.templates[templateIndex].lastStartedAt != startedAt else {
            return
        }

        plan.templates[templateIndex].lastStartedAt = startedAt
        cacheLoadedPlan(plan)
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
        guard var targetPlan = plan(for: planID),
            targetPlan.templates.contains(where: { $0.id == templateID })
        else {
            return
        }

        var changedPlans: [Plan] = []

        if targetPlan.pinnedTemplateID != templateID {
            targetPlan.pinnedTemplateID = templateID
            cacheLoadedPlan(targetPlan)
            changedPlans.append(targetPlan)
        }

        let otherPinnedPlanIDs = planSummaries.compactMap { summary in
            summary.id == planID || summary.pinnedTemplateID == nil ? nil : summary.id
        }

        for otherPlanID in otherPinnedPlanIDs {
            guard var otherPlan = plan(for: otherPlanID),
                otherPlan.pinnedTemplateID != nil
            else {
                continue
            }

            otherPlan.pinnedTemplateID = nil
            cacheLoadedPlan(otherPlan)
            changedPlans.append(otherPlan)
        }

        guard !changedPlans.isEmpty else {
            return
        }

        persistenceController.scheduleUpsertPlans(changedPlans)
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
        ensureProfilesLoaded()
        return profilesByExerciseID[exerciseID]
    }

    func saveProfiles(_ updatedProfiles: [ExerciseProfile]) {
        guard !updatedProfiles.isEmpty else {
            return
        }

        ensureProfilesLoaded()

        for profile in updatedProfiles {
            if let index = profiles.firstIndex(where: { $0.id == profile.id }) {
                profiles[index] = profile
            } else {
                profiles.append(profile)
            }
        }

        rebuildProfileCaches()
        persistenceController.scheduleUpsertProfiles(updatedProfiles)
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
        let changedPlans = synchronizeExerciseNameSnapshots(exerciseID: itemID, name: name)
        rebuildCatalogCaches()
        bumpCatalogRevision()
        persistenceController.scheduleUpsertCatalogItems([updatedItem])
        if !changedPlans.isEmpty {
            persistenceController.scheduleUpsertPlans(changedPlans)
        }
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
        persistenceController.scheduleUpsertCatalogItems([item])
        return item
    }

    var profileLookupByExerciseID: [UUID: ExerciseProfile] {
        ensureProfilesLoaded()
        return profilesByExerciseID
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

        if let nextAlternatingTemplateID = TemplateReferenceSelection.nextAlternatingTemplateID(
            in: plan,
            after: templateID
        ) {
            plan.pinnedTemplateID = nextAlternatingTemplateID
        }

        plan.templates[templateIndex] = template
        cacheLoadedPlan(plan)
        persistenceController.schedulePersistProgression(plan: plan, updatedProfiles: updatedProfiles)
    }

    func flushPendingPersistence() {
        persistenceController.flush()
    }

    private func applyLoadedPlanLibrary(_ loadedPlans: [Plan]) {
        guard hasLoadedPlanLibrary == false else {
            isLoadingPlanLibrary = false
            return
        }

        plans = loadedPlans
        planSummaries = loadedPlans.map(PlanSummary.init)
        loadedPlansByID = Dictionary(uniqueKeysWithValues: loadedPlans.map { ($0.id, $0) })
        hasLoadedPlanLibrary = true
        isLoadingPlanLibrary = false
        rebuildPlanCaches()
    }

    private func rebuildCaches() {
        rebuildCatalogCaches()
        rebuildPlanCaches()
        rebuildProfileCaches()
    }

    private func rebuildCatalogCaches() {
        catalogByID = Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, $0) })
    }

    private func cacheLoadedPlan(_ plan: Plan) {
        loadedPlansByID[plan.id] = plan
        upsertLoadedPlan(plan)
        upsertPlanSummary(PlanSummary(plan: plan))
        rebuildPlanCaches()
    }

    private func upsertLoadedPlan(_ plan: Plan) {
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

    private func upsertPlanSummary(_ summary: PlanSummary) {
        if let existingIndex = planSummaries.firstIndex(where: { $0.id == summary.id }) {
            let createdAt = planSummaries[existingIndex].createdAt
            planSummaries.remove(at: existingIndex)

            if createdAt == summary.createdAt {
                planSummaries.insert(summary, at: min(existingIndex, planSummaries.endIndex))
                return
            }
        }

        let insertionIndex = planSummaries.firstIndex(where: { $0.createdAt > summary.createdAt }) ?? planSummaries.endIndex
        planSummaries.insert(summary, at: insertionIndex)
    }

    private func rebuildPlanCaches() {
        planSummariesByID = Dictionary(uniqueKeysWithValues: planSummaries.map { ($0.id, $0) })
        cachedTemplateReferences = planSummaries.flatMap { plan in
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
        bumpPlanRevision()
    }

    private func rebuildProfileCaches() {
        profilesByExerciseID = Dictionary(uniqueKeysWithValues: profiles.map { ($0.exerciseID, $0) })
        if hasLoadedProfiles {
            profileCount = profiles.count
        }
    }

    private func bumpCatalogRevision() {
        catalogRevision &+= 1
    }

    private func bumpPlanRevision() {
        planRevision &+= 1
    }

    private func hasPinnedTemplate(excluding planID: UUID? = nil) -> Bool {
        planSummaries.contains { plan in
            guard plan.id != planID else {
                return false
            }

            return plan.pinnedTemplateID != nil
        }
    }

    private func synchronizeExerciseNameSnapshots(exerciseID: UUID, name: String) -> [Plan] {
        var changedPlanIDs: Set<UUID> = []

        for planIndex in plans.indices {
            for templateIndex in plans[planIndex].templates.indices {
                for blockIndex in plans[planIndex].templates[templateIndex].blocks.indices
                where plans[planIndex].templates[templateIndex].blocks[blockIndex].exerciseID == exerciseID {
                    guard plans[planIndex].templates[templateIndex].blocks[blockIndex].exerciseNameSnapshot != name else {
                        continue
                    }

                    plans[planIndex].templates[templateIndex].blocks[blockIndex].exerciseNameSnapshot = name
                    changedPlanIDs.insert(plans[planIndex].id)
                }
            }
        }

        guard !changedPlanIDs.isEmpty else {
            return []
        }

        for plan in plans where changedPlanIDs.contains(plan.id) {
            loadedPlansByID[plan.id] = plan
            upsertPlanSummary(PlanSummary(plan: plan))
        }
        rebuildPlanCaches()
        return plans.filter { changedPlanIDs.contains($0.id) }
    }

    private func templateBlockIndex(in template: WorkoutTemplate, matching finishedBlock: SessionBlock) -> Int? {
        template.blocks.firstIndex(where: { $0.id == finishedBlock.id })
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

    private func ensureProfilesLoaded() {
        guard hasLoadedProfiles == false else {
            return
        }

        profiles = persistenceController.loadProfiles()
        hasLoadedProfiles = true
        rebuildProfileCaches()
    }
}
