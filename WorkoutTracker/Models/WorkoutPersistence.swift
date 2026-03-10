import Foundation
import SwiftData

// Legacy v1/v1.5 models remain registered so older stores can be opened and reset.
@Model
final class StoredRoutine {
    @Attribute(.unique) var id: UUID
    var name: String
    var orderIndex: Int
    var programKindRaw: String?
    var programStep: Int?
    var programCycle: Int?
    @Relationship(deleteRule: .cascade, inverse: \StoredExercise.routine) var exercises: [StoredExercise]

    init(
        id: UUID,
        name: String,
        orderIndex: Int,
        programKindRaw: String?,
        programStep: Int?,
        programCycle: Int?
    ) {
        self.id = id
        self.name = name
        self.orderIndex = orderIndex
        self.programKindRaw = programKindRaw
        self.programStep = programStep
        self.programCycle = programCycle
        exercises = []
    }
}

@Model
final class StoredExercise {
    @Attribute(.unique) var id: UUID
    var name: String
    var trainingMax: Double?
    var orderIndex: Int
    var routine: StoredRoutine?

    init(
        id: UUID,
        name: String,
        trainingMax: Double?,
        orderIndex: Int
    ) {
        self.id = id
        self.name = name
        self.trainingMax = trainingMax
        self.orderIndex = orderIndex
    }
}

@Model
final class StoredWorkoutSession {
    @Attribute(.unique) var id: UUID
    var routineName: String
    var performedAt: Date
    var programContext: String?
    @Relationship(deleteRule: .cascade, inverse: \StoredWorkoutEntry.session) var entries: [StoredWorkoutEntry]

    init(
        id: UUID,
        routineName: String,
        performedAt: Date,
        programContext: String?
    ) {
        self.id = id
        self.routineName = routineName
        self.performedAt = performedAt
        self.programContext = programContext
        entries = []
    }
}

@Model
final class StoredWorkoutEntry {
    @Attribute(.unique) var id: UUID
    var exerciseName: String
    var orderIndex: Int
    var session: StoredWorkoutSession?
    @Relationship(deleteRule: .cascade, inverse: \StoredWorkoutSet.entry) var sets: [StoredWorkoutSet]

    init(
        id: UUID,
        exerciseName: String,
        orderIndex: Int
    ) {
        self.id = id
        self.exerciseName = exerciseName
        self.orderIndex = orderIndex
        sets = []
    }
}

@Model
final class StoredWorkoutSet {
    @Attribute(.unique) var id: UUID
    var weight: Double?
    var reps: Int?
    var orderIndex: Int
    var entry: StoredWorkoutEntry?

    init(
        id: UUID,
        weight: Double?,
        reps: Int?,
        orderIndex: Int
    ) {
        self.id = id
        self.weight = weight
        self.reps = reps
        self.orderIndex = orderIndex
    }
}

@Model
final class StoredPlanRecord {
    @Attribute(.unique) var id: UUID
    var payload: Data
    var updatedAt: Date

    init(id: UUID, payload: Data, updatedAt: Date = .now) {
        self.id = id
        self.payload = payload
        self.updatedAt = updatedAt
    }
}

@Model
final class StoredExerciseCatalogRecord {
    @Attribute(.unique) var id: UUID
    var payload: Data
    var sortOrder: Int

    init(id: UUID, payload: Data, sortOrder: Int) {
        self.id = id
        self.payload = payload
        self.sortOrder = sortOrder
    }
}

@Model
final class StoredExerciseProfileRecord {
    @Attribute(.unique) var id: UUID
    var exerciseID: UUID
    var payload: Data

    init(id: UUID, exerciseID: UUID, payload: Data) {
        self.id = id
        self.exerciseID = exerciseID
        self.payload = payload
    }
}

@Model
final class StoredActiveSessionRecord {
    @Attribute(.unique) var id: UUID
    var payload: Data
    var updatedAt: Date

