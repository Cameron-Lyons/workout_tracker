import Foundation
import SwiftData

final class SessionRepository: RepositoryBase {
    override init(modelContext: ModelContext) {
        super.init(modelContext: modelContext)
    }

    func loadActiveDraft() -> SessionDraft? {
        let descriptor = FetchDescriptor<StoredActiveSession>(sortBy: [SortDescriptor(\StoredActiveSession.lastUpdatedAt)])
        let records = (try? modelContext.fetch(descriptor)) ?? []
        return records.last.flatMap(activeDraft(from:))
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

        applyActiveDraft(draft, to: record)
        syncActiveBlocks(of: record, with: draft.blocks)
        return saveContext("active draft")
    }

    func loadCompletedSessions() -> [CompletedSession] {
        let descriptor = FetchDescriptor<StoredCompletedSession>(
            sortBy: [SortDescriptor(\StoredCompletedSession.completedAt)]
        )
        let records = (try? modelContext.fetch(descriptor)) ?? []
        return records.map(completedSession(from:))
    }

    @discardableResult
    func persistCompletedSessionAndClearActiveDraft(_ session: CompletedSession) -> Bool {
        let descriptor = FetchDescriptor<StoredCompletedSession>(
            predicate: #Predicate<StoredCompletedSession> { $0.id == session.id }
        )
        let record = (try? modelContext.fetch(descriptor))?.first ?? makeCompletedSessionRecord(from: session)
        if record.modelContext == nil {
            modelContext.insert(record)
        }

        applyCompletedSession(session, to: record)
        syncCompletedBlocks(of: record, with: session.blocks)
        loadActiveDraftRecords().forEach(modelContext.delete)
        return saveContext("completed session")
    }

