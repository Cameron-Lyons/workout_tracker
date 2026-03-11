import Foundation

@MainActor
enum PresetPackBuilder {
    private enum PresetPackRest {
        static let accessory = 60
        static let unilateralAccessory = 75
        static let standard = ExerciseBlockDefaults.restSeconds
        static let compound = 120
        static let mainLift = 150
        static let waveMainLift = 180
    }

    private enum PresetPackSets {
        static let standard = ExerciseBlockDefaults.setCount
        static let deadliftTopSets = 2
        static let singleTopSet = 1
        static let powerCleanSets = 5
        static let boringButBig = 5
    }

    private enum PresetPackRepRange {
        static let upperMain = RepRange(6, 8)
        static let row = RepRange(8, 10)
        static let posteriorChain = DoubleProgressionDefaults.repRange
        static let shoulders = RepRange(12, 15)
        static let accessory = RepRange(10, 15)
        static let squatVolume = RepRange(5, 8)
        static let heavyPull = RepRange(4, 6)
        static let calves = RepRange(12, 20)
        static let strength = RepRange(5, 5)
        static let power = RepRange(3, 3)
        static let boringButBig = RepRange(10, 10)
    }

    private enum PresetPackLabels {
        static let boringButBig = "BBB 5x10"
    }

    private enum PresetPackTrainingMax {
        static let benchPress = 135.0
        static let overheadPress = 95.0
        static let backSquat = 185.0
        static let deadlift = 225.0
    }

    static func makePlans(for pack: PresetPack, settings: SettingsStore) -> [Plan] {
        switch pack {
        case .generalGym:
            return [makeGeneralGymPlan(settings: settings)]
        case .startingStrength:
            return [makeStartingStrengthPlan(settings: settings)]
        case .fiveThreeOne:
            return [makeFiveThreeOnePlan()]
        case .boringButBig:
            return [makeBoringButBigPlan()]
        }
    }

