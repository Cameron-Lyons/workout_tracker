import Foundation

enum ProgressionEngine {
    private static let defaultWaveRounding = StrengthProgressionDefaults.gymRoundingIncrement

    static func resolvedTargets(
        for block: TemplateExercise,
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
        to block: TemplateExercise,
        using completedRows: [SessionSetRow],
        profile: ExerciseProfile?,
        fallbackIncrement: Double
    ) -> (block: TemplateExercise, profile: ExerciseProfile?) {
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
        to block: TemplateExercise,
        using completedRows: [SessionSetRow],
        profile: ExerciseProfile?,
        fallbackIncrement: Double
    ) -> (block: TemplateExercise, profile: ExerciseProfile?) {
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
        to block: TemplateExercise,
        using completedRows: [SessionSetRow],
        profile: ExerciseProfile?,
        fallbackIncrement: Double
    ) -> (block: TemplateExercise, profile: ExerciseProfile?) {
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
        from block: TemplateExercise,
        wave: PercentageWaveRule,
        profile: ExerciseProfile?
    ) -> TemplateExercise {
        var updatedBlock = block.updatingWave(wave)
        updatedBlock.targets = resolvedTargets(for: updatedBlock, profile: profile)
        return updatedBlock
    }
}

enum SessionEngine {
    private static let defaultRepRange = TemplateExerciseDefaults.repRange
    private static let minimumRestTimerSeconds = 1

