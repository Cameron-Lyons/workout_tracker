import Foundation
import SwiftData

class RepositoryBase {
    let modelContext: ModelContext

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func encode<Value: Encodable>(_ value: Value, operation: String) -> Data? {
        do {
            return try encoder.encode(value)
        } catch {
            PersistenceDiagnostics.record("Failed to encode \(operation)", error: error)
            return nil
        }
    }

    func decode<Value: Decodable>(_ type: Value.Type, from data: Data, operation: String) -> Value? {
        do {
            return try decoder.decode(Value.self, from: data)
        } catch {
            PersistenceDiagnostics.record("Failed to decode \(operation)", error: error)
            return nil
        }
    }

    @discardableResult
    func saveContext(_ operation: String) -> Bool {
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

    func orderedRecordsIfNeeded<Record>(_ records: [Record], by keyPath: KeyPath<Record, Int>) -> [Record] {
        guard records.count > 1 else {
            return records
        }

        var previousOrderIndex = records[0][keyPath: keyPath]
        for record in records.dropFirst() {
            let orderIndex = record[keyPath: keyPath]
            if orderIndex < previousOrderIndex {
                return records.sorted { $0[keyPath: keyPath] < $1[keyPath: keyPath] }
            }
            previousOrderIndex = orderIndex
        }

        return records
    }
}

final class PlanRepository: RepositoryBase {
    private let emptyArrayData = Data("[]".utf8)

    override init(modelContext: ModelContext) {
        super.init(modelContext: modelContext)
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
        persistCatalogItems(catalog, deleteMissing: true)
    }

    @discardableResult
    func upsertCatalogItems(_ items: [ExerciseCatalogItem]) -> Bool {
        persistCatalogItems(items, deleteMissing: false)
    }