    private static func makeGeneralGymPlan(settings: SettingsStore) -> Plan {
        let upperRule = SessionEngine.defaultDoubleProgressionRule(
            exerciseName: "Bench Press",
            preferredIncrement: settings.upperBodyIncrement
        )
        let lowerRule = SessionEngine.defaultDoubleProgressionRule(
            exerciseName: "Back Squat",
            preferredIncrement: settings.lowerBodyIncrement
        )

        let upperA = WorkoutTemplate(
            name: "Upper A",
            scheduledWeekdays: [.monday, .thursday],
            blocks: [
                ExerciseBlock(
                    exerciseID: CatalogSeed.benchPress,
                    exerciseNameSnapshot: "Bench Press",
                    restSeconds: PresetPackRest.compound,
                    progressionRule: upperRule,
                    targets: repeatedTargets(repRange: PresetPackRepRange.upperMain)
                ),
                ExerciseBlock(
                    exerciseID: CatalogSeed.barbellRow,
                    exerciseNameSnapshot: "Barbell Row",
                    restSeconds: PresetPackRest.compound,
                    progressionRule: upperRule,
                    targets: repeatedTargets(repRange: PresetPackRepRange.row)
                ),
                ExerciseBlock(
                    exerciseID: CatalogSeed.lateralRaise,
                    exerciseNameSnapshot: "Lateral Raise",
                    restSeconds: PresetPackRest.accessory,
                    supersetGroup: "A",
                    progressionRule: .manual,
                    targets: repeatedTargets(repRange: PresetPackRepRange.shoulders)
                ),
                ExerciseBlock(
                    exerciseID: CatalogSeed.tricepsPushdown,
                    exerciseNameSnapshot: "Triceps Pushdown",
                    restSeconds: PresetPackRest.accessory,
                    supersetGroup: "A",
                    progressionRule: .manual,
                    targets: repeatedTargets(repRange: PresetPackRepRange.accessory)
                ),
            ]
        )

        let lowerA = WorkoutTemplate(
            name: "Lower A",
            scheduledWeekdays: [.tuesday, .friday],
            blocks: [
                ExerciseBlock(
                    exerciseID: CatalogSeed.backSquat,
                    exerciseNameSnapshot: "Back Squat",
                    restSeconds: PresetPackRest.mainLift,
                    progressionRule: lowerRule,
                    targets: repeatedTargets(repRange: PresetPackRepRange.squatVolume)
                ),
                ExerciseBlock(
                    exerciseID: CatalogSeed.romanianDeadlift,
                    exerciseNameSnapshot: "Romanian Deadlift",
                    restSeconds: PresetPackRest.compound,
                    progressionRule: lowerRule,
                    targets: repeatedTargets(repRange: PresetPackRepRange.posteriorChain)
                ),
                ExerciseBlock(
                    exerciseID: CatalogSeed.legPress,
                    exerciseNameSnapshot: "Leg Press",
                    restSeconds: PresetPackRest.standard,
                    progressionRule: .manual,
                    targets: repeatedTargets(repRange: PresetPackRepRange.accessory)
                ),
                ExerciseBlock(
                    exerciseID: CatalogSeed.standingCalfRaise,
                    exerciseNameSnapshot: "Standing Calf Raise",
                    restSeconds: PresetPackRest.accessory,
                    progressionRule: .manual,
                    targets: repeatedTargets(repRange: PresetPackRepRange.calves)
                ),
            ]
        )

        let upperB = WorkoutTemplate(
            name: "Upper B",
            blocks: [
                ExerciseBlock(
                    exerciseID: CatalogSeed.overheadPress,
                    exerciseNameSnapshot: "Overhead Press",
                    restSeconds: PresetPackRest.compound,
                    progressionRule: upperRule,
                    targets: repeatedTargets(repRange: PresetPackRepRange.upperMain)
                ),
                ExerciseBlock(
                    exerciseID: CatalogSeed.pullUp,
                    exerciseNameSnapshot: "Pull Up",
                    restSeconds: PresetPackRest.compound,
                    progressionRule: .manual,
                    targets: repeatedTargets(repRange: PresetPackRepRange.posteriorChain)
                ),
                ExerciseBlock(
                    exerciseID: CatalogSeed.inclineBenchPress,
                    exerciseNameSnapshot: "Incline Bench Press",
                    restSeconds: PresetPackRest.standard,
                    supersetGroup: "B",
                    progressionRule: .manual,
                    targets: repeatedTargets(repRange: ExerciseBlockDefaults.repRange)
                ),
                ExerciseBlock(
                    exerciseID: CatalogSeed.hammerCurl,
                    exerciseNameSnapshot: "Hammer Curl",
                    restSeconds: PresetPackRest.accessory,
                    supersetGroup: "B",
                    progressionRule: .manual,
                    targets: repeatedTargets(repRange: PresetPackRepRange.accessory)
                ),
            ]
        )

        let lowerB = WorkoutTemplate(
            name: "Lower B",
            blocks: [
                ExerciseBlock(
                    exerciseID: CatalogSeed.deadlift,
                    exerciseNameSnapshot: "Deadlift",
                    restSeconds: PresetPackRest.mainLift,
                    progressionRule: lowerRule,
                    targets: repeatedTargets(
                        count: PresetPackSets.deadliftTopSets,
                        repRange: PresetPackRepRange.heavyPull
                    )
                ),
                ExerciseBlock(
                    exerciseID: CatalogSeed.frontSquat,
                    exerciseNameSnapshot: "Front Squat",
                    restSeconds: PresetPackRest.compound,
                    progressionRule: lowerRule,
                    targets: repeatedTargets(repRange: PresetPackRepRange.upperMain)
                ),
                ExerciseBlock(
                    exerciseID: CatalogSeed.bulgarianSplitSquat,
                    exerciseNameSnapshot: "Bulgarian Split Squat",
                    restSeconds: PresetPackRest.unilateralAccessory,
                    supersetGroup: "C",
                    progressionRule: .manual,
                    targets: repeatedTargets(repRange: ExerciseBlockDefaults.repRange)
                ),
                ExerciseBlock(
                    exerciseID: CatalogSeed.legCurl,
                    exerciseNameSnapshot: "Leg Curl",
                    restSeconds: PresetPackRest.accessory,
                    supersetGroup: "C",
                    progressionRule: .manual,
                    targets: repeatedTargets(repRange: PresetPackRepRange.accessory)
                ),
            ]
        )

        return Plan(
            name: "General Gym",
            pinnedTemplateID: upperA.id,
            templates: [upperA, lowerA, upperB, lowerB]
        )
    }

