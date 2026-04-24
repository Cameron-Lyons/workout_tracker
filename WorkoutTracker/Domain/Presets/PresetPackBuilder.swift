import Foundation

@MainActor
enum PresetPackBuilder {
    fileprivate static let catalogByKey: [String: ExerciseCatalogItem] = [
        "benchPress": ExerciseCatalogItem(id: CatalogSeed.benchPress, name: "Bench Press", category: .chest),
        "inclineBenchPress": ExerciseCatalogItem(id: CatalogSeed.inclineBenchPress, name: "Incline Bench Press", category: .chest),
        "dumbbellFly": ExerciseCatalogItem(id: CatalogSeed.dumbbellFly, name: "Dumbbell Fly", category: .chest),
        "backSquat": ExerciseCatalogItem(id: CatalogSeed.backSquat, name: "Back Squat", category: .legs),
        "frontSquat": ExerciseCatalogItem(id: CatalogSeed.frontSquat, name: "Front Squat", category: .legs),
        "deadlift": ExerciseCatalogItem(id: CatalogSeed.deadlift, name: "Deadlift", category: .legs),
        "romanianDeadlift": ExerciseCatalogItem(id: CatalogSeed.romanianDeadlift, name: "Romanian Deadlift", category: .legs),
        "overheadPress": ExerciseCatalogItem(id: CatalogSeed.overheadPress, name: "Overhead Press", category: .shoulders),
        "dumbbellShoulderPress": ExerciseCatalogItem(id: CatalogSeed.dumbbellShoulderPress, name: "Dumbbell Shoulder Press", category: .shoulders),
        "powerClean": ExerciseCatalogItem(id: CatalogSeed.powerClean, name: "Power Clean", category: .fullBody),
        "barbellRow": ExerciseCatalogItem(id: CatalogSeed.barbellRow, name: "Barbell Row", category: .back),
        "pullUp": ExerciseCatalogItem(id: CatalogSeed.pullUp, name: "Pull Up", category: .back),
        "weightedPullUp": ExerciseCatalogItem(id: CatalogSeed.weightedPullUp, name: "Weighted Pull Up", aliases: ["Pull Up"], category: .back),
        "latPulldown": ExerciseCatalogItem(id: CatalogSeed.latPulldown, name: "Lat Pulldown", category: .back),
        "seatedCableRow": ExerciseCatalogItem(id: CatalogSeed.seatedCableRow, name: "Seated Cable Row", category: .back),
        "dips": ExerciseCatalogItem(id: CatalogSeed.dips, name: "Dips", category: .chest),
        "lateralRaise": ExerciseCatalogItem(id: CatalogSeed.lateralRaise, name: "Lateral Raise", category: .shoulders),
        "facePull": ExerciseCatalogItem(id: CatalogSeed.facePull, name: "Face Pull", category: .shoulders),
        "rearDeltFly": ExerciseCatalogItem(id: CatalogSeed.rearDeltFly, name: "Rear Delt Fly", category: .shoulders),
        "tricepsPushdown": ExerciseCatalogItem(id: CatalogSeed.tricepsPushdown, name: "Triceps Pushdown", category: .arms),
        "skullCrusher": ExerciseCatalogItem(id: CatalogSeed.skullCrusher, name: "Skull Crusher", category: .arms),
        "barbellCurl": ExerciseCatalogItem(id: CatalogSeed.barbellCurl, name: "Barbell Curl", category: .arms),
        "hammerCurl": ExerciseCatalogItem(id: CatalogSeed.hammerCurl, name: "Hammer Curl", category: .arms),
        "legPress": ExerciseCatalogItem(id: CatalogSeed.legPress, name: "Leg Press", category: .legs),
        "legCurl": ExerciseCatalogItem(id: CatalogSeed.legCurl, name: "Leg Curl", category: .legs),
        "legExtension": ExerciseCatalogItem(id: CatalogSeed.legExtension, name: "Leg Extension", category: .legs),
        "walkingLunge": ExerciseCatalogItem(id: CatalogSeed.walkingLunge, name: "Walking Lunge", category: .legs),
        "bulgarianSplitSquat": ExerciseCatalogItem(id: CatalogSeed.bulgarianSplitSquat, name: "Bulgarian Split Squat", category: .legs),
        "hipThrust": ExerciseCatalogItem(id: CatalogSeed.hipThrust, name: "Hip Thrust", category: .legs),
        "standingCalfRaise": ExerciseCatalogItem(id: CatalogSeed.standingCalfRaise, name: "Standing Calf Raise", category: .legs),
        "seatedCalfRaise": ExerciseCatalogItem(id: CatalogSeed.seatedCalfRaise, name: "Seated Calf Raise", category: .legs),
    ]

