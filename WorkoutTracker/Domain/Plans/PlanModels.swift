import Foundation

struct ExerciseBlock: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var exerciseID: UUID
    var exerciseNameSnapshot: String
    var blockNote: String
    var restSeconds: Int
    var supersetGroup: String?
    var progressionRule: ProgressionRule
    var targets: [SetTarget]
    var allowsAutoWarmups: Bool

    init(
        id: UUID = UUID(),
        exerciseID: UUID,
        exerciseNameSnapshot: String,
        blockNote: String = "",
        restSeconds: Int = ExerciseBlockDefaults.restSeconds,
        supersetGroup: String? = nil,
        progressionRule: ProgressionRule = .manual,
        targets: [SetTarget],
        allowsAutoWarmups: Bool = true
    ) {
        self.id = id
        self.exerciseID = exerciseID
        self.exerciseNameSnapshot = exerciseNameSnapshot
        self.blockNote = blockNote
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
    var blocks: [ExerciseBlock]
    var lastStartedAt: Date?

    init(
        id: UUID = UUID(),
        name: String,
        note: String = "",
        scheduledWeekdays: [Weekday] = [],
        blocks: [ExerciseBlock],
        lastStartedAt: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.note = note
        self.scheduledWeekdays = scheduledWeekdays
        self.blocks = blocks
        self.lastStartedAt = lastStartedAt
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
    var scheduledWeekdays: [Weekday]
    var lastStartedAt: Date?
    var blockExerciseIDs: [UUID]

    init(
        id: UUID,
        name: String,
        scheduledWeekdays: [Weekday],
        lastStartedAt: Date?,
        blockExerciseIDs: [UUID]
    ) {
        self.id = id
        self.name = name
        self.scheduledWeekdays = scheduledWeekdays
        self.lastStartedAt = lastStartedAt
        self.blockExerciseIDs = blockExerciseIDs
    }

    init(template: WorkoutTemplate) {
        self.init(
            id: template.id,
            name: template.name,
            scheduledWeekdays: template.scheduledWeekdays,
            lastStartedAt: template.lastStartedAt,
            blockExerciseIDs: template.blocks.map(\.exerciseID)
        )
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
