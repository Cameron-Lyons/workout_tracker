import Foundation
import SwiftData

final class SessionRepository: RepositoryBase {
    override init(modelContext: ModelContext) {
        super.init(modelContext: modelContext)
    }

    func loadActiveDraft() -> SessionDraft? {
        let descriptor = FetchDescriptor<StoredActiveSession>(
            sortBy: [SortDescriptor(\StoredActiveSession.lastUpdatedAt)]
        )
        let records = (try? modelContext.fetch(descriptor)) ?? []
        return records.last.flatMap(decodedActiveDraft(from:))
    }

    @discardableResult
    func saveActiveDraft(_ draft: SessionDraft?) -> Bool {
        let records = loadActiveDraftRecords()
        let existingRecord = records.first
        records.dropFirst().forEach(modelContext.delete)

        guard let draft else {
            if let existingRecord {
                modelContext.delete(existingRecord)
            }
            return saveContext("active draft")
        }

        guard let payloadData = encode(draft, operation: "active draft \(draft.id.uuidString)") else {
            return false
        }

        let record: StoredActiveSession
        if let existingRecord {
            record = existingRecord
        } else {
            record = StoredActiveSession(
                id: draft.id,
                planID: draft.planID,
                templateID: draft.templateID,
                templateNameSnapshot: draft.templateNameSnapshot,
                startedAt: draft.startedAt,
                lastUpdatedAt: draft.lastUpdatedAt,
                notes: draft.notes,
                restTimerEndsAt: draft.restTimerEndsAt,
                payloadData: payloadData
            )
            modelContext.insert(record)
        }

        applyActiveDraft(draft, payloadData: payloadData, to: record)
        return saveContext("active draft")
    }

    func loadCompletedSessions() -> [CompletedSession] {
        let descriptor = FetchDescriptor<StoredCompletedSession>(
            sortBy: [SortDescriptor(\StoredCompletedSession.completedAt)]
        )
        let records = (try? modelContext.fetch(descriptor)) ?? []
        return records.compactMap(decodedCompletedSession(from:))
    }

    @discardableResult
    func persistCompletedSessionAndClearActiveDraft(_ session: CompletedSession) -> Bool {
        guard
            let payloadData = encode(
                session,
                operation: "completed session \(session.id.uuidString)"
            )
        else {
            return false
        }

        let record =
            loadCompletedSessionRecord(session.id)
            ?? StoredCompletedSession(
                id: session.id,
                planID: session.planID,
                templateID: session.templateID,
                templateNameSnapshot: session.templateNameSnapshot,
                completedAt: session.completedAt,
                payloadData: payloadData
            )
        if record.modelContext == nil {
            modelContext.insert(record)
        }

        applyCompletedSession(session, payloadData: payloadData, to: record)
        loadActiveDraftRecords().forEach(modelContext.delete)
        return saveContext("completed session")
    }

    @discardableResult
    func deleteEverything() -> Bool {
        loadActiveDraftRecords().forEach(modelContext.delete)
        loadCompletedSessionRecords().forEach(modelContext.delete)
        return saveContext("sessions reset")
    }

    private func decodedActiveDraft(from record: StoredActiveSession) -> SessionDraft? {
        decode(
            SessionDraft.self,
            from: record.payloadData,
            operation: "active draft \(record.id.uuidString)"
        )
    }

    private func decodedCompletedSession(from record: StoredCompletedSession) -> CompletedSession? {
        decode(
            CompletedSession.self,
            from: record.payloadData,
            operation: "completed session \(record.id.uuidString)"
        )
    }

    private func applyActiveDraft(_ draft: SessionDraft, payloadData: Data, to record: StoredActiveSession) {
        if record.id != draft.id {
            record.id = draft.id
        }

        if record.planID != draft.planID {
            record.planID = draft.planID
        }

        if record.templateID != draft.templateID {
            record.templateID = draft.templateID
        }

        if record.templateNameSnapshot != draft.templateNameSnapshot {
            record.templateNameSnapshot = draft.templateNameSnapshot
        }

        if record.startedAt != draft.startedAt {
            record.startedAt = draft.startedAt
        }

        if record.lastUpdatedAt != draft.lastUpdatedAt {
            record.lastUpdatedAt = draft.lastUpdatedAt
        }

        if record.notes != draft.notes {
            record.notes = draft.notes
        }

        if record.restTimerEndsAt != draft.restTimerEndsAt {
            record.restTimerEndsAt = draft.restTimerEndsAt
        }

        if record.payloadData != payloadData {
            record.payloadData = payloadData
        }
    }

    private func applyCompletedSession(
        _ session: CompletedSession,
        payloadData: Data,
        to record: StoredCompletedSession
    ) {
        if record.id != session.id {
            record.id = session.id
        }

        if record.planID != session.planID {
            record.planID = session.planID
        }

        if record.templateID != session.templateID {
            record.templateID = session.templateID
        }

        if record.templateNameSnapshot != session.templateNameSnapshot {
            record.templateNameSnapshot = session.templateNameSnapshot
        }

        if record.completedAt != session.completedAt {
            record.completedAt = session.completedAt
        }

        if record.payloadData != payloadData {
            record.payloadData = payloadData
        }
    }

    private func loadActiveDraftRecords() -> [StoredActiveSession] {
        (try? modelContext.fetch(FetchDescriptor<StoredActiveSession>())) ?? []
    }

    private func loadCompletedSessionRecords() -> [StoredCompletedSession] {
        (try? modelContext.fetch(FetchDescriptor<StoredCompletedSession>())) ?? []
    }

    private func loadCompletedSessionRecord(_ sessionID: UUID) -> StoredCompletedSession? {
        let descriptor = FetchDescriptor<StoredCompletedSession>(
            predicate: #Predicate<StoredCompletedSession> { $0.id == sessionID }
        )
        return (try? modelContext.fetch(descriptor))?.first
    }
}
