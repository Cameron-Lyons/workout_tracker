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

        apply(draft, to: record)
        syncActiveBlocks(of: record, with: draft.blocks)
        return saveContext("active draft")
    }

    func loadCompletedSessions() -> [CompletedSession] {
        let descriptor = FetchDescriptor<StoredCompletedSession>(
            sortBy: [SortDescriptor(\StoredCompletedSession.completedAt)]
        )
        let records = (try? modelContext.fetch(descriptor)) ?? []
        return records.compactMap(completedSession(from:))
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

        apply(session, to: record)
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
            blocks: record.blocks
                .sorted(by: { $0.orderIndex < $1.orderIndex })
                .compactMap(activeBlock(from:)),
            restTimerEndsAt: record.restTimerEndsAt
        )
    }

    private func activeBlock(from record: StoredActiveSessionBlock) -> SessionBlock? {
        SessionBlock(
            id: record.id,
            exerciseID: record.exerciseID,
            exerciseNameSnapshot: record.exerciseNameSnapshot,
            blockNote: record.blockNote,
            restSeconds: record.restSeconds,
            supersetGroup: record.supersetGroup,
            progressionRule: decode(ProgressionRule.self, from: record.progressionRuleData) ?? .manual,
            sets: orderedSessionRows(from: record.rows)
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
            sets: orderedSessionRows(from: record.rows)
        )
    }

    private func apply(_ draft: SessionDraft, to record: StoredActiveSession) {
        applySessionFields(
            id: draft.id,
            planID: draft.planID,
            templateID: draft.templateID,
            templateNameSnapshot: draft.templateNameSnapshot,
            startedAt: draft.startedAt,
            notes: draft.notes,
            to: record
        )

        if record.lastUpdatedAt != draft.lastUpdatedAt {
            record.lastUpdatedAt = draft.lastUpdatedAt
        }

        if record.restTimerEndsAt != draft.restTimerEndsAt {
            record.restTimerEndsAt = draft.restTimerEndsAt
        }
    }

    private func syncActiveBlocks(of sessionRecord: StoredActiveSession, with blocks: [SessionBlock]) {
        syncBlocks(
            existingBlocks: sessionRecord.blocks,
            with: blocks,
            create: { block, index in
                let snapshot = StoredSessionBlockSnapshot(
                    block: block,
                    orderIndex: index,
                    progressionRuleData: encode(block.progressionRule) ?? Data()
                )
                let record = StoredActiveSessionBlock(
                    id: snapshot.id,
                    orderIndex: snapshot.orderIndex,
                    exerciseID: snapshot.exerciseID,
                    exerciseNameSnapshot: snapshot.exerciseNameSnapshot,
                    blockNote: snapshot.blockNote,
                    restSeconds: snapshot.restSeconds,
                    supersetGroup: snapshot.supersetGroup,
                    progressionRuleData: snapshot.progressionRuleData
                )
                modelContext.insert(record)
                return record
            },
            attach: { record in
                if record.session?.id != sessionRecord.id {
                    record.session = sessionRecord
                }
            },
            syncRows: { record, rows in
                syncActiveRows(of: record, with: rows)
            },
            assign: { orderedRecords in
                if sameRecordOrder(sessionRecord.blocks, orderedRecords, id: \.id) == false {
                    sessionRecord.blocks = orderedRecords
                }
            }
        )
    }

    private func syncActiveRows(of blockRecord: StoredActiveSessionBlock, with rows: [SessionSetRow]) {
        syncRows(
            existingRows: blockRecord.rows,
            with: rows,
            create: { row, index in
                let snapshot = StoredSessionRowSnapshot(row: row, orderIndex: index)
                let record = StoredActiveSessionRow(
                    id: snapshot.id,
                    orderIndex: snapshot.orderIndex,
                    targetID: snapshot.targetID,
                    targetSetKindRaw: snapshot.targetSetKindRaw,
                    targetWeight: snapshot.targetWeight,
                    targetRepLower: snapshot.targetRepLower,
                    targetRepUpper: snapshot.targetRepUpper,
                    targetRir: snapshot.targetRir,
                    targetRestSeconds: snapshot.targetRestSeconds,
                    targetNote: snapshot.targetNote,
                    logID: snapshot.logID,
                    logWeight: snapshot.logWeight,
                    logReps: snapshot.logReps,
                    logRir: snapshot.logRir,
                    logCompletedAt: snapshot.logCompletedAt
                )
                modelContext.insert(record)
                return record
            },
            attach: { record in
                if record.block?.id != blockRecord.id {
                    record.block = blockRecord
                }
            },
            assign: { orderedRecords in
                if sameRecordOrder(blockRecord.rows, orderedRecords, id: \.id) == false {
                    blockRecord.rows = orderedRecords
                }
            }
        )
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
        applySessionFields(
            id: session.id,
            planID: session.planID,
            templateID: session.templateID,
            templateNameSnapshot: session.templateNameSnapshot,
            startedAt: session.startedAt,
            notes: session.notes,
            to: record
        )

        if record.completedAt != session.completedAt {
            record.completedAt = session.completedAt
        }
    }

    private func syncCompletedBlocks(of sessionRecord: StoredCompletedSession, with blocks: [CompletedSessionBlock]) {
        syncBlocks(
            existingBlocks: sessionRecord.blocks,
            with: blocks,
            create: { block, index in
                let snapshot = StoredSessionBlockSnapshot(
                    block: block,
                    orderIndex: index,
                    progressionRuleData: encode(block.progressionRule) ?? Data()
                )
                let record = StoredCompletedSessionBlock(
                    id: snapshot.id,
                    orderIndex: snapshot.orderIndex,
                    exerciseID: snapshot.exerciseID,
                    exerciseNameSnapshot: snapshot.exerciseNameSnapshot,
                    blockNote: snapshot.blockNote,
                    restSeconds: snapshot.restSeconds,
                    supersetGroup: snapshot.supersetGroup,
                    progressionRuleData: snapshot.progressionRuleData
                )
                modelContext.insert(record)
                return record
            },
            attach: { record in
                if record.session?.id != sessionRecord.id {
                    record.session = sessionRecord
                }
            },
            syncRows: { record, rows in
                syncCompletedRows(of: record, with: rows)
            },
            assign: { orderedRecords in
                if sameRecordOrder(sessionRecord.blocks, orderedRecords, id: \.id) == false {
                    sessionRecord.blocks = orderedRecords
                }
            }
        )
    }

    private func syncCompletedRows(of blockRecord: StoredCompletedSessionBlock, with rows: [SessionSetRow]) {
        syncRows(
            existingRows: blockRecord.rows,
            with: rows,
            create: { row, index in
                let snapshot = StoredSessionRowSnapshot(row: row, orderIndex: index)
                let record = StoredCompletedSessionRow(
                    id: snapshot.id,
                    orderIndex: snapshot.orderIndex,
                    targetID: snapshot.targetID,
                    targetSetKindRaw: snapshot.targetSetKindRaw,
                    targetWeight: snapshot.targetWeight,
                    targetRepLower: snapshot.targetRepLower,
                    targetRepUpper: snapshot.targetRepUpper,
                    targetRir: snapshot.targetRir,
                    targetRestSeconds: snapshot.targetRestSeconds,
                    targetNote: snapshot.targetNote,
                    logID: snapshot.logID,
                    logWeight: snapshot.logWeight,
                    logReps: snapshot.logReps,
                    logRir: snapshot.logRir,
                    logCompletedAt: snapshot.logCompletedAt
                )
                modelContext.insert(record)
                return record
            },
            attach: { record in
                if record.block?.id != blockRecord.id {
                    record.block = blockRecord
                }
            },
            assign: { orderedRecords in
                if sameRecordOrder(blockRecord.rows, orderedRecords, id: \.id) == false {
                    blockRecord.rows = orderedRecords
                }
            }
        )
    }

    private func orderedSessionRows<Record: StoredSessionRowRecord>(from records: [Record]) -> [SessionSetRow] {
        records
            .sorted(by: { $0.orderIndex < $1.orderIndex })
            .map(sessionSetRow(from:))
    }

    private func sessionSetRow<Record: StoredSessionRowRecord>(from record: Record) -> SessionSetRow {
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

    private func applySessionFields<Record: StoredSessionRecord>(
        id: UUID,
        planID: UUID?,
        templateID: UUID,
        templateNameSnapshot: String,
        startedAt: Date,
        notes: String,
        to record: Record
    ) {
        if record.id != id {
            record.id = id
        }

        if record.planID != planID {
            record.planID = planID
        }

        if record.templateID != templateID {
            record.templateID = templateID
        }

        if record.templateNameSnapshot != templateNameSnapshot {
            record.templateNameSnapshot = templateNameSnapshot
        }

        if record.startedAt != startedAt {
            record.startedAt = startedAt
        }

        if record.notes != notes {
            record.notes = notes
        }
    }

    private func syncBlocks<Record: StoredSessionBlockRecord, Block: SessionBlockSnapshot>(
        existingBlocks: [Record],
        with blocks: [Block],
        create: (Block, Int) -> Record,
        attach: (Record) -> Void,
        syncRows: (Record, [SessionSetRow]) -> Void,
        assign: ([Record]) -> Void
    ) {
        var existingByID = Dictionary(uniqueKeysWithValues: existingBlocks.map { ($0.id, $0) })
        var orderedRecords: [Record] = []
        orderedRecords.reserveCapacity(blocks.count)

        for (index, block) in blocks.enumerated() {
            let record = existingByID.removeValue(forKey: block.id) ?? create(block, index)
            attach(record)
            applyBlockFields(block, to: record, orderIndex: index)
            syncRows(record, block.sets)
            orderedRecords.append(record)
        }

        existingByID.values.forEach(modelContext.delete)
        assign(orderedRecords)
    }

    private func applyBlockFields<Record: StoredSessionBlockRecord, Block: SessionBlockSnapshot>(
        _ block: Block,
        to record: Record,
        orderIndex: Int
    ) {
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

    private func syncRows<Record: StoredSessionRowRecord>(
        existingRows: [Record],
        with rows: [SessionSetRow],
        create: (SessionSetRow, Int) -> Record,
        attach: (Record) -> Void,
        assign: ([Record]) -> Void
    ) {
        var existingByID = Dictionary(uniqueKeysWithValues: existingRows.map { ($0.id, $0) })
        var orderedRecords: [Record] = []
        orderedRecords.reserveCapacity(rows.count)

        for (index, row) in rows.enumerated() {
            let record = existingByID.removeValue(forKey: row.id) ?? create(row, index)
            attach(record)
            apply(row, to: record, orderIndex: index)
            orderedRecords.append(record)
        }

        existingByID.values.forEach(modelContext.delete)
        assign(orderedRecords)
    }

    private func apply<Record: StoredSessionRowRecord>(
        _ row: SessionSetRow,
        to record: Record,
        orderIndex: Int
    ) {
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

private protocol StoredSessionRecord: AnyObject {
    associatedtype BlockRecord: StoredSessionBlockRecord

    var id: UUID { get set }
    var planID: UUID? { get set }
    var templateID: UUID { get set }
    var templateNameSnapshot: String { get set }
    var startedAt: Date { get set }
    var notes: String { get set }
    var blocks: [BlockRecord] { get set }
}

private protocol StoredSessionBlockRecord: PersistentModel {
    associatedtype RowRecord: StoredSessionRowRecord

    var id: UUID { get set }
    var orderIndex: Int { get set }
    var exerciseID: UUID { get set }
    var exerciseNameSnapshot: String { get set }
    var blockNote: String { get set }
    var restSeconds: Int { get set }
    var supersetGroup: String? { get set }
    var progressionRuleData: Data { get set }
    var rows: [RowRecord] { get set }
}

private protocol StoredSessionRowRecord: PersistentModel {
    var id: UUID { get set }
    var orderIndex: Int { get set }
    var targetID: UUID { get set }
    var targetSetKindRaw: String { get set }
    var targetWeight: Double? { get set }
    var targetRepLower: Int { get set }
    var targetRepUpper: Int { get set }
    var targetRir: Int? { get set }
    var targetRestSeconds: Int? { get set }
    var targetNote: String? { get set }
    var logID: UUID { get set }
    var logWeight: Double? { get set }
    var logReps: Int? { get set }
    var logRir: Int? { get set }
    var logCompletedAt: Date? { get set }
}

private protocol SessionBlockSnapshot {
    var id: UUID { get }
    var exerciseID: UUID { get }
    var exerciseNameSnapshot: String { get }
    var blockNote: String { get }
    var restSeconds: Int { get }
    var supersetGroup: String? { get }
    var progressionRule: ProgressionRule { get }
    var sets: [SessionSetRow] { get }
}

private struct StoredSessionBlockSnapshot {
    let id: UUID
    let orderIndex: Int
    let exerciseID: UUID
    let exerciseNameSnapshot: String
    let blockNote: String
    let restSeconds: Int
    let supersetGroup: String?
    let progressionRuleData: Data

    init<Block: SessionBlockSnapshot>(block: Block, orderIndex: Int, progressionRuleData: Data) {
        self.id = block.id
        self.orderIndex = orderIndex
        self.exerciseID = block.exerciseID
        self.exerciseNameSnapshot = block.exerciseNameSnapshot
        self.blockNote = block.blockNote
        self.restSeconds = block.restSeconds
        self.supersetGroup = block.supersetGroup
        self.progressionRuleData = progressionRuleData
    }
}

private struct StoredSessionRowSnapshot {
    let id: UUID
    let orderIndex: Int
    let targetID: UUID
    let targetSetKindRaw: String
    let targetWeight: Double?
    let targetRepLower: Int
    let targetRepUpper: Int
    let targetRir: Int?
    let targetRestSeconds: Int?
    let targetNote: String?
    let logID: UUID
    let logWeight: Double?
    let logReps: Int?
    let logRir: Int?
    let logCompletedAt: Date?

    init(row: SessionSetRow, orderIndex: Int) {
        id = row.id
        self.orderIndex = orderIndex
        targetID = row.target.id
        targetSetKindRaw = row.target.setKind.rawValue
        targetWeight = row.target.targetWeight
        targetRepLower = row.target.repRange.lowerBound
        targetRepUpper = row.target.repRange.upperBound
        targetRir = row.target.rir
        targetRestSeconds = row.target.restSeconds
        targetNote = row.target.note
        logID = row.log.id
        logWeight = row.log.weight
        logReps = row.log.reps
        logRir = row.log.rir
        logCompletedAt = row.log.completedAt
    }
}

extension StoredActiveSession: StoredSessionRecord {}
extension StoredCompletedSession: StoredSessionRecord {}

extension StoredActiveSessionBlock: StoredSessionBlockRecord {}
extension StoredCompletedSessionBlock: StoredSessionBlockRecord {}

extension StoredActiveSessionRow: StoredSessionRowRecord {}
extension StoredCompletedSessionRow: StoredSessionRowRecord {}

extension SessionBlock: SessionBlockSnapshot {}
extension CompletedSessionBlock: SessionBlockSnapshot {}
