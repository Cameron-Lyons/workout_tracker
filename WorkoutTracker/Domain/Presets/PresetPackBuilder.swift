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
        static let powerMainLift = 150
    }

    private enum PresetPackSets {
        static let standard = ExerciseBlockDefaults.setCount
        static let powerMainSets = 4
        static let strongLifts = 5
        static let greyskull = 3
        static let gzclTierOne = 3
        static let gzclTierTwo = 3
        static let gzclTierThree = 3
        static let deadliftTopSets = 2
        static let singleTopSet = 1
        static let powerCleanSets = 5
        static let madcowRecovery = 4
        static let madcowIntensityRamp = 3
        static let boringButBig = 5
    }

    private enum PresetPackRepRange {
        static let powerStrength = RepRange(3, 5)
        static let hypertrophyMain = RepRange(8, 12)
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
        static let gzclTierTwo = RepRange(8, 10)
        static let gzclTierThree = RepRange(12, 15)
        static let madcowTriple = RepRange(3, 3)
        static let madcowBackoff = RepRange(8, 8)
    }

    private enum PresetPackLabels {
        static let boringButBig = "BBB 5x10"
        static let greyskullAMRAP = "AMRAP+"
        static let madcowTopTriple = "Top triple"
        static let madcowBackoff = "Backoff set"
    }

    static func makePlans(for pack: PresetPack, settings: SettingsStore) -> [Plan] {
        switch pack {
        case .generalGym:
            return [makeGeneralGymPlan(settings: settings)]
        case .phul:
            return [makePHULPlan(settings: settings)]
        case .startingStrength:
            return [makeStartingStrengthPlan(settings: settings)]
        case .strongLiftsFiveByFive:
            return [makeStrongLiftsPlan(settings: settings)]
        case .greyskullLP:
            return [makeGreyskullPlan(settings: settings)]
        case .fiveThreeOne:
            return [makeFiveThreeOnePlan(settings: settings)]
        case .boringButBig:
            return [makeBoringButBigPlan(settings: settings)]
        case .madcowFiveByFive:
            return [makeMadcowPlan()]
        case .gzclp:
            return [makeGZCLPPlan(settings: settings)]
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

    private static func makePHULPlan(settings: SettingsStore) -> Plan {
        let upperPower = WorkoutTemplate(
            name: "Upper Power",
            scheduledWeekdays: [.monday],
            blocks: [
                doubleProgressionBlock(
                    exerciseID: CatalogSeed.benchPress,
                    exerciseName: "Bench Press",
                    restSeconds: PresetPackRest.powerMainLift,
                    count: PresetPackSets.powerMainSets,
                    repRange: PresetPackRepRange.powerStrength,
                    increment: settings.upperBodyIncrement
                ),
                doubleProgressionBlock(
                    exerciseID: CatalogSeed.barbellRow,
                    exerciseName: "Barbell Row",
                    restSeconds: PresetPackRest.powerMainLift,
                    count: PresetPackSets.powerMainSets,
                    repRange: PresetPackRepRange.powerStrength,
                    increment: settings.upperBodyIncrement
                ),
                doubleProgressionBlock(
                    exerciseID: CatalogSeed.overheadPress,
                    exerciseName: "Overhead Press",
                    restSeconds: PresetPackRest.compound,
                    repRange: PresetPackRepRange.upperMain,
                    increment: settings.upperBodyIncrement
                ),
                manualBlock(
                    exerciseID: CatalogSeed.pullUp,
                    exerciseName: "Pull Up",
                    restSeconds: PresetPackRest.compound,
                    repRange: PresetPackRepRange.row
                ),
                manualBlock(
                    exerciseID: CatalogSeed.hammerCurl,
                    exerciseName: "Hammer Curl",
                    restSeconds: PresetPackRest.accessory,
                    repRange: PresetPackRepRange.accessory
                ),
                manualBlock(
                    exerciseID: CatalogSeed.tricepsPushdown,
                    exerciseName: "Triceps Pushdown",
                    restSeconds: PresetPackRest.accessory,
                    repRange: PresetPackRepRange.accessory
                ),
            ]
        )

        let lowerPower = WorkoutTemplate(
            name: "Lower Power",
            scheduledWeekdays: [.tuesday],
            blocks: [
                doubleProgressionBlock(
                    exerciseID: CatalogSeed.backSquat,
                    exerciseName: "Back Squat",
                    restSeconds: PresetPackRest.powerMainLift,
                    count: PresetPackSets.powerMainSets,
                    repRange: PresetPackRepRange.powerStrength,
                    increment: settings.lowerBodyIncrement
                ),
                doubleProgressionBlock(
                    exerciseID: CatalogSeed.deadlift,
                    exerciseName: "Deadlift",
                    restSeconds: PresetPackRest.mainLift,
                    count: PresetPackSets.standard,
                    repRange: PresetPackRepRange.powerStrength,
                    increment: settings.lowerBodyIncrement
                ),
                manualBlock(
                    exerciseID: CatalogSeed.legPress,
                    exerciseName: "Leg Press",
                    repRange: PresetPackRepRange.hypertrophyMain
                ),
                manualBlock(
                    exerciseID: CatalogSeed.legCurl,
                    exerciseName: "Leg Curl",
                    repRange: PresetPackRepRange.row
                ),
                manualBlock(
                    exerciseID: CatalogSeed.standingCalfRaise,
                    exerciseName: "Standing Calf Raise",
                    count: PresetPackSets.powerMainSets,
                    repRange: RepRange(8, 12)
                ),
            ]
        )

        let upperHypertrophy = WorkoutTemplate(
            name: "Upper Hypertrophy",
            scheduledWeekdays: [.thursday],
            blocks: [
                doubleProgressionBlock(
                    exerciseID: CatalogSeed.inclineBenchPress,
                    exerciseName: "Incline Bench Press",
                    restSeconds: PresetPackRest.compound,
                    count: PresetPackSets.powerMainSets,
                    repRange: PresetPackRepRange.hypertrophyMain,
                    increment: settings.upperBodyIncrement
                ),
                doubleProgressionBlock(
                    exerciseID: CatalogSeed.seatedCableRow,
                    exerciseName: "Seated Cable Row",
                    restSeconds: PresetPackRest.compound,
                    count: PresetPackSets.powerMainSets,
                    repRange: PresetPackRepRange.hypertrophyMain,
                    increment: settings.upperBodyIncrement
                ),
                doubleProgressionBlock(
                    exerciseID: CatalogSeed.overheadPress,
                    exerciseName: "Overhead Press",
                    restSeconds: PresetPackRest.standard,
                    repRange: PresetPackRepRange.hypertrophyMain,
                    increment: settings.upperBodyIncrement
                ),
                manualBlock(
                    exerciseID: CatalogSeed.latPulldown,
                    exerciseName: "Lat Pulldown",
                    repRange: PresetPackRepRange.accessory
                ),
                manualBlock(
                    exerciseID: CatalogSeed.lateralRaise,
                    exerciseName: "Lateral Raise",
                    restSeconds: PresetPackRest.accessory,
                    repRange: PresetPackRepRange.shoulders
                ),
                manualBlock(
                    exerciseID: CatalogSeed.hammerCurl,
                    exerciseName: "Hammer Curl",
                    restSeconds: PresetPackRest.accessory,
                    repRange: PresetPackRepRange.accessory
                ),
                manualBlock(
                    exerciseID: CatalogSeed.tricepsPushdown,
                    exerciseName: "Triceps Pushdown",
                    restSeconds: PresetPackRest.accessory,
                    repRange: PresetPackRepRange.accessory
                ),
            ]
        )

        let lowerHypertrophy = WorkoutTemplate(
            name: "Lower Hypertrophy",
            scheduledWeekdays: [.friday],
            blocks: [
                doubleProgressionBlock(
                    exerciseID: CatalogSeed.frontSquat,
                    exerciseName: "Front Squat",
                    restSeconds: PresetPackRest.compound,
                    count: PresetPackSets.powerMainSets,
                    repRange: PresetPackRepRange.hypertrophyMain,
                    increment: settings.lowerBodyIncrement
                ),
                doubleProgressionBlock(
                    exerciseID: CatalogSeed.romanianDeadlift,
                    exerciseName: "Romanian Deadlift",
                    restSeconds: PresetPackRest.compound,
                    count: PresetPackSets.powerMainSets,
                    repRange: PresetPackRepRange.hypertrophyMain,
                    increment: settings.lowerBodyIncrement
                ),
                manualBlock(
                    exerciseID: CatalogSeed.bulgarianSplitSquat,
                    exerciseName: "Bulgarian Split Squat",
                    restSeconds: PresetPackRest.unilateralAccessory,
                    repRange: PresetPackRepRange.accessory
                ),
                manualBlock(
                    exerciseID: CatalogSeed.legCurl,
                    exerciseName: "Leg Curl",
                    repRange: PresetPackRepRange.accessory
                ),
                manualBlock(
                    exerciseID: CatalogSeed.legExtension,
                    exerciseName: "Leg Extension",
                    repRange: PresetPackRepRange.accessory
                ),
                manualBlock(
                    exerciseID: CatalogSeed.seatedCalfRaise,
                    exerciseName: "Seated Calf Raise",
                    count: PresetPackSets.powerMainSets,
                    repRange: PresetPackRepRange.calves
                ),
            ]
        )

        return Plan(
            name: "PHUL",
            pinnedTemplateID: upperPower.id,
            templates: [upperPower, lowerPower, upperHypertrophy, lowerHypertrophy]
        )
    }

    private static func makeStrongLiftsPlan(settings: SettingsStore) -> Plan {
        let workoutA = WorkoutTemplate(
            name: "Workout A",
            scheduledWeekdays: [.monday, .friday],
            blocks: [
                doubleProgressionBlock(
                    exerciseID: CatalogSeed.backSquat,
                    exerciseName: "Back Squat",
                    restSeconds: PresetPackRest.mainLift,
                    count: PresetPackSets.strongLifts,
                    repRange: PresetPackRepRange.strength,
                    increment: settings.lowerBodyIncrement
                ),
                doubleProgressionBlock(
                    exerciseID: CatalogSeed.benchPress,
                    exerciseName: "Bench Press",
                    restSeconds: PresetPackRest.compound,
                    count: PresetPackSets.strongLifts,
                    repRange: PresetPackRepRange.strength,
                    increment: settings.upperBodyIncrement
                ),
                doubleProgressionBlock(
                    exerciseID: CatalogSeed.barbellRow,
                    exerciseName: "Barbell Row",
                    restSeconds: PresetPackRest.compound,
                    count: PresetPackSets.strongLifts,
                    repRange: PresetPackRepRange.strength,
                    increment: settings.upperBodyIncrement
                ),
            ]
        )

        let workoutB = WorkoutTemplate(
            name: "Workout B",
            scheduledWeekdays: [.wednesday],
            blocks: [
                doubleProgressionBlock(
                    exerciseID: CatalogSeed.backSquat,
                    exerciseName: "Back Squat",
                    restSeconds: PresetPackRest.mainLift,
                    count: PresetPackSets.strongLifts,
                    repRange: PresetPackRepRange.strength,
                    increment: settings.lowerBodyIncrement
                ),
                doubleProgressionBlock(
                    exerciseID: CatalogSeed.overheadPress,
                    exerciseName: "Overhead Press",
                    restSeconds: PresetPackRest.compound,
                    count: PresetPackSets.strongLifts,
                    repRange: PresetPackRepRange.strength,
                    increment: settings.upperBodyIncrement
                ),
                doubleProgressionBlock(
                    exerciseID: CatalogSeed.deadlift,
                    exerciseName: "Deadlift",
                    restSeconds: PresetPackRest.waveMainLift,
                    count: PresetPackSets.singleTopSet,
                    repRange: PresetPackRepRange.strength,
                    increment: settings.lowerBodyIncrement
                ),
            ]
        )

        return Plan(
            name: "StrongLifts 5x5",
            pinnedTemplateID: workoutA.id,
            templates: [workoutA, workoutB]
        )
    }

    private static func makeGreyskullPlan(settings: SettingsStore) -> Plan {
        let workoutA = WorkoutTemplate(
            name: "Workout A",
            scheduledWeekdays: [.monday, .friday],
            blocks: [
                greyskullBlock(
                    exerciseID: CatalogSeed.backSquat,
                    exerciseName: "Back Squat",
                    restSeconds: PresetPackRest.mainLift,
                    increment: settings.lowerBodyIncrement
                ),
                greyskullBlock(
                    exerciseID: CatalogSeed.benchPress,
                    exerciseName: "Bench Press",
                    restSeconds: PresetPackRest.compound,
                    increment: settings.upperBodyIncrement
                ),
                greyskullBlock(
                    exerciseID: CatalogSeed.barbellRow,
                    exerciseName: "Barbell Row",
                    restSeconds: PresetPackRest.compound,
                    increment: settings.upperBodyIncrement
                ),
            ]
        )

        let workoutB = WorkoutTemplate(
            name: "Workout B",
            scheduledWeekdays: [.wednesday],
            blocks: [
                greyskullBlock(
                    exerciseID: CatalogSeed.backSquat,
                    exerciseName: "Back Squat",
                    restSeconds: PresetPackRest.mainLift,
                    increment: settings.lowerBodyIncrement
                ),
                greyskullBlock(
                    exerciseID: CatalogSeed.overheadPress,
                    exerciseName: "Overhead Press",
                    restSeconds: PresetPackRest.compound,
                    increment: settings.upperBodyIncrement
                ),
                greyskullBlock(
                    exerciseID: CatalogSeed.deadlift,
                    exerciseName: "Deadlift",
                    restSeconds: PresetPackRest.waveMainLift,
                    increment: settings.lowerBodyIncrement
                ),
            ]
        )

        return Plan(
            name: "Greyskull LP",
            pinnedTemplateID: workoutA.id,
            templates: [workoutA, workoutB]
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

    private static func makeFiveThreeOnePlan(settings: SettingsStore) -> Plan {
        let squatDay = waveTemplate(
            name: "Squat Day",
            mainExerciseID: CatalogSeed.backSquat,
            mainExerciseName: "Back Squat",
            settings: settings,
            accessories: [
                accessoryBlock(id: CatalogSeed.frontSquat, name: "Front Squat"),
                accessoryBlock(id: CatalogSeed.legCurl, name: "Leg Curl"),
            ]
        )
        let benchDay = waveTemplate(
            name: "Bench Day",
            mainExerciseID: CatalogSeed.benchPress,
            mainExerciseName: "Bench Press",
            settings: settings,
            accessories: [
                accessoryBlock(id: CatalogSeed.pullUp, name: "Pull Up"),
                accessoryBlock(id: CatalogSeed.tricepsPushdown, name: "Triceps Pushdown"),
            ]
        )
        let deadliftDay = waveTemplate(
            name: "Deadlift Day",
            mainExerciseID: CatalogSeed.deadlift,
            mainExerciseName: "Deadlift",
            settings: settings,
            accessories: [
                accessoryBlock(id: CatalogSeed.barbellRow, name: "Barbell Row"),
                accessoryBlock(id: CatalogSeed.seatedCalfRaise, name: "Seated Calf Raise"),
            ]
        )
        let pressDay = waveTemplate(
            name: "Press Day",
            mainExerciseID: CatalogSeed.overheadPress,
            mainExerciseName: "Overhead Press",
            settings: settings,
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

    private static func makeBoringButBigPlan(settings: SettingsStore) -> Plan {
        let squatDay = bbbTemplate(
            name: "BBB Squat Day",
            mainExerciseID: CatalogSeed.backSquat,
            mainExerciseName: "Back Squat",
            settings: settings,
            bbbExerciseID: CatalogSeed.backSquat,
            bbbExerciseName: "Back Squat"
        )
        let benchDay = bbbTemplate(
            name: "BBB Bench Day",
            mainExerciseID: CatalogSeed.benchPress,
            mainExerciseName: "Bench Press",
            settings: settings,
            bbbExerciseID: CatalogSeed.benchPress,
            bbbExerciseName: "Bench Press"
        )
        let deadliftDay = bbbTemplate(
            name: "BBB Deadlift Day",
            mainExerciseID: CatalogSeed.deadlift,
            mainExerciseName: "Deadlift",
            settings: settings,
            bbbExerciseID: CatalogSeed.deadlift,
            bbbExerciseName: "Deadlift"
        )
        let pressDay = bbbTemplate(
            name: "BBB Press Day",
            mainExerciseID: CatalogSeed.overheadPress,
            mainExerciseName: "Overhead Press",
            settings: settings,
            bbbExerciseID: CatalogSeed.overheadPress,
            bbbExerciseName: "Overhead Press"
        )

        return Plan(
            name: "Boring But Big",
            pinnedTemplateID: squatDay.id,
            templates: [squatDay, benchDay, deadliftDay, pressDay]
        )
    }

    private static func makeMadcowPlan() -> Plan {
        let volumeDay = WorkoutTemplate(
            name: "Volume Day",
            scheduledWeekdays: [.monday],
            blocks: [
                manualBlock(
                    exerciseID: CatalogSeed.backSquat,
                    exerciseName: "Back Squat",
                    restSeconds: PresetPackRest.mainLift,
                    count: PresetPackSets.strongLifts,
                    repRange: PresetPackRepRange.strength
                ),
                manualBlock(
                    exerciseID: CatalogSeed.benchPress,
                    exerciseName: "Bench Press",
                    restSeconds: PresetPackRest.compound,
                    count: PresetPackSets.strongLifts,
                    repRange: PresetPackRepRange.strength
                ),
                manualBlock(
                    exerciseID: CatalogSeed.barbellRow,
                    exerciseName: "Barbell Row",
                    restSeconds: PresetPackRest.compound,
                    count: PresetPackSets.strongLifts,
                    repRange: PresetPackRepRange.strength
                ),
            ]
        )

        let recoveryDay = WorkoutTemplate(
            name: "Recovery Day",
            scheduledWeekdays: [.wednesday],
            blocks: [
                manualBlock(
                    exerciseID: CatalogSeed.backSquat,
                    exerciseName: "Back Squat",
                    restSeconds: PresetPackRest.compound,
                    count: PresetPackSets.madcowRecovery,
                    repRange: PresetPackRepRange.strength
                ),
                manualBlock(
                    exerciseID: CatalogSeed.overheadPress,
                    exerciseName: "Overhead Press",
                    restSeconds: PresetPackRest.compound,
                    count: PresetPackSets.madcowRecovery,
                    repRange: PresetPackRepRange.strength
                ),
                manualBlock(
                    exerciseID: CatalogSeed.deadlift,
                    exerciseName: "Deadlift",
                    restSeconds: PresetPackRest.mainLift,
                    count: PresetPackSets.madcowRecovery,
                    repRange: PresetPackRepRange.strength
                ),
            ]
        )

        let intensityDay = WorkoutTemplate(
            name: "Intensity Day",
            scheduledWeekdays: [.friday],
            blocks: [
                manualBlock(
                    exerciseID: CatalogSeed.backSquat,
                    exerciseName: "Back Squat",
                    restSeconds: PresetPackRest.mainLift,
                    targets: madcowIntensityTargets()
                ),
                manualBlock(
                    exerciseID: CatalogSeed.benchPress,
                    exerciseName: "Bench Press",
                    restSeconds: PresetPackRest.compound,
                    targets: madcowIntensityTargets()
                ),
                manualBlock(
                    exerciseID: CatalogSeed.barbellRow,
                    exerciseName: "Barbell Row",
                    restSeconds: PresetPackRest.compound,
                    targets: madcowIntensityTargets()
                ),
            ]
        )

        return Plan(
            name: "Madcow 5x5",
            pinnedTemplateID: volumeDay.id,
            templates: [volumeDay, recoveryDay, intensityDay]
        )
    }

    private static func makeGZCLPPlan(settings: SettingsStore) -> Plan {
        let workoutA = WorkoutTemplate(
            name: "Workout A",
            scheduledWeekdays: [.monday],
            blocks: [
                gzclTierOneBlock(
                    exerciseID: CatalogSeed.backSquat,
                    exerciseName: "Back Squat",
                    increment: settings.lowerBodyIncrement
                ),
                gzclTierTwoBlock(
                    exerciseID: CatalogSeed.benchPress,
                    exerciseName: "Bench Press",
                    increment: settings.upperBodyIncrement
                ),
                gzclTierThreeBlock(
                    exerciseID: CatalogSeed.barbellRow,
                    exerciseName: "Barbell Row"
                ),
            ]
        )

        let workoutB = WorkoutTemplate(
            name: "Workout B",
            scheduledWeekdays: [.tuesday],
            blocks: [
                gzclTierOneBlock(
                    exerciseID: CatalogSeed.overheadPress,
                    exerciseName: "Overhead Press",
                    increment: settings.upperBodyIncrement
                ),
                gzclTierTwoBlock(
                    exerciseID: CatalogSeed.deadlift,
                    exerciseName: "Deadlift",
                    increment: settings.lowerBodyIncrement
                ),
                gzclTierThreeBlock(
                    exerciseID: CatalogSeed.latPulldown,
                    exerciseName: "Lat Pulldown"
                ),
            ]
        )

        let workoutC = WorkoutTemplate(
            name: "Workout C",
            scheduledWeekdays: [.thursday],
            blocks: [
                gzclTierOneBlock(
                    exerciseID: CatalogSeed.benchPress,
                    exerciseName: "Bench Press",
                    increment: settings.upperBodyIncrement
                ),
                gzclTierTwoBlock(
                    exerciseID: CatalogSeed.frontSquat,
                    exerciseName: "Front Squat",
                    increment: settings.lowerBodyIncrement
                ),
                gzclTierThreeBlock(
                    exerciseID: CatalogSeed.seatedCableRow,
                    exerciseName: "Seated Cable Row"
                ),
            ]
        )

        let workoutD = WorkoutTemplate(
            name: "Workout D",
            scheduledWeekdays: [.friday],
            blocks: [
                gzclTierOneBlock(
                    exerciseID: CatalogSeed.deadlift,
                    exerciseName: "Deadlift",
                    increment: settings.lowerBodyIncrement
                ),
                gzclTierTwoBlock(
                    exerciseID: CatalogSeed.overheadPress,
                    exerciseName: "Overhead Press",
                    increment: settings.upperBodyIncrement
                ),
                gzclTierThreeBlock(
                    exerciseID: CatalogSeed.pullUp,
                    exerciseName: "Pull Up"
                ),
            ]
        )

        return Plan(
            name: "GZCLP",
            pinnedTemplateID: workoutA.id,
            templates: [workoutA, workoutB, workoutC, workoutD]
        )
    }

    private static func doubleProgressionRule(
        repRange: RepRange,
        increment: Double
    ) -> ProgressionRule {
        ProgressionRule(
            kind: .doubleProgression,
            doubleProgression: DoubleProgressionRule(
                targetRepRange: repRange,
                increment: increment
            )
        )
    }

    private static func doubleProgressionBlock(
        exerciseID: UUID,
        exerciseName: String,
        restSeconds: Int = ExerciseBlockDefaults.restSeconds,
        count: Int = PresetPackSets.standard,
        repRange: RepRange = DoubleProgressionDefaults.repRange,
        increment: Double,
        supersetGroup: String? = nil
    ) -> ExerciseBlock {
        ExerciseBlock(
            exerciseID: exerciseID,
            exerciseNameSnapshot: exerciseName,
            restSeconds: restSeconds,
            supersetGroup: supersetGroup,
            progressionRule: doubleProgressionRule(repRange: repRange, increment: increment),
            targets: repeatedTargets(count: count, repRange: repRange)
        )
    }

    private static func manualBlock(
        exerciseID: UUID,
        exerciseName: String,
        restSeconds: Int = ExerciseBlockDefaults.restSeconds,
        count: Int = PresetPackSets.standard,
        repRange: RepRange = ExerciseBlockDefaults.repRange,
        supersetGroup: String? = nil
    ) -> ExerciseBlock {
        ExerciseBlock(
            exerciseID: exerciseID,
            exerciseNameSnapshot: exerciseName,
            restSeconds: restSeconds,
            supersetGroup: supersetGroup,
            progressionRule: .manual,
            targets: repeatedTargets(count: count, repRange: repRange)
        )
    }

    private static func manualBlock(
        exerciseID: UUID,
        exerciseName: String,
        restSeconds: Int = ExerciseBlockDefaults.restSeconds,
        targets: [SetTarget],
        supersetGroup: String? = nil
    ) -> ExerciseBlock {
        ExerciseBlock(
            exerciseID: exerciseID,
            exerciseNameSnapshot: exerciseName,
            restSeconds: restSeconds,
            supersetGroup: supersetGroup,
            progressionRule: .manual,
            targets: targets
        )
    }

    private static func greyskullBlock(
        exerciseID: UUID,
        exerciseName: String,
        restSeconds: Int = ExerciseBlockDefaults.restSeconds,
        increment: Double
    ) -> ExerciseBlock {
        ExerciseBlock(
            exerciseID: exerciseID,
            exerciseNameSnapshot: exerciseName,
            restSeconds: restSeconds,
            progressionRule: doubleProgressionRule(
                repRange: PresetPackRepRange.strength,
                increment: increment
            ),
            targets: greyskullTargets()
        )
    }

    private static func greyskullTargets() -> [SetTarget] {
        var targets = repeatedTargets(
            count: PresetPackSets.greyskull,
            repRange: PresetPackRepRange.strength
        )
        targets[targets.index(before: targets.endIndex)].note = PresetPackLabels.greyskullAMRAP
        return targets
    }

    private static func madcowIntensityTargets() -> [SetTarget] {
        var targets = repeatedTargets(
            count: PresetPackSets.madcowIntensityRamp,
            repRange: PresetPackRepRange.strength
        )
        targets.append(
            SetTarget(
                repRange: PresetPackRepRange.madcowTriple,
                note: PresetPackLabels.madcowTopTriple
            )
        )
        targets.append(
            SetTarget(
                repRange: PresetPackRepRange.madcowBackoff,
                note: PresetPackLabels.madcowBackoff
            )
        )
        return targets
    }

    private static func gzclTierOneBlock(
        exerciseID: UUID,
        exerciseName: String,
        increment: Double
    ) -> ExerciseBlock {
        doubleProgressionBlock(
            exerciseID: exerciseID,
            exerciseName: exerciseName,
            restSeconds: PresetPackRest.mainLift,
            count: PresetPackSets.gzclTierOne,
            repRange: PresetPackRepRange.powerStrength,
            increment: increment
        )
    }

    private static func gzclTierTwoBlock(
        exerciseID: UUID,
        exerciseName: String,
        increment: Double
    ) -> ExerciseBlock {
        doubleProgressionBlock(
            exerciseID: exerciseID,
            exerciseName: exerciseName,
            restSeconds: PresetPackRest.compound,
            count: PresetPackSets.gzclTierTwo,
            repRange: PresetPackRepRange.gzclTierTwo,
            increment: increment
        )
    }

    private static func gzclTierThreeBlock(
        exerciseID: UUID,
        exerciseName: String
    ) -> ExerciseBlock {
        manualBlock(
            exerciseID: exerciseID,
            exerciseName: exerciseName,
            restSeconds: PresetPackRest.standard,
            count: PresetPackSets.gzclTierThree,
            repRange: PresetPackRepRange.gzclTierThree
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

    private static func waveProgressionRule(
        for exerciseName: String,
        settings: SettingsStore
    ) -> ProgressionRule {
        ProgressionRule(
            kind: .percentageWave,
            percentageWave: PercentageWaveRule.fiveThreeOne(
                trainingMax: ExerciseRecommendationDefaults.defaultTrainingMax(for: exerciseName),
                cycleIncrement: settings.preferredIncrement(for: exerciseName)
            )
        )
    }

    private static func waveMainBlock(
        exerciseID: UUID,
        exerciseName: String,
        settings: SettingsStore
    ) -> ExerciseBlock {
        var block = ExerciseBlock(
            exerciseID: exerciseID,
            exerciseNameSnapshot: exerciseName,
            restSeconds: PresetPackRest.waveMainLift,
            progressionRule: waveProgressionRule(for: exerciseName, settings: settings),
            targets: []
        )

        block.targets = ProgressionEngine.resolvedTargets(for: block, profile: nil)
        return block
    }

    private static func waveTemplate(
        name: String,
        mainExerciseID: UUID,
        mainExerciseName: String,
        settings: SettingsStore,
        accessories: [ExerciseBlock]
    ) -> WorkoutTemplate {
        WorkoutTemplate(
            name: name,
            blocks: [
                waveMainBlock(
                    exerciseID: mainExerciseID,
                    exerciseName: mainExerciseName,
                    settings: settings
                )
            ] + accessories
        )
    }

    private static func bbbTemplate(
        name: String,
        mainExerciseID: UUID,
        mainExerciseName: String,
        settings: SettingsStore,
        bbbExerciseID: UUID,
        bbbExerciseName: String
    ) -> WorkoutTemplate {
        WorkoutTemplate(
            name: name,
            blocks: [
                waveMainBlock(
                    exerciseID: mainExerciseID,
                    exerciseName: mainExerciseName,
                    settings: settings
                ),
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
