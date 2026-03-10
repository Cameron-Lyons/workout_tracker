import Foundation

@MainActor
enum PresetPackBuilder {
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
                    restSeconds: 120,
                    progressionRule: upperRule,
                    targets: repeatedTargets(count: 3, repRange: RepRange(6, 8))
                ),
                ExerciseBlock(
                    exerciseID: CatalogSeed.barbellRow,
                    exerciseNameSnapshot: "Barbell Row",
                    restSeconds: 120,
                    progressionRule: upperRule,
                    targets: repeatedTargets(count: 3, repRange: RepRange(8, 10))
                ),
                ExerciseBlock(
                    exerciseID: CatalogSeed.lateralRaise,
                    exerciseNameSnapshot: "Lateral Raise",
                    restSeconds: 60,
                    supersetGroup: "A",
                    progressionRule: .manual,
                    targets: repeatedTargets(count: 3, repRange: RepRange(12, 15))
                ),
                ExerciseBlock(
                    exerciseID: CatalogSeed.tricepsPushdown,
                    exerciseNameSnapshot: "Triceps Pushdown",
                    restSeconds: 60,
                    supersetGroup: "A",
                    progressionRule: .manual,
                    targets: repeatedTargets(count: 3, repRange: RepRange(10, 15))
                )
            ]
        )

        let lowerA = WorkoutTemplate(
            name: "Lower A",
            scheduledWeekdays: [.tuesday, .friday],
            blocks: [
                ExerciseBlock(
                    exerciseID: CatalogSeed.backSquat,
                    exerciseNameSnapshot: "Back Squat",
                    restSeconds: 150,
                    progressionRule: lowerRule,
                    targets: repeatedTargets(count: 3, repRange: RepRange(5, 8))
                ),
                ExerciseBlock(
                    exerciseID: CatalogSeed.romanianDeadlift,
                    exerciseNameSnapshot: "Romanian Deadlift",
                    restSeconds: 120,
                    progressionRule: lowerRule,
                    targets: repeatedTargets(count: 3, repRange: RepRange(6, 10))
                ),
                ExerciseBlock(
                    exerciseID: CatalogSeed.legPress,
                    exerciseNameSnapshot: "Leg Press",
                    restSeconds: 90,
                    progressionRule: .manual,
                    targets: repeatedTargets(count: 3, repRange: RepRange(10, 15))
                ),
                ExerciseBlock(
                    exerciseID: CatalogSeed.standingCalfRaise,
                    exerciseNameSnapshot: "Standing Calf Raise",
                    restSeconds: 60,
                    progressionRule: .manual,
                    targets: repeatedTargets(count: 3, repRange: RepRange(12, 20))
                )
            ]
        )

        let upperB = WorkoutTemplate(
            name: "Upper B",
            blocks: [
                ExerciseBlock(
                    exerciseID: CatalogSeed.overheadPress,
                    exerciseNameSnapshot: "Overhead Press",
                    restSeconds: 120,
                    progressionRule: upperRule,
                    targets: repeatedTargets(count: 3, repRange: RepRange(6, 8))
                ),
                ExerciseBlock(
                    exerciseID: CatalogSeed.pullUp,
                    exerciseNameSnapshot: "Pull Up",
                    restSeconds: 120,
                    progressionRule: .manual,
                    targets: repeatedTargets(count: 3, repRange: RepRange(6, 10))
                ),
                ExerciseBlock(
                    exerciseID: CatalogSeed.inclineBenchPress,
                    exerciseNameSnapshot: "Incline Bench Press",
                    restSeconds: 90,
                    supersetGroup: "B",
                    progressionRule: .manual,
                    targets: repeatedTargets(count: 3, repRange: RepRange(8, 12))
                ),
                ExerciseBlock(
                    exerciseID: CatalogSeed.hammerCurl,
                    exerciseNameSnapshot: "Hammer Curl",
                    restSeconds: 60,
                    supersetGroup: "B",
                    progressionRule: .manual,
                    targets: repeatedTargets(count: 3, repRange: RepRange(10, 15))
                )
            ]
        )

        let lowerB = WorkoutTemplate(
            name: "Lower B",
            blocks: [
                ExerciseBlock(
                    exerciseID: CatalogSeed.deadlift,
                    exerciseNameSnapshot: "Deadlift",
                    restSeconds: 150,
                    progressionRule: lowerRule,
                    targets: repeatedTargets(count: 2, repRange: RepRange(4, 6))
                ),
                ExerciseBlock(
                    exerciseID: CatalogSeed.frontSquat,
                    exerciseNameSnapshot: "Front Squat",
                    restSeconds: 120,
                    progressionRule: lowerRule,
                    targets: repeatedTargets(count: 3, repRange: RepRange(6, 8))
                ),
                ExerciseBlock(
                    exerciseID: CatalogSeed.bulgarianSplitSquat,
                    exerciseNameSnapshot: "Bulgarian Split Squat",
                    restSeconds: 75,
                    supersetGroup: "C",
                    progressionRule: .manual,
                    targets: repeatedTargets(count: 3, repRange: RepRange(8, 12))
                ),
                ExerciseBlock(
                    exerciseID: CatalogSeed.legCurl,
                    exerciseNameSnapshot: "Leg Curl",
                    restSeconds: 60,
                    supersetGroup: "C",
                    progressionRule: .manual,
                    targets: repeatedTargets(count: 3, repRange: RepRange(10, 15))
                )
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
                    restSeconds: 150,
                    progressionRule: squatRule,
                    targets: repeatedTargets(count: 3, repRange: RepRange(5, 5))
                ),
                ExerciseBlock(
                    exerciseID: CatalogSeed.benchPress,
                    exerciseNameSnapshot: "Bench Press",
                    restSeconds: 120,
                    progressionRule: upperRule,
                    targets: repeatedTargets(count: 3, repRange: RepRange(5, 5))
                ),
                ExerciseBlock(
                    exerciseID: CatalogSeed.deadlift,
                    exerciseNameSnapshot: "Deadlift",
                    restSeconds: 180,
                    progressionRule: SessionEngine.defaultDoubleProgressionRule(
                        exerciseName: "Deadlift",
                        preferredIncrement: settings.lowerBodyIncrement
                    ),
                    targets: repeatedTargets(count: 1, repRange: RepRange(5, 5))
                )
            ]
        )

        let dayB = WorkoutTemplate(
            name: "Workout B",
            scheduledWeekdays: [.wednesday],
            blocks: [
                ExerciseBlock(
                    exerciseID: CatalogSeed.backSquat,
                    exerciseNameSnapshot: "Back Squat",
                    restSeconds: 150,
                    progressionRule: squatRule,
                    targets: repeatedTargets(count: 3, repRange: RepRange(5, 5))
                ),
                ExerciseBlock(
                    exerciseID: CatalogSeed.overheadPress,
                    exerciseNameSnapshot: "Overhead Press",
                    restSeconds: 120,
                    progressionRule: upperRule,
                    targets: repeatedTargets(count: 3, repRange: RepRange(5, 5))
                ),
                ExerciseBlock(
                    exerciseID: CatalogSeed.powerClean,
                    exerciseNameSnapshot: "Power Clean",
                    restSeconds: 120,
                    progressionRule: upperRule,
                    targets: repeatedTargets(count: 5, repRange: RepRange(3, 3))
                )
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
                accessoryBlock(id: CatalogSeed.legCurl, name: "Leg Curl")
            ]
        )
        let benchDay = waveTemplate(
            name: "Bench Day",
            mainExerciseID: CatalogSeed.benchPress,
            mainExerciseName: "Bench Press",
            accessories: [
                accessoryBlock(id: CatalogSeed.pullUp, name: "Pull Up"),
                accessoryBlock(id: CatalogSeed.tricepsPushdown, name: "Triceps Pushdown")
            ]
        )
        let deadliftDay = waveTemplate(
            name: "Deadlift Day",
            mainExerciseID: CatalogSeed.deadlift,
            mainExerciseName: "Deadlift",
            accessories: [
                accessoryBlock(id: CatalogSeed.barbellRow, name: "Barbell Row"),
                accessoryBlock(id: CatalogSeed.seatedCalfRaise, name: "Seated Calf Raise")
            ]
        )
        let pressDay = waveTemplate(
            name: "Press Day",
            mainExerciseID: CatalogSeed.overheadPress,
            mainExerciseName: "Overhead Press",
            accessories: [
                accessoryBlock(id: CatalogSeed.latPulldown, name: "Lat Pulldown"),
                accessoryBlock(id: CatalogSeed.hammerCurl, name: "Hammer Curl")
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

    private static func repeatedTargets(count: Int, repRange: RepRange) -> [SetTarget] {
        (0..<count).map { _ in
            SetTarget(repRange: repRange)
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

    private static func waveTemplate(
        name: String,
        mainExerciseID: UUID,
        mainExerciseName: String,
        accessories: [ExerciseBlock]
    ) -> WorkoutTemplate {
        WorkoutTemplate(
            name: name,
            blocks: [
                ExerciseBlock(
                    exerciseID: mainExerciseID,
                    exerciseNameSnapshot: mainExerciseName,
                    restSeconds: 180,
                    progressionRule: ProgressionRule(
                        kind: .percentageWave,
                        percentageWave: PercentageWaveRule.fiveThreeOne(
                            cycleIncrement: ExerciseClassification.isLowerBody(mainExerciseName) ? 10 : 5
                        )
                    ),
                    targets: []
                )
            ] + accessories
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
                ExerciseBlock(
                    exerciseID: mainExerciseID,
                    exerciseNameSnapshot: mainExerciseName,
                    restSeconds: 180,
                    progressionRule: ProgressionRule(
                        kind: .percentageWave,
                        percentageWave: PercentageWaveRule.fiveThreeOne(
                            cycleIncrement: ExerciseClassification.isLowerBody(mainExerciseName) ? 10 : 5
                        )
                    ),
                    targets: []
                ),
                ExerciseBlock(
                    exerciseID: bbbExerciseID,
                    exerciseNameSnapshot: bbbExerciseName,
                    restSeconds: 120,
                    progressionRule: .manual,
                    targets: (0..<5).map { _ in
                        SetTarget(
                            setKind: .working,
                            targetWeight: nil,
                            repRange: RepRange(10, 10),
                            note: "BBB 5x10"
                        )
                    }
                )
            ]
        )
    }

}