    @discardableResult
    private func persistCatalogItems(_ items: [ExerciseCatalogItem], deleteMissing: Bool) -> Bool {
        var recordsByID = Dictionary(uniqueKeysWithValues: loadCatalogRecords().map { ($0.id, $0) })

        for item in items {
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

        if deleteMissing {
            recordsByID.values.forEach(modelContext.delete)
        }

        return saveContext("catalog")
    }

    func loadPlans() -> [Plan] {
        let descriptor = FetchDescriptor<StoredPlan>(sortBy: [SortDescriptor(\.createdAt)])
        let records = (try? modelContext.fetch(descriptor)) ?? []
        return records.compactMap(decodedPlan(from:))
    }

    func loadPlanSummaries() -> [PlanSummary] {
        let descriptor = FetchDescriptor<StoredPlan>(sortBy: [SortDescriptor(\.createdAt)])
        let records = (try? modelContext.fetch(descriptor)) ?? []
        return records.compactMap(decodedPlanSummary(from:))
    }

    func loadPlan(_ planID: UUID) -> Plan? {
        loadPlanRecord(planID).flatMap(decodedPlan(from:))
    }

    @discardableResult
    func savePlans(_ plans: [Plan]) -> Bool {
        persistPlans(plans, deleteMissing: true)
    }

    @discardableResult
    func upsertPlans(_ plans: [Plan]) -> Bool {
        persistPlans(plans, deleteMissing: false)
    }

    @discardableResult
    func deletePlans(_ planIDs: [UUID]) -> Bool {
        guard !planIDs.isEmpty else {
            return true
        }

        let planIDSet = Set(planIDs)
        loadPlanRecords()
            .filter { planIDSet.contains($0.id) }
            .forEach(modelContext.delete)
        return saveContext("plans")
    }

    @discardableResult
    private func persistPlans(_ plans: [Plan], deleteMissing: Bool) -> Bool {
        let existingRecords: [StoredPlan]
        if deleteMissing {
            existingRecords = loadPlanRecords()
        } else {
            existingRecords = plans.compactMap { loadPlanRecord($0.id) }
        }

        var recordsByID = Dictionary(uniqueKeysWithValues: existingRecords.map { ($0.id, $0) })

        for plan in plans {
            guard let storage = encodedPlanStorage(for: plan) else {
                continue
            }

            let record: StoredPlan
            if let existing = recordsByID.removeValue(forKey: plan.id) {
                record = existing
            } else {
                record = StoredPlan(
                    id: plan.id,
                    name: plan.name,
                    createdAt: plan.createdAt,
                    pinnedTemplateID: plan.pinnedTemplateID,
                    payloadData: storage.payloadData,
                    summaryData: storage.summaryData
                )
                modelContext.insert(record)
            }

            apply(plan, payloadData: storage.payloadData, summary: storage.summary, summaryData: storage.summaryData, to: record)
        }

        if deleteMissing {
            recordsByID.values.forEach(modelContext.delete)
        }

        return saveContext("plans")
    }

    @discardableResult
    func markTemplateStarted(planID: UUID, templateID: UUID, startedAt: Date) -> Bool {
        guard let record = loadPlanRecord(planID),
            var plan = decodedPlan(from: record),
            let templateIndex = plan.templates.firstIndex(where: { $0.id == templateID })
        else {
            return false
        }

        guard plan.templates[templateIndex].lastStartedAt != startedAt else {
            return true
        }

        plan.templates[templateIndex].lastStartedAt = startedAt
        guard let storage = encodedPlanStorage(for: plan) else {
            return false
        }

        apply(plan, payloadData: storage.payloadData, summary: storage.summary, summaryData: storage.summaryData, to: record)
        return saveContext("template start")
    }

    func loadProfiles() -> [ExerciseProfile] {
        let records = (try? modelContext.fetch(FetchDescriptor<StoredExerciseProfile>())) ?? []
        return records.compactMap(profile(from:))
    }

    func loadProfileCount() -> Int {
        (try? modelContext.fetchCount(FetchDescriptor<StoredExerciseProfile>())) ?? 0
    }

    @discardableResult
    func saveProfiles(_ profiles: [ExerciseProfile]) -> Bool {
        persistProfiles(profiles, deleteMissing: true)
    }

    @discardableResult
    func upsertProfiles(_ profiles: [ExerciseProfile]) -> Bool {
        persistProfiles(profiles, deleteMissing: false)
    }

    @discardableResult
    private func persistProfiles(_ profiles: [ExerciseProfile], deleteMissing: Bool) -> Bool {
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

        if deleteMissing {
            recordsByID.values.forEach(modelContext.delete)
        }

        return saveContext("profiles")
    }

    @discardableResult
    func deleteEverything() -> Bool {
        loadCatalogRecords().forEach(modelContext.delete)
        loadPlanRecords().forEach(modelContext.delete)
        loadProfileRecords().forEach(modelContext.delete)
        return saveContext("plans reset")
    }

    private func catalogItem(from record: StoredCatalogItem) -> ExerciseCatalogItem? {
        ExerciseCatalogItem(
            id: record.id,
            name: record.name,
            aliases: decode(
                [String].self,
                from: record.aliasesData,
                operation: "catalog item aliases for \(record.id.uuidString)"
            ) ?? [],
            category: ExerciseCategory(rawValue: record.categoryRaw) ?? .custom
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

        if let aliasesData = encode(
            item.aliases,
            operation: "catalog item aliases for \(item.id.uuidString)"
        ), record.aliasesData != aliasesData {
            record.aliasesData = aliasesData
        }

        if record.categoryRaw != item.category.rawValue {
            record.categoryRaw = item.category.rawValue
        }
    }

    private func apply(
        _ plan: Plan,
        payloadData: Data,
        summary: PlanSummary,
        summaryData: Data,
        to record: StoredPlan
    ) {
        if record.name != plan.name {
            record.name = plan.name
        }

        if record.createdAt != plan.createdAt {
            record.createdAt = plan.createdAt
        }

        if record.pinnedTemplateID != plan.pinnedTemplateID {
            record.pinnedTemplateID = plan.pinnedTemplateID
        }

        if record.payloadData != payloadData {
            record.payloadData = payloadData
        }

        if record.summaryData != summaryData {
            record.summaryData = summaryData
        }

        if record.name != summary.name {
            record.name = summary.name
        }
    }

    private func encodedPlanStorage(for plan: Plan) -> (payloadData: Data, summary: PlanSummary, summaryData: Data)? {
        guard let payloadData = encode(plan, operation: "plan \(plan.id.uuidString)") else {
            return nil
        }

        let summary = startupSummary(for: plan)
        guard let summaryData = encode(summary, operation: "plan summary for \(plan.id.uuidString)") else {
            return nil
        }

        return (payloadData, summary, summaryData)
    }

    private func decodedPlan(from record: StoredPlan) -> Plan? {
        decode(
            Plan.self,
            from: record.payloadData,
            operation: "plan \(record.id.uuidString)"
        )
    }

    private func decodedPlanSummary(from record: StoredPlan) -> PlanSummary? {
        if let summary = decode(
            PlanSummary.self,
            from: record.summaryData,
            operation: "plan summary for \(record.id.uuidString)"
        ) {
            return summary
        }

        guard let plan = decodedPlan(from: record) else {
            return nil
        }

        return startupSummary(for: plan)
    }

    private func startupSummary(for plan: Plan) -> PlanSummary {
        let includeBlockExerciseIDs = plan.templates.count == 2

        return PlanSummary(
            id: plan.id,
            name: plan.name,
            createdAt: plan.createdAt,
            pinnedTemplateID: plan.pinnedTemplateID,
            templates: plan.templates.map { template in
                TemplateSummary(
                    id: template.id,
                    name: template.name,
                    note: template.note,
                    scheduledWeekdays: template.scheduledWeekdays,
                    lastStartedAt: template.lastStartedAt,
                    blockExerciseIDs: includeBlockExerciseIDs ? template.blocks.map(\.exerciseID) : []
                )
            }
        )
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

    private func loadPlanRecord(_ planID: UUID) -> StoredPlan? {
        let descriptor = FetchDescriptor<StoredPlan>(
            predicate: #Predicate<StoredPlan> { $0.id == planID }
        )
        return (try? modelContext.fetch(descriptor))?.first
    }

    private func loadProfileRecords() -> [StoredExerciseProfile] {
        (try? modelContext.fetch(FetchDescriptor<StoredExerciseProfile>())) ?? []
    }
}