    init(id: UUID, payload: Data, updatedAt: Date = .now) {
        self.id = id
        self.payload = payload
        self.updatedAt = updatedAt
    }
}

@Model
final class StoredCompletedSessionRecord {
    @Attribute(.unique) var id: UUID
    var completedAt: Date
    var payload: Data

    init(id: UUID, completedAt: Date, payload: Data) {
        self.id = id
        self.completedAt = completedAt
        self.payload = payload
    }
}

enum WorkoutSchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            StoredRoutine.self,
            StoredExercise.self,
            StoredWorkoutSession.self,
            StoredWorkoutEntry.self,
            StoredWorkoutSet.self,
            StoredPlanRecord.self,
            StoredExerciseCatalogRecord.self,
            StoredExerciseProfileRecord.self,
            StoredActiveSessionRecord.self,
            StoredCompletedSessionRecord.self,
            StoredCatalogItem.self,
            StoredExerciseProfile.self,
            StoredPlan.self,
            StoredTemplate.self,
            StoredTemplateBlock.self,
            StoredTemplateTarget.self,
            StoredActiveSession.self,
            StoredActiveSessionBlock.self,
            StoredActiveSessionRow.self,
            StoredCompletedSession.self,
            StoredCompletedSessionBlock.self,
            StoredCompletedSessionRow.self
        ]
    }

    @Model
    final class StoredCatalogItem {
        @Attribute(.unique) var id: UUID
        var name: String
        var aliasesData: Data
        var categoryRaw: String
        var equipment: String?
        var isCustom: Bool

        init(
            id: UUID,
            name: String,
            aliasesData: Data,
            categoryRaw: String,
            equipment: String?,
            isCustom: Bool
        ) {
            self.id = id
            self.name = name
            self.aliasesData = aliasesData
            self.categoryRaw = categoryRaw
            self.equipment = equipment
            self.isCustom = isCustom
        }
    }

    @Model
    final class StoredExerciseProfile {
        @Attribute(.unique) var id: UUID
        var exerciseID: UUID
        var trainingMax: Double?
        var preferredIncrement: Double?
        var notes: String

        init(
            id: UUID,
            exerciseID: UUID,
            trainingMax: Double?,
            preferredIncrement: Double?,
            notes: String
        ) {
            self.id = id
            self.exerciseID = exerciseID
            self.trainingMax = trainingMax
            self.preferredIncrement = preferredIncrement
            self.notes = notes
        }
    }

    @Model
    final class StoredPlan {
        @Attribute(.unique) var id: UUID
        var name: String
        var createdAt: Date
        var pinnedTemplateID: UUID?
        var presetPackID: String?
        @Relationship(deleteRule: .cascade, inverse: \StoredTemplate.plan) var templates: [StoredTemplate]

        init(
            id: UUID,
            name: String,
            createdAt: Date,
            pinnedTemplateID: UUID?,
            presetPackID: String?
        ) {
            self.id = id
            self.name = name
            self.createdAt = createdAt
            self.pinnedTemplateID = pinnedTemplateID
            self.presetPackID = presetPackID
            templates = []
        }
    }

    @Model
    final class StoredTemplate {
        @Attribute(.unique) var id: UUID
        var name: String
        var note: String
        var scheduledWeekdaysData: Data
        var lastStartedAt: Date?
        var orderIndex: Int
        var plan: StoredPlan?
        @Relationship(deleteRule: .cascade, inverse: \StoredTemplateBlock.template) var blocks: [StoredTemplateBlock]

        init(
            id: UUID,
            name: String,
            note: String,
            scheduledWeekdaysData: Data,
            lastStartedAt: Date?,
            orderIndex: Int
        ) {
            self.id = id
            self.name = name
            self.note = note
            self.scheduledWeekdaysData = scheduledWeekdaysData
            self.lastStartedAt = lastStartedAt
            self.orderIndex = orderIndex
            blocks = []
        }
    }

    @Model
    final class StoredTemplateBlock {
        @Attribute(.unique) var id: UUID
        var exerciseID: UUID
        var exerciseNameSnapshot: String
        var blockNote: String
        var restSeconds: Int
        var supersetGroup: String?
        var allowsAutoWarmups: Bool
        var orderIndex: Int
        var progressionRuleData: Data
        var template: StoredTemplate?
        @Relationship(deleteRule: .cascade, inverse: \StoredTemplateTarget.block) var targets: [StoredTemplateTarget]

        init(
            id: UUID,
            exerciseID: UUID,
            exerciseNameSnapshot: String,
            blockNote: String,
            restSeconds: Int,
            supersetGroup: String?,
            allowsAutoWarmups: Bool,
            orderIndex: Int,
            progressionRuleData: Data
        ) {
            self.id = id
            self.exerciseID = exerciseID
            self.exerciseNameSnapshot = exerciseNameSnapshot
            self.blockNote = blockNote
            self.restSeconds = restSeconds
            self.supersetGroup = supersetGroup
            self.allowsAutoWarmups = allowsAutoWarmups
            self.orderIndex = orderIndex
            self.progressionRuleData = progressionRuleData
            targets = []
        }
    }

    @Model
    final class StoredTemplateTarget {
        @Attribute(.unique) var id: UUID
        var orderIndex: Int
        var setKindRaw: String
        var targetWeight: Double?
        var repLower: Int
        var repUpper: Int
        var rir: Int?
        var restSeconds: Int?
        var note: String?
        var block: StoredTemplateBlock?

        init(
            id: UUID,
            orderIndex: Int,
            setKindRaw: String,
            targetWeight: Double?,
            repLower: Int,
            repUpper: Int,
            rir: Int?,
            restSeconds: Int?,
            note: String?
        ) {
            self.id = id
            self.orderIndex = orderIndex
            self.setKindRaw = setKindRaw
            self.targetWeight = targetWeight
            self.repLower = repLower
            self.repUpper = repUpper
            self.rir = rir
            self.restSeconds = restSeconds
            self.note = note
        }
    }

    @Model
    final class StoredActiveSession {
        @Attribute(.unique) var id: UUID
        var planID: UUID?
        var templateID: UUID
        var templateNameSnapshot: String
        var startedAt: Date
        var lastUpdatedAt: Date
        var notes: String
        var restTimerEndsAt: Date?
        @Relationship(deleteRule: .cascade, inverse: \StoredActiveSessionBlock.session) var blocks: [StoredActiveSessionBlock]

        init(
            id: UUID,
            planID: UUID?,
            templateID: UUID,
            templateNameSnapshot: String,
            startedAt: Date,
            lastUpdatedAt: Date,
            notes: String,
            restTimerEndsAt: Date?
        ) {
            self.id = id
            self.planID = planID
            self.templateID = templateID
            self.templateNameSnapshot = templateNameSnapshot
            self.startedAt = startedAt
            self.lastUpdatedAt = lastUpdatedAt
            self.notes = notes
            self.restTimerEndsAt = restTimerEndsAt
            blocks = []
        }
    }

    @Model
    final class StoredActiveSessionBlock {
        @Attribute(.unique) var id: UUID
        var orderIndex: Int
        var sourceBlockID: UUID?
        var exerciseID: UUID
        var exerciseNameSnapshot: String
        var blockNote: String
        var restSeconds: Int
        var supersetGroup: String?
        var progressionRuleData: Data
        var session: StoredActiveSession?
        @Relationship(deleteRule: .cascade, inverse: \StoredActiveSessionRow.block) var rows: [StoredActiveSessionRow]

        init(
            id: UUID,
            orderIndex: Int,
            sourceBlockID: UUID?,
            exerciseID: UUID,
            exerciseNameSnapshot: String,
            blockNote: String,
            restSeconds: Int,
            supersetGroup: String?,
            progressionRuleData: Data
        ) {
            self.id = id
            self.orderIndex = orderIndex
            self.sourceBlockID = sourceBlockID
            self.exerciseID = exerciseID
            self.exerciseNameSnapshot = exerciseNameSnapshot
            self.blockNote = blockNote
            self.restSeconds = restSeconds
            self.supersetGroup = supersetGroup
            self.progressionRuleData = progressionRuleData
            rows = []
        }
    }

    @Model
    final class StoredActiveSessionRow {
        @Attribute(.unique) var id: UUID
        var orderIndex: Int
        var targetID: UUID
        var targetSetKindRaw: String
        var targetWeight: Double?
        var targetRepLower: Int
        var targetRepUpper: Int
        var targetRir: Int?
        var targetRestSeconds: Int?
        var targetNote: String?
        var logID: UUID
        var logWeight: Double?
        var logReps: Int?
        var logRir: Int?
        var logCompletedAt: Date?
        var block: StoredActiveSessionBlock?

        init(
            id: UUID,
            orderIndex: Int,
            targetID: UUID,
            targetSetKindRaw: String,
            targetWeight: Double?,
            targetRepLower: Int,
            targetRepUpper: Int,
            targetRir: Int?,
            targetRestSeconds: Int?,
            targetNote: String?,
            logID: UUID,
            logWeight: Double?,
            logReps: Int?,
            logRir: Int?,
            logCompletedAt: Date?
        ) {
            self.id = id
            self.orderIndex = orderIndex
            self.targetID = targetID
            self.targetSetKindRaw = targetSetKindRaw
            self.targetWeight = targetWeight
            self.targetRepLower = targetRepLower
            self.targetRepUpper = targetRepUpper
            self.targetRir = targetRir
            self.targetRestSeconds = targetRestSeconds
            self.targetNote = targetNote
            self.logID = logID
            self.logWeight = logWeight
            self.logReps = logReps
            self.logRir = logRir
            self.logCompletedAt = logCompletedAt
        }
    }

    @Model
    final class StoredCompletedSession {
        @Attribute(.unique) var id: UUID
        var planID: UUID?
        var templateID: UUID
        var templateNameSnapshot: String
        var startedAt: Date
        var completedAt: Date
        var notes: String
        @Relationship(deleteRule: .cascade, inverse: \StoredCompletedSessionBlock.session) var blocks: [StoredCompletedSessionBlock]

        init(
            id: UUID,
            planID: UUID?,
            templateID: UUID,
            templateNameSnapshot: String,
            startedAt: Date,
            completedAt: Date,
            notes: String
        ) {
            self.id = id
            self.planID = planID
            self.templateID = templateID
            self.templateNameSnapshot = templateNameSnapshot
            self.startedAt = startedAt
            self.completedAt = completedAt
            self.notes = notes
            blocks = []
        }
    }

    @Model
    final class StoredCompletedSessionBlock {
        @Attribute(.unique) var id: UUID
        var orderIndex: Int
        var exerciseID: UUID
        var exerciseNameSnapshot: String
        var blockNote: String
        var restSeconds: Int
        var supersetGroup: String?
        var progressionRuleData: Data
        var session: StoredCompletedSession?
        @Relationship(deleteRule: .cascade, inverse: \StoredCompletedSessionRow.block) var rows: [StoredCompletedSessionRow]

        init(
            id: UUID,
            orderIndex: Int,
            exerciseID: UUID,
            exerciseNameSnapshot: String,
            blockNote: String,
            restSeconds: Int,
            supersetGroup: String?,
            progressionRuleData: Data
        ) {
            self.id = id
            self.orderIndex = orderIndex
            self.exerciseID = exerciseID
            self.exerciseNameSnapshot = exerciseNameSnapshot
            self.blockNote = blockNote
            self.restSeconds = restSeconds
            self.supersetGroup = supersetGroup
            self.progressionRuleData = progressionRuleData
            rows = []
        }
    }

    @Model
    final class StoredCompletedSessionRow {
        @Attribute(.unique) var id: UUID
        var orderIndex: Int
        var targetID: UUID
        var targetSetKindRaw: String
        var targetWeight: Double?
        var targetRepLower: Int
        var targetRepUpper: Int
        var targetRir: Int?
        var targetRestSeconds: Int?
        var targetNote: String?
        var logID: UUID
        var logWeight: Double?
        var logReps: Int?
        var logRir: Int?
        var logCompletedAt: Date?
        var block: StoredCompletedSessionBlock?

        init(
            id: UUID,
            orderIndex: Int,
            targetID: UUID,
            targetSetKindRaw: String,
            targetWeight: Double?,
            targetRepLower: Int,
            targetRepUpper: Int,
            targetRir: Int?,
            targetRestSeconds: Int?,
            targetNote: String?,
            logID: UUID,
            logWeight: Double?,
            logReps: Int?,
            logRir: Int?,
            logCompletedAt: Date?
        ) {
            self.id = id
            self.orderIndex = orderIndex
            self.targetID = targetID
            self.targetSetKindRaw = targetSetKindRaw
            self.targetWeight = targetWeight
            self.targetRepLower = targetRepLower
            self.targetRepUpper = targetRepUpper
            self.targetRir = targetRir
            self.targetRestSeconds = targetRestSeconds
            self.targetNote = targetNote
            self.logID = logID
            self.logWeight = logWeight
            self.logReps = logReps
            self.logRir = logRir
            self.logCompletedAt = logCompletedAt
        }
    }
}

