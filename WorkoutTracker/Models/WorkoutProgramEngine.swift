import Foundation

enum ProgressionEngine {
    private static let defaultWaveRounding = StrengthProgressionDefaults.gymRoundingIncrement

    static func resolvedTargets(
        for block: ExerciseBlock,
        profile: ExerciseProfile?
    ) -> [SetTarget] {
        switch block.progressionRule.kind {
        case .manual, .doubleProgression:
            return block.targets

        case .percentageWave:
            guard let wave = block.progressionRule.percentageWave else {
                return block.targets
            }

            let trainingMax = profile?.trainingMax ?? wave.trainingMax
            let safeWeekIndex = max(0, min(wave.currentWeekIndex, wave.weeks.count - 1))
            let week = wave.weeks[safeWeekIndex]

            return week.sets.map { waveSet in
                SetTarget(
                    setKind: .working,
                    targetWeight: trainingMax.map { roundToGymIncrement($0 * waveSet.percentage) },
                    repRange: waveSet.repRange,
                    rir: nil,
                    restSeconds: nil,
                    note: week.name + (waveSet.note.map { " • \($0)" } ?? "")
                )
            }
        }
    }

    static func applyCompletion(
        to block: ExerciseBlock,
        using completedBlock: CompletedSessionBlock,
        profile: ExerciseProfile?,
        fallbackIncrement: Double
    ) -> (block: ExerciseBlock, profile: ExerciseProfile?) {
        switch block.progressionRule.kind {
        case .manual:
            return (block, profile)

        case .doubleProgression:
            return applyDoubleProgression(
                to: block,
                using: completedBlock,
                profile: profile,
                fallbackIncrement: fallbackIncrement
            )

        case .percentageWave:
            return applyPercentageWave(
                to: block,
                using: completedBlock,
                profile: profile,
                fallbackIncrement: fallbackIncrement
            )
        }
    }

    private static func applyDoubleProgression(
        to block: ExerciseBlock,
        using completedBlock: CompletedSessionBlock,
        profile: ExerciseProfile?,
        fallbackIncrement: Double
    ) -> (block: ExerciseBlock, profile: ExerciseProfile?) {
        guard let config = block.progressionRule.doubleProgression else {
            return (block, profile)
        }

        let workingRows = completedBlock.sets.filter { $0.target.setKind == .working }
        guard !workingRows.isEmpty,
            workingRows.allSatisfy(\.log.isCompleted)
        else {
            return (block, profile)
        }

        let hitAllTargets = workingRows.allSatisfy {
            guard let reps = $0.log.reps else {
                return false
            }

            return reps >= config.targetRepRange.upperBound
        }

        let increment = profile?.preferredIncrement ?? config.increment
        let completedRowsByTargetID = workingRows.reduce(into: [UUID: SessionSetRow]()) { partialResult, row in
            partialResult[row.target.id] = row
        }
        var seededMissingTargetWeight = false
        let updatedTargets = block.targets.map { target in
            guard target.setKind == .working else {
                return target
            }

            var updatedTarget = target
            if let targetWeight = target.targetWeight {
                if hitAllTargets {
                    updatedTarget.targetWeight = targetWeight + increment
                }
            } else if let completedWeight = completedRowsByTargetID[target.id]?.log.weight {
                updatedTarget.targetWeight = hitAllTargets ? completedWeight + increment : completedWeight
                seededMissingTargetWeight = true
            }
            if hitAllTargets {
                updatedTarget.repRange = config.targetRepRange
            }
            return updatedTarget
        }

        guard hitAllTargets || seededMissingTargetWeight else {
            return (block, profile)
        }

        var updatedRule = block.progressionRule
        if updatedRule.doubleProgression == nil {
            updatedRule.doubleProgression = DoubleProgressionRule(
                targetRepRange: config.targetRepRange,
                increment: fallbackIncrement
            )
        }

        var updatedBlock = block
        updatedBlock.targets = updatedTargets
        updatedBlock.progressionRule = updatedRule
        return (updatedBlock, profile)
    }

    private static func applyPercentageWave(
        to block: ExerciseBlock,
        using completedBlock: CompletedSessionBlock,
        profile: ExerciseProfile?,
        fallbackIncrement: Double
    ) -> (block: ExerciseBlock, profile: ExerciseProfile?) {
        guard var wave = block.progressionRule.percentageWave, !wave.weeks.isEmpty else {
            return (block, profile)
        }

        let workingRows = completedBlock.sets.filter { $0.target.setKind == .working }
        guard !workingRows.isEmpty,
            workingRows.allSatisfy(\.log.isCompleted)
        else {
            return (block, profile)
        }

        let isWrapping = wave.currentWeekIndex >= wave.weeks.count - 1
        if isWrapping {
            wave.currentWeekIndex = 0
            wave.cycle += 1

            if let trainingMax = profile?.trainingMax ?? wave.trainingMax {
                let cycleIncrement = wave.cycleIncrement > 0 ? wave.cycleIncrement : fallbackIncrement
                let updatedTrainingMax = trainingMax + cycleIncrement
                wave.trainingMax = updatedTrainingMax

                if var updatedProfile = profile {
                    updatedProfile.trainingMax = updatedTrainingMax
                    return (updatedWaveBlock(from: block, wave: wave, profile: updatedProfile), updatedProfile)
                }
            }
        } else {
            wave.currentWeekIndex += 1
        }

        return (updatedWaveBlock(from: block, wave: wave, profile: profile), profile)
    }

