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
        let descriptor = FetchDescriptor<StoredActiveSession>(sortBy: [SortDescriptor(\StoredActiveSession.lastUpdatedAt)])
        let records = (try? modelContext.fetch(descriptor)) ?? []
        return records.last.flatMap(activeDraft(from:))
    }

    func saveActiveDraft(_ draft: SessionDraft?) {
        let records = loadActiveDraftRecords()
        let existingRecord = records.first
        records.dropFirst().forEach(modelContext.delete)

        guard let draft else {
            if let existingRecord {
                modelContext.delete(existingRecord)
            }
            saveContext()
            return
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
                restTimerEndsAt: draft.restTimerEndsAt
            )
            modelContext.insert(record)
        }

        apply(draft, to: record)
        syncActiveBlocks(of: record, with: draft.blocks)
        saveContext()
    }

    func loadCompletedSessions() -> [CompletedSession] {
        let descriptor = FetchDescriptor<StoredCompletedSession>(
            sortBy: [SortDescriptor(\StoredCompletedSession.completedAt)]
        )
        let records = (try? modelContext.fetch(descriptor)) ?? []
        return records.compactMap(completedSession(from:))
    }

    func saveCompletedSessions(_ sessions: [CompletedSession]) {
        var recordsByID = Dictionary(uniqueKeysWithValues: loadCompletedSessionRecords().map { ($0.id, $0) })

        for session in sessions {
            let record = recordsByID.removeValue(forKey: session.id) ?? makeCompletedSessionRecord(from: session)
            if record.modelContext == nil {
                modelContext.insert(record)
            }

            apply(session, to: record)
            syncCompletedBlocks(of: record, with: session.blocks)
        }

        recordsByID.values.forEach(modelContext.delete)
        saveContext()
    }

    func saveCompletedSession(_ session: CompletedSession) {
        let descriptor = FetchDescriptor<StoredCompletedSession>(
            predicate: #Predicate<StoredCompletedSession> { $0.id == session.id }
        )
        let record = (try? modelContext.fetch(descriptor))?.first ?? makeCompletedSessionRecord(from: session)
        if record.modelContext == nil {
            modelContext.insert(record)
        }

        apply(session, to: record)
        syncCompletedBlocks(of: record, with: session.blocks)
        saveContext()
    }

    func deleteEverything() {
        loadActiveDraftRecords().forEach(modelContext.delete)
        loadCompletedSessionRecords().forEach(modelContext.delete)
        loadLegacyActiveDraftRecords().forEach(modelContext.delete)
        loadLegacyCompletedSessionRecords().forEach(modelContext.delete)
        saveContext()
    }

    private func activeDraft(from record: StoredActiveSession) -> SessionDraft? {
        SessionDraft(
            id: record.id,
            planID: record.planID,
            templateID: record.templateID,
            templateNameSnapshot: record.templateNameSnapshot,
            startedAt: record.startedAt,
            lastUpdatedAt: record.lastUpdatedAt,
            notes: record.notes,
            blocks: record.blocks
                .sorted(by: { $0.orderIndex < $1.orderIndex })
                .compactMap(activeBlock(from:)),
            restTimerEndsAt: record.restTimerEndsAt
        )
    }

    private func activeBlock(from record: StoredActiveSessionBlock) -> SessionBlock? {
        SessionBlock(
            id: record.id,
            sourceBlockID: record.sourceBlockID,
            exerciseID: record.exerciseID,
            exerciseNameSnapshot: record.exerciseNameSnapshot,
            blockNote: record.blockNote,
            restSeconds: record.restSeconds,
            supersetGroup: record.supersetGroup,
            progressionRule: decode(ProgressionRule.self, from: record.progressionRuleData) ?? .manual,
            sets: record.rows
                .sorted(by: { $0.orderIndex < $1.orderIndex })
                .compactMap(activeRow(from:))
        )
    }

    private func activeRow(from record: StoredActiveSessionRow) -> SessionSetRow? {
        SessionSetRow(
            id: record.id,
            target: SetTarget(
                id: record.targetID,
                setKind: SetKind(rawValue: record.targetSetKindRaw) ?? .working,
                targetWeight: record.targetWeight,
                repRange: RepRange(record.targetRepLower, record.targetRepUpper),
                rir: record.targetRir,
                restSeconds: record.targetRestSeconds,
                note: record.targetNote
            ),
            log: SetLog(
                id: record.logID,
                setTargetID: record.targetID,
                weight: record.logWeight,
                reps: record.logReps,
                rir: record.logRir,
                completedAt: record.logCompletedAt
            )
        )
    }

    private func completedSession(from record: StoredCompletedSession) -> CompletedSession? {
        CompletedSession(
            id: record.id,
            planID: record.planID,
            templateID: record.templateID,
            templateNameSnapshot: record.templateNameSnapshot,
            startedAt: record.startedAt,
            completedAt: record.completedAt,
            notes: record.notes,
            blocks: record.blocks
                .sorted(by: { $0.orderIndex < $1.orderIndex })
                .compactMap(completedBlock(from:))
        )
    }

    private func completedBlock(from record: StoredCompletedSessionBlock) -> CompletedSessionBlock? {
        CompletedSessionBlock(
            id: record.id,
            exerciseID: record.exerciseID,
            exerciseNameSnapshot: record.exerciseNameSnapshot,
            blockNote: record.blockNote,
            restSeconds: record.restSeconds,
            supersetGroup: record.supersetGroup,
            progressionRule: decode(ProgressionRule.self, from: record.progressionRuleData) ?? .manual,
            sets: record.rows
                .sorted(by: { $0.orderIndex < $1.orderIndex })
                .compactMap(completedRow(from:))
        )
    }

    private func completedRow(from record: StoredCompletedSessionRow) -> SessionSetRow? {
        SessionSetRow(
            id: record.id,
            target: SetTarget(
                id: record.targetID,
                setKind: SetKind(rawValue: record.targetSetKindRaw) ?? .working,
                targetWeight: record.targetWeight,
                repRange: RepRange(record.targetRepLower, record.targetRepUpper),
                rir: record.targetRir,
                restSeconds: record.targetRestSeconds,
                note: record.targetNote
            ),
            log: SetLog(
                id: record.logID,
                setTargetID: record.targetID,
                weight: record.logWeight,
                reps: record.logReps,
                rir: record.logRir,
                completedAt: record.logCompletedAt
            )
        )
    }

    private func apply(_ draft: SessionDraft, to record: StoredActiveSession) {
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
    }

    private func syncActiveBlocks(of sessionRecord: StoredActiveSession, with blocks: [SessionBlock]) {
        var existingByID = Dictionary(uniqueKeysWithValues: sessionRecord.blocks.map { ($0.id, $0) })
        var orderedRecords: [StoredActiveSessionBlock] = []

        for (index, block) in blocks.enumerated() {
            let record: StoredActiveSessionBlock
            if let existing = existingByID.removeValue(forKey: block.id) {
                record = existing
            } else {
                record = StoredActiveSessionBlock(
                    id: block.id,
                    orderIndex: index,
                    sourceBlockID: block.sourceBlockID,
                    exerciseID: block.exerciseID,
                    exerciseNameSnapshot: block.exerciseNameSnapshot,
                    blockNote: block.blockNote,
                    restSeconds: block.restSeconds,
                    supersetGroup: block.supersetGroup,
                    progressionRuleData: encode(block.progressionRule) ?? Data()
                )
                modelContext.insert(record)
            }

            if record.session?.id != sessionRecord.id {
                record.session = sessionRecord
            }

            apply(block, to: record, orderIndex: index)
            syncActiveRows(of: record, with: block.sets)
            orderedRecords.append(record)
        }

        existingByID.values.forEach(modelContext.delete)
        if sessionRecord.blocks.map(\.id) != orderedRecords.map(\.id) {
            sessionRecord.blocks = orderedRecords
        }
    }

    private func apply(_ block: SessionBlock, to record: StoredActiveSessionBlock, orderIndex: Int) {
        if record.id != block.id {
            record.id = block.id
        }

        if record.orderIndex != orderIndex {
            record.orderIndex = orderIndex
        }

        if record.sourceBlockID != block.sourceBlockID {
            record.sourceBlockID = block.sourceBlockID
        }

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

        let progressionRuleData = encode(block.progressionRule) ?? Data()
        if record.progressionRuleData != progressionRuleData {
            record.progressionRuleData = progressionRuleData
        }
    }

    private func syncActiveRows(of blockRecord: StoredActiveSessionBlock, with rows: [SessionSetRow]) {
        var existingByID = Dictionary(uniqueKeysWithValues: blockRecord.rows.map { ($0.id, $0) })
        var orderedRecords: [StoredActiveSessionRow] = []

        for (index, row) in rows.enumerated() {
            let record: StoredActiveSessionRow
            if let existing = existingByID.removeValue(forKey: row.id) {
                record = existing
            } else {
                record = StoredActiveSessionRow(
                    id: row.id,
                    orderIndex: index,
                    targetID: row.target.id,
                    targetSetKindRaw: row.target.setKind.rawValue,
                    targetWeight: row.target.targetWeight,
                    targetRepLower: row.target.repRange.lowerBound,
                    targetRepUpper: row.target.repRange.upperBound,
                    targetRir: row.target.rir,
                    targetRestSeconds: row.target.restSeconds,
                    targetNote: row.target.note,
                    logID: row.log.id,
                    logWeight: row.log.weight,
                    logReps: row.log.reps,
                    logRir: row.log.rir,
                    logCompletedAt: row.log.completedAt
                )
                modelContext.insert(record)
            }

            if record.block?.id != blockRecord.id {
                record.block = blockRecord
            }

            apply(row, to: record, orderIndex: index)
            orderedRecords.append(record)
        }

        existingByID.values.forEach(modelContext.delete)
        if blockRecord.rows.map(\.id) != orderedRecords.map(\.id) {
            blockRecord.rows = orderedRecords
        }
    }

    private func apply(_ row: SessionSetRow, to record: StoredActiveSessionRow, orderIndex: Int) {
        if record.id != row.id {
            record.id = row.id
        }

        if record.orderIndex != orderIndex {
            record.orderIndex = orderIndex
        }

        if record.targetID != row.target.id {
            record.targetID = row.target.id
        }

        if record.targetSetKindRaw != row.target.setKind.rawValue {
            record.targetSetKindRaw = row.target.setKind.rawValue
        }

        if record.targetWeight != row.target.targetWeight {
            record.targetWeight = row.target.targetWeight
        }

        if record.targetRepLower != row.target.repRange.lowerBound {
            record.targetRepLower = row.target.repRange.lowerBound
        }

        if record.targetRepUpper != row.target.repRange.upperBound {
            record.targetRepUpper = row.target.repRange.upperBound
        }

        if record.targetRir != row.target.rir {
            record.targetRir = row.target.rir
        }

        if record.targetRestSeconds != row.target.restSeconds {
            record.targetRestSeconds = row.target.restSeconds
        }

        if record.targetNote != row.target.note {
            record.targetNote = row.target.note
        }

        if record.logID != row.log.id {
            record.logID = row.log.id
        }

        if record.logWeight != row.log.weight {
            record.logWeight = row.log.weight
        }

        if record.logReps != row.log.reps {
            record.logReps = row.log.reps
        }

        if record.logRir != row.log.rir {
            record.logRir = row.log.rir
        }

        if record.logCompletedAt != row.log.completedAt {
            record.logCompletedAt = row.log.completedAt
        }
    }

    private func makeCompletedSessionRecord(from session: CompletedSession) -> StoredCompletedSession {
        StoredCompletedSession(
            id: session.id,
            planID: session.planID,
            templateID: session.templateID,
            templateNameSnapshot: session.templateNameSnapshot,
            startedAt: session.startedAt,
            completedAt: session.completedAt,
            notes: session.notes
        )
    }

    private func apply(_ session: CompletedSession, to record: StoredCompletedSession) {
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

        if record.startedAt != session.startedAt {
            record.startedAt = session.startedAt
        }

        if record.completedAt != session.completedAt {
            record.completedAt = session.completedAt
        }

        if record.notes != session.notes {
            record.notes = session.notes
        }
    }

    private func syncCompletedBlocks(of sessionRecord: StoredCompletedSession, with blocks: [CompletedSessionBlock]) {
        var existingByID = Dictionary(uniqueKeysWithValues: sessionRecord.blocks.map { ($0.id, $0) })
        var orderedRecords: [StoredCompletedSessionBlock] = []

        for (index, block) in blocks.enumerated() {
            let record: StoredCompletedSessionBlock
            if let existing = existingByID.removeValue(forKey: block.id) {
                record = existing
            } else {
                record = StoredCompletedSessionBlock(
                    id: block.id,
                    orderIndex: index,
                    exerciseID: block.exerciseID,
                    exerciseNameSnapshot: block.exerciseNameSnapshot,
                    blockNote: block.blockNote,
                    restSeconds: block.restSeconds,
                    supersetGroup: block.supersetGroup,
                    progressionRuleData: encode(block.progressionRule) ?? Data()
                )
                modelContext.insert(record)
            }

            if record.session?.id != sessionRecord.id {
                record.session = sessionRecord
            }

            apply(block, to: record, orderIndex: index)
            syncCompletedRows(of: record, with: block.sets)
            orderedRecords.append(record)
        }

        existingByID.values.forEach(modelContext.delete)
        if sessionRecord.blocks.map(\.id) != orderedRecords.map(\.id) {
            sessionRecord.blocks = orderedRecords
        }
    }

    private func apply(_ block: CompletedSessionBlock, to record: StoredCompletedSessionBlock, orderIndex: Int) {
        if record.id != block.id {
            record.id = block.id
        }

        if record.orderIndex != orderIndex {
            record.orderIndex = orderIndex
        }

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

        let progressionRuleData = encode(block.progressionRule) ?? Data()
        if record.progressionRuleData != progressionRuleData {
            record.progressionRuleData = progressionRuleData
        }
    }

    private func syncCompletedRows(of blockRecord: StoredCompletedSessionBlock, with rows: [SessionSetRow]) {
        var existingByID = Dictionary(uniqueKeysWithValues: blockRecord.rows.map { ($0.id, $0) })
        var orderedRecords: [StoredCompletedSessionRow] = []

        for (index, row) in rows.enumerated() {
            let record: StoredCompletedSessionRow
            if let existing = existingByID.removeValue(forKey: row.id) {
                record = existing
            } else {
                record = StoredCompletedSessionRow(
                    id: row.id,
                    orderIndex: index,
                    targetID: row.target.id,
                    targetSetKindRaw: row.target.setKind.rawValue,
                    targetWeight: row.target.targetWeight,
                    targetRepLower: row.target.repRange.lowerBound,
                    targetRepUpper: row.target.repRange.upperBound,
                    targetRir: row.target.rir,
                    targetRestSeconds: row.target.restSeconds,
                    targetNote: row.target.note,
                    logID: row.log.id,
                    logWeight: row.log.weight,
                    logReps: row.log.reps,
                    logRir: row.log.rir,
                    logCompletedAt: row.log.completedAt
                )
                modelContext.insert(record)
            }

            if record.block?.id != blockRecord.id {
                record.block = blockRecord
            }

            apply(row, toCompletedRecord: record, orderIndex: index)
            orderedRecords.append(record)
        }

        existingByID.values.forEach(modelContext.delete)
        if blockRecord.rows.map(\.id) != orderedRecords.map(\.id) {
            blockRecord.rows = orderedRecords
        }
    }

    private func apply(_ row: SessionSetRow, toCompletedRecord record: StoredCompletedSessionRow, orderIndex: Int) {
        if record.id != row.id {
            record.id = row.id
        }

        if record.orderIndex != orderIndex {
            record.orderIndex = orderIndex
        }

        if record.targetID != row.target.id {
            record.targetID = row.target.id
        }

        if record.targetSetKindRaw != row.target.setKind.rawValue {
            record.targetSetKindRaw = row.target.setKind.rawValue
        }

        if record.targetWeight != row.target.targetWeight {
            record.targetWeight = row.target.targetWeight
        }

        if record.targetRepLower != row.target.repRange.lowerBound {
            record.targetRepLower = row.target.repRange.lowerBound
        }

        if record.targetRepUpper != row.target.repRange.upperBound {
            record.targetRepUpper = row.target.repRange.upperBound
        }

        if record.targetRir != row.target.rir {
            record.targetRir = row.target.rir
        }

        if record.targetRestSeconds != row.target.restSeconds {
            record.targetRestSeconds = row.target.restSeconds
        }

        if record.targetNote != row.target.note {
            record.targetNote = row.target.note
        }

        if record.logID != row.log.id {
            record.logID = row.log.id
        }

        if record.logWeight != row.log.weight {
            record.logWeight = row.log.weight
        }

        if record.logReps != row.log.reps {
            record.logReps = row.log.reps
        }

        if record.logRir != row.log.rir {
            record.logRir = row.log.rir
        }

        if record.logCompletedAt != row.log.completedAt {
            record.logCompletedAt = row.log.completedAt
        }
    }

    private func loadActiveDraftRecords() -> [StoredActiveSession] {
        (try? modelContext.fetch(FetchDescriptor<StoredActiveSession>())) ?? []
    }

    private func loadCompletedSessionRecords() -> [StoredCompletedSession] {
        (try? modelContext.fetch(FetchDescriptor<StoredCompletedSession>())) ?? []
    }

    private func loadLegacyActiveDraftRecords() -> [StoredActiveSessionRecord] {
        (try? modelContext.fetch(FetchDescriptor<StoredActiveSessionRecord>())) ?? []
    }

    private func loadLegacyCompletedSessionRecords() -> [StoredCompletedSessionRecord] {
        (try? modelContext.fetch(FetchDescriptor<StoredCompletedSessionRecord>())) ?? []
    }

    private func encode<Value: Encodable>(_ value: Value) -> Data? {
        try? encoder.encode(value)
    }

    private func decode<Value: Decodable>(_ type: Value.Type, from data: Data) -> Value? {
        try? decoder.decode(Value.self, from: data)
    }

    private func saveContext() {
        guard modelContext.hasChanges else {
            return
        }

        try? modelContext.save()
    }
}