    static func makePlans(for pack: PresetPack, settings: SettingsStore) -> [Plan] {
        guard let definition = PresetProgramCatalog.shared.program(for: pack) else {
            assertionFailure("Missing preset program definition for \(pack.rawValue)")
            return []
        }

        do {
            return [try buildPlan(from: definition, settings: settings)]
        } catch {
            assertionFailure("Invalid preset program \(pack.rawValue): \(error)")
            return []
        }
    }

    private static func buildPlan(
        from definition: PresetProgramDefinition,
        settings: SettingsStore
    ) throws -> Plan {
        var templates: [WorkoutTemplate] = []

        for templateDefinition in definition.templates {
            let exercises = try templateDefinition.exercises.map { exerciseDefinition in
                try buildExercise(from: exerciseDefinition, settings: settings)
            }
            templates.append(
                WorkoutTemplate(
                    name: templateDefinition.name,
                    scheduledWeekdays: templateDefinition.scheduledWeekdays ?? [],
                    exercises: exercises
                )
            )
        }

        guard let pinnedTemplateID = templates.first(where: { $0.name == definition.pinnedTemplate })?.id else {
            throw PresetProgramError.missingPinnedTemplate(definition.pinnedTemplate)
        }

        return Plan(
            name: definition.planName,
            pinnedTemplateID: pinnedTemplateID,
            templates: templates
        )
    }

    private static func buildExercise(
        from definition: PresetExerciseDefinition,
        settings: SettingsStore
    ) throws -> TemplateExercise {
        guard let catalogItem = catalogByKey[definition.exercise] else {
            throw PresetProgramError.unknownExercise(definition.exercise)
        }

        let progressionRule = try progressionRule(
            for: definition.progression,
            exerciseName: catalogItem.name,
            targets: definition.targets,
            settings: settings
        )
        var exercise = TemplateExercise(
            exerciseID: catalogItem.id,
            exerciseNameSnapshot: catalogItem.name,
            restSeconds: definition.restSeconds,
            supersetGroup: definition.supersetGroup,
            progressionRule: progressionRule,
            targets: try targets(from: definition.targets, requiresTargets: definition.progression != .wave)
        )

        if definition.progression == .wave {
            exercise.targets = ProgressionEngine.resolvedTargets(for: exercise, profile: nil)
        }

        return exercise
    }

    private static func progressionRule(
        for progression: PresetProgression,
        exerciseName: String,
        targets: PresetTargetDefinition?,
        settings: SettingsStore
    ) throws -> ProgressionRule {
        switch progression {
        case .manual:
            return .manual
        case .doubleUpper:
            return try doubleProgressionRule(targets: targets, increment: settings.upperBodyIncrement)
        case .doubleLower:
            return try doubleProgressionRule(targets: targets, increment: settings.lowerBodyIncrement)
        case .wave:
            return ProgressionRule(
                kind: .percentageWave,
                percentageWave: PercentageWaveRule.fiveThreeOne(
                    trainingMax: ExerciseRecommendationDefaults.defaultTrainingMax(for: exerciseName),
                    cycleIncrement: settings.preferredIncrement(for: exerciseName)
                )
            )
        }
    }

