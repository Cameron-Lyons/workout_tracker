import Foundation

enum StrengthProgressionDefaults {
    static let gymRoundingIncrement = 2.5
    static let upperBodyIncreaseInPounds = 2.5
    static let lowerBodyIncreaseInPounds = 5.0
    static let lowerBodyTrainingMaxCycleIncreaseInPounds = 10.0
    static let recommendedMinimumIncreaseInPounds = 10.0
    static let recommendedMinimumIncreaseInKilograms = 5.0
}

enum WeightUnit: String, CaseIterable, Codable {
    case pounds
    case kilograms

    static let preferenceKey = "workout_tracker_weight_unit_v1"

    private static let poundsPerKilogram = 2.2046226218
    private static let poundsDisplayIncrement = StrengthProgressionDefaults.gymRoundingIncrement
    private static let kilogramsDisplayIncrement = StrengthProgressionDefaults.gymRoundingIncrement
    private static let minimumRoundingIncrement = 0.000_1
    private static let defaultMinimumIncreaseFloor = StrengthProgressionDefaults.gymRoundingIncrement
    private static let defaultUpperBodyIncrease = StrengthProgressionDefaults.upperBodyIncreaseInPounds
    private static let defaultLowerBodyIncrease = StrengthProgressionDefaults.lowerBodyIncreaseInPounds
    private static let recommendedMinimumIncreasePounds = StrengthProgressionDefaults.recommendedMinimumIncreaseInPounds
    private static let recommendedMinimumIncreaseKilograms = StrengthProgressionDefaults.recommendedMinimumIncreaseInKilograms

    var symbol: String {
        switch self {
        case .pounds:
            return "lb"
        case .kilograms:
            return "kg"
        }
    }

    var shortLabel: String {
        switch self {
        case .pounds:
            return "US (lb)"
        case .kilograms:
            return "Metric (kg)"
        }
    }

    var minimumIncreaseFloor: Double {
        Self.defaultMinimumIncreaseFloor
    }

    var upperBodyDefaultIncrease: Double {
        Self.defaultUpperBodyIncrease
    }

    var lowerBodyDefaultIncrease: Double {
        Self.defaultLowerBodyIncrease
    }

    var recommendedMinimumIncreaseDefault: Double {
        switch self {
        case .pounds:
            return Self.recommendedMinimumIncreasePounds
        case .kilograms:
            return Self.recommendedMinimumIncreaseKilograms
        }
    }

    var gymDisplayIncrement: Double {
        switch self {
        case .pounds:
            return Self.poundsDisplayIncrement
        case .kilograms:
            return Self.kilogramsDisplayIncrement
        }
    }

    func storedPounds(fromDisplayValue value: Double) -> Double {
        switch self {
        case .pounds:
            return value
        case .kilograms:
            return value * Self.poundsPerKilogram
        }
    }

    func displayValue(fromStoredPounds pounds: Double, snapToGymIncrement: Bool = true) -> Double {
        let converted: Double
        switch self {
        case .pounds:
            converted = pounds
        case .kilograms:
            converted = pounds / Self.poundsPerKilogram
        }

        if snapToGymIncrement {
            return roundedForGymDisplay(converted)
        }

        return converted
    }

    func roundedForGymDisplay(_ value: Double, increment: Double? = nil) -> Double {
        let resolvedIncrement = max(increment ?? gymDisplayIncrement, Self.minimumRoundingIncrement)
        return (value / resolvedIncrement).rounded() * resolvedIncrement
    }

    func normalizedDisplayIncrease(_ value: Double) -> Double {
        let clamped = max(value, minimumIncreaseFloor)
        return roundedForGymDisplay(clamped)
    }