    static func startSession(
        planID: UUID?,
        template: WorkoutTemplate,
        profilesByExerciseID: [UUID: ExerciseProfile],
        warmupRamp: [WarmupRampStep],
        startedAt: Date = .now
    ) -> SessionDraft {
        let blocks = template.exercises.map { block in
            let profile = profilesByExerciseID[block.exerciseID]
            let workingTargets = ProgressionEngine.resolvedTargets(for: block, profile: profile)
            let targets = resolvedTargets(
                for: block,
                workingTargets: workingTargets,
                warmupRamp: warmupRamp
            )

            return SessionExercise(
                id: block.id,
                exerciseID: block.exerciseID,
                exerciseNameSnapshot: block.exerciseNameSnapshot,
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
            exercises: blocks
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
            let exerciseIndex = resolvedExerciseIndex(in: draft, blockID: blockID, suggested: context.exerciseIndex),
            let setIndex = resolvedSetIndex(
                in: draft.exercises[exerciseIndex],
                setID: setID,
                suggested: context.setIndex
            )
        else {
            return .unchanged
        }

        let blockRestSeconds = draft.exercises[exerciseIndex].restSeconds
        if draft.exercises[exerciseIndex].sets[setIndex].log.isCompleted {
            draft.exercises[exerciseIndex].sets[setIndex].log.completedAt = nil
            draft.restTimerEndsAt = nil
        } else {
            if draft.exercises[exerciseIndex].sets[setIndex].log.weight == nil {
                draft.exercises[exerciseIndex].sets[setIndex].log.weight =
                    draft.exercises[exerciseIndex].sets[setIndex].target.targetWeight
            }
            if draft.exercises[exerciseIndex].sets[setIndex].log.reps == nil {
                draft.exercises[exerciseIndex].sets[setIndex].log.reps =
                    draft.exercises[exerciseIndex].sets[setIndex].target.repRange.upperBound
            }
            if draft.exercises[exerciseIndex].sets[setIndex].log.rir == nil {
                draft.exercises[exerciseIndex].sets[setIndex].log.rir =
                    draft.exercises[exerciseIndex].sets[setIndex].target.rir
            }
            draft.exercises[exerciseIndex].sets[setIndex].log.completedAt = completedAt
            let seconds = draft.exercises[exerciseIndex].sets[setIndex].target.restSeconds ?? blockRestSeconds
            draft.restTimerEndsAt = completedAt.addingTimeInterval(
                TimeInterval(max(minimumRestTimerSeconds, seconds))
            )
        }

        draft.touch(now: completedAt)
        return .progressChanged
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
            let exerciseIndex = resolvedExerciseIndex(in: draft, blockID: blockID, suggested: context.exerciseIndex),
            let setIndex = resolvedSetIndex(
                in: draft.exercises[exerciseIndex],
                setID: setID,
                suggested: context.setIndex
            )
        else {
            return .unchanged
        }

        let previousWeight = draft.exercises[exerciseIndex].sets[setIndex].log.weight
        if let baseWeight = previousWeight ?? draft.exercises[exerciseIndex].sets[setIndex].target.targetWeight {
            let updatedWeight = max(0, baseWeight + delta)
            guard previousWeight != updatedWeight else {
                return .unchanged
            }
            draft.exercises[exerciseIndex].sets[setIndex].log.weight = updatedWeight
        } else {
            guard delta > 0 else {
                return .unchanged
            }
            draft.exercises[exerciseIndex].sets[setIndex].log.weight = delta
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
            let exerciseIndex = resolvedExerciseIndex(in: draft, blockID: blockID, suggested: context.exerciseIndex),
            let setIndex = resolvedSetIndex(
                in: draft.exercises[exerciseIndex],
                setID: setID,
                suggested: context.setIndex
            )
        else {
            return .unchanged
        }

        let updatedWeight = max(0, newWeight)
        guard draft.exercises[exerciseIndex].sets[setIndex].log.weight != updatedWeight else {
            return .unchanged
        }

        draft.exercises[exerciseIndex].sets[setIndex].log.weight = updatedWeight
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
            let exerciseIndex = resolvedExerciseIndex(in: draft, blockID: blockID, suggested: context.exerciseIndex),
            let setIndex = resolvedSetIndex(
                in: draft.exercises[exerciseIndex],
                setID: setID,
                suggested: context.setIndex
            )
        else {
            return .unchanged
        }

        let previousReps = draft.exercises[exerciseIndex].sets[setIndex].log.reps
        let baseReps = previousReps ?? draft.exercises[exerciseIndex].sets[setIndex].target.repRange.upperBound
        let updatedReps = max(0, baseReps + delta)
        guard previousReps != updatedReps else {
            return .unchanged
        }

        draft.exercises[exerciseIndex].sets[setIndex].log.reps = updatedReps
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
            let exerciseIndex = resolvedExerciseIndex(in: draft, blockID: blockID, suggested: context.exerciseIndex),
            let setIndex = resolvedSetIndex(
                in: draft.exercises[exerciseIndex],
                setID: setID,
                suggested: context.setIndex
            )
        else {
            return .unchanged
        }

        let updatedReps = max(0, newReps)
        guard draft.exercises[exerciseIndex].sets[setIndex].log.reps != updatedReps else {
            return .unchanged
        }

        draft.exercises[exerciseIndex].sets[setIndex].log.reps = updatedReps
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
        guard let exerciseIndex = resolvedExerciseIndex(in: draft, blockID: blockID, suggested: context.exerciseIndex) else {
            return .unchanged
        }

        let copiedTarget = draft.exercises[exerciseIndex].sets.last?.target ?? SetTarget(repRange: defaultRepRange)
        let copiedLog = draft.exercises[exerciseIndex].sets.last?.log
        var newRow = SessionSetRow(target: copiedTarget)
        newRow.target.id = UUID()
        newRow.log.setTargetID = newRow.target.id
        if let copiedLog {
            newRow.log.weight = copiedLog.weight
            newRow.log.reps = copiedLog.reps
            newRow.log.rir = copiedLog.rir
        }
        draft.exercises[exerciseIndex].sets.append(newRow)
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
        guard let exerciseIndex = resolvedExerciseIndex(in: draft, blockID: blockID, suggested: context.exerciseIndex) else {
            return .unchanged
        }

        guard let lastRow = draft.exercises[exerciseIndex].sets.last else {
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
        draft.exercises[exerciseIndex].sets.append(newRow)
        draft.touch(now: now)
        return .structureChanged
    }

    @discardableResult
    static func addSessionExercise(
        exercise: ExerciseCatalogItem,
        draft: inout SessionDraft,
        defaultRestSeconds: Int,
        now: Date = .now
    ) -> SessionMutationResult {
        draft.exercises.append(
            SessionExercise(
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
        return .structureAndProgressChanged
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
            exercises: draft.exercises.map { block in
                CompletedSessionExercise(
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
        for block: TemplateExercise,
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

private extension TemplateExercise {
    func updatingWave(_ wave: PercentageWaveRule) -> TemplateExercise {
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
    static func resolvedExerciseIndex(
        in draft: SessionDraft,
        blockID: UUID,
        suggested: Int?
    ) -> Int? {
        if let suggested,
            draft.exercises.indices.contains(suggested),
            draft.exercises[suggested].id == blockID
        {
            return suggested
        }

        return draft.exercises.firstIndex(where: { $0.id == blockID })
    }

    static func resolvedSetIndex(
        in sessionExercise: SessionExercise,
        setID: UUID,
        suggested: Int?
    ) -> Int? {
        if let suggested,
            sessionExercise.sets.indices.contains(suggested),
            sessionExercise.sets[suggested].id == setID
        {
            return suggested
        }

        return sessionExercise.sets.firstIndex(where: { $0.id == setID })
    }
}
