import Foundation

enum StrengthProgressionDefaults {
    static let gymRoundingIncrement = 2.5
    static let upperBodyIncreaseInPounds = 2.5
    static let lowerBodyIncreaseInPounds = 5.0
}

enum WeightUnit: String, CaseIterable, Codable {
    case pounds
    case kilograms

    static let settingsKey = "workout_tracker_v2_weight_unit"

    private static let poundsPerKilogram = 2.2046226218
    private static let minimumRoundingIncrement = 0.000_1

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

    var defaultUpperBodyIncrement: Double {
        switch self {
        case .pounds:
            return StrengthProgressionDefaults.upperBodyIncreaseInPounds
        case .kilograms:
            return 1.25
        }
    }

    var defaultLowerBodyIncrement: Double {
        switch self {
        case .pounds:
            return StrengthProgressionDefaults.lowerBodyIncreaseInPounds
        case .kilograms:
            return 2.5
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

    func roundedForGymDisplay(_ value: Double, increment: Double = StrengthProgressionDefaults.gymRoundingIncrement) -> Double {
        let safeIncrement = max(increment, Self.minimumRoundingIncrement)
        return (value / safeIncrement).rounded() * safeIncrement
    }
}

enum WeightFormatter {
    static func displayString(_ storedWeightInPounds: Double?, unit: WeightUnit = .pounds) -> String {
        guard let storedWeightInPounds else {
            return ""
        }

        return displayString(
            displayValue: unit.displayValue(fromStoredPounds: storedWeightInPounds),
            unit: unit
        )
    }

    static func displayString(displayValue value: Double, unit: WeightUnit) -> String {
        let roundedValue = unit.roundedForGymDisplay(value)

        if roundedValue.rounded() == roundedValue {
            return String(Int(roundedValue))
        }

        let oneDecimalValue = (roundedValue * 10).rounded() / 10
        if (oneDecimalValue * 10).rounded() == oneDecimalValue * 10 {
            return String(format: "%.1f", oneDecimalValue)
        }

        return String(format: "%.2f", roundedValue)
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
        guard let oldDisplayValue = WeightInputParser.parseDisplayValue(text, allowsZero: true) else {
            return nil
        }

        let storedWeight = oldUnit.storedPounds(fromDisplayValue: oldDisplayValue)
        return WeightFormatter.displayString(storedWeight, unit: newUnit)
    }
}

enum ExerciseCategory: String, CaseIterable, Codable {
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

enum Weekday: Int, CaseIterable, Codable, Identifiable {
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

    var fullLabel: String {
        switch self {
        case .sunday: return "Sunday"
        case .monday: return "Monday"
        case .tuesday: return "Tuesday"
        case .wednesday: return "Wednesday"
        case .thursday: return "Thursday"
        case .friday: return "Friday"
        case .saturday: return "Saturday"
        }
    }
}

enum SetKind: String, CaseIterable, Codable {
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

enum ProgressionRuleKind: String, CaseIterable, Codable {
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
        "hip thrust"
    ]

    static func isLowerBody(_ exerciseName: String) -> Bool {
        let normalized = exerciseName.lowercased()
        return lowerBodyKeywords.contains { normalized.contains($0) }
    }
}

struct WarmupRampStep: Codable, Equatable {
    var percentage: Double
    var reps: Int
}

struct RepRange: Codable, Equatable {
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

struct ExerciseCatalogItem: Identifiable, Codable, Equatable, Hashable {
    var id: UUID
    var name: String
    var aliases: [String]
    var category: ExerciseCategory
    var equipment: String?
    var isCustom: Bool

    init(
        id: UUID = UUID(),
        name: String,
        aliases: [String] = [],
        category: ExerciseCategory,
        equipment: String? = nil,
        isCustom: Bool = false
    ) {
        self.id = id
        self.name = name
        self.aliases = aliases
        self.category = category
        self.equipment = equipment
        self.isCustom = isCustom
    }
}

struct ExerciseProfile: Identifiable, Codable, Equatable {
    var id: UUID
    var exerciseID: UUID
    var trainingMax: Double?
    var preferredIncrement: Double?
    var notes: String

    init(
        id: UUID = UUID(),
        exerciseID: UUID,
        trainingMax: Double? = nil,
        preferredIncrement: Double? = nil,
        notes: String = ""
    ) {
        self.id = id
        self.exerciseID = exerciseID
        self.trainingMax = trainingMax
        self.preferredIncrement = preferredIncrement
        self.notes = notes
    }
}

struct DoubleProgressionRule: Codable, Equatable {
    var targetRepRange: RepRange
    var increment: Double
}

struct PercentageWaveSet: Identifiable, Codable, Equatable {
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

struct PercentageWaveWeek: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var sets: [PercentageWaveSet]

    init(id: UUID = UUID(), name: String, sets: [PercentageWaveSet]) {
        self.id = id
        self.name = name
        self.sets = sets
    }
}

struct PercentageWaveRule: Codable, Equatable {
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

struct ProgressionRule: Identifiable, Codable, Equatable {
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

struct SetTarget: Identifiable, Codable, Equatable {
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

struct SetLog: Identifiable, Codable, Equatable {
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

struct SessionSetRow: Identifiable, Codable, Equatable {
    var id: UUID
    var target: SetTarget
    var log: SetLog

    init(id: UUID = UUID(), target: SetTarget, log: SetLog? = nil) {
        self.id = id
        self.target = target
        self.log = log ?? SetLog(setTargetID: target.id)
    }
}

struct ExerciseBlock: Identifiable, Codable, Equatable {
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
        restSeconds: Int = 90,
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

struct WorkoutTemplate: Identifiable, Codable, Equatable {
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

struct Plan: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var createdAt: Date
    var pinnedTemplateID: UUID?
    var presetPackID: String?
    var templates: [WorkoutTemplate]

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = .now,
        pinnedTemplateID: UUID? = nil,
        presetPackID: String? = nil,
        templates: [WorkoutTemplate]
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.pinnedTemplateID = pinnedTemplateID
        self.presetPackID = presetPackID
        self.templates = templates
    }
}

struct SessionBlock: Identifiable, Codable, Equatable {
    var id: UUID
    var sourceBlockID: UUID?
    var exerciseID: UUID
    var exerciseNameSnapshot: String
    var blockNote: String
    var restSeconds: Int
    var supersetGroup: String?
    var progressionRule: ProgressionRule
    var sets: [SessionSetRow]

    init(
        id: UUID = UUID(),
        sourceBlockID: UUID? = nil,
        exerciseID: UUID,
        exerciseNameSnapshot: String,
        blockNote: String = "",
        restSeconds: Int,
        supersetGroup: String? = nil,
        progressionRule: ProgressionRule,
        sets: [SessionSetRow]
    ) {
        self.id = id
        self.sourceBlockID = sourceBlockID
        self.exerciseID = exerciseID
        self.exerciseNameSnapshot = exerciseNameSnapshot
        self.blockNote = blockNote
        self.restSeconds = restSeconds
        self.supersetGroup = supersetGroup
        self.progressionRule = progressionRule
        self.sets = sets
    }
}

struct SessionDraft: Identifiable, Codable, Equatable {
    var id: UUID
    var planID: UUID?
    var templateID: UUID
    var templateNameSnapshot: String
    var startedAt: Date
    var lastUpdatedAt: Date
    var notes: String
    var blocks: [SessionBlock]
    var restTimerEndsAt: Date?

    init(
        id: UUID = UUID(),
        planID: UUID?,
        templateID: UUID,
        templateNameSnapshot: String,
        startedAt: Date = .now,
        lastUpdatedAt: Date = .now,
        notes: String = "",
        blocks: [SessionBlock],
        restTimerEndsAt: Date? = nil
    ) {
        self.id = id
        self.planID = planID
        self.templateID = templateID
        self.templateNameSnapshot = templateNameSnapshot
        self.startedAt = startedAt
        self.lastUpdatedAt = lastUpdatedAt
        self.notes = notes
        self.blocks = blocks
        self.restTimerEndsAt = restTimerEndsAt
    }
}

struct CompletedSessionBlock: Identifiable, Codable, Equatable {
    var id: UUID
    var exerciseID: UUID
    var exerciseNameSnapshot: String
    var blockNote: String
    var restSeconds: Int
    var supersetGroup: String?
    var progressionRule: ProgressionRule
    var sets: [SessionSetRow]

    init(
        id: UUID = UUID(),
        exerciseID: UUID,
        exerciseNameSnapshot: String,
        blockNote: String,
        restSeconds: Int,
        supersetGroup: String?,
        progressionRule: ProgressionRule,
        sets: [SessionSetRow]
    ) {
        self.id = id
        self.exerciseID = exerciseID
        self.exerciseNameSnapshot = exerciseNameSnapshot
        self.blockNote = blockNote
        self.restSeconds = restSeconds
        self.supersetGroup = supersetGroup
        self.progressionRule = progressionRule
        self.sets = sets
    }
}

struct CompletedSession: Identifiable, Codable, Equatable {
    var id: UUID
    var planID: UUID?
    var templateID: UUID
    var templateNameSnapshot: String
    var startedAt: Date
    var completedAt: Date
    var notes: String
    var blocks: [CompletedSessionBlock]

    init(
        id: UUID = UUID(),
        planID: UUID?,
        templateID: UUID,
        templateNameSnapshot: String,
        startedAt: Date,
        completedAt: Date = .now,
        notes: String = "",
        blocks: [CompletedSessionBlock]
    ) {
        self.id = id
        self.planID = planID
        self.templateID = templateID
        self.templateNameSnapshot = templateNameSnapshot
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.notes = notes
        self.blocks = blocks
    }
}

struct TemplateReference: Identifiable, Equatable {
    var id: UUID { templateID }
    var planID: UUID
    var planName: String
    var templateID: UUID
    var templateName: String
    var scheduledWeekdays: [Weekday]
    var lastStartedAt: Date?
}

struct ProgressPoint: Identifiable, Equatable {
    var id: UUID
    var sessionID: UUID
    var date: Date
    var topWeight: Double
    var estimatedOneRepMax: Double
    var volume: Double

    init(
        id: UUID = UUID(),
        sessionID: UUID,
        date: Date,
        topWeight: Double,
        estimatedOneRepMax: Double,
        volume: Double
    ) {
        self.id = id
        self.sessionID = sessionID
        self.date = date
        self.topWeight = topWeight
        self.estimatedOneRepMax = estimatedOneRepMax
        self.volume = volume
    }
}

struct PersonalRecord: Identifiable, Equatable {
    var id: UUID
    var sessionID: UUID
    var exerciseID: UUID
    var displayName: String
    var weight: Double
    var reps: Int
    var estimatedOneRepMax: Double
    var achievedAt: Date

    init(
        id: UUID = UUID(),
        sessionID: UUID,
        exerciseID: UUID,
        displayName: String,
        weight: Double,
        reps: Int,
        estimatedOneRepMax: Double,
        achievedAt: Date
    ) {
        self.id = id
        self.sessionID = sessionID
        self.exerciseID = exerciseID
        self.displayName = displayName
        self.weight = weight
        self.reps = reps
        self.estimatedOneRepMax = estimatedOneRepMax
        self.achievedAt = achievedAt
    }
}

struct ExerciseAnalyticsSummary: Identifiable, Equatable {
    var id: UUID { exerciseID }
    var exerciseID: UUID
    var displayName: String
    var pointCount: Int
    var totalVolume: Double
    var currentPR: PersonalRecord?
    var points: [ProgressPoint]
}

struct ProgressOverview: Equatable {
    var totalSessions: Int
    var sessionsThisWeek: Int
    var sessionsLast30Days: Int
    var totalVolume: Double
    var averageSessionsPerWeek: Double

    static let empty = ProgressOverview(
        totalSessions: 0,
        sessionsThisWeek: 0,
        sessionsLast30Days: 0,
        totalVolume: 0,
        averageSessionsPerWeek: 0
    )
}

struct SessionFinishSummary: Identifiable, Equatable {
    var id: UUID
    var templateName: String
    var completedAt: Date
    var completedSetCount: Int
    var totalVolume: Double
    var personalRecords: [PersonalRecord]

    init(
        id: UUID = UUID(),
        templateName: String,
        completedAt: Date,
        completedSetCount: Int,
        totalVolume: Double,
        personalRecords: [PersonalRecord]
    ) {
        self.id = id
        self.templateName = templateName
        self.completedAt = completedAt
        self.completedSetCount = completedSetCount
        self.totalVolume = totalVolume
        self.personalRecords = personalRecords
    }
}

enum PresetPack: String, CaseIterable, Identifiable {
    case generalGym
    case startingStrength
    case fiveThreeOne
    case boringButBig

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .generalGym:
            return "General Gym"
        case .startingStrength:
            return "Starting Strength"
        case .fiveThreeOne:
            return "5/3/1"
        case .boringButBig:
            return "Boring But Big"
        }
    }

    var description: String {
        switch self {
        case .generalGym:
            return "Balanced upper/lower templates with flexible progression for mixed gym training."
        case .startingStrength:
            return "Simple barbell-focused A/B sessions using double progression."
        case .fiveThreeOne:
            return "Four main-lift days powered by generic percentage-wave progression."
        case .boringButBig:
            return "5/3/1 main work plus 5x10 supplemental volume."
        }
    }

    var systemImage: String {
        switch self {
        case .generalGym:
            return "square.grid.2x2"
        case .startingStrength:
            return "figure.strengthtraining.traditional"
        case .fiveThreeOne:
            return "number"
        case .boringButBig:
            return "chart.bar.doc.horizontal"
        }
    }
}

enum CatalogSeed {
    static let benchPress = UUID(uuidString: "9D4E02E5-FE6A-4A29-9706-52AE57E21400")!
    static let inclineBenchPress = UUID(uuidString: "A23712A8-FA3B-4231-A9CC-F56B4E0A1A02")!
    static let dumbbellFly = UUID(uuidString: "C33BE145-B321-4C14-B6B8-BB384E2B0280")!
    static let backSquat = UUID(uuidString: "4B572B89-5A24-43E0-9A8C-4FD96EC60F85")!
    static let frontSquat = UUID(uuidString: "E9B7A3B0-65E0-4D4D-A7C3-03C5E4F45E56")!
    static let deadlift = UUID(uuidString: "7A8C8F4E-97D3-4384-8C5B-2FC4B0F79F76")!
    static let romanianDeadlift = UUID(uuidString: "4BB1B3B3-9036-45B4-A94F-0F74A9E613E1")!
    static let overheadPress = UUID(uuidString: "6B2AB7AA-C4C7-4C5A-AB11-08D0773F2C4A")!
    static let dumbbellShoulderPress = UUID(uuidString: "6302DDF0-66D2-487E-A065-C19BAF820A85")!
    static let powerClean = UUID(uuidString: "9C880197-BDF5-44F0-B0C4-B4C7067B5584")!
    static let barbellRow = UUID(uuidString: "581C76C0-D2F9-4983-90A1-0B75A7940C93")!
    static let pullUp = UUID(uuidString: "8446357E-46D5-4ACE-96FD-73CBA1B988F2")!
    static let weightedPullUp = UUID(uuidString: "3D09C996-3D5E-4B39-9D82-F4CDB76196C5")!
    static let latPulldown = UUID(uuidString: "51852E98-96A5-4B28-BE98-7259C821AB3E")!
    static let seatedCableRow = UUID(uuidString: "1BCB11A6-D81D-41A0-81CF-9A9E016F417D")!
    static let dips = UUID(uuidString: "BC345C05-A84A-46AC-BB10-A47C8520E08B")!
    static let lateralRaise = UUID(uuidString: "A7FA92CF-E3A4-4A12-897E-EC63E599A906")!
    static let facePull = UUID(uuidString: "8D6E8B56-ACD7-4687-8AFE-0A7D84B0A189")!
    static let rearDeltFly = UUID(uuidString: "D40CF4D4-362C-4E53-B736-DAA80D567456")!
    static let tricepsPushdown = UUID(uuidString: "03472BC6-B9CB-41AB-80A6-B0C786AB9F5E")!
    static let skullCrusher = UUID(uuidString: "980F575D-F91D-4CF9-B225-F3540C07A5C5")!
    static let barbellCurl = UUID(uuidString: "A8001A73-530A-4F70-9CD4-B82F520E278E")!
    static let hammerCurl = UUID(uuidString: "9FD7BC0E-BEAF-4893-8AFB-975652F357A4")!
    static let legPress = UUID(uuidString: "61021D3E-3AA9-4393-B734-81D96DE2D645")!
    static let legCurl = UUID(uuidString: "BF1C7685-D25F-45E6-9C3F-E31B9E44E83A")!
    static let legExtension = UUID(uuidString: "8BFF0227-117A-4E28-A5F2-09EC28EAB23E")!
    static let walkingLunge = UUID(uuidString: "A6D885B0-A734-4CD6-9676-E8379F50B74C")!
    static let bulgarianSplitSquat = UUID(uuidString: "E4BF4790-144A-4D13-B782-017E732B47DB")!
    static let hipThrust = UUID(uuidString: "0AA75AAB-BE44-4B58-96D6-E2507066E8BF")!
    static let standingCalfRaise = UUID(uuidString: "E3F726AF-A4A9-4A72-B26A-C48E2174B94F")!
    static let seatedCalfRaise = UUID(uuidString: "5F388D61-742B-4AB2-B1FB-C0E96D08B236")!

    static func defaultCatalog() -> [ExerciseCatalogItem] {
        [
            ExerciseCatalogItem(id: benchPress, name: "Bench Press", category: .chest, equipment: "Barbell"),
            ExerciseCatalogItem(id: inclineBenchPress, name: "Incline Bench Press", category: .chest, equipment: "Barbell"),
            ExerciseCatalogItem(id: dumbbellFly, name: "Dumbbell Fly", category: .chest, equipment: "Dumbbell"),
            ExerciseCatalogItem(id: backSquat, name: "Back Squat", category: .legs, equipment: "Barbell"),
            ExerciseCatalogItem(id: frontSquat, name: "Front Squat", category: .legs, equipment: "Barbell"),
            ExerciseCatalogItem(id: deadlift, name: "Deadlift", category: .legs, equipment: "Barbell"),
            ExerciseCatalogItem(id: romanianDeadlift, name: "Romanian Deadlift", category: .legs, equipment: "Barbell"),
            ExerciseCatalogItem(id: overheadPress, name: "Overhead Press", category: .shoulders, equipment: "Barbell"),
            ExerciseCatalogItem(id: dumbbellShoulderPress, name: "Dumbbell Shoulder Press", category: .shoulders, equipment: "Dumbbell"),
            ExerciseCatalogItem(id: powerClean, name: "Power Clean", category: .fullBody, equipment: "Barbell"),
            ExerciseCatalogItem(id: barbellRow, name: "Barbell Row", category: .back, equipment: "Barbell"),
            ExerciseCatalogItem(id: pullUp, name: "Pull Up", category: .back, equipment: "Bodyweight"),
            ExerciseCatalogItem(id: weightedPullUp, name: "Weighted Pull Up", aliases: ["Pull Up"], category: .back, equipment: "Bodyweight"),
            ExerciseCatalogItem(id: latPulldown, name: "Lat Pulldown", category: .back, equipment: "Cable"),
            ExerciseCatalogItem(id: seatedCableRow, name: "Seated Cable Row", category: .back, equipment: "Cable"),
            ExerciseCatalogItem(id: dips, name: "Dips", category: .chest, equipment: "Bodyweight"),
            ExerciseCatalogItem(id: lateralRaise, name: "Lateral Raise", category: .shoulders, equipment: "Dumbbell"),
            ExerciseCatalogItem(id: facePull, name: "Face Pull", category: .shoulders, equipment: "Cable"),
            ExerciseCatalogItem(id: rearDeltFly, name: "Rear Delt Fly", category: .shoulders, equipment: "Dumbbell"),
            ExerciseCatalogItem(id: tricepsPushdown, name: "Triceps Pushdown", category: .arms, equipment: "Cable"),
            ExerciseCatalogItem(id: skullCrusher, name: "Skull Crusher", category: .arms, equipment: "EZ Bar"),
            ExerciseCatalogItem(id: barbellCurl, name: "Barbell Curl", category: .arms, equipment: "Barbell"),
            ExerciseCatalogItem(id: hammerCurl, name: "Hammer Curl", category: .arms, equipment: "Dumbbell"),
            ExerciseCatalogItem(id: legPress, name: "Leg Press", category: .legs, equipment: "Machine"),
            ExerciseCatalogItem(id: legCurl, name: "Leg Curl", category: .legs, equipment: "Machine"),
            ExerciseCatalogItem(id: legExtension, name: "Leg Extension", category: .legs, equipment: "Machine"),
            ExerciseCatalogItem(id: walkingLunge, name: "Walking Lunge", category: .legs, equipment: "Dumbbell"),
            ExerciseCatalogItem(id: bulgarianSplitSquat, name: "Bulgarian Split Squat", category: .legs, equipment: "Dumbbell"),
            ExerciseCatalogItem(id: hipThrust, name: "Hip Thrust", category: .legs, equipment: "Barbell"),
            ExerciseCatalogItem(id: standingCalfRaise, name: "Standing Calf Raise", category: .legs, equipment: "Machine"),
            ExerciseCatalogItem(id: seatedCalfRaise, name: "Seated Calf Raise", category: .legs, equipment: "Machine")
        ]
    }
}

extension String {
    var nonEmptyTrimmed: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

extension Array {
    @discardableResult
    mutating func removeIfPresent(at index: Int) -> Bool {
        guard indices.contains(index) else {
            return false
        }

        remove(at: index)
        return true
    }
}