    func convertedDisplayString(from oldUnit: WeightUnit, text: String) -> String? {
        guard let oldDisplayValue = Double(text), oldDisplayValue > 0 else {
            return nil
        }

        let storedWeight = oldUnit.storedPounds(fromDisplayValue: oldDisplayValue)
        return WeightFormatter.displayString(storedWeight, unit: self)
    }
}

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
    private enum Constants {
        static let oneDecimalScale = 10.0
        static let twoDecimalScale = 100.0
    }

    static func displayString(_ storedWeightInPounds: Double, unit: WeightUnit = .pounds) -> String {
        let value = unit.displayValue(fromStoredPounds: storedWeightInPounds)
        return displayString(displayValue: value, unit: unit)
    }

    static func displayString(displayValue value: Double, unit: WeightUnit) -> String {
        let roundedValue = unit.roundedForGymDisplay(value)

        if roundedValue.rounded() == roundedValue {
            return String(Int(roundedValue))
        }

        // Gym-friendly values are typically whole or half-ish steps; one decimal keeps labels compact.
        let oneDecimalValue = (roundedValue * Constants.oneDecimalScale).rounded() / Constants.oneDecimalScale
        if oneDecimalValue.rounded() == oneDecimalValue {
            return String(Int(oneDecimalValue))
        }

        if (oneDecimalValue * Constants.oneDecimalScale).rounded() == oneDecimalValue * Constants.oneDecimalScale {
            return String(format: "%.1f", oneDecimalValue)
        }

        let twoDecimalValue = (roundedValue * Constants.twoDecimalScale).rounded() / Constants.twoDecimalScale
        if twoDecimalValue.rounded() == twoDecimalValue {
            return String(Int(twoDecimalValue))
        }

        if (twoDecimalValue * Constants.oneDecimalScale).rounded() == twoDecimalValue * Constants.oneDecimalScale {
            return String(format: "%.1f", twoDecimalValue)
        }

        return String(format: "%.2f", twoDecimalValue)
    }

}

enum WeightInputParser {
    static func parseDisplayValue(_ text: String, allowsZero: Bool = false) -> Double? {
        let sanitized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")

        guard !sanitized.isEmpty, let value = Double(sanitized) else {
            return nil
        }

        if allowsZero {
            return value >= 0 ? value : nil
        }

        return value > 0 ? value : nil
    }
}

enum WeightUnitTransition {
    static func changedUnits(
        previous: inout WeightUnit,
        next: WeightUnit
    ) -> (old: WeightUnit, new: WeightUnit)? {
        let oldUnit = previous
        previous = next

        guard oldUnit != next else {
            return nil
        }

        return (old: oldUnit, new: next)
    }
}

enum WeightInputConversion {
    static func parseStoredPounds(
        from text: String,
        unit: WeightUnit,
        allowsZero: Bool = false
    ) -> Double? {
        guard let displayValue = WeightInputParser.parseDisplayValue(text, allowsZero: allowsZero) else {
            return nil
        }

        return unit.storedPounds(fromDisplayValue: displayValue)
    }

    static func convertedDisplayString(
        from text: String,
        oldUnit: WeightUnit,
        newUnit: WeightUnit
    ) -> String? {
        newUnit.convertedDisplayString(from: oldUnit, text: text)
    }
}

enum LiftClassifier {
    private static let lowerBodyKeywords = [
        "squat",
        "deadlift",
        "clean",
        "lunge",
        "leg",
        "calf",
        "hip thrust"
    ]

    static func isLowerBodyLift(_ exerciseName: String) -> Bool {
        let normalized = exerciseName.lowercased()
        return lowerBodyKeywords.contains { keyword in
            normalized.contains(keyword)
        }
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

    init(
        id: UUID = UUID(),
        weight: Double? = nil,
        reps: Int? = nil
    ) {
        self.id = id
        self.weight = weight
        self.reps = reps
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

    init(
        id: UUID = UUID(),
        sessionID: UUID,
        routineName: String,
        exerciseName: String,
        performedAt: Date,
        setIndex: Int,
        weight: Double? = nil,
        reps: Int? = nil
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