enum WorkoutSchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            StoredRoutine.self,
            StoredExercise.self,
            StoredWorkoutSession.self,
            StoredWorkoutEntry.self,
            StoredWorkoutSet.self,
            StoredPlanRecord.self,
            StoredExerciseCatalogRecord.self,
            StoredExerciseProfileRecord.self,
            StoredActiveSessionRecord.self,
            StoredCompletedSessionRecord.self,
            StoredCatalogItem.self,
            StoredExerciseProfile.self,
            StoredPlan.self,
            StoredTemplate.self,
            StoredTemplateBlock.self,
            StoredTemplateTarget.self,
            StoredActiveSession.self,
            StoredActiveSessionBlock.self,
            StoredActiveSessionRow.self,
            StoredCompletedSession.self,
            StoredCompletedSessionBlock.self,
            StoredCompletedSessionRow.self
        ]
    }

    @Model
    final class StoredCatalogItem {
        @Attribute(.unique) var id: UUID
        var name: String
        var aliasesData: Data
        var categoryRaw: String

        init(
            id: UUID,
            name: String,
            aliasesData: Data,
            categoryRaw: String
        ) {
            self.id = id
            self.name = name
            self.aliasesData = aliasesData
            self.categoryRaw = categoryRaw
        }
    }

    @Model
    final class StoredExerciseProfile {
        @Attribute(.unique) var id: UUID
        var exerciseID: UUID
        var trainingMax: Double?
        var preferredIncrement: Double?

        init(
            id: UUID,
            exerciseID: UUID,
            trainingMax: Double?,
            preferredIncrement: Double?
        ) {
            self.id = id
            self.exerciseID = exerciseID
            self.trainingMax = trainingMax
            self.preferredIncrement = preferredIncrement
        }
    }

    @Model
    final class StoredPlan {
        @Attribute(.unique) var id: UUID
        var name: String
        var createdAt: Date
        var pinnedTemplateID: UUID?
        @Relationship(deleteRule: .cascade, inverse: \StoredTemplate.plan) var templates: [StoredTemplate]

        init(
            id: UUID,
            name: String,
            createdAt: Date,
            pinnedTemplateID: UUID?
        ) {
            self.id = id
            self.name = name
            self.createdAt = createdAt
            self.pinnedTemplateID = pinnedTemplateID
            templates = []
        }
    }

    @Model
    final class StoredTemplate {
        @Attribute(.unique) var id: UUID
        var name: String
        var note: String
        var scheduledWeekdaysData: Data
        var lastStartedAt: Date?
        var orderIndex: Int
        var plan: StoredPlan?
        @Relationship(deleteRule: .cascade, inverse: \StoredTemplateBlock.template) var blocks: [StoredTemplateBlock]

        init(
            id: UUID,
            name: String,
            note: String,
            scheduledWeekdaysData: Data,
            lastStartedAt: Date?,
            orderIndex: Int
        ) {
            self.id = id
            self.name = name
            self.note = note
            self.scheduledWeekdaysData = scheduledWeekdaysData
            self.lastStartedAt = lastStartedAt
            self.orderIndex = orderIndex
            blocks = []
        }
    }

    @Model
    final class StoredTemplateBlock {
        @Attribute(.unique) var id: UUID
        var exerciseID: UUID
        var exerciseNameSnapshot: String
        var blockNote: String
        var restSeconds: Int
        var supersetGroup: String?
        var allowsAutoWarmups: Bool
        var orderIndex: Int
        var progressionRuleData: Data
        var template: StoredTemplate?
        @Relationship(deleteRule: .cascade, inverse: \StoredTemplateTarget.block) var targets: [StoredTemplateTarget]

        init(
            id: UUID,
            exerciseID: UUID,
            exerciseNameSnapshot: String,
            blockNote: String,
            restSeconds: Int,
            supersetGroup: String?,
            allowsAutoWarmups: Bool,
            orderIndex: Int,
            progressionRuleData: Data
        ) {
            self.id = id
            self.exerciseID = exerciseID
            self.exerciseNameSnapshot = exerciseNameSnapshot
            self.blockNote = blockNote
            self.restSeconds = restSeconds
            self.supersetGroup = supersetGroup
            self.allowsAutoWarmups = allowsAutoWarmups
            self.orderIndex = orderIndex
            self.progressionRuleData = progressionRuleData
            targets = []
        }
    }

    @Model
    final class StoredTemplateTarget {
        @Attribute(.unique) var id: UUID
        var orderIndex: Int
        var setKindRaw: String
        var targetWeight: Double?
        var repLower: Int
        var repUpper: Int
        var rir: Int?
        var restSeconds: Int?
        var note: String?
        var block: StoredTemplateBlock?

        init(
            id: UUID,
            orderIndex: Int,
            setKindRaw: String,
            targetWeight: Double?,
            repLower: Int,
            repUpper: Int,
            rir: Int?,
            restSeconds: Int?,
            note: String?
        ) {
            self.id = id
            self.orderIndex = orderIndex
            self.setKindRaw = setKindRaw
            self.targetWeight = targetWeight
            self.repLower = repLower
            self.repUpper = repUpper
            self.rir = rir
            self.restSeconds = restSeconds
            self.note = note
        }
    }

    @Model
    final class StoredActiveSession {
        @Attribute(.unique) var id: UUID
        var planID: UUID?
        var templateID: UUID
        var templateNameSnapshot: String
        var startedAt: Date
        var lastUpdatedAt: Date
        var notes: String
        var restTimerEndsAt: Date?
        @Relationship(deleteRule: .cascade, inverse: \StoredActiveSessionBlock.session) var blocks: [StoredActiveSessionBlock]

        init(
            id: UUID,
            planID: UUID?,
            templateID: UUID,
            templateNameSnapshot: String,
            startedAt: Date,
            lastUpdatedAt: Date,
            notes: String,
            restTimerEndsAt: Date?
        ) {
            self.id = id
            self.planID = planID
            self.templateID = templateID
            self.templateNameSnapshot = templateNameSnapshot
            self.startedAt = startedAt
            self.lastUpdatedAt = lastUpdatedAt
            self.notes = notes
            self.restTimerEndsAt = restTimerEndsAt
            blocks = []
        }
    }

    @Model
    final class StoredActiveSessionBlock {
        @Attribute(.unique) var id: UUID
        var orderIndex: Int
        var exerciseID: UUID
        var exerciseNameSnapshot: String
        var blockNote: String
        var restSeconds: Int
        var supersetGroup: String?
        var progressionRuleData: Data
        var session: StoredActiveSession?
        @Relationship(deleteRule: .cascade, inverse: \StoredActiveSessionRow.block) var rows: [StoredActiveSessionRow]

        init(
            id: UUID,
            orderIndex: Int,
            exerciseID: UUID,
            exerciseNameSnapshot: String,
            blockNote: String,
            restSeconds: Int,
            supersetGroup: String?,
            progressionRuleData: Data
        ) {
            self.id = id
            self.orderIndex = orderIndex
            self.exerciseID = exerciseID
            self.exerciseNameSnapshot = exerciseNameSnapshot
            self.blockNote = blockNote
            self.restSeconds = restSeconds
            self.supersetGroup = supersetGroup
            self.progressionRuleData = progressionRuleData
            rows = []
        }
    }

    @Model
    final class StoredActiveSessionRow {
        @Attribute(.unique) var id: UUID
        var orderIndex: Int
        var targetID: UUID
        var targetSetKindRaw: String
        var targetWeight: Double?
        var targetRepLower: Int
        var targetRepUpper: Int
        var targetRir: Int?
        var targetRestSeconds: Int?
        var targetNote: String?
        var logID: UUID
        var logWeight: Double?
        var logReps: Int?
        var logRir: Int?
        var logCompletedAt: Date?
        var block: StoredActiveSessionBlock?

        init(
            id: UUID,
            orderIndex: Int,
            targetID: UUID,
            targetSetKindRaw: String,
            targetWeight: Double?,
            targetRepLower: Int,
            targetRepUpper: Int,
            targetRir: Int?,
            targetRestSeconds: Int?,
            targetNote: String?,
            logID: UUID,
            logWeight: Double?,
            logReps: Int?,
            logRir: Int?,
            logCompletedAt: Date?
        ) {
            self.id = id
            self.orderIndex = orderIndex
            self.targetID = targetID
            self.targetSetKindRaw = targetSetKindRaw
            self.targetWeight = targetWeight
            self.targetRepLower = targetRepLower
            self.targetRepUpper = targetRepUpper
            self.targetRir = targetRir
            self.targetRestSeconds = targetRestSeconds
            self.targetNote = targetNote
            self.logID = logID
            self.logWeight = logWeight
            self.logReps = logReps
            self.logRir = logRir
            self.logCompletedAt = logCompletedAt
        }
    }

    @Model
    final class StoredCompletedSession {
        @Attribute(.unique) var id: UUID
        var planID: UUID?
        var templateID: UUID
        var templateNameSnapshot: String
        var startedAt: Date
        var completedAt: Date
        var notes: String
        @Relationship(deleteRule: .cascade, inverse: \StoredCompletedSessionBlock.session) var blocks: [StoredCompletedSessionBlock]

        init(
            id: UUID,
            planID: UUID?,
            templateID: UUID,
            templateNameSnapshot: String,
            startedAt: Date,
            completedAt: Date,
            notes: String
        ) {
            self.id = id
            self.planID = planID
            self.templateID = templateID
            self.templateNameSnapshot = templateNameSnapshot
            self.startedAt = startedAt
            self.completedAt = completedAt
            self.notes = notes
            blocks = []
        }
    }

    @Model
    final class StoredCompletedSessionBlock {
        @Attribute(.unique) var id: UUID
        var orderIndex: Int
        var exerciseID: UUID
        var exerciseNameSnapshot: String
        var blockNote: String
        var restSeconds: Int
        var supersetGroup: String?
        var progressionRuleData: Data
        var session: StoredCompletedSession?
        @Relationship(deleteRule: .cascade, inverse: \StoredCompletedSessionRow.block) var rows: [StoredCompletedSessionRow]

        init(
            id: UUID,
            orderIndex: Int,
            exerciseID: UUID,
            exerciseNameSnapshot: String,
            blockNote: String,
            restSeconds: Int,
            supersetGroup: String?,
            progressionRuleData: Data
        ) {
            self.id = id
            self.orderIndex = orderIndex
            self.exerciseID = exerciseID
            self.exerciseNameSnapshot = exerciseNameSnapshot
            self.blockNote = blockNote
            self.restSeconds = restSeconds
            self.supersetGroup = supersetGroup
            self.progressionRuleData = progressionRuleData
            rows = []
        }
    }

    @Model
    final class StoredCompletedSessionRow {
        @Attribute(.unique) var id: UUID
        var orderIndex: Int
        var targetID: UUID
        var targetSetKindRaw: String
        var targetWeight: Double?
        var targetRepLower: Int
        var targetRepUpper: Int
        var targetRir: Int?
        var targetRestSeconds: Int?
        var targetNote: String?
        var logID: UUID
        var logWeight: Double?
        var logReps: Int?
        var logRir: Int?
        var logCompletedAt: Date?
        var block: StoredCompletedSessionBlock?

        init(
            id: UUID,
            orderIndex: Int,
            targetID: UUID,
            targetSetKindRaw: String,
            targetWeight: Double?,
            targetRepLower: Int,
            targetRepUpper: Int,
            targetRir: Int?,
            targetRestSeconds: Int?,
            targetNote: String?,
            logID: UUID,
            logWeight: Double?,
            logReps: Int?,
            logRir: Int?,
            logCompletedAt: Date?
        ) {
            self.id = id
            self.orderIndex = orderIndex
            self.targetID = targetID
            self.targetSetKindRaw = targetSetKindRaw
            self.targetWeight = targetWeight
            self.targetRepLower = targetRepLower
            self.targetRepUpper = targetRepUpper
            self.targetRir = targetRir
            self.targetRestSeconds = targetRestSeconds
            self.targetNote = targetNote
            self.logID = logID
            self.logWeight = logWeight
            self.logReps = logReps
            self.logRir = logRir
            self.logCompletedAt = logCompletedAt
        }
    }
}

