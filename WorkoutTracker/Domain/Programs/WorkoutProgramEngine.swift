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
        using completedRows: [SessionSetRow],
        profile: ExerciseProfile?,
        fallbackIncrement: Double
    ) -> (block: ExerciseBlock, profile: ExerciseProfile?) {
        switch block.progressionRule.kind {
        case .manual:
            return (block, profile)

        case .doubleProgression:
            return applyDoubleProgression(
                to: block,
                using: completedRows,
                profile: profile,
                fallbackIncrement: fallbackIncrement
            )

        case .percentageWave:
            return applyPercentageWave(
                to: block,
                using: completedRows,
                profile: profile,
                fallbackIncrement: fallbackIncrement
            )
        }
    }

    private static func applyDoubleProgression(
        to block: ExerciseBlock,
        using completedRows: [SessionSetRow],
        profile: ExerciseProfile?,
        fallbackIncrement: Double
    ) -> (block: ExerciseBlock, profile: ExerciseProfile?) {
        guard let config = block.progressionRule.doubleProgression else {
            return (block, profile)
        }

        let workingRows = completedRows.filter { $0.target.setKind == .working }
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
        using completedRows: [SessionSetRow],
        profile: ExerciseProfile?,
        fallbackIncrement: Double
    ) -> (block: ExerciseBlock, profile: ExerciseProfile?) {
        guard var wave = block.progressionRule.percentageWave, !wave.weeks.isEmpty else {
            return (block, profile)
        }

        let workingRows = completedRows.filter { $0.target.setKind == .working }
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

    @discardableResult
    static func toggleCompletion(
        of setID: UUID,
        in blockID: UUID,
        draft: inout SessionDraft,
        context: SessionMutationContext = .empty,
        completedAt: Date = .now
    ) -> SessionMutationResult {
        guard
            let blockIndex = resolvedBlockIndex(in: draft, blockID: blockID, suggested: context.blockIndex),
            let setIndex = resolvedSetIndex(
                in: draft.blocks[blockIndex],
                setID: setID,
                suggested: context.setIndex
            )
        else {
            return .unchanged
        }

        let blockRestSeconds = draft.blocks[blockIndex].restSeconds
        if draft.blocks[blockIndex].sets[setIndex].log.isCompleted {
            draft.blocks[blockIndex].sets[setIndex].log.completedAt = nil
            draft.restTimerEndsAt = nil
        } else {
            if draft.blocks[blockIndex].sets[setIndex].log.weight == nil {
                draft.blocks[blockIndex].sets[setIndex].log.weight =
                    draft.blocks[blockIndex].sets[setIndex].target.targetWeight
            }
            if draft.blocks[blockIndex].sets[setIndex].log.reps == nil {
                draft.blocks[blockIndex].sets[setIndex].log.reps =
                    draft.blocks[blockIndex].sets[setIndex].target.repRange.upperBound
            }
            if draft.blocks[blockIndex].sets[setIndex].log.rir == nil {
                draft.blocks[blockIndex].sets[setIndex].log.rir =
                    draft.blocks[blockIndex].sets[setIndex].target.rir
            }
            draft.blocks[blockIndex].sets[setIndex].log.completedAt = completedAt
            let seconds = draft.blocks[blockIndex].sets[setIndex].target.restSeconds ?? blockRestSeconds
            draft.restTimerEndsAt = completedAt.addingTimeInterval(
                TimeInterval(max(minimumRestTimerSeconds, seconds))
            )
        }

        draft.touch(now: completedAt)
        return .changed
    }

    @discardableResult
    static func adjustWeight(
        by delta: Double,
        setID: UUID,
        in blockID: UUID,
        draft: inout SessionDraft,
        context: SessionMutationContext = .empty,
        now: Date = .now
    ) -> SessionMutationResult {
        guard
            let blockIndex = resolvedBlockIndex(in: draft, blockID: blockID, suggested: context.blockIndex),
            let setIndex = resolvedSetIndex(
                in: draft.blocks[blockIndex],
                setID: setID,
                suggested: context.setIndex
            )
        else {
            return .unchanged
        }

        let previousWeight = draft.blocks[blockIndex].sets[setIndex].log.weight
        if let baseWeight = previousWeight ?? draft.blocks[blockIndex].sets[setIndex].target.targetWeight {
            let updatedWeight = max(0, baseWeight + delta)
            guard previousWeight != updatedWeight else {
                return .unchanged
            }
            draft.blocks[blockIndex].sets[setIndex].log.weight = updatedWeight
        } else {
            guard delta > 0 else {
                return .unchanged
            }
            draft.blocks[blockIndex].sets[setIndex].log.weight = delta
        }

        draft.touch(now: now)
        return .changed
    }

    @discardableResult
    static func updateWeight(
        to newWeight: Double,
        setID: UUID,
        in blockID: UUID,
        draft: inout SessionDraft,
        context: SessionMutationContext = .empty,
        now: Date = .now
    ) -> SessionMutationResult {
        guard
            let blockIndex = resolvedBlockIndex(in: draft, blockID: blockID, suggested: context.blockIndex),
            let setIndex = resolvedSetIndex(
                in: draft.blocks[blockIndex],
                setID: setID,
                suggested: context.setIndex
            )
        else {
            return .unchanged
        }

        let updatedWeight = max(0, newWeight)
        guard draft.blocks[blockIndex].sets[setIndex].log.weight != updatedWeight else {
            return .unchanged
        }

        draft.blocks[blockIndex].sets[setIndex].log.weight = updatedWeight
        draft.touch(now: now)
        return .changed
    }

    @discardableResult
    static func adjustReps(
        by delta: Int,
        setID: UUID,
        in blockID: UUID,
        draft: inout SessionDraft,
        context: SessionMutationContext = .empty,
        now: Date = .now
    ) -> SessionMutationResult {
        guard
            let blockIndex = resolvedBlockIndex(in: draft, blockID: blockID, suggested: context.blockIndex),
            let setIndex = resolvedSetIndex(
                in: draft.blocks[blockIndex],
                setID: setID,
                suggested: context.setIndex
            )
        else {
            return .unchanged
        }

        let previousReps = draft.blocks[blockIndex].sets[setIndex].log.reps
        let baseReps = previousReps ?? draft.blocks[blockIndex].sets[setIndex].target.repRange.upperBound
        let updatedReps = max(0, baseReps + delta)
        guard previousReps != updatedReps else {
            return .unchanged
        }

        draft.blocks[blockIndex].sets[setIndex].log.reps = updatedReps
        draft.touch(now: now)
        return .changed
    }

    @discardableResult
    static func updateReps(
        to newReps: Int,
        setID: UUID,
        in blockID: UUID,
        draft: inout SessionDraft,
        context: SessionMutationContext = .empty,
        now: Date = .now
    ) -> SessionMutationResult {
        guard
            let blockIndex = resolvedBlockIndex(in: draft, blockID: blockID, suggested: context.blockIndex),
            let setIndex = resolvedSetIndex(
                in: draft.blocks[blockIndex],
                setID: setID,
                suggested: context.setIndex
            )
        else {
            return .unchanged
        }

        let updatedReps = max(0, newReps)
        guard draft.blocks[blockIndex].sets[setIndex].log.reps != updatedReps else {
            return .unchanged
        }

        draft.blocks[blockIndex].sets[setIndex].log.reps = updatedReps
        draft.touch(now: now)
        return .changed
    }

    @discardableResult
    static func updateNotes(
        in blockID: UUID,
        note: String,
        draft: inout SessionDraft,
        context: SessionMutationContext = .empty,
        now: Date = .now
    ) -> SessionMutationResult {
        guard let blockIndex = resolvedBlockIndex(in: draft, blockID: blockID, suggested: context.blockIndex) else {
            return .unchanged
        }

        guard draft.blocks[blockIndex].blockNote != note else {
            return .unchanged
        }

        draft.blocks[blockIndex].blockNote = note
        draft.touch(now: now)
        return .changed
    }

    @discardableResult
    static func updateSessionNotes(
        _ notes: String,
        draft: inout SessionDraft,
        now: Date = .now
    ) -> SessionMutationResult {
        guard draft.notes != notes else {
            return .unchanged
        }

        draft.notes = notes
        draft.touch(now: now)
        return .changed
    }

    @discardableResult
    static func addSet(
        to blockID: UUID,
        draft: inout SessionDraft,
        context: SessionMutationContext = .empty,
        now: Date = .now
    ) -> SessionMutationResult {
        guard let blockIndex = resolvedBlockIndex(in: draft, blockID: blockID, suggested: context.blockIndex) else {
            return .unchanged
        }

        let copiedTarget = draft.blocks[blockIndex].sets.last?.target ?? SetTarget(repRange: defaultRepRange)
        let copiedLog = draft.blocks[blockIndex].sets.last?.log
        var newRow = SessionSetRow(target: copiedTarget)
        newRow.target.id = UUID()
        newRow.log.setTargetID = newRow.target.id
        if let copiedLog {
            newRow.log.weight = copiedLog.weight
            newRow.log.reps = copiedLog.reps
            newRow.log.rir = copiedLog.rir
        }
        draft.blocks[blockIndex].sets.append(newRow)
        draft.touch(now: now)
        return .structureChanged
    }

    @discardableResult
    static func copyLastSet(
        in blockID: UUID,
        draft: inout SessionDraft,
        context: SessionMutationContext = .empty,
        now: Date = .now
    ) -> SessionMutationResult {
        guard let blockIndex = resolvedBlockIndex(in: draft, blockID: blockID, suggested: context.blockIndex) else {
            return .unchanged
        }

        guard let lastRow = draft.blocks[blockIndex].sets.last else {
            return .unchanged
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
        draft.blocks[blockIndex].sets.append(newRow)
        draft.touch(now: now)
        return .structureChanged
    }

    @discardableResult
    static func addExerciseBlock(
        exercise: ExerciseCatalogItem,
        draft: inout SessionDraft,
        defaultRestSeconds: Int,
        now: Date = .now
    ) -> SessionMutationResult {
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
        return .structureChanged
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
            completedAt: completedAt,
            blocks: draft.blocks.map { block in
                CompletedSessionBlock(
                    exerciseID: block.exerciseID,
                    exerciseNameSnapshot: block.exerciseNameSnapshot,
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
    mutating func touch(_ restTimerEndsAt: Date? = nil, now: Date = .now) {
        lastUpdatedAt = now
        self.restTimerEndsAt = restTimerEndsAt ?? self.restTimerEndsAt
    }
}

private extension SessionEngine {
    static func resolvedBlockIndex(
        in draft: SessionDraft,
        blockID: UUID,
        suggested: Int?
    ) -> Int? {
        if let suggested,
            draft.blocks.indices.contains(suggested),
            draft.blocks[suggested].id == blockID
        {
            return suggested
        }

        return draft.blocks.firstIndex(where: { $0.id == blockID })
    }

    static func resolvedSetIndex(
        in block: SessionBlock,
        setID: UUID,
        suggested: Int?
    ) -> Int? {
        if let suggested,
            block.sets.indices.contains(suggested),
            block.sets[suggested].id == setID
        {
            return suggested
        }

        return block.sets.firstIndex(where: { $0.id == setID })
    }
}
