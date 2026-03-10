import XCTest
@testable import WorkoutTracker

final class WorkoutProgramEngineTests: XCTestCase {
    func testManualProgressionReturnsExistingTargets() {
        let block = ExerciseBlock(
            exerciseID: CatalogSeed.benchPress,
            exerciseNameSnapshot: "Bench Press",
            progressionRule: .manual,
            targets: [
                SetTarget(targetWeight: 185, repRange: RepRange(5, 5))
            ]
        )

        let resolvedTargets = ProgressionEngine.resolvedTargets(for: block, profile: nil)

        XCTAssertEqual(resolvedTargets, block.targets)
    }

    func testDoubleProgressionIncreasesWorkingTargetsAfterTopRepGoalIsMet() {
        let block = ExerciseBlock(
            exerciseID: CatalogSeed.backSquat,
            exerciseNameSnapshot: "Back Squat",
            progressionRule: ProgressionRule(
                kind: .doubleProgression,
                doubleProgression: DoubleProgressionRule(
                    targetRepRange: RepRange(8, 10),
                    increment: 5
                )
            ),
            targets: [
                SetTarget(targetWeight: 225, repRange: RepRange(8, 10)),
                SetTarget(targetWeight: 225, repRange: RepRange(8, 10))
            ]
        )

        let completedBlock = CompletedSessionBlock(
            exerciseID: CatalogSeed.backSquat,
            exerciseNameSnapshot: "Back Squat",
            blockNote: "",
            restSeconds: 90,
            supersetGroup: nil,
            progressionRule: block.progressionRule,
            sets: [
                SessionSetRow(
                    target: block.targets[0],
                    log: SetLog(
                        setTargetID: block.targets[0].id,
                        weight: 225,
                        reps: 10,
                        completedAt: .now
                    )
                ),
                SessionSetRow(
                    target: block.targets[1],
                    log: SetLog(
                        setTargetID: block.targets[1].id,
                        weight: 225,
                        reps: 11,
                        completedAt: .now
                    )
                )
            ]
        )

        let updated = ProgressionEngine.applyCompletion(
            to: block,
            using: completedBlock,
            profile: nil,
            fallbackIncrement: 5
        )

        XCTAssertEqual(updated.block.targets.compactMap(\.targetWeight), [230, 230])
    }

    func testPercentageWaveUsesTrainingMaxToResolveWorkingSets() {
        let block = ExerciseBlock(
            exerciseID: CatalogSeed.benchPress,
            exerciseNameSnapshot: "Bench Press",
            progressionRule: ProgressionRule(
                kind: .percentageWave,
                percentageWave: PercentageWaveRule(
                    trainingMax: 200,
                    weeks: [
                        PercentageWaveWeek(
                            name: "Week 1",
                            sets: [
                                PercentageWaveSet(percentage: 0.65, repRange: RepRange(5, 5)),
                                PercentageWaveSet(percentage: 0.75, repRange: RepRange(5, 5)),
                                PercentageWaveSet(percentage: 0.85, repRange: RepRange(5, 5))
                            ]
                        )
                    ],
                    cycleIncrement: 5
                )
            ),
            targets: []
        )

        let resolvedTargets = ProgressionEngine.resolvedTargets(for: block, profile: nil)

        XCTAssertEqual(resolvedTargets.compactMap(\.targetWeight), [130, 150, 170])
        XCTAssertEqual(resolvedTargets.map(\.repRange), [RepRange(5, 5), RepRange(5, 5), RepRange(5, 5)])
    }

    func testPercentageWaveWrapAdvancesCycleAndTrainingMax() {
        let wave = PercentageWaveRule(
            trainingMax: 200,
            weeks: [
                PercentageWaveWeek(name: "Week 1", sets: [PercentageWaveSet(percentage: 0.65, repRange: RepRange(5, 5))]),
                PercentageWaveWeek(name: "Week 2", sets: [PercentageWaveSet(percentage: 0.70, repRange: RepRange(3, 3))])
            ],
            currentWeekIndex: 1,
            cycle: 1,
            cycleIncrement: 10
        )
        let block = ExerciseBlock(
            exerciseID: CatalogSeed.deadlift,
            exerciseNameSnapshot: "Deadlift",
            progressionRule: ProgressionRule(kind: .percentageWave, percentageWave: wave),
            targets: []
        )

        let completedBlock = CompletedSessionBlock(
            exerciseID: CatalogSeed.deadlift,
            exerciseNameSnapshot: "Deadlift",
            blockNote: "",
            restSeconds: 180,
            supersetGroup: nil,
            progressionRule: block.progressionRule,
            sets: []
        )
        let profile = ExerciseProfile(exerciseID: CatalogSeed.deadlift, trainingMax: 200, preferredIncrement: 10)

        let updated = ProgressionEngine.applyCompletion(
            to: block,
            using: completedBlock,
            profile: profile,
            fallbackIncrement: 10
        )

        XCTAssertEqual(updated.block.progressionRule.percentageWave?.currentWeekIndex, 0)
        XCTAssertEqual(updated.block.progressionRule.percentageWave?.cycle, 2)
        XCTAssertEqual(updated.profile?.trainingMax, 210)
    }

    func testStartingSessionInjectsWarmupsBeforeWorkingSets() {
        let template = WorkoutTemplate(
            name: "Test Template",
            blocks: [
                ExerciseBlock(
                    exerciseID: CatalogSeed.benchPress,
                    exerciseNameSnapshot: "Bench Press",
                    progressionRule: .manual,
                    targets: [
                        SetTarget(targetWeight: 185, repRange: RepRange(5, 5), restSeconds: 90)
                    ],
                    allowsAutoWarmups: true
                )
            ]
        )

        let draft = SessionEngine.startSession(
            planID: UUID(),
            template: template,
            profilesByExerciseID: [:],
            warmupRamp: WarmupDefaults.ramp
        )

        let setKinds = draft.blocks.first?.sets.map(\.target.setKind)
        XCTAssertEqual(setKinds, [.warmup, .warmup, .working])
        XCTAssertEqual(draft.blocks.first?.sets.first?.target.targetWeight, 75)
        XCTAssertEqual(draft.blocks.first?.sets.dropFirst().first?.target.targetWeight, 110)
    }
}
