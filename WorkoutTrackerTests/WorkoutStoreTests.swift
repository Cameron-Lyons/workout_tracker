import Foundation
import XCTest
@testable import WorkoutTracker

final class WorkoutStoreTests: XCTestCase {
    private func makeStore(useStarterDataWhenEmpty: Bool = false) -> WorkoutStore {
        let container = WorkoutModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        return WorkoutStore(
            modelContainer: container,
            useStarterDataWhenEmpty: useStarterDataWhenEmpty
        )
    }

    func testLogWorkoutAppendsHistoryLiftRecordsAndProgressSnapshots() throws {
        let store = makeStore()
        let routine = Routine(
            id: UUID(),
            name: "Push Day",
            exercises: [
                Exercise(id: UUID(), name: "Bench Press", trainingMax: 225),
                Exercise(id: UUID(), name: "Barbell Row", trainingMax: 185)
            ]
        )

        store.addRoutine(routine)

        store.logWorkout(
            routineID: routine.id,
            entries: [
                ExerciseEntry(
                    exerciseName: "Bench Press",
                    sets: [
                        ExerciseSet(weight: 225, reps: 5),
                        ExerciseSet(weight: 235, reps: 3)
                    ]
                ),
                ExerciseEntry(
                    exerciseName: "Barbell Row",
                    sets: [
                        ExerciseSet(weight: 155, reps: 8)
                    ]
                )
            ]
        )

        XCTAssertEqual(store.workoutHistory.count, 1)
        XCTAssertEqual(store.workoutHistory[0].routineName, "Push Day")
        XCTAssertEqual(store.workoutHistory[0].entries.count, 2)

        XCTAssertEqual(store.liftHistory.count, 3)
        XCTAssertEqual(store.exerciseNamesWithLiftHistory, ["Barbell Row", "Bench Press"])

        let benchProgress = store.liftProgress(forExerciseName: "Bench Press")
        XCTAssertEqual(benchProgress.count, 1)
        XCTAssertEqual(benchProgress[0].topWeightInStoredPounds, 235)

        let rowProgress = store.liftProgress(forExerciseName: "Barbell Row")
        XCTAssertEqual(rowProgress.count, 1)
        XCTAssertEqual(rowProgress[0].topWeightInStoredPounds, 155)
    }

    func testLogWorkoutAdvancesProgramAndTrainingMaxAtCycleWrap() throws {
        let store = makeStore()
        let squatID = UUID()
        let benchID = UUID()
        let routine = Routine(
            id: UUID(),
            name: "5/3/1",
            exercises: [
                Exercise(id: squatID, name: "Back Squat", trainingMax: 300),
                Exercise(id: benchID, name: "Bench Press", trainingMax: 200)
            ],
            program: ProgramConfig(
                kind: .fiveThreeOne,
                state: ProgramState(step: 3, cycle: 2)
            )
        )

        store.addRoutine(routine)
        store.logWorkout(
            routineID: routine.id,
            entries: [
                ExerciseEntry(
                    exerciseName: "Back Squat",
                    sets: [ExerciseSet(weight: 315, reps: 1)]
                )
            ]
        )

        let progressedRoutine = try XCTUnwrap(store.routine(withID: routine.id))
        XCTAssertEqual(progressedRoutine.program?.state.step, 0)
        XCTAssertEqual(progressedRoutine.program?.state.cycle, 3)

        let squat = try XCTUnwrap(progressedRoutine.exercises.first { $0.id == squatID })
        XCTAssertEqual(squat.trainingMax, 310)

        let bench = try XCTUnwrap(progressedRoutine.exercises.first { $0.id == benchID })
        XCTAssertEqual(bench.trainingMax, 205)
    }

    func testLogWorkoutIgnoresEntriesWithoutSets() {
        let store = makeStore()
        let routine = Routine(
            id: UUID(),
            name: "Light Day",
            exercises: [Exercise(id: UUID(), name: "Bench Press")]
        )

        store.addRoutine(routine)
        store.logWorkout(
            routineID: routine.id,
            entries: [ExerciseEntry(exerciseName: "Bench Press", sets: [])]
        )

        XCTAssertTrue(store.workoutHistory.isEmpty)
        XCTAssertTrue(store.liftHistory.isEmpty)
        XCTAssertTrue(store.exerciseNamesWithLiftHistory.isEmpty)
    }

    func testWeightRecommendationUsesPreferredRoutineHistoryWhenExerciseAppearsInMultipleRoutines() throws {
        let store = makeStore()
        let routineA = Routine(
            id: UUID(),
            name: "Upper A",
            exercises: [Exercise(id: UUID(), name: "Bench Press")]
        )
        let routineB = Routine(
            id: UUID(),
            name: "Upper B",
            exercises: [Exercise(id: UUID(), name: "Bench Press")]
        )

        store.addRoutine(routineA)
        store.addRoutine(routineB)

        store.logWorkout(
            routineID: routineA.id,
            entries: [
                ExerciseEntry(
                    exerciseName: "Bench Press",
                    sets: [ExerciseSet(weight: 200, reps: 8)]
                )
            ]
        )

        Thread.sleep(forTimeInterval: 0.02)

        store.logWorkout(
            routineID: routineB.id,
            entries: [
                ExerciseEntry(
                    exerciseName: "Bench Press",
                    sets: [ExerciseSet(weight: 215, reps: 3)]
                )
            ]
        )

        let recommendation = try XCTUnwrap(
            store.weightRecommendation(
                routineName: "Upper A",
                exerciseName: "Bench Press",
                targetReps: [],
                minimumIncrease: 2.5,
                unit: .pounds
            )
        )

        XCTAssertTrue(recommendation.shouldIncrease)
        XCTAssertEqual(recommendation.recommendedWeight, 202.5)
        XCTAssertTrue(recommendation.guidance.contains("Top set reached 8 reps"))
    }

    func testWeightRecommendationForLowerBodyUsesDefaultIncrementWhenTargetsMet() throws {
        let store = makeStore()
        let routine = Routine(
            id: UUID(),
            name: "Lower",
            exercises: [Exercise(id: UUID(), name: "Back Squat")]
        )

        store.addRoutine(routine)
        store.logWorkout(
            routineID: routine.id,
            entries: [
                ExerciseEntry(
                    exerciseName: "Back Squat",
                    sets: [
                        ExerciseSet(weight: 315, reps: 5),
                        ExerciseSet(weight: 315, reps: 5),
                        ExerciseSet(weight: 315, reps: 5)
                    ]
                )
            ]
        )

        let recommendation = try XCTUnwrap(
            store.weightRecommendation(
                routineName: "Lower",
                exerciseName: "Back Squat",
                targetReps: [5, 5, 5],
                minimumIncrease: 2.5,
                unit: .pounds
            )
        )

        XCTAssertTrue(recommendation.shouldIncrease)
        XCTAssertEqual(recommendation.recommendedWeight, 320)
        XCTAssertTrue(recommendation.guidance.contains("Hit all target reps (5/5/5)"))
        XCTAssertTrue(recommendation.guidance.contains("Add 5 lb"))
    }
}