    private static func doubleProgressionRule(
        targets: PresetTargetDefinition?,
        increment: Double
    ) throws -> ProgressionRule {
        ProgressionRule(
            kind: .doubleProgression,
            doubleProgression: DoubleProgressionRule(
                targetRepRange: try primaryRepRange(from: targets),
                increment: increment
            )
        )
    }

    fileprivate static func targets(
        from definition: PresetTargetDefinition?,
        requiresTargets: Bool
    ) throws -> [SetTarget] {
        guard let definition else {
            if requiresTargets {
                throw PresetProgramError.missingTargets
            }
            return []
        }

        if let sets = definition.sets {
            return try sets.map { set in
                SetTarget(repRange: try set.repRangeValue(), note: set.note)
            }
        }

        guard let count = definition.count, count > 0 else {
            throw PresetProgramError.invalidTargetCount(definition.count ?? 0)
        }

        let repRange = try definition.repRangeValue()
        return (0..<count).map { index in
            SetTarget(
                repRange: repRange,
                note: index == count - 1 ? definition.finalSetNote ?? definition.note : definition.note
            )
        }
    }

    fileprivate static func primaryRepRange(from definition: PresetTargetDefinition?) throws -> RepRange {
        guard let definition else {
            throw PresetProgramError.missingTargets
        }

        if let sets = definition.sets, let firstSet = sets.first {
            return try firstSet.repRangeValue()
        }

        return try definition.repRangeValue()
    }
}

private enum PresetProgression: String, Decodable {
    case manual
    case doubleUpper
    case doubleLower
    case wave
}

private struct PresetProgramCatalogFile: Decodable {
    var programs: [PresetProgramDefinition]
}

private struct PresetProgramDefinition: Decodable {
    var pack: PresetPack
    var planName: String
    var pinnedTemplate: String
    var templates: [PresetTemplateDefinition]
}

private struct PresetTemplateDefinition: Decodable {
    var name: String
    var scheduledWeekdays: [Weekday]?
    var exercises: [PresetExerciseDefinition]

    private enum CodingKeys: String, CodingKey {
        case name
        case scheduledWeekdays
        case exercises
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decode(String.self, forKey: .name)
        exercises = try container.decode([PresetExerciseDefinition].self, forKey: .exercises)

        let weekdayKeys = try container.decodeIfPresent([String].self, forKey: .scheduledWeekdays)
        scheduledWeekdays = try weekdayKeys?.map { weekdayKey in
            switch weekdayKey {
            case "sunday":
                return .sunday
            case "monday":
                return .monday
            case "tuesday":
                return .tuesday
            case "wednesday":
                return .wednesday
            case "thursday":
                return .thursday
            case "friday":
                return .friday
            case "saturday":
                return .saturday
            default:
                throw DecodingError.dataCorruptedError(
                    forKey: .scheduledWeekdays,
                    in: container,
                    debugDescription: "Unknown weekday '\(weekdayKey)'."
                )
            }
        }
    }
}

private struct PresetExerciseDefinition: Decodable {
    var exercise: String
    var restSeconds: Int
    var supersetGroup: String?
    var progression: PresetProgression
    var targets: PresetTargetDefinition?
}

private struct PresetTargetDefinition: Decodable {
    var count: Int?
    var repRange: [Int]?
    var note: String?
    var finalSetNote: String?
    var sets: [PresetSetDefinition]?

    func repRangeValue() throws -> RepRange {
        try Self.repRangeValue(from: repRange)
    }

    static func repRangeValue(from values: [Int]?) throws -> RepRange {
        guard let values, values.count == 2 else {
            throw PresetProgramError.invalidRepRange(values ?? [])
        }

        guard values[0] > 0, values[0] <= values[1] else {
            throw PresetProgramError.invalidRepRange(values)
        }

        return RepRange(values[0], values[1])
    }
}

private struct PresetSetDefinition: Decodable {
    var repRange: [Int]
    var note: String?

    func repRangeValue() throws -> RepRange {
        try PresetTargetDefinition.repRangeValue(from: repRange)
    }
}