    private static func makeStartingStrengthPlan(settings: SettingsStore) -> Plan {
        let squatRule = SessionEngine.defaultDoubleProgressionRule(
            exerciseName: "Back Squat",
            preferredIncrement: settings.lowerBodyIncrement
        )
        let upperRule = SessionEngine.defaultDoubleProgressionRule(
            exerciseName: "Bench Press",
            preferredIncrement: settings.upperBodyIncrement
        )

        let dayA = WorkoutTemplate(
            name: "Workout A",
            scheduledWeekdays: [.monday, .friday],
            blocks: [
                ExerciseBlock(
                    exerciseID: CatalogSeed.backSquat,
                    exerciseNameSnapshot: "Back Squat",
                    restSeconds: PresetPackRest.mainLift,
                    progressionRule: squatRule,
                    targets: repeatedTargets(repRange: PresetPackRepRange.strength)
                ),
                ExerciseBlock(
                    exerciseID: CatalogSeed.benchPress,
                    exerciseNameSnapshot: "Bench Press",
                    restSeconds: PresetPackRest.compound,
                    progressionRule: upperRule,
                    targets: repeatedTargets(repRange: PresetPackRepRange.strength)
                ),
                ExerciseBlock(
                    exerciseID: CatalogSeed.deadlift,
                    exerciseNameSnapshot: "Deadlift",
                    restSeconds: PresetPackRest.waveMainLift,
                    progressionRule: SessionEngine.defaultDoubleProgressionRule(
                        exerciseName: "Deadlift",
                        preferredIncrement: settings.lowerBodyIncrement
                    ),
                    targets: repeatedTargets(
                        count: PresetPackSets.singleTopSet,
                        repRange: PresetPackRepRange.strength
                    )
                ),
            ]
        )

        let dayB = WorkoutTemplate(
            name: "Workout B",
            scheduledWeekdays: [.wednesday],
            blocks: [
                ExerciseBlock(
                    exerciseID: CatalogSeed.backSquat,
                    exerciseNameSnapshot: "Back Squat",
                    restSeconds: PresetPackRest.mainLift,
                    progressionRule: squatRule,
                    targets: repeatedTargets(repRange: PresetPackRepRange.strength)
                ),
                ExerciseBlock(
                    exerciseID: CatalogSeed.overheadPress,
                    exerciseNameSnapshot: "Overhead Press",
                    restSeconds: PresetPackRest.compound,
                    progressionRule: upperRule,
                    targets: repeatedTargets(repRange: PresetPackRepRange.strength)
                ),
                ExerciseBlock(
                    exerciseID: CatalogSeed.powerClean,
                    exerciseNameSnapshot: "Power Clean",
                    restSeconds: PresetPackRest.compound,
                    progressionRule: upperRule,
                    targets: repeatedTargets(
                        count: PresetPackSets.powerCleanSets,
                        repRange: PresetPackRepRange.power
                    )
                ),
            ]
        )

        return Plan(
            name: "Starting Strength",
            pinnedTemplateID: dayA.id,
            templates: [dayA, dayB]
        )
    }

    private static func makeFiveThreeOnePlan() -> Plan {
        let squatDay = waveTemplate(
            name: "Squat Day",
            mainExerciseID: CatalogSeed.backSquat,
            mainExerciseName: "Back Squat",
            accessories: [
                accessoryBlock(id: CatalogSeed.frontSquat, name: "Front Squat"),
                accessoryBlock(id: CatalogSeed.legCurl, name: "Leg Curl"),
            ]
        )
        let benchDay = waveTemplate(
            name: "Bench Day",
            mainExerciseID: CatalogSeed.benchPress,
            mainExerciseName: "Bench Press",
            accessories: [
                accessoryBlock(id: CatalogSeed.pullUp, name: "Pull Up"),
                accessoryBlock(id: CatalogSeed.tricepsPushdown, name: "Triceps Pushdown"),
            ]
        )
        let deadliftDay = waveTemplate(
            name: "Deadlift Day",
            mainExerciseID: CatalogSeed.deadlift,
            mainExerciseName: "Deadlift",
            accessories: [
                accessoryBlock(id: CatalogSeed.barbellRow, name: "Barbell Row"),
                accessoryBlock(id: CatalogSeed.seatedCalfRaise, name: "Seated Calf Raise"),
            ]
        )
        let pressDay = waveTemplate(
            name: "Press Day",
            mainExerciseID: CatalogSeed.overheadPress,
            mainExerciseName: "Overhead Press",
            accessories: [
                accessoryBlock(id: CatalogSeed.latPulldown, name: "Lat Pulldown"),
                accessoryBlock(id: CatalogSeed.hammerCurl, name: "Hammer Curl"),
            ]
        )

        return Plan(
            name: "5/3/1",
            pinnedTemplateID: squatDay.id,
            templates: [squatDay, benchDay, deadliftDay, pressDay]
        )
    }