enum WorkoutSchemaMigrationPlan: SchemaMigrationPlan {
    static let schemas: [any VersionedSchema.Type] = [
        WorkoutSchemaV1.self,
        WorkoutSchemaV2.self
    ]

    static let stages: [MigrationStage] = [
        migrateV1toV2
    ]

    static let migrateV1toV2 = MigrationStage.lightweight(
        fromVersion: WorkoutSchemaV1.self,
        toVersion: WorkoutSchemaV2.self
    )
}

typealias StoredCatalogItem = WorkoutSchemaV2.StoredCatalogItem
typealias StoredExerciseProfile = WorkoutSchemaV2.StoredExerciseProfile
typealias StoredPlan = WorkoutSchemaV2.StoredPlan
typealias StoredTemplate = WorkoutSchemaV2.StoredTemplate
typealias StoredTemplateBlock = WorkoutSchemaV2.StoredTemplateBlock
typealias StoredTemplateTarget = WorkoutSchemaV2.StoredTemplateTarget
typealias StoredActiveSession = WorkoutSchemaV2.StoredActiveSession
typealias StoredActiveSessionBlock = WorkoutSchemaV2.StoredActiveSessionBlock
typealias StoredActiveSessionRow = WorkoutSchemaV2.StoredActiveSessionRow
typealias StoredCompletedSession = WorkoutSchemaV2.StoredCompletedSession
typealias StoredCompletedSessionBlock = WorkoutSchemaV2.StoredCompletedSessionBlock
typealias StoredCompletedSessionRow = WorkoutSchemaV2.StoredCompletedSessionRow

enum WorkoutModelContainerFactory {
    static func makeContainer(isStoredInMemoryOnly: Bool = false) -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: isStoredInMemoryOnly)

        do {
            return try ModelContainer(
                for: Schema(versionedSchema: WorkoutSchemaV2.self),
                migrationPlan: WorkoutSchemaMigrationPlan.self,
                configurations: configuration
            )
        } catch {
            fatalError("Failed to initialize SwiftData container: \(error)")
        }
    }
}
