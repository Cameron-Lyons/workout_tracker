import Foundation
import SwiftData

@MainActor
final class PlanRepository {
    private let modelContext: ModelContext
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let emptyArrayData = Data("[]".utf8)

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func loadCatalog() -> [ExerciseCatalogItem] {
        let records = (try? modelContext.fetch(FetchDescriptor<StoredCatalogItem>())) ?? []
        return
            records
            .compactMap(catalogItem(from:))
            .sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
    }

    @discardableResult
    func saveCatalog(_ catalog: [ExerciseCatalogItem]) -> Bool {
        var recordsByID = Dictionary(uniqueKeysWithValues: loadCatalogRecords().map { ($0.id, $0) })

        for item in catalog {
            let record: StoredCatalogItem
            if let existing = recordsByID.removeValue(forKey: item.id) {
                record = existing
            } else {
                record = StoredCatalogItem(
                    id: item.id,
                    name: item.name,
                    aliasesData: emptyArrayData,
                    categoryRaw: item.category.rawValue
                )
                modelContext.insert(record)
            }

            apply(item, to: record)
        }

        recordsByID.values.forEach(modelContext.delete)
        return saveContext("catalog")
    }

    func loadPlans() -> [Plan] {
        let descriptor = FetchDescriptor<StoredPlan>(sortBy: [SortDescriptor(\.createdAt)])
        let records = (try? modelContext.fetch(descriptor)) ?? []
        return records.compactMap(plan(from:))
    }

    @discardableResult
    func savePlans(_ plans: [Plan]) -> Bool {
        var recordsByID = Dictionary(uniqueKeysWithValues: loadPlanRecords().map { ($0.id, $0) })

        for plan in plans {
            let record: StoredPlan
            if let existing = recordsByID.removeValue(forKey: plan.id) {
                record = existing
            } else {
                record = StoredPlan(
                    id: plan.id,
                    name: plan.name,
                    createdAt: plan.createdAt,
                    pinnedTemplateID: plan.pinnedTemplateID
                )
                modelContext.insert(record)
            }

            apply(plan, to: record)
            syncTemplates(of: record, with: plan.templates)
        }

        recordsByID.values.forEach(modelContext.delete)
        return saveContext("plans")
    }

    func loadProfiles() -> [ExerciseProfile] {
        let records = (try? modelContext.fetch(FetchDescriptor<StoredExerciseProfile>())) ?? []
        return records.compactMap(profile(from:))
    }

    @discardableResult
    func saveProfiles(_ profiles: [ExerciseProfile]) -> Bool {
        var recordsByID = Dictionary(uniqueKeysWithValues: loadProfileRecords().map { ($0.id, $0) })

        for profile in profiles {
            let record: StoredExerciseProfile
            if let existing = recordsByID.removeValue(forKey: profile.id) {
                record = existing
            } else {
                record = StoredExerciseProfile(
                    id: profile.id,
                    exerciseID: profile.exerciseID,
                    trainingMax: profile.trainingMax,
                    preferredIncrement: profile.preferredIncrement
                )
                modelContext.insert(record)
            }

            apply(profile, to: record)
        }

        recordsByID.values.forEach(modelContext.delete)
        return saveContext("profiles")
    }

    @discardableResult
    func deleteEverything() -> Bool {
        loadCatalogRecords().forEach(modelContext.delete)
        loadPlanRecords().forEach(modelContext.delete)
        loadProfileRecords().forEach(modelContext.delete)
        loadLegacyCatalogRecords().forEach(modelContext.delete)
        loadLegacyPlanRecords().forEach(modelContext.delete)
        loadLegacyProfileRecords().forEach(modelContext.delete)
        return saveContext("plans reset")
    }

    private func catalogItem(from record: StoredCatalogItem) -> ExerciseCatalogItem? {
        ExerciseCatalogItem(
            id: record.id,
            name: record.name,
            aliases: decode([String].self, from: record.aliasesData) ?? [],
            category: ExerciseCategory(rawValue: record.categoryRaw) ?? .custom
        )
    }

