import Foundation

enum ExerciseCategory: String, CaseIterable, Codable, Sendable {
    case chest
    case back
    case shoulders
    case legs
    case arms
    case fullBody
    case conditioning
    case core
    case custom
}

enum Weekday: Int, CaseIterable, Codable, Identifiable, Sendable {
    case sunday = 1
    case monday = 2
    case tuesday = 3
    case wednesday = 4
    case thursday = 5
    case friday = 6
    case saturday = 7

    var id: Int { rawValue }

    var shortLabel: String {
        switch self {
        case .sunday: return "Sun"
        case .monday: return "Mon"
        case .tuesday: return "Tue"
        case .wednesday: return "Wed"
        case .thursday: return "Thu"
        case .friday: return "Fri"
        case .saturday: return "Sat"
        }
    }

}

enum SetKind: String, CaseIterable, Codable, Sendable {
    case warmup
    case working
    case dropSet

    var displayName: String {
        switch self {
        case .warmup:
            return "Warmup"
        case .working:
            return "Working"
        case .dropSet:
            return "Dropset"
        }
    }
}

enum ProgressionRuleKind: String, CaseIterable, Codable, Sendable {
    case manual
    case doubleProgression
    case percentageWave

    var displayLabel: String {
        switch self {
        case .manual:
            return "Manual"
        case .doubleProgression:
            return "Double"
        case .percentageWave:
            return "Wave"
        }
    }
}

enum ExerciseClassification {
    private static let lowerBodyKeywords = [
        "squat",
        "deadlift",
        "clean",
        "lunge",
        "leg",
        "calf",
        "hip thrust",
    ]

    static func isLowerBody(_ exerciseName: String) -> Bool {
        let normalized = exerciseName.lowercased()
        return lowerBodyKeywords.contains { normalized.contains($0) }
    }
}

struct WarmupRampStep: Codable, Equatable, Sendable {
    var percentage: Double
    var reps: Int
}

struct RepRange: Codable, Equatable, Sendable {
    var lowerBound: Int
    var upperBound: Int

    init(_ lowerBound: Int, _ upperBound: Int) {
        self.lowerBound = lowerBound
        self.upperBound = upperBound
    }

    var displayLabel: String {
        if lowerBound == upperBound {
            return "\(lowerBound)"
        }

        return "\(lowerBound)-\(upperBound)"
    }
}

struct ExerciseCatalogItem: Identifiable, Codable, Equatable, Hashable, Sendable {
    var id: UUID
    var name: String
    var aliases: [String]
    var category: ExerciseCategory

    init(
        id: UUID = UUID(),
        name: String,
        aliases: [String] = [],
        category: ExerciseCategory
    ) {
        self.id = id
        self.name = name
        self.aliases = aliases
        self.category = category
    }
}

struct ExerciseProfile: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var exerciseID: UUID
    var trainingMax: Double?
    var preferredIncrement: Double?

    init(
        id: UUID = UUID(),
        exerciseID: UUID,
        trainingMax: Double? = nil,
        preferredIncrement: Double? = nil
    ) {
        self.id = id
        self.exerciseID = exerciseID
        self.trainingMax = trainingMax
        self.preferredIncrement = preferredIncrement
    }
}

struct DoubleProgressionRule: Codable, Equatable, Sendable {
    var targetRepRange: RepRange
    var increment: Double
}

struct PercentageWaveSet: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var percentage: Double
    var repRange: RepRange
    var note: String?

    init(
        id: UUID = UUID(),
        percentage: Double,
        repRange: RepRange,
        note: String? = nil
    ) {
        self.id = id
        self.percentage = percentage
        self.repRange = repRange
        self.note = note
    }
}

struct PercentageWaveWeek: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var name: String
    var sets: [PercentageWaveSet]

    init(id: UUID = UUID(), name: String, sets: [PercentageWaveSet]) {
        self.id = id
        self.name = name
        self.sets = sets
    }
}