    @discardableResult
    func deleteEverything() -> Bool {
        loadActiveDraftRecords().forEach(modelContext.delete)
        loadCompletedSessionRecords().forEach(modelContext.delete)
        return saveContext("sessions reset")
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
            blocks: orderedRecordsIfNeeded(record.blocks, by: \.orderIndex)
                .compactMap(activeBlock(from:)),
            restTimerEndsAt: record.restTimerEndsAt
        )
    }

    private func activeBlock(from record: StoredActiveSessionBlock) -> SessionBlock? {
        guard let progressionRule = decode(
            ProgressionRule.self,
            from: record.progressionRuleData,
            operation: "active session block progression rule for \(record.id.uuidString)"
        ) else {
            return nil
        }

        return SessionBlock(
            id: record.id,
            exerciseID: record.exerciseID,
            exerciseNameSnapshot: record.exerciseNameSnapshot,
            blockNote: record.blockNote,
            restSeconds: record.restSeconds,
            supersetGroup: record.supersetGroup,
            progressionRule: progressionRule,
            sets: orderedRecordsIfNeeded(record.rows, by: \.orderIndex).map(activeSessionRow(from:))
        )
    }

    private func activeSessionRow(from record: StoredActiveSessionRow) -> SessionSetRow {
        SessionSetRow(
            id: record.id,
            target: SetTarget(
                id: record.targetID,
                setKind: SetKind(rawValue: record.targetSetKindRaw) ?? .working,
                targetWeight: record.targetWeight,
                repRange: RepRange(record.targetRepLower, record.targetRepUpper),
                rir: nil,
                restSeconds: record.targetRestSeconds,
                note: record.targetNote
            ),
            log: SetLog(
                id: record.id,
                setTargetID: record.targetID,
                weight: record.logWeight,
                reps: record.logReps,
                rir: nil,
                completedAt: record.logCompletedAt
            )
        )
    }

    private func completedSession(from record: StoredCompletedSession) -> CompletedSession {
        CompletedSession(
            id: record.id,
            planID: record.planID,
            templateID: record.templateID,
            templateNameSnapshot: record.templateNameSnapshot,
            completedAt: record.completedAt,
            blocks: orderedRecordsIfNeeded(record.blocks, by: \.orderIndex).map(completedBlock(from:))
        )
    }

    private func completedBlock(from record: StoredCompletedSessionBlock) -> CompletedSessionBlock {
        CompletedSessionBlock(
            id: record.id,
            exerciseID: record.exerciseID,
            exerciseNameSnapshot: record.exerciseNameSnapshot,
            sets: orderedRecordsIfNeeded(record.rows, by: \.orderIndex).map(completedSessionRow(from:))
        )
    }

    private func completedSessionRow(from record: StoredCompletedSessionRow) -> CompletedSetRow {
        CompletedSetRow(
            id: record.id,
            setKind: SetKind(rawValue: record.targetSetKindRaw) ?? .working,
            weight: record.logWeight,
            reps: record.logReps,
            completedAt: record.logCompletedAt
        )
    }

    private func applyActiveDraft(_ draft: SessionDraft, to record: StoredActiveSession) {
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
        orderedRecords.reserveCapacity(blocks.count)

        for (index, block) in blocks.enumerated() {
            let record = existingByID.removeValue(forKey: block.id) ?? makeActiveBlockRecord(from: block, orderIndex: index)
            if record.session?.id != sessionRecord.id {
                record.session = sessionRecord
            }

            applyActiveBlock(block, to: record, orderIndex: index)
            syncActiveRows(of: record, with: block.sets)
            orderedRecords.append(record)
        }

        existingByID.values.forEach(modelContext.delete)
        if sameRecordOrder(sessionRecord.blocks, orderedRecords, id: \.id) == false {
            sessionRecord.blocks = orderedRecords
        }
    }

    private func makeActiveBlockRecord(from block: SessionBlock, orderIndex: Int) -> StoredActiveSessionBlock {
        let record = StoredActiveSessionBlock(
            id: block.id,
            orderIndex: orderIndex,
            exerciseID: block.exerciseID,
            exerciseNameSnapshot: block.exerciseNameSnapshot,
            blockNote: block.blockNote,
            restSeconds: block.restSeconds,
            supersetGroup: block.supersetGroup,
            progressionRuleData: encode(
                block.progressionRule,
                operation: "active session block progression rule for \(block.id.uuidString)"
            ) ?? Data()
        )
        modelContext.insert(record)
        return record
    }

    private func applyActiveBlock(_ block: SessionBlock, to record: StoredActiveSessionBlock, orderIndex: Int) {
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

        if let progressionRuleData = encode(
            block.progressionRule,
            operation: "active session block progression rule for \(block.id.uuidString)"
        ), record.progressionRuleData != progressionRuleData
        {
            record.progressionRuleData = progressionRuleData
        }
    }

    private func syncActiveRows(of blockRecord: StoredActiveSessionBlock, with rows: [SessionSetRow]) {
        var existingByID = Dictionary(uniqueKeysWithValues: blockRecord.rows.map { ($0.id, $0) })
        var orderedRecords: [StoredActiveSessionRow] = []
        orderedRecords.reserveCapacity(rows.count)

        for (index, row) in rows.enumerated() {
            let record = existingByID.removeValue(forKey: row.id) ?? makeActiveRowRecord(from: row, orderIndex: index)
            if record.block?.id != blockRecord.id {
                record.block = blockRecord
            }

            applyActiveRow(row, to: record, orderIndex: index)
            orderedRecords.append(record)
        }

        existingByID.values.forEach(modelContext.delete)
        if sameRecordOrder(blockRecord.rows, orderedRecords, id: \.id) == false {
            blockRecord.rows = orderedRecords
        }
    }

    private func makeActiveRowRecord(from row: SessionSetRow, orderIndex: Int) -> StoredActiveSessionRow {
        let record = StoredActiveSessionRow(
            id: row.id,
            orderIndex: orderIndex,
            targetID: row.target.id,
            targetSetKindRaw: row.target.setKind.rawValue,
            targetWeight: row.target.targetWeight,
            targetRepLower: row.target.repRange.lowerBound,
            targetRepUpper: row.target.repRange.upperBound,
            targetRestSeconds: row.target.restSeconds,
            targetNote: row.target.note,
            logWeight: row.log.weight,
            logReps: row.log.reps,
            logCompletedAt: row.log.completedAt
        )
        modelContext.insert(record)
        return record
    }

    private func applyActiveRow(_ row: SessionSetRow, to record: StoredActiveSessionRow, orderIndex: Int) {
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

        if record.targetRestSeconds != row.target.restSeconds {
            record.targetRestSeconds = row.target.restSeconds
        }

        if record.targetNote != row.target.note {
            record.targetNote = row.target.note
        }

        if record.logWeight != row.log.weight {
            record.logWeight = row.log.weight
        }

        if record.logReps != row.log.reps {
            record.logReps = row.log.reps
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
            completedAt: session.completedAt
        )
    }

    private func applyCompletedSession(_ session: CompletedSession, to record: StoredCompletedSession) {
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
    }

    private func syncCompletedBlocks(of sessionRecord: StoredCompletedSession, with blocks: [CompletedSessionBlock]) {
        var existingByID = Dictionary(uniqueKeysWithValues: sessionRecord.blocks.map { ($0.id, $0) })
        var orderedRecords: [StoredCompletedSessionBlock] = []
        orderedRecords.reserveCapacity(blocks.count)

        for (index, block) in blocks.enumerated() {
            let record = existingByID.removeValue(forKey: block.id) ?? makeCompletedBlockRecord(from: block, orderIndex: index)
            if record.session?.id != sessionRecord.id {
                record.session = sessionRecord
            }

            applyCompletedBlock(block, to: record, orderIndex: index)
            syncCompletedRows(of: record, with: block.sets)
            orderedRecords.append(record)
        }

        existingByID.values.forEach(modelContext.delete)
        if sameRecordOrder(sessionRecord.blocks, orderedRecords, id: \.id) == false {
            sessionRecord.blocks = orderedRecords
        }
    }

    private func makeCompletedBlockRecord(from block: CompletedSessionBlock, orderIndex: Int) -> StoredCompletedSessionBlock {
        let record = StoredCompletedSessionBlock(
            id: block.id,
            orderIndex: orderIndex,
            exerciseID: block.exerciseID,
            exerciseNameSnapshot: block.exerciseNameSnapshot
        )
        modelContext.insert(record)
        return record
    }

    private func applyCompletedBlock(_ block: CompletedSessionBlock, to record: StoredCompletedSessionBlock, orderIndex: Int) {
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
    }

    private func syncCompletedRows(of blockRecord: StoredCompletedSessionBlock, with rows: [CompletedSetRow]) {
        var existingByID = Dictionary(uniqueKeysWithValues: blockRecord.rows.map { ($0.id, $0) })
        var orderedRecords: [StoredCompletedSessionRow] = []
        orderedRecords.reserveCapacity(rows.count)

        for (index, row) in rows.enumerated() {
            let record = existingByID.removeValue(forKey: row.id) ?? makeCompletedRowRecord(from: row, orderIndex: index)
            if record.block?.id != blockRecord.id {
                record.block = blockRecord
            }

            applyCompletedRow(row, to: record, orderIndex: index)
            orderedRecords.append(record)
        }

        existingByID.values.forEach(modelContext.delete)
        if sameRecordOrder(blockRecord.rows, orderedRecords, id: \.id) == false {
            blockRecord.rows = orderedRecords
        }
    }

    private func makeCompletedRowRecord(from row: CompletedSetRow, orderIndex: Int) -> StoredCompletedSessionRow {
        let record = StoredCompletedSessionRow(
            id: row.id,
            orderIndex: orderIndex,
            targetSetKindRaw: row.setKind.rawValue,
            logWeight: row.weight,
            logReps: row.reps,
            logCompletedAt: row.completedAt
        )
        modelContext.insert(record)
        return record
    }

    private func applyCompletedRow(_ row: CompletedSetRow, to record: StoredCompletedSessionRow, orderIndex: Int) {
        if record.id != row.id {
            record.id = row.id
        }

        if record.orderIndex != orderIndex {
            record.orderIndex = orderIndex
        }

        if record.targetSetKindRaw != row.setKind.rawValue {
            record.targetSetKindRaw = row.setKind.rawValue
        }

        if record.logWeight != row.weight {
            record.logWeight = row.weight
        }

        if record.logReps != row.reps {
            record.logReps = row.reps
        }

        if record.logCompletedAt != row.completedAt {
            record.logCompletedAt = row.completedAt
        }
    }

    private func loadActiveDraftRecords() -> [StoredActiveSession] {
        (try? modelContext.fetch(FetchDescriptor<StoredActiveSession>())) ?? []
    }

    private func loadCompletedSessionRecords() -> [StoredCompletedSession] {
        (try? modelContext.fetch(FetchDescriptor<StoredCompletedSession>())) ?? []
    }

    private func sameRecordOrder<Record>(
        _ existing: [Record],
        _ updated: [Record],
        id: KeyPath<Record, UUID>
    ) -> Bool {
        existing.count == updated.count
            && zip(existing, updated).allSatisfy { lhs, rhs in
                lhs[keyPath: id] == rhs[keyPath: id]
            }
    }
}
