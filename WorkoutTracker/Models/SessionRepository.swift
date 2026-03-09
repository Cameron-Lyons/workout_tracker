import Foundation
import SwiftData

@MainActor
final class SessionRepository {
    private let modelContext: ModelContext
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func loadActiveDraft() -> SessionDraft? {
        guard let record = (try? modelContext.fetch(FetchDescriptor<StoredActiveSessionRecord>()))?.first else {
            return nil
        }

        return try? decoder.decode(SessionDraft.self, from: record.payload)
    }

    func saveActiveDraft(_ draft: SessionDraft?) {
        let records = loadActiveDraftRecords()
        let existingRecord = records.first
        records.dropFirst().forEach(modelContext.delete)

        if let draft, let payload = try? encoder.encode(draft) {
            if let existingRecord {
                existingRecord.id = draft.id
                existingRecord.payload = payload
                existingRecord.updatedAt = .now
            } else {
                modelContext.insert(StoredActiveSessionRecord(id: draft.id, payload: payload))
            }
        } else if let existingRecord {
            modelContext.delete(existingRecord)
        }

        saveContext()
    }

    func loadCompletedSessions() -> [CompletedSession] {
        let descriptor = FetchDescriptor<StoredCompletedSessionRecord>(
            sortBy: [SortDescriptor(\.completedAt)]
        )
        let records = (try? modelContext.fetch(descriptor)) ?? []
        return records.compactMap { try? decoder.decode(CompletedSession.self, from: $0.payload) }
    }

    func saveCompletedSessions(_ sessions: [CompletedSession]) {
        var recordsByID = Dictionary(uniqueKeysWithValues: loadCompletedSessionRecords().map { ($0.id, $0) })

        for session in sessions {
            guard let payload = try? encoder.encode(session) else {
                continue
            }

            if let record = recordsByID.removeValue(forKey: session.id) {
                record.completedAt = session.completedAt
                record.payload = payload
            } else {
                modelContext.insert(
                    StoredCompletedSessionRecord(
                        id: session.id,
                        completedAt: session.completedAt,
                        payload: payload
                    )
                )
            }
        }

        recordsByID.values.forEach(modelContext.delete)

        saveContext()
    }

    func deleteEverything() {
        saveActiveDraft(nil)
        saveCompletedSessions([])
    }

    private func loadActiveDraftRecords() -> [StoredActiveSessionRecord] {
        (try? modelContext.fetch(FetchDescriptor<StoredActiveSessionRecord>())) ?? []
    }

    private func loadCompletedSessionRecords() -> [StoredCompletedSessionRecord] {
        (try? modelContext.fetch(FetchDescriptor<StoredCompletedSessionRecord>())) ?? []
    }

    private func saveContext() {
        guard modelContext.hasChanges else {
            return
        }

        try? modelContext.save()
    }
}
