import Foundation

struct TemplateExercise: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var exerciseID: UUID
    var exerciseNameSnapshot: String
    var restSeconds: Int
    var supersetGroup: String?
    var progressionRule: ProgressionRule
    var targets: [SetTarget]
    var allowsAutoWarmups: Bool

    init(
        id: UUID = UUID(),
        exerciseID: UUID,
        exerciseNameSnapshot: String,
        restSeconds: Int = TemplateExerciseDefaults.restSeconds,
        supersetGroup: String? = nil,
        progressionRule: ProgressionRule = .manual,
        targets: [SetTarget],
        allowsAutoWarmups: Bool = true
    ) {
        self.id = id
        self.exerciseID = exerciseID
        self.exerciseNameSnapshot = exerciseNameSnapshot
        self.restSeconds = restSeconds
        self.supersetGroup = supersetGroup
        self.progressionRule = progressionRule
        self.targets = targets
        self.allowsAutoWarmups = allowsAutoWarmups
    }
}

struct WorkoutTemplate: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var name: String
    var note: String
    var scheduledWeekdays: [Weekday]
    var exercises: [TemplateExercise]
    var lastStartedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, name, note, scheduledWeekdays, exercises, lastStartedAt
        case legacyBlocks = "blocks"
    }

    init(
        id: UUID = UUID(),
        name: String,
        note: String = "",
        scheduledWeekdays: [Weekday] = [],
        exercises: [TemplateExercise],
        lastStartedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.note = note
        self.scheduledWeekdays = scheduledWeekdays
        self.exercises = exercises
        self.lastStartedAt = lastStartedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
        scheduledWeekdays = try container.decodeIfPresent([Weekday].self, forKey: .scheduledWeekdays) ?? []
        if container.contains(.exercises) {
            exercises = try container.decode([TemplateExercise].self, forKey: .exercises)
        } else {
            exercises = try container.decode([TemplateExercise].self, forKey: .legacyBlocks)
        }
        lastStartedAt = try container.decodeIfPresent(Date.self, forKey: .lastStartedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(note, forKey: .note)
        try container.encode(scheduledWeekdays, forKey: .scheduledWeekdays)
        try container.encode(exercises, forKey: .exercises)
        try container.encodeIfPresent(lastStartedAt, forKey: .lastStartedAt)
    }
}

struct Plan: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var name: String
    var createdAt: Date
    var pinnedTemplateID: UUID?
    var templates: [WorkoutTemplate]

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = .now,
        pinnedTemplateID: UUID? = nil,
        templates: [WorkoutTemplate]
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.pinnedTemplateID = pinnedTemplateID
        self.templates = templates
    }
}

struct TemplateSummary: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var name: String
    var note: String
    var scheduledWeekdays: [Weekday]
    var lastStartedAt: Date?
    var exerciseIDs: [UUID]

    enum CodingKeys: String, CodingKey {
        case id, name, note, scheduledWeekdays, lastStartedAt, exerciseIDs
        case legacyBlockExerciseIDs = "blockExerciseIDs"
    }

    init(
        id: UUID,
        name: String,
        note: String,
        scheduledWeekdays: [Weekday],
        lastStartedAt: Date?,
        exerciseIDs: [UUID]
    ) {
        self.id = id
        self.name = name
        self.note = note
        self.scheduledWeekdays = scheduledWeekdays
        self.lastStartedAt = lastStartedAt
        self.exerciseIDs = exerciseIDs
    }

    init(template: WorkoutTemplate) {
        self.init(
            id: template.id,
            name: template.name,
            note: template.note,
            scheduledWeekdays: template.scheduledWeekdays,
            lastStartedAt: template.lastStartedAt,
            exerciseIDs: template.exercises.map(\.exerciseID)
        )
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
        scheduledWeekdays = try container.decodeIfPresent([Weekday].self, forKey: .scheduledWeekdays) ?? []
        lastStartedAt = try container.decodeIfPresent(Date.self, forKey: .lastStartedAt)
        if container.contains(.exerciseIDs) {
            exerciseIDs = try container.decode([UUID].self, forKey: .exerciseIDs)
        } else {
            exerciseIDs = try container.decode([UUID].self, forKey: .legacyBlockExerciseIDs)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(note, forKey: .note)
        try container.encode(scheduledWeekdays, forKey: .scheduledWeekdays)
        try container.encodeIfPresent(lastStartedAt, forKey: .lastStartedAt)
        try container.encode(exerciseIDs, forKey: .exerciseIDs)
    }
}

struct PlanSummary: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var name: String
    var createdAt: Date
    var pinnedTemplateID: UUID?
    var templates: [TemplateSummary]

    init(
        id: UUID,
        name: String,
        createdAt: Date,
        pinnedTemplateID: UUID?,
        templates: [TemplateSummary]
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.pinnedTemplateID = pinnedTemplateID
        self.templates = templates
    }

    init(plan: Plan) {
        self.init(
            id: plan.id,
            name: plan.name,
            createdAt: plan.createdAt,
            pinnedTemplateID: plan.pinnedTemplateID,
            templates: plan.templates.map(TemplateSummary.init)
        )
    }
}