    private func plan(from record: StoredPlan) -> Plan? {
        Plan(
            id: record.id,
            name: record.name,
            createdAt: record.createdAt,
            pinnedTemplateID: record.pinnedTemplateID,
            templates: record.templates
                .sorted(by: { $0.orderIndex < $1.orderIndex })
                .compactMap(template(from:))
        )
    }

    private func template(from record: StoredTemplate) -> WorkoutTemplate? {
        WorkoutTemplate(
            id: record.id,
            name: record.name,
            note: record.note,
            scheduledWeekdays: decode([Weekday].self, from: record.scheduledWeekdaysData) ?? [],
            blocks: record.blocks
                .sorted(by: { $0.orderIndex < $1.orderIndex })
                .compactMap(templateBlock(from:)),
            lastStartedAt: record.lastStartedAt
        )
    }

    private func templateBlock(from record: StoredTemplateBlock) -> ExerciseBlock? {
        ExerciseBlock(
            id: record.id,
            exerciseID: record.exerciseID,
            exerciseNameSnapshot: record.exerciseNameSnapshot,
            blockNote: record.blockNote,
            restSeconds: record.restSeconds,
            supersetGroup: record.supersetGroup,
            progressionRule: decode(ProgressionRule.self, from: record.progressionRuleData) ?? .manual,
            targets: record.targets
                .sorted(by: { $0.orderIndex < $1.orderIndex })
                .compactMap(templateTarget(from:)),
            allowsAutoWarmups: record.allowsAutoWarmups
        )
    }

    private func templateTarget(from record: StoredTemplateTarget) -> SetTarget? {
        SetTarget(
            id: record.id,
            setKind: SetKind(rawValue: record.setKindRaw) ?? .working,
            targetWeight: record.targetWeight,
            repRange: RepRange(record.repLower, record.repUpper),
            rir: record.rir,
            restSeconds: record.restSeconds,
            note: record.note
        )
    }

    private func profile(from record: StoredExerciseProfile) -> ExerciseProfile? {
        ExerciseProfile(
            id: record.id,
            exerciseID: record.exerciseID,
            trainingMax: record.trainingMax,
            preferredIncrement: record.preferredIncrement
        )
    }

    private func apply(_ item: ExerciseCatalogItem, to record: StoredCatalogItem) {
        if record.name != item.name {
            record.name = item.name
        }

        let aliasesData = encode(item.aliases) ?? emptyArrayData
        if record.aliasesData != aliasesData {
            record.aliasesData = aliasesData
        }

        if record.categoryRaw != item.category.rawValue {
            record.categoryRaw = item.category.rawValue
        }
    }

    private func apply(_ plan: Plan, to record: StoredPlan) {
        if record.name != plan.name {
            record.name = plan.name
        }

        if record.createdAt != plan.createdAt {
            record.createdAt = plan.createdAt
        }

        if record.pinnedTemplateID != plan.pinnedTemplateID {
            record.pinnedTemplateID = plan.pinnedTemplateID
        }
    }

    private func syncTemplates(of planRecord: StoredPlan, with templates: [WorkoutTemplate]) {
        var existingByID = Dictionary(uniqueKeysWithValues: planRecord.templates.map { ($0.id, $0) })
        var orderedRecords: [StoredTemplate] = []

        for (index, template) in templates.enumerated() {
            let record: StoredTemplate
            if let existing = existingByID.removeValue(forKey: template.id) {
                record = existing
            } else {
                record = StoredTemplate(
                    id: template.id,
                    name: template.name,
                    note: template.note,
                    scheduledWeekdaysData: emptyArrayData,
                    lastStartedAt: template.lastStartedAt,
                    orderIndex: index
                )
                modelContext.insert(record)
            }

            if record.plan?.id != planRecord.id {
                record.plan = planRecord
            }

            apply(template, to: record, orderIndex: index)
            syncBlocks(of: record, with: template.blocks)
            orderedRecords.append(record)
        }

        existingByID.values.forEach(modelContext.delete)
        if planRecord.templates.map(\.id) != orderedRecords.map(\.id) {
            planRecord.templates = orderedRecords
        }
    }

