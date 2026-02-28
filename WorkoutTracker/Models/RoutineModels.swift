import Foundation

enum ProgramKind: String, Codable {
    case startingStrength
    case fiveThreeOne
    case boringButBig

    var displayName: String {
        switch self {
        case .startingStrength:
            return "Starting Strength"
        case .fiveThreeOne:
            return "5/3/1"
        case .boringButBig:
            return "Boring But Big"
        }
    }
}

enum PopularRoutinePack: String, CaseIterable, Identifiable {
    case pushPullLegs
    case upperLower
    case strongLiftsFiveByFive
    case arnoldSplit
    case phul

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pushPullLegs:
            return "Push/Pull/Legs"
        case .upperLower:
            return "Upper/Lower"
        case .strongLiftsFiveByFive:
            return "StrongLifts 5x5"
        case .arnoldSplit:
            return "Arnold Split"
        case .phul:
            return "PHUL"
        }
    }

    var systemImage: String {
        switch self {
        case .pushPullLegs:
            return "figure.strengthtraining.traditional"
        case .upperLower:
            return "arrow.up.arrow.down"
        case .strongLiftsFiveByFive:
            return "5.circle"
        case .arnoldSplit:
            return "dumbbell"
        case .phul:
            return "chart.bar"
        }
    }
}

enum WeightFormatter {
    static func displayString(_ weight: Double) -> String {
        if weight.rounded() == weight {
            return String(Int(weight))
        }
        return String(format: "%.1f", weight)
    }
}

extension String {
    var nonEmptyTrimmed: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

struct ProgramState: Codable, Equatable {
    var step: Int
    var cycle: Int

    init(step: Int = 0, cycle: Int = 1) {
        self.step = step
        self.cycle = cycle
    }
}

struct ProgramConfig: Codable, Equatable {
    var kind: ProgramKind
    var state: ProgramState

    init(kind: ProgramKind, state: ProgramState = ProgramState()) {
        self.kind = kind
        self.state = state
    }
}

struct Routine: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var exercises: [Exercise]
    var program: ProgramConfig?

    init(
        id: UUID = UUID(),
        name: String,
        exercises: [Exercise],
        program: ProgramConfig? = nil
    ) {
        self.id = id
        self.name = name
        self.exercises = exercises
        self.program = program
    }
}

struct Exercise: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var name: String
    var trainingMax: Double?

    init(id: UUID = UUID(), name: String, trainingMax: Double? = nil) {
        self.id = id
        self.name = name
        self.trainingMax = trainingMax
    }
}

struct ExerciseSet: Identifiable, Codable, Equatable {
    var id: UUID
    var weight: Double?
    var reps: Int?
    var transcript: String?

    init(
        id: UUID = UUID(),
        weight: Double? = nil,
        reps: Int? = nil,
        transcript: String? = nil
    ) {
        self.id = id
        self.weight = weight
        self.reps = reps
        self.transcript = transcript
    }
}

struct ExerciseEntry: Identifiable, Codable, Equatable {
    var id: UUID
    var exerciseName: String
    var sets: [ExerciseSet]

    init(
        id: UUID = UUID(),
        exerciseName: String,
        sets: [ExerciseSet] = []
    ) {
        self.id = id
        self.exerciseName = exerciseName
        self.sets = sets
    }

    enum CodingKeys: String, CodingKey {
        case id
        case exerciseName
        case sets
        case weight
        case reps
        case transcript
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        exerciseName = try container.decode(String.self, forKey: .exerciseName)

        if let decodedSets = try container.decodeIfPresent([ExerciseSet].self, forKey: .sets) {
            sets = decodedSets
            return
        }

        // Backward compatibility for old single-set history payloads.
        let legacyWeight = try container.decodeIfPresent(Double.self, forKey: .weight)
        let legacyReps = try container.decodeIfPresent(Int.self, forKey: .reps)
        let legacyTranscript = try container.decodeIfPresent(String.self, forKey: .transcript)

        if legacyWeight != nil || legacyReps != nil || ((legacyTranscript ?? "").isEmpty == false) {
            sets = [ExerciseSet(weight: legacyWeight, reps: legacyReps, transcript: legacyTranscript)]
        } else {
            sets = []
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(exerciseName, forKey: .exerciseName)
        try container.encode(sets, forKey: .sets)
    }
}

struct WorkoutSession: Identifiable, Codable, Equatable {
    var id: UUID
    var routineName: String
    var performedAt: Date
    var entries: [ExerciseEntry]
    var programContext: String?

    init(
        id: UUID = UUID(),
        routineName: String,
        performedAt: Date = Date(),
        entries: [ExerciseEntry],
        programContext: String? = nil
    ) {
        self.id = id
        self.routineName = routineName
        self.performedAt = performedAt
        self.entries = entries
        self.programContext = programContext
    }
}

struct LiftRecord: Identifiable, Codable, Equatable {
    var id: UUID
    var sessionID: UUID
    var routineName: String
    var exerciseName: String
    var performedAt: Date
    var setIndex: Int
    var weight: Double?
    var reps: Int?
    var transcript: String?

    init(
        id: UUID = UUID(),
        sessionID: UUID,
        routineName: String,
        exerciseName: String,
        performedAt: Date,
        setIndex: Int,
        weight: Double? = nil,
        reps: Int? = nil,
        transcript: String? = nil
    ) {
        self.id = id
        self.sessionID = sessionID
        self.routineName = routineName
        self.exerciseName = exerciseName
        self.performedAt = performedAt
        self.setIndex = setIndex
        self.weight = weight
        self.reps = reps
        self.transcript = transcript
    }
}
