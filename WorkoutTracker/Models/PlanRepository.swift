import Foundation
import SwiftData

@MainActor
final class PlanRepository {
    private let modelContext: ModelContext
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func loadCatalog() -> [ExerciseCatalogItem] {
        let descriptor = FetchDescriptor<StoredExerciseCatalogRecord>(
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        let records = (try? modelContext.fetch(descriptor)) ?? []

        return records.compactMap { try? decoder.decode(ExerciseCatalogItem.self, from: $0.payload) }
    }

    func saveCatalog(_ catalog: [ExerciseCatalogItem]) {
        var recordsByID = Dictionary(uniqueKeysWithValues: loadCatalogRecords().map { ($0.id, $0) })

        for (index, item) in catalog.enumerated() {
            guard let payload = try? encoder.encode(item) else {
                continue
            }

            if let record = recordsByID.removeValue(forKey: item.id) {
                record.payload = payload
                record.sortOrder = index
            } else {
                modelContext.insert(
                    StoredExerciseCatalogRecord(id: item.id, payload: payload, sortOrder: index)
                )
            }
        }

        recordsByID.values.forEach(modelContext.delete)

        saveContext()
    }

    func loadPlans() -> [Plan] {
        let descriptor = FetchDescriptor<StoredPlanRecord>(
            sortBy: [SortDescriptor(\.updatedAt)]
        )
        let records = (try? modelContext.fetch(descriptor)) ?? []
        return records.compactMap { try? decoder.decode(Plan.self, from: $0.payload) }
    }

    func savePlans(_ plans: [Plan]) {
        var recordsByID = Dictionary(uniqueKeysWithValues: loadPlanRecords().map { ($0.id, $0) })

        for plan in plans {
            guard let payload = try? encoder.encode(plan) else {
                continue
            }

            if let record = recordsByID.removeValue(forKey: plan.id) {
                record.payload = payload
                record.updatedAt = .now
            } else {
                modelContext.insert(StoredPlanRecord(id: plan.id, payload: payload))
            }
        }

        recordsByID.values.forEach(modelContext.delete)

        saveContext()
    }

    func loadProfiles() -> [ExerciseProfile] {
        let records = (try? modelContext.fetch(FetchDescriptor<StoredExerciseProfileRecord>())) ?? []
        return records.compactMap { try? decoder.decode(ExerciseProfile.self, from: $0.payload) }
    }

    func saveProfiles(_ profiles: [ExerciseProfile]) {
        var recordsByID = Dictionary(uniqueKeysWithValues: loadProfileRecords().map { ($0.id, $0) })

        for profile in profiles {
            guard let payload = try? encoder.encode(profile) else {
                continue
            }

            if let record = recordsByID.removeValue(forKey: profile.id) {
                record.exerciseID = profile.exerciseID
                record.payload = payload
            } else {
                modelContext.insert(
                    StoredExerciseProfileRecord(id: profile.id, exerciseID: profile.exerciseID, payload: payload)
                )
            }
        }

        recordsByID.values.forEach(modelContext.delete)

        saveContext()
    }

    func deleteEverything() {
        loadCatalogRecords().forEach(modelContext.delete)
        loadPlanRecords().forEach(modelContext.delete)
        loadProfileRecords().forEach(modelContext.delete)
        saveContext()
    }

    private func loadCatalogRecords() -> [StoredExerciseCatalogRecord] {
        (try? modelContext.fetch(FetchDescriptor<StoredExerciseCatalogRecord>())) ?? []
    }

    private func loadPlanRecords() -> [StoredPlanRecord] {
        (try? modelContext.fetch(FetchDescriptor<StoredPlanRecord>())) ?? []
    }

    private func loadProfileRecords() -> [StoredExerciseProfileRecord] {
        (try? modelContext.fetch(FetchDescriptor<StoredExerciseProfileRecord>())) ?? []
    }

    private func saveContext() {
        guard modelContext.hasChanges else {
            return
        }

        try? modelContext.save()
    }
}