    private static func roundToGymIncrement(_ value: Double) -> Double {
        (value / defaultWaveRounding).rounded() * defaultWaveRounding
    }

    private static func updatedWaveBlock(
        from block: ExerciseBlock,
        wave: PercentageWaveRule,
        profile: ExerciseProfile?
    ) -> ExerciseBlock {
        var updatedBlock = block.updatingWave(wave)
        updatedBlock.targets = resolvedTargets(for: updatedBlock, profile: profile)
        return updatedBlock
    }
}

enum SessionEngine {
    private static let defaultRepRange = ExerciseBlockDefaults.repRange
    private static let minimumRestTimerSeconds = 1

    static func startSession(
        planID: UUID?,
        template: WorkoutTemplate,
        profilesByExerciseID: [UUID: ExerciseProfile],
        warmupRamp: [WarmupRampStep],
        startedAt: Date = .now
    ) -> SessionDraft {
        let blocks = template.blocks.map { block in
            let profile = profilesByExerciseID[block.exerciseID]
            let workingTargets = ProgressionEngine.resolvedTargets(for: block, profile: profile)
            let targets = resolvedTargets(
                for: block,
                workingTargets: workingTargets,
                warmupRamp: warmupRamp
            )

            return SessionBlock(
                id: block.id,
                exerciseID: block.exerciseID,
                exerciseNameSnapshot: block.exerciseNameSnapshot,
                blockNote: block.blockNote,
                restSeconds: block.restSeconds,
                supersetGroup: block.supersetGroup,
                progressionRule: block.progressionRule,
                sets: targets.map { SessionSetRow(target: $0) }
            )
        }

        return SessionDraft(
            planID: planID,
            templateID: template.id,
            templateNameSnapshot: template.name,
            startedAt: startedAt,
            lastUpdatedAt: startedAt,
            blocks: blocks
        )
    }

    static func toggleCompletion(
        of setID: UUID,
        in blockID: UUID,
        draft: inout SessionDraft,
        completedAt: Date = .now
    ) {
        var nextRestTimerEndsAt: Date?

        draft.mutateBlock(blockID) { block in
            let blockRestSeconds = block.restSeconds
            block.mutatingSet(setID) { row in
                if row.log.isCompleted {
                    row.log.completedAt = nil
                    nextRestTimerEndsAt = nil
                } else {
                    row.log.weight = row.log.weight ?? row.target.targetWeight
                    row.log.reps = row.log.reps ?? row.target.repRange.upperBound
                    row.log.rir = row.log.rir ?? row.target.rir
                    row.log.completedAt = completedAt
                    let seconds = row.target.restSeconds ?? blockRestSeconds
                    nextRestTimerEndsAt = completedAt.addingTimeInterval(
                        TimeInterval(max(minimumRestTimerSeconds, seconds))
                    )
                }
            }
        }

        draft.restTimerEndsAt = nextRestTimerEndsAt
        draft.touch(now: completedAt)
    }

    static func adjustWeight(
        by delta: Double,
        setID: UUID,
        in blockID: UUID,
        draft: inout SessionDraft,
        now: Date = .now
    ) {
        draft.mutateBlock(blockID) { block in
            block.mutatingSet(setID) { row in
                if let baseWeight = row.log.weight ?? row.target.targetWeight {
                    row.log.weight = max(0, baseWeight + delta)
                } else if delta > 0 {
                    row.log.weight = delta
                }
            }
        }
        draft.touch(now: now)
    }

    static func adjustReps(
        by delta: Int,
        setID: UUID,
        in blockID: UUID,
        draft: inout SessionDraft,
        now: Date = .now
    ) {
        draft.mutateBlock(blockID) { block in
            block.mutatingSet(setID) { row in
                let baseReps = row.log.reps ?? row.target.repRange.upperBound
                row.log.reps = max(0, baseReps + delta)
            }
        }
        draft.touch(now: now)
    }

    static func updateNotes(
        in blockID: UUID,
        note: String,
        draft: inout SessionDraft,
        now: Date = .now
    ) {
        draft.mutateBlock(blockID) { block in
            block.blockNote = note
        }
        draft.touch(now: now)
    }

    static func updateSessionNotes(
        _ notes: String,
        draft: inout SessionDraft,
        now: Date = .now
    ) {
        draft.notes = notes
        draft.touch(now: now)
    }

    static func addSet(
        to blockID: UUID,
        draft: inout SessionDraft,
        now: Date = .now
    ) {
        draft.mutateBlock(blockID) { block in
            let copiedTarget = block.sets.last?.target ?? SetTarget(repRange: defaultRepRange)
            let copiedLog = block.sets.last?.log
            var newRow = SessionSetRow(target: copiedTarget)
            newRow.target.id = UUID()
            newRow.log.setTargetID = newRow.target.id
            if let copiedLog {
                newRow.log.weight = copiedLog.weight
                newRow.log.reps = copiedLog.reps
                newRow.log.rir = copiedLog.rir
            }
            block.sets.append(newRow)
        }
        draft.touch(now: now)
    }