struct PercentageWaveRule: Codable, Equatable, Sendable {
    var trainingMax: Double?
    var weeks: [PercentageWaveWeek]
    var currentWeekIndex: Int
    var cycle: Int
    var cycleIncrement: Double

    init(
        trainingMax: Double? = nil,
        weeks: [PercentageWaveWeek],
        currentWeekIndex: Int = 0,
        cycle: Int = 1,
        cycleIncrement: Double
    ) {
        self.trainingMax = trainingMax
        self.weeks = weeks
        self.currentWeekIndex = currentWeekIndex
        self.cycle = cycle
        self.cycleIncrement = cycleIncrement
    }
}

extension PercentageWaveRule {
    static func fiveThreeOne(
        trainingMax: Double? = nil,
        currentWeekIndex: Int = 0,
        cycle: Int = 1,
        cycleIncrement: Double
    ) -> PercentageWaveRule {
        PercentageWaveRule(
            trainingMax: trainingMax,
            weeks: makeFiveThreeOneWeeks(),
            currentWeekIndex: currentWeekIndex,
            cycle: cycle,
            cycleIncrement: cycleIncrement
        )
    }

    private static func makeFiveThreeOneWeeks() -> [PercentageWaveWeek] {
        [
            PercentageWaveWeek(
                name: "Week 1",
                sets: [
                    PercentageWaveSet(percentage: 0.65, repRange: RepRange(5, 5)),
                    PercentageWaveSet(percentage: 0.75, repRange: RepRange(5, 5)),
                    PercentageWaveSet(percentage: 0.85, repRange: RepRange(5, 5), note: "AMRAP"),
                ]
            ),
            PercentageWaveWeek(
                name: "Week 2",
                sets: [
                    PercentageWaveSet(percentage: 0.70, repRange: RepRange(3, 3)),
                    PercentageWaveSet(percentage: 0.80, repRange: RepRange(3, 3)),
                    PercentageWaveSet(percentage: 0.90, repRange: RepRange(3, 3), note: "AMRAP"),
                ]
            ),
            PercentageWaveWeek(
                name: "Week 3",
                sets: [
                    PercentageWaveSet(percentage: 0.75, repRange: RepRange(5, 5)),
                    PercentageWaveSet(percentage: 0.85, repRange: RepRange(3, 3)),
                    PercentageWaveSet(percentage: 0.95, repRange: RepRange(1, 1), note: "AMRAP"),
                ]
            ),
            PercentageWaveWeek(
                name: "Deload",
                sets: [
                    PercentageWaveSet(percentage: 0.40, repRange: RepRange(5, 5)),
                    PercentageWaveSet(percentage: 0.50, repRange: RepRange(5, 5)),
                    PercentageWaveSet(percentage: 0.60, repRange: RepRange(5, 5)),
                ]
            ),
        ]
    }
}

struct ProgressionRule: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var kind: ProgressionRuleKind
    var doubleProgression: DoubleProgressionRule?
    var percentageWave: PercentageWaveRule?

    init(
        id: UUID = UUID(),
        kind: ProgressionRuleKind,
        doubleProgression: DoubleProgressionRule? = nil,
        percentageWave: PercentageWaveRule? = nil
    ) {
        self.id = id
        self.kind = kind
        self.doubleProgression = doubleProgression
        self.percentageWave = percentageWave
    }

    static let manual = ProgressionRule(kind: .manual)
}

struct SetTarget: Identifiable, Codable, Equatable, Sendable {
    var id: UUID
    var setKind: SetKind
    var targetWeight: Double?
    var repRange: RepRange
    var rir: Int?
    var restSeconds: Int?
    var note: String?

    init(
        id: UUID = UUID(),
        setKind: SetKind = .working,
        targetWeight: Double? = nil,
        repRange: RepRange,
        rir: Int? = nil,
        restSeconds: Int? = nil,
        note: String? = nil
    ) {
        self.id = id
        self.setKind = setKind
        self.targetWeight = targetWeight
        self.repRange = repRange
        self.rir = rir
        self.restSeconds = restSeconds
        self.note = note
    }
}
