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

struct SessionExercise: Identifiable, Codable, Equatable, Sendable {
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
    var exercises: [SessionExercise]
    var restTimerEndsAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, planID, templateID, templateNameSnapshot, startedAt, lastUpdatedAt, exercises, restTimerEndsAt
        case legacyBlocks = "blocks"
    }

    init(
        id: UUID = UUID(),
        planID: UUID?,
        templateID: UUID,
        templateNameSnapshot: String,
        startedAt: Date = .now,
        lastUpdatedAt: Date = .now,
        exercises: [SessionExercise],
        restTimerEndsAt: Date? = nil
    ) {
        self.id = id
        self.planID = planID
        self.templateID = templateID
        self.templateNameSnapshot = templateNameSnapshot
        self.startedAt = startedAt
        self.lastUpdatedAt = lastUpdatedAt
        self.exercises = exercises
        self.restTimerEndsAt = restTimerEndsAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        planID = try container.decodeIfPresent(UUID.self, forKey: .planID)
        templateID = try container.decode(UUID.self, forKey: .templateID)
        templateNameSnapshot = try container.decode(String.self, forKey: .templateNameSnapshot)
        startedAt = try container.decode(Date.self, forKey: .startedAt)
        lastUpdatedAt = try container.decode(Date.self, forKey: .lastUpdatedAt)
        if container.contains(.exercises) {
            exercises = try container.decode([SessionExercise].self, forKey: .exercises)
        } else {
            exercises = try container.decode([SessionExercise].self, forKey: .legacyBlocks)
        }
        restTimerEndsAt = try container.decodeIfPresent(Date.self, forKey: .restTimerEndsAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(planID, forKey: .planID)
        try container.encode(templateID, forKey: .templateID)
        try container.encode(templateNameSnapshot, forKey: .templateNameSnapshot)
        try container.encode(startedAt, forKey: .startedAt)
        try container.encode(lastUpdatedAt, forKey: .lastUpdatedAt)
        try container.encode(exercises, forKey: .exercises)
        try container.encodeIfPresent(restTimerEndsAt, forKey: .restTimerEndsAt)
    }
}

struct CompletedSessionExercise: Identifiable, Codable, Equatable, Sendable {
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
    var exercises: [CompletedSessionExercise]

    enum CodingKeys: String, CodingKey {
        case id, planID, templateID, templateNameSnapshot, completedAt, exercises
        case legacyBlocks = "blocks"
    }

    init(
        id: UUID = UUID(),
        planID: UUID?,
        templateID: UUID,
        templateNameSnapshot: String,
        completedAt: Date = .now,
        exercises: [CompletedSessionExercise]
    ) {
        self.id = id
        self.planID = planID
        self.templateID = templateID
        self.templateNameSnapshot = templateNameSnapshot
        self.completedAt = completedAt
        self.exercises = exercises
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        planID = try container.decodeIfPresent(UUID.self, forKey: .planID)
        templateID = try container.decode(UUID.self, forKey: .templateID)
        templateNameSnapshot = try container.decode(String.self, forKey: .templateNameSnapshot)
        completedAt = try container.decode(Date.self, forKey: .completedAt)
        if container.contains(.exercises) {
            exercises = try container.decode([CompletedSessionExercise].self, forKey: .exercises)
        } else {
            exercises = try container.decode([CompletedSessionExercise].self, forKey: .legacyBlocks)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(planID, forKey: .planID)
        try container.encode(templateID, forKey: .templateID)
        try container.encode(templateNameSnapshot, forKey: .templateNameSnapshot)
        try container.encode(completedAt, forKey: .completedAt)
        try container.encode(exercises, forKey: .exercises)
    }
}
