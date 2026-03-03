import Foundation
import SwiftData

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
final class StoredLiftRecord {
    @Attribute(.unique) var id: UUID
    var sessionID: UUID
    var routineName: String
    var exerciseName: String
    var performedAt: Date
    var setIndex: Int
    var weight: Double?
    var reps: Int?

    init(
        id: UUID,
        sessionID: UUID,
        routineName: String,
        exerciseName: String,
        performedAt: Date,
        setIndex: Int,
        weight: Double?,
        reps: Int?
    ) {
        self.id = id
        self.sessionID = sessionID
        self.routineName = routineName
        self.exerciseName = exerciseName
        self.performedAt = performedAt
        self.setIndex = setIndex
        self.weight = weight
        self.reps = reps
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
                StoredLiftRecord.self,
                configurations: configuration
            )
        } catch {
            fatalError("Failed to initialize SwiftData container: \(error)")
        }
    }
}
