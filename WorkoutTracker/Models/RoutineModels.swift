import Foundation

enum StrengthProgressionDefaults {
    static let gymRoundingIncrement = 2.5
    static let upperBodyIncreaseInPounds = 2.5
    static let lowerBodyIncreaseInPounds = 5.0
}

enum ExerciseBlockDefaults {
    static let restSeconds = 90
    static let setCount = 3
    static let repRange = RepRange(8, 12)
}

enum DoubleProgressionDefaults {
    static let repRange = RepRange(6, 10)
}

enum WarmupDefaults {
    static let note = "Auto warmup"
    static let ramp = [
        WarmupRampStep(percentage: 0.40, reps: 5),
        WarmupRampStep(percentage: 0.60, reps: 3)
    ]
}

enum AnalyticsDefaults {
    static let rollingWindowDays = 30
    static let recentActivityLimit = 5
    static let quickStartLimit = 4
    static let secondsPerWeek: TimeInterval = 60 * 60 * 24 * 7
    static let oneRepMaxDivisor = 30.0

    static func rollingWindowStart(from startOfToday: Date, calendar: Calendar) -> Date {
        calendar.date(byAdding: .day, value: -rollingWindowDays, to: startOfToday) ?? startOfToday
    }

    static func weeksSpan(from firstSessionDate: Date, to startOfToday: Date) -> Double {
        max(1.0, startOfToday.timeIntervalSince(firstSessionDate) / secondsPerWeek)
    }
}

enum WeightUnit: String, CaseIterable, Codable, Sendable {
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
        "hip thrust"
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
                    PercentageWaveSet(percentage: 0.85, repRange: RepRange(5, 5), note: "AMRAP")
                ]
            ),
            PercentageWaveWeek(
                name: "Week 2",
                sets: [
                    PercentageWaveSet(percentage: 0.70, repRange: RepRange(3, 3)),
                    PercentageWaveSet(percentage: 0.80, repRange: RepRange(3, 3)),
                    PercentageWaveSet(percentage: 0.90, repRange: RepRange(3, 3), note: "AMRAP")
                ]
            ),
            PercentageWaveWeek(
                name: "Week 3",
                sets: [
                    PercentageWaveSet(percentage: 0.75, repRange: RepRange(5, 5)),
                    PercentageWaveSet(percentage: 0.85, repRange: RepRange(3, 3)),
                    PercentageWaveSet(percentage: 0.95, repRange: RepRange(1, 1), note: "AMRAP")
                ]
            ),
            PercentageWaveWeek(
                name: "Deload",
                sets: [
                    PercentageWaveSet(percentage: 0.40, repRange: RepRange(5, 5)),
                    PercentageWaveSet(percentage: 0.50, repRange: RepRange(5, 5)),
                    PercentageWaveSet(percentage: 0.60, repRange: RepRange(5, 5))
                ]
            )
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