    private func apply(_ template: WorkoutTemplate, to record: StoredTemplate, orderIndex: Int) {
        if record.name != template.name {
            record.name = template.name
        }

        if record.note != template.note {
            record.note = template.note
        }

        let weekdaysData = encode(template.scheduledWeekdays) ?? emptyArrayData
        if record.scheduledWeekdaysData != weekdaysData {
            record.scheduledWeekdaysData = weekdaysData
        }

        if record.lastStartedAt != template.lastStartedAt {
            record.lastStartedAt = template.lastStartedAt
        }

        if record.orderIndex != orderIndex {
            record.orderIndex = orderIndex
        }
    }

    private func syncBlocks(of templateRecord: StoredTemplate, with blocks: [ExerciseBlock]) {
        var existingByID = Dictionary(uniqueKeysWithValues: templateRecord.blocks.map { ($0.id, $0) })
        var orderedRecords: [StoredTemplateBlock] = []

        for (index, block) in blocks.enumerated() {
            let record: StoredTemplateBlock
            if let existing = existingByID.removeValue(forKey: block.id) {
                record = existing
            } else {
                record = StoredTemplateBlock(
                    id: block.id,
                    exerciseID: block.exerciseID,
                    exerciseNameSnapshot: block.exerciseNameSnapshot,
                    blockNote: block.blockNote,
                    restSeconds: block.restSeconds,
                    supersetGroup: block.supersetGroup,
                    allowsAutoWarmups: block.allowsAutoWarmups,
                    orderIndex: index,
                    progressionRuleData: encode(block.progressionRule) ?? Data()
                )
                modelContext.insert(record)
            }

            if record.template?.id != templateRecord.id {
                record.template = templateRecord
            }

            apply(block, to: record, orderIndex: index)
            syncTargets(of: record, with: block.targets)
            orderedRecords.append(record)
        }

        existingByID.values.forEach(modelContext.delete)
        if templateRecord.blocks.map(\.id) != orderedRecords.map(\.id) {
            templateRecord.blocks = orderedRecords
        }
    }

    private func apply(_ block: ExerciseBlock, to record: StoredTemplateBlock, orderIndex: Int) {
        if record.exerciseID != block.exerciseID {
            record.exerciseID = block.exerciseID
        }

        if record.exerciseNameSnapshot != block.exerciseNameSnapshot {
            record.exerciseNameSnapshot = block.exerciseNameSnapshot
        }

        if record.blockNote != block.blockNote {
            record.blockNote = block.blockNote
        }

        if record.restSeconds != block.restSeconds {
            record.restSeconds = block.restSeconds
        }

        if record.supersetGroup != block.supersetGroup {
            record.supersetGroup = block.supersetGroup
        }

        if record.allowsAutoWarmups != block.allowsAutoWarmups {
            record.allowsAutoWarmups = block.allowsAutoWarmups
        }

        if record.orderIndex != orderIndex {
            record.orderIndex = orderIndex
        }

        let progressionRuleData = encode(block.progressionRule) ?? Data()
        if record.progressionRuleData != progressionRuleData {
            record.progressionRuleData = progressionRuleData
        }
    }

