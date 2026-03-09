import Foundation
import SwiftData

@MainActor
enum PersistenceMigrationCoordinator {
    private enum Compatibility {
        static let storageVersion = 4
        static let storageVersionKey = "workout_tracker_storage_version_v4"
    }

    private static let decoder = JSONDecoder()

    static func prepareIfNeeded(modelContainer: ModelContainer) {
        let defaults = UserDefaults.standard
        let storedVersion = defaults.integer(forKey: Compatibility.storageVersionKey)
        guard storedVersion < Compatibility.storageVersion else {
            return
        }

        let context = ModelContext(modelContainer)
        context.autosaveEnabled = false

        let removedUnsupportedLegacyData = clearUnsupportedLegacyRecords(in: context)
        let hasRelationalData = hasRelationalData(in: context)
        let hasBlobData = hasBlobData(in: context)

        if hasRelationalData == false, hasBlobData {
            migrateBlobRecords(in: context)
            deleteLegacyBlobRecords(in: context)
        } else if hasRelationalData {
            deleteLegacyBlobRecords(in: context)
        }

        if removedUnsupportedLegacyData && !hasRelationalData && !hasBlobData {
            SettingsStore.resetPersistedSettings(defaults: defaults)
        }

        if context.hasChanges {
            try? context.save()
        }

        defaults.set(Compatibility.storageVersion, forKey: Compatibility.storageVersionKey)
    }

    private static func hasRelationalData(in context: ModelContext) -> Bool {
        let planCount = (try? context.fetchCount(FetchDescriptor<StoredPlan>())) ?? 0
        if planCount > 0 {
            return true
        }

        let catalogCount = (try? context.fetchCount(FetchDescriptor<StoredCatalogItem>())) ?? 0
        if catalogCount > 0 {
            return true
        }

        let profileCount = (try? context.fetchCount(FetchDescriptor<StoredExerciseProfile>())) ?? 0
        if profileCount > 0 {
            return true
        }

        let activeCount = (try? context.fetchCount(FetchDescriptor<StoredActiveSession>())) ?? 0
        if activeCount > 0 {
            return true
        }

        let completedCount = (try? context.fetchCount(FetchDescriptor<StoredCompletedSession>())) ?? 0
        return completedCount > 0
    }

    private static func hasBlobData(in context: ModelContext) -> Bool {
        let planCount = (try? context.fetchCount(FetchDescriptor<StoredPlanRecord>())) ?? 0
        if planCount > 0 {
            return true
        }

        let catalogCount = (try? context.fetchCount(FetchDescriptor<StoredExerciseCatalogRecord>())) ?? 0
        if catalogCount > 0 {
            return true
        }

        let profileCount = (try? context.fetchCount(FetchDescriptor<StoredExerciseProfileRecord>())) ?? 0
        if profileCount > 0 {
            return true
        }

        let activeCount = (try? context.fetchCount(FetchDescriptor<StoredActiveSessionRecord>())) ?? 0
        if activeCount > 0 {
            return true
        }

        let completedCount = (try? context.fetchCount(FetchDescriptor<StoredCompletedSessionRecord>())) ?? 0
        return completedCount > 0
    }

    private static func clearUnsupportedLegacyRecords(in context: ModelContext) -> Bool {
        var didDelete = false
        didDelete = deleteAll(StoredRoutine.self, in: context) || didDelete
        didDelete = deleteAll(StoredExercise.self, in: context) || didDelete
        didDelete = deleteAll(StoredWorkoutSession.self, in: context) || didDelete
        didDelete = deleteAll(StoredWorkoutEntry.self, in: context) || didDelete
        didDelete = deleteAll(StoredWorkoutSet.self, in: context) || didDelete
        return didDelete
    }

    private static func migrateBlobRecords(in context: ModelContext) {
        let planRepository = PlanRepository(modelContext: context)
        let sessionRepository = SessionRepository(modelContext: context)

        let catalog = loadLegacyCatalog(in: context)
        if !catalog.isEmpty {
            planRepository.saveCatalog(catalog)
        }

        let plans = loadLegacyPlans(in: context)
        if !plans.isEmpty {
            planRepository.savePlans(plans)
        }

        let profiles = loadLegacyProfiles(in: context)
        if !profiles.isEmpty {
            planRepository.saveProfiles(profiles)
        }

        sessionRepository.saveActiveDraft(loadLegacyActiveDraft(in: context))

        let completedSessions = loadLegacyCompletedSessions(in: context)
        if !completedSessions.isEmpty {
            sessionRepository.saveCompletedSessions(completedSessions)
        }
    }

    private static func loadLegacyCatalog(in context: ModelContext) -> [ExerciseCatalogItem] {
        let descriptor = FetchDescriptor<StoredExerciseCatalogRecord>(
            sortBy: [SortDescriptor(\StoredExerciseCatalogRecord.sortOrder)]
        )
        let records = (try? context.fetch(descriptor)) ?? []
        return records.compactMap { try? decoder.decode(ExerciseCatalogItem.self, from: $0.payload) }
    }

    private static func loadLegacyPlans(in context: ModelContext) -> [Plan] {
        let descriptor = FetchDescriptor<StoredPlanRecord>(sortBy: [SortDescriptor(\StoredPlanRecord.updatedAt)])
        let records = (try? context.fetch(descriptor)) ?? []
        return records.compactMap { try? decoder.decode(Plan.self, from: $0.payload) }
    }

    private static func loadLegacyProfiles(in context: ModelContext) -> [ExerciseProfile] {
        let records = (try? context.fetch(FetchDescriptor<StoredExerciseProfileRecord>())) ?? []
        return records.compactMap { try? decoder.decode(ExerciseProfile.self, from: $0.payload) }
    }

    private static func loadLegacyActiveDraft(in context: ModelContext) -> SessionDraft? {
        let record = (try? context.fetch(FetchDescriptor<StoredActiveSessionRecord>()))?.first
        return record.flatMap { try? decoder.decode(SessionDraft.self, from: $0.payload) }
    }

    private static func loadLegacyCompletedSessions(in context: ModelContext) -> [CompletedSession] {
        let descriptor = FetchDescriptor<StoredCompletedSessionRecord>(
            sortBy: [SortDescriptor(\StoredCompletedSessionRecord.completedAt)]
        )
        let records = (try? context.fetch(descriptor)) ?? []
        return records.compactMap { try? decoder.decode(CompletedSession.self, from: $0.payload) }
    }

    private static func deleteLegacyBlobRecords(in context: ModelContext) {
        deleteAll(StoredPlanRecord.self, in: context)
        deleteAll(StoredExerciseCatalogRecord.self, in: context)
        deleteAll(StoredExerciseProfileRecord.self, in: context)
        deleteAll(StoredActiveSessionRecord.self, in: context)
        deleteAll(StoredCompletedSessionRecord.self, in: context)
    }

    @discardableResult
    private static func deleteAll<Model: PersistentModel>(_ modelType: Model.Type, in context: ModelContext) -> Bool {
        let records = (try? context.fetch(FetchDescriptor<Model>())) ?? []
        guard !records.isEmpty else {
            return false
        }

        for record in records {
            context.delete(record)
        }

        return true
    }
}
