import Foundation

struct PrescribedSetTemplate: Equatable {
    var reps: Int
    var weight: Double?
    var note: String?
}

struct ProgramWorkoutPlan: Equatable {
    var contextLabel: String?
    var activeExerciseIDs: Set<UUID>?
    var setTemplatesByExerciseID: [UUID: [PrescribedSetTemplate]]

    static let empty = ProgramWorkoutPlan(
        contextLabel: nil,
        activeExerciseIDs: nil,
        setTemplatesByExerciseID: [:]
    )
}

enum WorkoutProgramEngine {
    private struct PercentageSetSpec {
        var percent: Double
        var reps: Int
        var note: String?

        init(_ percent: Double, _ reps: Int, note: String? = nil) {
            self.percent = percent
            self.reps = reps
            self.note = note
        }
    }

    private struct WeekPlanSpec {
        var name: String
        var primarySpecs: [PercentageSetSpec]
    }

    private enum Constants {
        static let startingStrengthDayCount = 2
        static let startingStrengthDayAExercises: Set<String> = ["back squat", "bench press", "deadlift"]
        static let startingStrengthDayBExercises: Set<String> = ["back squat", "overhead press", "power clean"]
        static let startingStrengthDeadliftSetCount = 1
        static let startingStrengthDeadliftReps = 5
        static let startingStrengthPowerCleanSetCount = 5
        static let startingStrengthPowerCleanReps = 3
        static let startingStrengthDefaultSetCount = 3
        static let startingStrengthDefaultReps = 5
        static let startingStrengthSmallLiftIncrement = 2.5
        static let standardIncrement = 5.0

        static let fiveThreeOneWeekCount = 4
        static let fiveThreeOneLastWeekIndex = fiveThreeOneWeekCount - 1
        static let bbbSupplementalPercent = 0.50
        static let bbbSupplementalSetCount = 5
        static let bbbSupplementalReps = 10
        static let bbbNote = "BBB (5x10)"
        static let noTrainingMaxNote = "Set training max (TM) in Edit Routine"
        static let lowerBodyTrainingMaxIncrement = 10.0
        static let roundingIncrement = 2.5

        static let fiveThreeOneWeekSpecs: [WeekPlanSpec] = [
            WeekPlanSpec(
                name: "Week 1 (5-rep week)",
                primarySpecs: [
                    PercentageSetSpec(0.65, 5),
                    PercentageSetSpec(0.75, 5),
                    PercentageSetSpec(0.85, 5, note: "AMRAP (as many reps as possible)")
                ]
            ),
            WeekPlanSpec(
                name: "Week 2 (3-rep week)",
                primarySpecs: [
                    PercentageSetSpec(0.70, 3),
                    PercentageSetSpec(0.80, 3),
                    PercentageSetSpec(0.90, 3, note: "AMRAP (as many reps as possible)")
                ]
            ),
            WeekPlanSpec(
                name: "Week 3 (5/3/1 week)",
                primarySpecs: [
                    PercentageSetSpec(0.75, 5),
                    PercentageSetSpec(0.85, 3),
                    PercentageSetSpec(0.95, 1, note: "AMRAP (as many reps as possible)")
                ]
            ),
            WeekPlanSpec(
                name: "Week 4 (Deload)",
                primarySpecs: [
                    PercentageSetSpec(0.40, 5),
                    PercentageSetSpec(0.50, 5),
                    PercentageSetSpec(0.60, 5)
                ]
            )
        ]
    }

    static func plan(for routine: Routine) -> ProgramWorkoutPlan {
        guard let program = routine.program else {
            return .empty
        }

        switch program.kind {
        case .startingStrength:
            return startingStrengthPlan(for: routine, state: program.state)
        case .fiveThreeOne:
            return fiveThreeOnePlan(for: routine, state: program.state, includeBBB: false)
        case .boringButBig:
            return fiveThreeOnePlan(for: routine, state: program.state, includeBBB: true)
        }
    }

    static func contextLabel(for routine: Routine) -> String? {
        guard let program = routine.program else {
            return nil
        }

        switch program.kind {
        case .startingStrength:
            let isDayA = program.state.step % Constants.startingStrengthDayCount == 0
            return "\(isDayA ? "Day A" : "Day B") • Workout \(program.state.cycle)"
        case .fiveThreeOne, .boringButBig:
            let weekIndex = program.state.step % Constants.fiveThreeOneWeekCount
            let week = Constants.fiveThreeOneWeekSpecs[weekIndex]
            return "Cycle \(program.state.cycle) • \(week.name)"
        }
    }

    static func advanceProgramState(in routine: inout Routine) {
        guard var program = routine.program else {
            return
        }

        switch program.kind {
        case .startingStrength:
            program.state.step = (program.state.step + 1) % Constants.startingStrengthDayCount
            program.state.cycle += 1

        case .fiveThreeOne, .boringButBig:
            if program.state.step >= Constants.fiveThreeOneLastWeekIndex {
                program.state.step = 0
                program.state.cycle += 1
                routine.exercises = routine.exercises.map(increaseTrainingMaxForNextCycle)
            } else {
                program.state.step += 1
            }
        }

        routine.program = program
    }