    static func copyLastSet(
        in blockID: UUID,
        draft: inout SessionDraft,
        now: Date = .now
    ) {
        draft.mutateBlock(blockID) { block in
            guard let lastRow = block.sets.last else {
                return
            }

            var newRow = SessionSetRow(
                target: lastRow.target,
                log: SetLog(
                    setTargetID: lastRow.target.id,
                    weight: lastRow.log.weight,
                    reps: lastRow.log.reps,
                    rir: lastRow.log.rir
                )
            )
            newRow.target.id = UUID()
            newRow.log.setTargetID = newRow.target.id
            block.sets.append(newRow)
        }
        draft.touch(now: now)
    }

    static func addExerciseBlock(
        exercise: ExerciseCatalogItem,
        draft: inout SessionDraft,
        defaultRestSeconds: Int,
        now: Date = .now
    ) {
        draft.blocks.append(
            SessionBlock(
                exerciseID: exercise.id,
                exerciseNameSnapshot: exercise.name,
                restSeconds: defaultRestSeconds,
                progressionRule: .manual,
                sets: [
                    SessionSetRow(
                        target: SetTarget(
                            setKind: .working,
                            targetWeight: nil,
                            repRange: defaultRepRange,
                            restSeconds: defaultRestSeconds
                        )
                    )
                ]
            )
        )
        draft.touch(now: now)
    }

    static func finishSession(
        draft: SessionDraft,
        completedAt: Date = .now
    ) -> CompletedSession {
        CompletedSession(
            id: draft.id,
            planID: draft.planID,
            templateID: draft.templateID,
            templateNameSnapshot: draft.templateNameSnapshot,
            startedAt: draft.startedAt,
            completedAt: completedAt,
            notes: draft.notes,
            blocks: draft.blocks.map { block in
                CompletedSessionBlock(
                    exerciseID: block.exerciseID,
                    exerciseNameSnapshot: block.exerciseNameSnapshot,
                    blockNote: block.blockNote,
                    restSeconds: block.restSeconds,
                    supersetGroup: block.supersetGroup,
                    progressionRule: block.progressionRule,
                    sets: block.sets
                )
            }
        )
    }

    static func defaultDoubleProgressionRule(
        exerciseName: String,
        preferredIncrement: Double? = nil
    ) -> ProgressionRule {
        let fallbackIncrement =
            ExerciseClassification.isLowerBody(exerciseName)
            ? StrengthProgressionDefaults.lowerBodyIncreaseInPounds
            : StrengthProgressionDefaults.upperBodyIncreaseInPounds

        return ProgressionRule(
            kind: .doubleProgression,
            doubleProgression: DoubleProgressionRule(
                targetRepRange: DoubleProgressionDefaults.repRange,
                increment: preferredIncrement ?? fallbackIncrement
            )
        )
    }

    private static func resolvedTargets(
        for block: ExerciseBlock,
        workingTargets: [SetTarget],
        warmupRamp: [WarmupRampStep]
    ) -> [SetTarget] {
        guard block.allowsAutoWarmups,
            let firstWeightedTarget = workingTargets.first(where: { $0.targetWeight != nil }),
            let firstWeight = firstWeightedTarget.targetWeight,
            firstWeight > 0
        else {
            return workingTargets
        }

        let warmups = warmupRamp.map {
            SetTarget(
                setKind: .warmup,
                targetWeight: (firstWeight * $0.percentage / StrengthProgressionDefaults.gymRoundingIncrement)
                    .rounded() * StrengthProgressionDefaults.gymRoundingIncrement,
                repRange: RepRange($0.reps, $0.reps),
                restSeconds: block.restSeconds,
                note: WarmupDefaults.note
            )
        }

        return warmups + workingTargets
    }

}

private extension ExerciseBlock {
    func updatingWave(_ wave: PercentageWaveRule) -> ExerciseBlock {
        var updatedRule = progressionRule
        updatedRule.percentageWave = wave

        var updatedBlock = self
        updatedBlock.progressionRule = updatedRule
        return updatedBlock
    }
}

private extension SessionDraft {
    mutating func mutateBlock(
        _ blockID: UUID,
        mutation: (inout SessionBlock) -> Void
    ) {
        guard let index = blocks.firstIndex(where: { $0.id == blockID }) else {
            return
        }

        mutation(&blocks[index])
    }

    mutating func touch(_ restTimerEndsAt: Date? = nil, now: Date = .now) {
        lastUpdatedAt = now
        self.restTimerEndsAt = restTimerEndsAt ?? self.restTimerEndsAt
    }
}

private extension SessionBlock {
    mutating func mutatingSet(
        _ setID: UUID,
        mutation: (inout SessionSetRow) -> Void
    ) {
        guard let index = sets.firstIndex(where: { $0.id == setID }) else {
            return
        }

        mutation(&sets[index])
    }
}
