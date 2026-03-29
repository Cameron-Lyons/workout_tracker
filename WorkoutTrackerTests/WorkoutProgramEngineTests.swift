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
                SetTarget(targetWeight: 225, repRange: RepRange(8, 10)),
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
                ),
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

    func testDoubleProgressionSeedsMissingTargetWeightsFromCompletedWork() {
        let block = ExerciseBlock(
            exerciseID: CatalogSeed.backSquat,
            exerciseNameSnapshot: "Back Squat",
            progressionRule: ProgressionRule(
                kind: .doubleProgression,
                doubleProgression: DoubleProgressionRule(
                    targetRepRange: RepRange(5, 5),
                    increment: 5
                )
            ),
            targets: [
                SetTarget(repRange: RepRange(5, 5)),
                SetTarget(repRange: RepRange(5, 5)),
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
                        reps: 5,
                        completedAt: .now
                    )
                ),
                SessionSetRow(
                    target: block.targets[1],
                    log: SetLog(
                        setTargetID: block.targets[1].id,
                        weight: 225,
                        reps: 5,
                        completedAt: .now
                    )
                ),
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

    func testDoubleProgressionHandlesDuplicateTargetIDsInCompletedRows() {
        let target = SetTarget(repRange: RepRange(5, 5))
        let block = ExerciseBlock(
            exerciseID: CatalogSeed.backSquat,
            exerciseNameSnapshot: "Back Squat",
            progressionRule: ProgressionRule(
                kind: .doubleProgression,
                doubleProgression: DoubleProgressionRule(
                    targetRepRange: RepRange(5, 5),
                    increment: 5
                )
            ),
            targets: [target]
        )

        let duplicateRow = SessionSetRow(
            target: target,
            log: SetLog(
                setTargetID: target.id,
                weight: 135,
                reps: 5,
                completedAt: .now
            )
        )
        let completedBlock = CompletedSessionBlock(
            exerciseID: CatalogSeed.backSquat,
            exerciseNameSnapshot: "Back Squat",
            blockNote: "",
            restSeconds: 90,
            supersetGroup: nil,
            progressionRule: block.progressionRule,
            sets: [duplicateRow, duplicateRow]
        )

        let updated = ProgressionEngine.applyCompletion(
            to: block,
            using: completedBlock,
            profile: nil,
            fallbackIncrement: 5
        )

        XCTAssertEqual(updated.block.targets.compactMap(\.targetWeight), [140])
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
                                PercentageWaveSet(percentage: 0.85, repRange: RepRange(5, 5)),
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
                PercentageWaveWeek(name: "Week 2", sets: [PercentageWaveSet(percentage: 0.70, repRange: RepRange(3, 3))]),
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

        let completedTarget = SetTarget(setKind: .working, targetWeight: 140, repRange: RepRange(3, 3))
        let completedBlock = CompletedSessionBlock(
            exerciseID: CatalogSeed.deadlift,
            exerciseNameSnapshot: "Deadlift",
            blockNote: "",
            restSeconds: 180,
            supersetGroup: nil,
            progressionRule: block.progressionRule,
            sets: [
                SessionSetRow(
                    target: completedTarget,
                    log: SetLog(setTargetID: completedTarget.id, weight: 140, reps: 3, completedAt: .now)
                )
            ]
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
        XCTAssertEqual(updated.block.targets.count, 1)
        XCTAssertEqual(updated.block.targets.first?.targetWeight, 137.5)
        XCTAssertEqual(updated.block.targets.first?.repRange, RepRange(5, 5))
    }

    func testPercentageWaveDoesNotAdvanceWhenWorkingSetsRemainIncomplete() {
        let wave = PercentageWaveRule(
            trainingMax: 200,
            weeks: [
                PercentageWaveWeek(name: "Week 1", sets: [PercentageWaveSet(percentage: 0.65, repRange: RepRange(5, 5))]),
                PercentageWaveWeek(name: "Week 2", sets: [PercentageWaveSet(percentage: 0.70, repRange: RepRange(3, 3))]),
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

        let incompleteTarget = SetTarget(setKind: .working, targetWeight: 140, repRange: RepRange(3, 3))
        let completedBlock = CompletedSessionBlock(
            exerciseID: CatalogSeed.deadlift,
            exerciseNameSnapshot: "Deadlift",
            blockNote: "",
            restSeconds: 180,
            supersetGroup: nil,
            progressionRule: block.progressionRule,
            sets: [
                SessionSetRow(
                    target: incompleteTarget,
                    log: SetLog(setTargetID: incompleteTarget.id, weight: 140, reps: 3, completedAt: nil)
                )
            ]
        )
        let profile = ExerciseProfile(exerciseID: CatalogSeed.deadlift, trainingMax: 200, preferredIncrement: 10)

        let updated = ProgressionEngine.applyCompletion(
            to: block,
            using: completedBlock,
            profile: profile,
            fallbackIncrement: 10
        )

        XCTAssertEqual(updated.block.progressionRule.percentageWave?.currentWeekIndex, 1)
        XCTAssertEqual(updated.block.progressionRule.percentageWave?.cycle, 1)
        XCTAssertEqual(updated.profile?.trainingMax, 200)
        XCTAssertEqual(updated.block.targets, block.targets)
    }

    func testPercentageWaveWrapRespectsCustomCycleIncrementBelowFallback() {
        let wave = PercentageWaveRule(
            trainingMax: 200,
            weeks: [
                PercentageWaveWeek(name: "Week 1", sets: [PercentageWaveSet(percentage: 0.65, repRange: RepRange(5, 5))]),
                PercentageWaveWeek(name: "Week 2", sets: [PercentageWaveSet(percentage: 0.70, repRange: RepRange(3, 3))]),
            ],
            currentWeekIndex: 1,
            cycle: 1,
            cycleIncrement: 5
        )
        let block = ExerciseBlock(
            exerciseID: CatalogSeed.deadlift,
            exerciseNameSnapshot: "Deadlift",
            progressionRule: ProgressionRule(kind: .percentageWave, percentageWave: wave),
            targets: []
        )
        let completedTarget = SetTarget(setKind: .working, targetWeight: 140, repRange: RepRange(3, 3))
        let completedBlock = CompletedSessionBlock(
            exerciseID: CatalogSeed.deadlift,
            exerciseNameSnapshot: "Deadlift",
            blockNote: "",
            restSeconds: 180,
            supersetGroup: nil,
            progressionRule: block.progressionRule,
            sets: [
                SessionSetRow(
                    target: completedTarget,
                    log: SetLog(setTargetID: completedTarget.id, weight: 140, reps: 3, completedAt: .now)
                )
            ]
        )
        let profile = ExerciseProfile(exerciseID: CatalogSeed.deadlift, trainingMax: 200, preferredIncrement: 10)

        let updated = ProgressionEngine.applyCompletion(
            to: block,
            using: completedBlock,
            profile: profile,
            fallbackIncrement: 10
        )

        XCTAssertEqual(updated.profile?.trainingMax, 205)
        XCTAssertEqual(updated.block.progressionRule.percentageWave?.trainingMax, 205)
    }

    func testDoubleProgressionDoesNotAdvanceWithoutWorkingSets() {
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
                    target: SetTarget(setKind: .warmup, targetWeight: 135, repRange: RepRange(5, 5)),
                    log: SetLog(setTargetID: UUID(), weight: 135, reps: 5, completedAt: .now)
                )
            ]
        )

        let updated = ProgressionEngine.applyCompletion(
            to: block,
            using: completedBlock,
            profile: nil,
            fallbackIncrement: 5
        )

        XCTAssertEqual(updated.block.targets.compactMap(\.targetWeight), [225])
    }

    func testDoubleProgressionDoesNotAdvanceWhenWorkingSetsRemainIncomplete() {
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
                SetTarget(targetWeight: 225, repRange: RepRange(8, 10)),
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
                        reps: 10,
                        completedAt: nil
                    )
                ),
            ]
        )

        let updated = ProgressionEngine.applyCompletion(
            to: block,
            using: completedBlock,
            profile: nil,
            fallbackIncrement: 5
        )

        XCTAssertEqual(updated.block.targets.compactMap(\.targetWeight), [225, 225])
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

    func testToggleCompletionKeepsLoggedValuesWhenReopeningASet() throws {
        let target = SetTarget(targetWeight: 185, repRange: RepRange(5, 5), rir: 2)
        let completedAt = Date(timeIntervalSince1970: 1_741_478_400)
        let reopenedAt = completedAt.addingTimeInterval(60)
        let row = SessionSetRow(
            target: target,
            log: SetLog(
                setTargetID: target.id,
                weight: 190,
                reps: 6,
                rir: 1,
                completedAt: completedAt
            )
        )
        let block = SessionBlock(
            exerciseID: CatalogSeed.benchPress,
            exerciseNameSnapshot: "Bench Press",
            restSeconds: 90,
            progressionRule: .manual,
            sets: [row]
        )
        var draft = SessionDraft(
            planID: UUID(),
            templateID: UUID(),
            templateNameSnapshot: "Bench Day",
            blocks: [block],
            restTimerEndsAt: completedAt.addingTimeInterval(90)
        )

        SessionEngine.toggleCompletion(of: row.id, in: block.id, draft: &draft, completedAt: reopenedAt)

        let reopenedRow = try XCTUnwrap(draft.blocks.first?.sets.first)
        XCTAssertFalse(reopenedRow.log.isCompleted)
        XCTAssertEqual(reopenedRow.log.weight, 190)
        XCTAssertEqual(reopenedRow.log.reps, 6)
        XCTAssertEqual(reopenedRow.log.rir, 1)
        XCTAssertNil(draft.restTimerEndsAt)
    }

    func testAdjustWeightDoesNotMaterializeZeroWhenDecreasingUnsetWeight() throws {
        let row = SessionSetRow(target: SetTarget(repRange: RepRange(5, 5)))
        let block = SessionBlock(
            exerciseID: CatalogSeed.benchPress,
            exerciseNameSnapshot: "Bench Press",
            restSeconds: 90,
            progressionRule: .manual,
            sets: [row]
        )
        var draft = SessionDraft(
            planID: UUID(),
            templateID: UUID(),
            templateNameSnapshot: "Bench Day",
            blocks: [block]
        )

        SessionEngine.adjustWeight(by: -5, setID: row.id, in: block.id, draft: &draft)

        let updatedRow = try XCTUnwrap(draft.blocks.first?.sets.first)
        XCTAssertNil(updatedRow.target.targetWeight)
        XCTAssertNil(updatedRow.log.weight)
    }

    func testUpdateWeightStoresExactLoggedWeight() throws {
        let row = SessionSetRow(
            target: SetTarget(
                targetWeight: 185,
                repRange: RepRange(5, 5)
            )
        )
        let block = SessionBlock(
            exerciseID: CatalogSeed.benchPress,
            exerciseNameSnapshot: "Bench Press",
            restSeconds: 90,
            progressionRule: .manual,
            sets: [row]
        )
        var draft = SessionDraft(
            planID: UUID(),
            templateID: UUID(),
            templateNameSnapshot: "Bench Day",
            blocks: [block]
        )

        SessionEngine.updateWeight(to: 192.5, setID: row.id, in: block.id, draft: &draft)

        let updatedRow = try XCTUnwrap(draft.blocks.first?.sets.first)
        XCTAssertEqual(updatedRow.log.weight, 192.5)
    }

    func testUpdateRepsStoresExactLoggedReps() throws {
        let row = SessionSetRow(target: SetTarget(repRange: RepRange(8, 10)))
        let block = SessionBlock(
            exerciseID: CatalogSeed.benchPress,
            exerciseNameSnapshot: "Bench Press",
            restSeconds: 90,
            progressionRule: .manual,
            sets: [row]
        )
        var draft = SessionDraft(
            planID: UUID(),
            templateID: UUID(),
            templateNameSnapshot: "Bench Day",
            blocks: [block]
        )

        SessionEngine.updateReps(to: 12, setID: row.id, in: block.id, draft: &draft)

        let updatedRow = try XCTUnwrap(draft.blocks.first?.sets.first)
        XCTAssertEqual(updatedRow.log.reps, 12)
    }

    func testAddSetAssignsNewTargetIdentityAndCopiesLastLogValues() throws {
        let target = SetTarget(targetWeight: 185, repRange: RepRange(5, 5))
        let row = SessionSetRow(
            target: target,
            log: SetLog(
                setTargetID: target.id,
                weight: 190,
                reps: 6,
                rir: 1
            )
        )
        let block = SessionBlock(
            exerciseID: CatalogSeed.benchPress,
            exerciseNameSnapshot: "Bench Press",
            restSeconds: 90,
            progressionRule: .manual,
            sets: [row]
        )
        var draft = SessionDraft(
            planID: UUID(),
            templateID: UUID(),
            templateNameSnapshot: "Bench Day",
            blocks: [block]
        )

        SessionEngine.addSet(to: block.id, draft: &draft)

        let rows = try XCTUnwrap(draft.blocks.first?.sets)
        XCTAssertEqual(rows.count, 2)
        XCTAssertNotEqual(rows[0].target.id, rows[1].target.id)
        XCTAssertEqual(rows[1].log.setTargetID, rows[1].target.id)
        XCTAssertEqual(rows[1].log.weight, 190)
        XCTAssertEqual(rows[1].log.reps, 6)
        XCTAssertEqual(rows[1].log.rir, 1)
        XCTAssertNil(rows[1].log.completedAt)
    }
}