    private static func startingStrengthPlan(for routine: Routine, state: ProgramState) -> ProgramWorkoutPlan {
        let isDayA = state.step % Constants.startingStrengthDayCount == 0
        let dayExercises = isDayA
            ? Constants.startingStrengthDayAExercises
            : Constants.startingStrengthDayBExercises

        var activeIDs: Set<UUID> = []
        var setTemplatesByExerciseID: [UUID: [PrescribedSetTemplate]] = [:]

        let completedSessions = max(state.cycle - 1, 0)

        for exercise in routine.exercises {
            let normalizedName = exercise.name.lowercased()
            guard dayExercises.contains(normalizedName) else {
                continue
            }

            activeIDs.insert(exercise.id)

            let progressionCount = startingStrengthProgressionCount(
                exerciseName: normalizedName,
                completedSessions: completedSessions
            )
            let increment = startingStrengthIncrement(for: normalizedName)
            let recommendedWeight = exercise.trainingMax.map {
                roundToNearestTwoPointFive($0 + Double(progressionCount) * increment)
            }

            let templateSets: [PrescribedSetTemplate]
            switch normalizedName {
            case "deadlift":
                templateSets = buildRepeatedSets(
                    count: Constants.startingStrengthDeadliftSetCount,
                    reps: Constants.startingStrengthDeadliftReps,
                    weight: recommendedWeight
                )
            case "power clean":
                templateSets = buildRepeatedSets(
                    count: Constants.startingStrengthPowerCleanSetCount,
                    reps: Constants.startingStrengthPowerCleanReps,
                    weight: recommendedWeight
                )
            default:
                templateSets = buildRepeatedSets(
                    count: Constants.startingStrengthDefaultSetCount,
                    reps: Constants.startingStrengthDefaultReps,
                    weight: recommendedWeight
                )
            }

            setTemplatesByExerciseID[exercise.id] = appendSetTMNoteIfNeeded(
                templateSets,
                hasTrainingMax: exercise.trainingMax != nil
            )
        }

        let context = "\(isDayA ? "Day A" : "Day B") • Workout \(state.cycle)"

        return ProgramWorkoutPlan(
            contextLabel: context,
            activeExerciseIDs: activeIDs,
            setTemplatesByExerciseID: setTemplatesByExerciseID
        )
    }

    private static func fiveThreeOnePlan(
        for routine: Routine,
        state: ProgramState,
        includeBBB: Bool
    ) -> ProgramWorkoutPlan {
        let weekIndex = state.step % Constants.fiveThreeOneWeekCount
        let week = Constants.fiveThreeOneWeekSpecs[weekIndex]

        var setTemplatesByExerciseID: [UUID: [PrescribedSetTemplate]] = [:]

        for exercise in routine.exercises {
            let primarySets = week.primarySpecs.map { spec in
                PrescribedSetTemplate(
                    reps: spec.reps,
                    weight: exercise.trainingMax.map { roundToNearestTwoPointFive($0 * spec.percent) },
                    note: spec.note
                )
            }

            var allSets = primarySets

            if includeBBB, weekIndex != Constants.fiveThreeOneLastWeekIndex {
                let supplementalWeight = exercise.trainingMax.map {
                    roundToNearestTwoPointFive($0 * Constants.bbbSupplementalPercent)
                }
                let bbbSets = buildRepeatedSets(
                    count: Constants.bbbSupplementalSetCount,
                    reps: Constants.bbbSupplementalReps,
                    weight: supplementalWeight,
                    note: Constants.bbbNote
                )
                allSets.append(contentsOf: bbbSets)
            }

            setTemplatesByExerciseID[exercise.id] = appendSetTMNoteIfNeeded(
                allSets,
                hasTrainingMax: exercise.trainingMax != nil
            )
        }

        return ProgramWorkoutPlan(
            contextLabel: "Cycle \(state.cycle) • \(week.name)",
            activeExerciseIDs: nil,
            setTemplatesByExerciseID: setTemplatesByExerciseID
        )
    }

    private static func buildRepeatedSets(
        count: Int,
        reps: Int,
        weight: Double?,
        note: String? = nil
    ) -> [PrescribedSetTemplate] {
        (0..<count).map { _ in
            PrescribedSetTemplate(reps: reps, weight: weight, note: note)
        }
    }

    private static func appendSetTMNoteIfNeeded(
        _ sets: [PrescribedSetTemplate],
        hasTrainingMax: Bool
    ) -> [PrescribedSetTemplate] {
        guard !hasTrainingMax else {
            return sets
        }

        return sets.map { set in
            let note = set.note.map { "\($0) • \(Constants.noTrainingMaxNote)" } ?? Constants.noTrainingMaxNote
            return PrescribedSetTemplate(reps: set.reps, weight: set.weight, note: note)
        }
    }

    private static func startingStrengthIncrement(for normalizedExerciseName: String) -> Double {
        switch normalizedExerciseName {
        case "bench press", "overhead press", "power clean":
            return Constants.startingStrengthSmallLiftIncrement
        default:
            return Constants.standardIncrement
        }
    }

    private static func startingStrengthProgressionCount(
        exerciseName normalizedExerciseName: String,
        completedSessions: Int
    ) -> Int {
        switch normalizedExerciseName {
        case "back squat":
            return completedSessions
        case "bench press", "deadlift":
            return (completedSessions + 1) / 2
        case "overhead press", "power clean":
            return completedSessions / 2
        default:
            return completedSessions
        }
    }

    private static func increaseTrainingMaxForNextCycle(_ exercise: Exercise) -> Exercise {
        guard let trainingMax = exercise.trainingMax else {
            return exercise
        }

        let increment = LiftClassifier.isLowerBodyLift(exercise.name)
            ? Constants.lowerBodyTrainingMaxIncrement
            : Constants.standardIncrement
        return Exercise(
            id: exercise.id,
            name: exercise.name,
            trainingMax: roundToNearestTwoPointFive(trainingMax + increment)
        )
    }

    private static func roundToNearestTwoPointFive(_ value: Double) -> Double {
        (value / Constants.roundingIncrement).rounded() * Constants.roundingIncrement
    }
}
