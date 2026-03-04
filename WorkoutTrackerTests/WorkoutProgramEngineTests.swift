import XCTest
@testable import WorkoutTracker

final class WorkoutProgramEngineTests: XCTestCase {
    func testPlanWithoutProgramReturnsEmpty() {
        let routine = Routine(
            name: "No Program",
            exercises: [Exercise(name: "Bench Press", trainingMax: 185)]
        )

        let plan = WorkoutProgramEngine.plan(for: routine)

        XCTAssertEqual(plan, .empty)
    }

    func testStartingStrengthDayAIncludesExpectedExercisesAndProgression() throws {
        let squat = Exercise(id: UUID(), name: "Back Squat", trainingMax: 200)
        let bench = Exercise(id: UUID(), name: "Bench Press", trainingMax: 150)
        let deadlift = Exercise(id: UUID(), name: "Deadlift", trainingMax: 300)
        let overhead = Exercise(id: UUID(), name: "Overhead Press", trainingMax: 100)
        let row = Exercise(id: UUID(), name: "Barbell Row", trainingMax: 160)

        let routine = Routine(
            name: "Starting Strength",
            exercises: [squat, bench, deadlift, overhead, row],
            program: ProgramConfig(
                kind: .startingStrength,
                state: ProgramState(step: 0, cycle: 3)
            )
        )

        let plan = WorkoutProgramEngine.plan(for: routine)

        XCTAssertEqual(plan.contextLabel, "Day A • Workout 3")
        XCTAssertEqual(plan.activeExerciseIDs, Set([squat.id, bench.id, deadlift.id]))

        let squatSets = try XCTUnwrap(plan.setTemplatesByExerciseID[squat.id])
        XCTAssertEqual(squatSets.count, 3)
        XCTAssertTrue(squatSets.allSatisfy { $0.reps == 5 })
        XCTAssertTrue(squatSets.allSatisfy { $0.weight == 210.0 })
        XCTAssertTrue(squatSets.allSatisfy { $0.note == nil })

        let benchSets = try XCTUnwrap(plan.setTemplatesByExerciseID[bench.id])
        XCTAssertEqual(benchSets.count, 3)
        XCTAssertTrue(benchSets.allSatisfy { $0.reps == 5 })
        XCTAssertTrue(benchSets.allSatisfy { $0.weight == 152.5 })

        let deadliftSets = try XCTUnwrap(plan.setTemplatesByExerciseID[deadlift.id])
        XCTAssertEqual(deadliftSets.count, 1)
        XCTAssertEqual(deadliftSets[0].reps, 5)
        XCTAssertEqual(deadliftSets[0].weight, 305.0)

        XCTAssertNil(plan.setTemplatesByExerciseID[overhead.id])
        XCTAssertNil(plan.setTemplatesByExerciseID[row.id])
    }

    func testStartingStrengthDayBIncludesPowerCleanAndTMGuidanceWhenTrainingMaxMissing() throws {
        let squat = Exercise(id: UUID(), name: "Back Squat", trainingMax: 200)
        let overhead = Exercise(id: UUID(), name: "Overhead Press", trainingMax: 100)
        let powerClean = Exercise(id: UUID(), name: "Power Clean", trainingMax: nil)

        let routine = Routine(
            name: "Starting Strength",
            exercises: [squat, overhead, powerClean],
            program: ProgramConfig(
                kind: .startingStrength,
                state: ProgramState(step: 1, cycle: 2)
            )
        )

        let plan = WorkoutProgramEngine.plan(for: routine)

        XCTAssertEqual(plan.contextLabel, "Day B • Workout 2")
        XCTAssertEqual(plan.activeExerciseIDs, Set([squat.id, overhead.id, powerClean.id]))

        let squatSets = try XCTUnwrap(plan.setTemplatesByExerciseID[squat.id])
        XCTAssertTrue(squatSets.allSatisfy { $0.weight == 205.0 })

        let overheadSets = try XCTUnwrap(plan.setTemplatesByExerciseID[overhead.id])
        XCTAssertTrue(overheadSets.allSatisfy { $0.weight == 100.0 })

        let powerCleanSets = try XCTUnwrap(plan.setTemplatesByExerciseID[powerClean.id])
        XCTAssertEqual(powerCleanSets.count, 5)
        XCTAssertTrue(powerCleanSets.allSatisfy { $0.reps == 3 })
        XCTAssertTrue(powerCleanSets.allSatisfy { $0.weight == nil })
        XCTAssertTrue(powerCleanSets.allSatisfy { $0.note == "Set training max (TM) in Edit Routine" })
    }