private enum PresetProgramError: Error, CustomStringConvertible {
    case missingResource
    case missingPinnedTemplate(String)
    case missingTargets
    case unknownExercise(String)
    case invalidRepRange([Int])
    case invalidTargetCount(Int)
    case duplicateProgram(String)
    case emptyProgram(String)
    case emptyTemplate(String)
    case missingProgram(String)

    var description: String {
        switch self {
        case .missingResource:
            return "PresetPrograms.json was not found."
        case let .missingPinnedTemplate(name):
            return "Pinned template '\(name)' does not exist."
        case .missingTargets:
            return "Non-wave exercises must declare targets."
        case let .unknownExercise(key):
            return "Unknown exercise key '\(key)'."
        case let .invalidRepRange(values):
            return "Invalid rep range \(values)."
        case let .invalidTargetCount(count):
            return "Invalid target count \(count)."
        case let .duplicateProgram(pack):
            return "Duplicate program definition for '\(pack)'."
        case let .emptyProgram(pack):
            return "Program '\(pack)' has no templates."
        case let .emptyTemplate(name):
            return "Template '\(name)' has no exercises."
        case let .missingProgram(pack):
            return "Program '\(pack)' is not defined."
        }
    }
}

@MainActor
private final class PresetProgramCatalog {
    static let shared = PresetProgramCatalog()

    private let programsByPack: [PresetPack: PresetProgramDefinition]

    private init() {
        do {
            let catalog = try Self.loadCatalog()
            try Self.validate(catalog)
            programsByPack = Dictionary(uniqueKeysWithValues: catalog.programs.map { ($0.pack, $0) })
        } catch {
            assertionFailure("Unable to load preset program catalog: \(error)")
            programsByPack = [:]
        }
    }

    func program(for pack: PresetPack) -> PresetProgramDefinition? {
        programsByPack[pack]
    }

    private static func loadCatalog() throws -> PresetProgramCatalogFile {
        let url = try resourceURL()
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(PresetProgramCatalogFile.self, from: data)
    }

    private static func resourceURL() throws -> URL {
        for bundle in Bundle.allBundles + Bundle.allFrameworks {
            if let url = bundle.url(forResource: "PresetPrograms", withExtension: "json", subdirectory: "Presets") {
                return url
            }
            if let url = bundle.url(forResource: "PresetPrograms", withExtension: "json") {
                return url
            }
        }

        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Resources/Presets/PresetPrograms.json")
        if FileManager.default.fileExists(atPath: sourceURL.path) {
            return sourceURL
        }

        throw PresetProgramError.missingResource
    }

    private static func validate(_ catalog: PresetProgramCatalogFile) throws {
        var seenPacks = Set<PresetPack>()
        for program in catalog.programs {
            guard seenPacks.insert(program.pack).inserted else {
                throw PresetProgramError.duplicateProgram(program.pack.rawValue)
            }
            guard !program.templates.isEmpty else {
                throw PresetProgramError.emptyProgram(program.pack.rawValue)
            }
            guard program.templates.contains(where: { $0.name == program.pinnedTemplate }) else {
                throw PresetProgramError.missingPinnedTemplate(program.pinnedTemplate)
            }

            for template in program.templates {
                guard !template.exercises.isEmpty else {
                    throw PresetProgramError.emptyTemplate(template.name)
                }
                for exercise in template.exercises {
                    guard PresetPackBuilder.catalogByKey[exercise.exercise] != nil else {
                        throw PresetProgramError.unknownExercise(exercise.exercise)
                    }
                    _ = try PresetPackBuilder.targets(
                        from: exercise.targets,
                        requiresTargets: exercise.progression != .wave
                    )
                    if exercise.progression != .manual, exercise.progression != .wave {
                        _ = try PresetPackBuilder.primaryRepRange(from: exercise.targets)
                    }
                }
            }
        }

        for pack in PresetPack.allCases where !seenPacks.contains(pack) {
            throw PresetProgramError.missingProgram(pack.rawValue)
        }
    }
}