    private static func makeBoringButBigPlan() -> Plan {
        let squatDay = bbbTemplate(
            name: "BBB Squat Day",
            mainExerciseID: CatalogSeed.backSquat,
            mainExerciseName: "Back Squat",
            bbbExerciseID: CatalogSeed.backSquat,
            bbbExerciseName: "Back Squat"
        )
        let benchDay = bbbTemplate(
            name: "BBB Bench Day",
            mainExerciseID: CatalogSeed.benchPress,
            mainExerciseName: "Bench Press",
            bbbExerciseID: CatalogSeed.benchPress,
            bbbExerciseName: "Bench Press"
        )
        let deadliftDay = bbbTemplate(
            name: "BBB Deadlift Day",
            mainExerciseID: CatalogSeed.deadlift,
            mainExerciseName: "Deadlift",
            bbbExerciseID: CatalogSeed.deadlift,
            bbbExerciseName: "Deadlift"
        )
        let pressDay = bbbTemplate(
            name: "BBB Press Day",
            mainExerciseID: CatalogSeed.overheadPress,
            mainExerciseName: "Overhead Press",
            bbbExerciseID: CatalogSeed.overheadPress,
            bbbExerciseName: "Overhead Press"
        )

        return Plan(
            name: "Boring But Big",
            pinnedTemplateID: squatDay.id,
            templates: [squatDay, benchDay, deadliftDay, pressDay]
        )
    }

    private static func repeatedTargets(
        count: Int = PresetPackSets.standard,
        repRange: RepRange,
        note: String? = nil
    ) -> [SetTarget] {
        (0..<count).map { _ in
            SetTarget(repRange: repRange, note: note)
        }
    }

    private static func accessoryBlock(id: UUID, name: String) -> ExerciseBlock {
        ExerciseBlock(
            exerciseID: id,
            exerciseNameSnapshot: name,
            restSeconds: ExerciseBlockDefaults.restSeconds,
            progressionRule: .manual,
            targets: repeatedTargets(
                count: ExerciseBlockDefaults.setCount,
                repRange: ExerciseBlockDefaults.repRange
            )
        )
    }

    private static func waveProgressionRule(for exerciseID: UUID, exerciseName: String) -> ProgressionRule {
        ProgressionRule(
            kind: .percentageWave,
            percentageWave: PercentageWaveRule.fiveThreeOne(
                trainingMax: defaultTrainingMax(for: exerciseID),
                cycleIncrement: ExerciseClassification.isLowerBody(exerciseName) ? 10 : 5
            )
        )
    }

    private static func waveMainBlock(exerciseID: UUID, exerciseName: String) -> ExerciseBlock {
        var block = ExerciseBlock(
            exerciseID: exerciseID,
            exerciseNameSnapshot: exerciseName,
            restSeconds: PresetPackRest.waveMainLift,
            progressionRule: waveProgressionRule(for: exerciseID, exerciseName: exerciseName),
            targets: []
        )

        block.targets = ProgressionEngine.resolvedTargets(for: block, profile: nil)
        return block
    }

    private static func defaultTrainingMax(for exerciseID: UUID) -> Double? {
        switch exerciseID {
        case CatalogSeed.benchPress:
            return PresetPackTrainingMax.benchPress
        case CatalogSeed.overheadPress:
            return PresetPackTrainingMax.overheadPress
        case CatalogSeed.backSquat:
            return PresetPackTrainingMax.backSquat
        case CatalogSeed.deadlift:
            return PresetPackTrainingMax.deadlift
        default:
            return nil
        }
    }

    private static func waveTemplate(
        name: String,
        mainExerciseID: UUID,
        mainExerciseName: String,
        accessories: [ExerciseBlock]
    ) -> WorkoutTemplate {
        WorkoutTemplate(
            name: name,
            blocks: [waveMainBlock(exerciseID: mainExerciseID, exerciseName: mainExerciseName)] + accessories
        )
    }

    private static func bbbTemplate(
        name: String,
        mainExerciseID: UUID,
        mainExerciseName: String,
        bbbExerciseID: UUID,
        bbbExerciseName: String
    ) -> WorkoutTemplate {
        WorkoutTemplate(
            name: name,
            blocks: [
                waveMainBlock(exerciseID: mainExerciseID, exerciseName: mainExerciseName),
                ExerciseBlock(
                    exerciseID: bbbExerciseID,
                    exerciseNameSnapshot: bbbExerciseName,
                    restSeconds: PresetPackRest.compound,
                    progressionRule: .manual,
                    targets: repeatedTargets(
                        count: PresetPackSets.boringButBig,
                        repRange: PresetPackRepRange.boringButBig,
                        note: PresetPackLabels.boringButBig
                    )
                ),
            ]
        )
    }

}