    func testFiveThreeOneWeekOneBuildsPrimarySets() throws {
        let bench = Exercise(id: UUID(), name: "Bench Press", trainingMax: 200)
        let routine = Routine(
            name: "5/3/1",
            exercises: [bench],
            program: ProgramConfig(
                kind: .fiveThreeOne,
                state: ProgramState(step: 0, cycle: 2)
            )
        )

        let plan = WorkoutProgramEngine.plan(for: routine)

        XCTAssertNil(plan.activeExerciseIDs)
        XCTAssertEqual(plan.contextLabel, "Cycle 2 • Week 1 (5-rep week)")

        let sets = try XCTUnwrap(plan.setTemplatesByExerciseID[bench.id])
        XCTAssertEqual(sets.count, 3)
        XCTAssertEqual(sets.map(\.reps), [5, 5, 5])
        XCTAssertEqual(sets.map(\.weight), [130.0, 150.0, 170.0].map(Optional.some))
        XCTAssertEqual(sets[2].note, "AMRAP (as many reps as possible)")
    }

    func testBoringButBigAddsSupplementalSetsExceptDeloadWeek() throws {
        let squat = Exercise(id: UUID(), name: "Back Squat", trainingMax: 300)

        let weekOneRoutine = Routine(
            name: "BBB",
            exercises: [squat],
            program: ProgramConfig(
                kind: .boringButBig,
                state: ProgramState(step: 0, cycle: 1)
            )
        )

        let weekOnePlan = WorkoutProgramEngine.plan(for: weekOneRoutine)
        let weekOneSets = try XCTUnwrap(weekOnePlan.setTemplatesByExerciseID[squat.id])
        XCTAssertEqual(weekOneSets.count, 8)
        XCTAssertEqual(weekOneSets.filter { $0.note == "BBB (5x10)" }.count, 5)

        let deloadRoutine = Routine(
            id: weekOneRoutine.id,
            name: weekOneRoutine.name,
            exercises: [squat],
            program: ProgramConfig(
                kind: .boringButBig,
                state: ProgramState(step: 3, cycle: 1)
            )
        )

        let deloadPlan = WorkoutProgramEngine.plan(for: deloadRoutine)
        let deloadSets = try XCTUnwrap(deloadPlan.setTemplatesByExerciseID[squat.id])
        XCTAssertEqual(deloadSets.count, 3)
        XCTAssertFalse(deloadSets.contains { $0.note == "BBB (5x10)" })
    }

    func testAdvanceProgramStateStartingStrengthWrapsAndIncrementsCycle() {
        var routine = Routine(
            name: "Starting Strength",
            exercises: [Exercise(name: "Back Squat", trainingMax: 200)],
            program: ProgramConfig(
                kind: .startingStrength,
                state: ProgramState(step: 1, cycle: 4)
            )
        )

        WorkoutProgramEngine.advanceProgramState(in: &routine)

        XCTAssertEqual(routine.program?.state.step, 0)
        XCTAssertEqual(routine.program?.state.cycle, 5)
    }

    func testAdvanceProgramStateFiveThreeOneCycleWrapIncreasesTrainingMaxes() {
        let squat = Exercise(id: UUID(), name: "Back Squat", trainingMax: 299)
        let bench = Exercise(id: UUID(), name: "Bench Press", trainingMax: 202.6)
        let row = Exercise(id: UUID(), name: "Barbell Row", trainingMax: nil)

        var routine = Routine(
            name: "5/3/1",
            exercises: [squat, bench, row],
            program: ProgramConfig(
                kind: .fiveThreeOne,
                state: ProgramState(step: 3, cycle: 2)
            )
        )

        WorkoutProgramEngine.advanceProgramState(in: &routine)

        XCTAssertEqual(routine.program?.state.step, 0)
        XCTAssertEqual(routine.program?.state.cycle, 3)

        XCTAssertEqual(routine.exercises[0].trainingMax, 310.0)
        XCTAssertEqual(routine.exercises[1].trainingMax, 207.5)
        XCTAssertNil(routine.exercises[2].trainingMax)
    }
}
