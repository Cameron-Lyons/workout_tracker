import Foundation

struct SetLog: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var setTargetID: UUID
    var weight: Double?
    var reps: Int?
    var rir: Int?
    var completedAt: Date?

    init(
        id: UUID = UUID(),
        setTargetID: UUID,
        weight: Double? = nil,
        reps: Int? = nil,
        rir: Int? = nil,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.setTargetID = setTargetID
        self.weight = weight
        self.reps = reps
        self.rir = rir
        self.completedAt = completedAt
    }

    var isCompleted: Bool {
        completedAt != nil
    }
}

struct SessionSetRow: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var target: SetTarget
    var log: SetLog

    init(id: UUID = UUID(), target: SetTarget, log: SetLog? = nil) {
        self.id = id
        self.target = target
        self.log = log ?? SetLog(setTargetID: target.id)
    }
}

struct CompletedSetRow: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var setKind: SetKind
    var weight: Double?
    var reps: Int?
    var completedAt: Date?

    init(
        id: UUID = UUID(),
        setKind: SetKind,
        weight: Double? = nil,
        reps: Int? = nil,
        completedAt: Date? = nil
    ) {
        self.id = id
        self.setKind = setKind
        self.weight = weight
        self.reps = reps
        self.completedAt = completedAt
    }

    init(_ row: SessionSetRow) {
        self.init(
            id: row.id,
            setKind: row.target.setKind,
            weight: row.log.weight,
            reps: row.log.reps,
            completedAt: row.log.completedAt
        )
    }

    var isCompleted: Bool {
        completedAt != nil
    }
}

struct SessionBlock: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var exerciseID: UUID
    var exerciseNameSnapshot: String
    var restSeconds: Int
    var supersetGroup: String?
    var progressionRule: ProgressionRule
    var sets: [SessionSetRow]

    init(
        id: UUID = UUID(),
        exerciseID: UUID,
        exerciseNameSnapshot: String,
        restSeconds: Int,
        supersetGroup: String? = nil,
        progressionRule: ProgressionRule,
        sets: [SessionSetRow]
    ) {
        self.id = id
        self.exerciseID = exerciseID
        self.exerciseNameSnapshot = exerciseNameSnapshot
        self.restSeconds = restSeconds
        self.supersetGroup = supersetGroup
        self.progressionRule = progressionRule
        self.sets = sets
    }
}

struct SessionDraft: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var planID: UUID?
    var templateID: UUID
    var templateNameSnapshot: String
    var startedAt: Date
    var lastUpdatedAt: Date
    var blocks: [SessionBlock]
    var restTimerEndsAt: Date?

    init(
        id: UUID = UUID(),
        planID: UUID?,
        templateID: UUID,
        templateNameSnapshot: String,
        startedAt: Date = .now,
        lastUpdatedAt: Date = .now,
        blocks: [SessionBlock],
        restTimerEndsAt: Date? = nil
    ) {
        self.id = id
        self.planID = planID
        self.templateID = templateID
        self.templateNameSnapshot = templateNameSnapshot
        self.startedAt = startedAt
        self.lastUpdatedAt = lastUpdatedAt
        self.blocks = blocks
        self.restTimerEndsAt = restTimerEndsAt
    }
}

struct CompletedSessionBlock: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var exerciseID: UUID
    var exerciseNameSnapshot: String
    var sets: [CompletedSetRow]

    init(
        id: UUID = UUID(),
        exerciseID: UUID,
        exerciseNameSnapshot: String,
        sets: [CompletedSetRow]
    ) {
        self.id = id
        self.exerciseID = exerciseID
        self.exerciseNameSnapshot = exerciseNameSnapshot
        self.sets = sets
    }

    init(
        id: UUID = UUID(),
        exerciseID: UUID,
        exerciseNameSnapshot: String,
        sets: [SessionSetRow]
    ) {
        self.init(
            id: id,
            exerciseID: exerciseID,
            exerciseNameSnapshot: exerciseNameSnapshot,
            sets: sets.map(CompletedSetRow.init)
        )
    }
}

struct CompletedSession: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var planID: UUID?
    var templateID: UUID
    var templateNameSnapshot: String
    var completedAt: Date
    var blocks: [CompletedSessionBlock]

    init(
        id: UUID = UUID(),
        planID: UUID?,
        templateID: UUID,
        templateNameSnapshot: String,
        completedAt: Date = .now,
        blocks: [CompletedSessionBlock]
    ) {
        self.id = id
        self.planID = planID
        self.templateID = templateID
        self.templateNameSnapshot = templateNameSnapshot
        self.completedAt = completedAt
        self.blocks = blocks
    }
}
