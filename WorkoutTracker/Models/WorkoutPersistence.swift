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

enum WorkoutModelContainerFactory {
    static func makeContainer(isStoredInMemoryOnly: Bool = false) -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: isStoredInMemoryOnly)

        do {
            return try ModelContainer(
                for: StoredRoutine.self,
                StoredExercise.self,
                StoredWorkoutSession.self,
                StoredWorkoutEntry.self,
                StoredWorkoutSet.self,
                StoredPlanRecord.self,
                StoredExerciseCatalogRecord.self,
                StoredExerciseProfileRecord.self,
                StoredActiveSessionRecord.self,
                StoredCompletedSessionRecord.self,
                configurations: configuration
            )
        } catch {
            fatalError("Failed to initialize SwiftData container: \(error)")
        }
    }
}