    private func syncTargets(of blockRecord: StoredTemplateBlock, with targets: [SetTarget]) {
        var existingByID = Dictionary(uniqueKeysWithValues: blockRecord.targets.map { ($0.id, $0) })
        var orderedRecords: [StoredTemplateTarget] = []

        for (index, target) in targets.enumerated() {
            let record: StoredTemplateTarget
            if let existing = existingByID.removeValue(forKey: target.id) {
                record = existing
            } else {
                record = StoredTemplateTarget(
                    id: target.id,
                    orderIndex: index,
                    setKindRaw: target.setKind.rawValue,
                    targetWeight: target.targetWeight,
                    repLower: target.repRange.lowerBound,
                    repUpper: target.repRange.upperBound,
                    rir: target.rir,
                    restSeconds: target.restSeconds,
                    note: target.note
                )
                modelContext.insert(record)
            }

            if record.block?.id != blockRecord.id {
                record.block = blockRecord
            }

            apply(target, to: record, orderIndex: index)
            orderedRecords.append(record)
        }

        existingByID.values.forEach(modelContext.delete)
        if blockRecord.targets.map(\.id) != orderedRecords.map(\.id) {
            blockRecord.targets = orderedRecords
        }
    }

    private func apply(_ target: SetTarget, to record: StoredTemplateTarget, orderIndex: Int) {
        if record.orderIndex != orderIndex {
            record.orderIndex = orderIndex
        }

        if record.setKindRaw != target.setKind.rawValue {
            record.setKindRaw = target.setKind.rawValue
        }

        if record.targetWeight != target.targetWeight {
            record.targetWeight = target.targetWeight
        }

        if record.repLower != target.repRange.lowerBound {
            record.repLower = target.repRange.lowerBound
        }

        if record.repUpper != target.repRange.upperBound {
            record.repUpper = target.repRange.upperBound
        }

        if record.rir != target.rir {
            record.rir = target.rir
        }

        if record.restSeconds != target.restSeconds {
            record.restSeconds = target.restSeconds
        }

        if record.note != target.note {
            record.note = target.note
        }
    }

    private func apply(_ profile: ExerciseProfile, to record: StoredExerciseProfile) {
        if record.exerciseID != profile.exerciseID {
            record.exerciseID = profile.exerciseID
        }

        if record.trainingMax != profile.trainingMax {
            record.trainingMax = profile.trainingMax
        }

        if record.preferredIncrement != profile.preferredIncrement {
            record.preferredIncrement = profile.preferredIncrement
        }
    }

    private func loadCatalogRecords() -> [StoredCatalogItem] {
        (try? modelContext.fetch(FetchDescriptor<StoredCatalogItem>())) ?? []
    }

    private func loadPlanRecords() -> [StoredPlan] {
        (try? modelContext.fetch(FetchDescriptor<StoredPlan>())) ?? []
    }

    private func loadProfileRecords() -> [StoredExerciseProfile] {
        (try? modelContext.fetch(FetchDescriptor<StoredExerciseProfile>())) ?? []
    }

    private func loadLegacyCatalogRecords() -> [StoredExerciseCatalogRecord] {
        (try? modelContext.fetch(FetchDescriptor<StoredExerciseCatalogRecord>())) ?? []
    }

    private func loadLegacyPlanRecords() -> [StoredPlanRecord] {
        (try? modelContext.fetch(FetchDescriptor<StoredPlanRecord>())) ?? []
    }

    private func loadLegacyProfileRecords() -> [StoredExerciseProfileRecord] {
        (try? modelContext.fetch(FetchDescriptor<StoredExerciseProfileRecord>())) ?? []
    }

    private func encode<Value: Encodable>(_ value: Value) -> Data? {
        try? encoder.encode(value)
    }

    private func decode<Value: Decodable>(_ type: Value.Type, from data: Data) -> Value? {
        try? decoder.decode(Value.self, from: data)
    }

    @discardableResult
    private func saveContext(_ operation: String) -> Bool {
        guard modelContext.hasChanges else {
            return true
        }

        do {
            try modelContext.save()
            return true
        } catch {
            modelContext.rollback()
            PersistenceDiagnostics.record("Failed to save \(operation) context", error: error)
            return false
        }
    }
}