struct SessionBlock: Identifiable, Codable, Equatable, Sendable {
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
        blockNote: String = "",
        restSeconds: Int,
        supersetGroup: String? = nil,
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

struct SessionDraft: Identifiable, Codable, Equatable, Sendable {
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

struct CompletedSessionBlock: Identifiable, Codable, Equatable, Sendable {
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

struct CompletedSession: Identifiable, Codable, Equatable, Sendable {
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

struct TemplateReference: Identifiable, Equatable, Sendable {
    var id: UUID { templateID }
    var planID: UUID
    var planName: String
    var templateID: UUID
    var templateName: String
    var scheduledWeekdays: [Weekday]
    var lastStartedAt: Date?
}

struct ProgressPoint: Identifiable, Equatable, Sendable {
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

struct PersonalRecord: Identifiable, Equatable, Sendable {
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

struct ExerciseAnalyticsSummary: Identifiable, Equatable, Sendable {
    var id: UUID { exerciseID }
    var exerciseID: UUID
    var displayName: String
    var pointCount: Int
    var totalVolume: Double
    var currentPR: PersonalRecord?
    var points: [ProgressPoint]
}

struct ProgressOverview: Equatable, Sendable {
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

struct SessionFinishSummary: Identifiable, Equatable, Sendable {
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

enum TemplateReferenceSelection {
    static func pinnedTemplate(
        from plans: [Plan],
        references: [TemplateReference],
        now: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> TemplateReference? {
        let referencesByTemplateID = Dictionary(uniqueKeysWithValues: references.map { ($0.templateID, $0) })
        let weekday = Weekday(rawValue: calendar.component(.weekday, from: now))

        if let weekday,
           let scheduledToday = references.first(where: { $0.scheduledWeekdays.contains(weekday) }) {
            return scheduledToday
        }

        for plan in plans {
            if let pinnedTemplateID = plan.pinnedTemplateID,
               let pinned = referencesByTemplateID[pinnedTemplateID] {
                return pinned
            }
        }

        return references.max(by: {
            ($0.lastStartedAt ?? .distantPast) < ($1.lastStartedAt ?? .distantPast)
        }) ?? references.first
    }

    static func quickStarts(
        references: [TemplateReference],
        sessions: [CompletedSession],
        limit: Int = AnalyticsDefaults.quickStartLimit
    ) -> [TemplateReference] {
        let referencesByTemplateID = Dictionary(uniqueKeysWithValues: references.map { ($0.templateID, $0) })
        let recentTemplateIDs = sessions.reversed().map(\.templateID)
        var resolved: [TemplateReference] = []
        var seenTemplateIDs: Set<UUID> = []

        for templateID in recentTemplateIDs {
            guard let match = referencesByTemplateID[templateID],
                  seenTemplateIDs.insert(match.templateID).inserted else {
                continue
            }

            resolved.append(match)
            if resolved.count == limit {
                return resolved
            }
        }

        for reference in references where seenTemplateIDs.insert(reference.templateID).inserted {
            resolved.append(reference)
            if resolved.count == limit {
                break
            }
        }

        return resolved
    }
}

enum PersonalRecordSelection {
    static func mergedNewestFirst(
        _ newRecords: [PersonalRecord],
        existingRecords: [PersonalRecord],
        limit: Int? = nil
    ) -> [PersonalRecord] {
        let mergedRecords = Array(newRecords.reversed()) + existingRecords
        var seenRecordIDs: Set<UUID> = []
        let deduplicated = mergedRecords.filter { record in
            seenRecordIDs.insert(record.id).inserted
        }

        if let limit {
            return Array(deduplicated.prefix(limit))
        }

        return deduplicated
    }
}

enum ExerciseAnalyticsSelection {
    static func selectedExerciseID(
        _ currentSelection: UUID?,
        summaries: [ExerciseAnalyticsSummary]
    ) -> UUID? {
        guard !summaries.isEmpty else {
            return nil
        }

        if let currentSelection,
           summaries.contains(where: { $0.exerciseID == currentSelection }) {
            return currentSelection
        }

        return summaries.first?.exerciseID
    }
}

enum PresetPack: String, CaseIterable, Identifiable, Sendable {
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
            ExerciseCatalogItem(id: benchPress, name: "Bench Press", category: .chest),
            ExerciseCatalogItem(id: inclineBenchPress, name: "Incline Bench Press", category: .chest),
            ExerciseCatalogItem(id: dumbbellFly, name: "Dumbbell Fly", category: .chest),
            ExerciseCatalogItem(id: backSquat, name: "Back Squat", category: .legs),
            ExerciseCatalogItem(id: frontSquat, name: "Front Squat", category: .legs),
            ExerciseCatalogItem(id: deadlift, name: "Deadlift", category: .legs),
            ExerciseCatalogItem(id: romanianDeadlift, name: "Romanian Deadlift", category: .legs),
            ExerciseCatalogItem(id: overheadPress, name: "Overhead Press", category: .shoulders),
            ExerciseCatalogItem(id: dumbbellShoulderPress, name: "Dumbbell Shoulder Press", category: .shoulders),
            ExerciseCatalogItem(id: powerClean, name: "Power Clean", category: .fullBody),
            ExerciseCatalogItem(id: barbellRow, name: "Barbell Row", category: .back),
            ExerciseCatalogItem(id: pullUp, name: "Pull Up", category: .back),
            ExerciseCatalogItem(id: weightedPullUp, name: "Weighted Pull Up", aliases: ["Pull Up"], category: .back),
            ExerciseCatalogItem(id: latPulldown, name: "Lat Pulldown", category: .back),
            ExerciseCatalogItem(id: seatedCableRow, name: "Seated Cable Row", category: .back),
            ExerciseCatalogItem(id: dips, name: "Dips", category: .chest),
            ExerciseCatalogItem(id: lateralRaise, name: "Lateral Raise", category: .shoulders),
            ExerciseCatalogItem(id: facePull, name: "Face Pull", category: .shoulders),
            ExerciseCatalogItem(id: rearDeltFly, name: "Rear Delt Fly", category: .shoulders),
            ExerciseCatalogItem(id: tricepsPushdown, name: "Triceps Pushdown", category: .arms),
            ExerciseCatalogItem(id: skullCrusher, name: "Skull Crusher", category: .arms),
            ExerciseCatalogItem(id: barbellCurl, name: "Barbell Curl", category: .arms),
            ExerciseCatalogItem(id: hammerCurl, name: "Hammer Curl", category: .arms),
            ExerciseCatalogItem(id: legPress, name: "Leg Press", category: .legs),
            ExerciseCatalogItem(id: legCurl, name: "Leg Curl", category: .legs),
            ExerciseCatalogItem(id: legExtension, name: "Leg Extension", category: .legs),
            ExerciseCatalogItem(id: walkingLunge, name: "Walking Lunge", category: .legs),
            ExerciseCatalogItem(id: bulgarianSplitSquat, name: "Bulgarian Split Squat", category: .legs),
            ExerciseCatalogItem(id: hipThrust, name: "Hip Thrust", category: .legs),
            ExerciseCatalogItem(id: standingCalfRaise, name: "Standing Calf Raise", category: .legs),
            ExerciseCatalogItem(id: seatedCalfRaise, name: "Seated Calf Raise", category: .legs)
        ]
    }
}

extension String {
    var nonEmptyTrimmed: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
