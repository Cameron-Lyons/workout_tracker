import Foundation
import SwiftData

@testable import WorkoutTracker

enum WorkoutBenchmarkFixtures {
    static let referenceNow = Date(timeIntervalSinceReferenceDate: 765_432_100)
    static let catalog = Array(CatalogSeed.defaultCatalog().prefix(12))
    static let catalogByID = Dictionary(uniqueKeysWithValues: catalog.map { ($0.id, $0) })

    private static let weekdayPatterns: [[Weekday]] = [
        [.monday, .thursday],
        [.tuesday, .friday],
        [.wednesday, .saturday],
        [.monday, .wednesday, .friday],
    ]

    static func makeCompletedSessions(
        sessionCount: Int,
        blocksPerSession: Int,
        setsPerBlock: Int
    ) -> [CompletedSession] {
        var sessions: [CompletedSession] = []
        sessions.reserveCapacity(sessionCount)

        for sessionIndex in 0..<sessionCount {
            let completedAt = referenceNow.addingTimeInterval(TimeInterval(sessionIndex - sessionCount) * 86_400)
            let blocks = (0..<blocksPerSession).map { blockIndex in
                makeCompletedBlock(
                    sessionIndex: sessionIndex,
                    blockIndex: blockIndex,
                    setsPerBlock: setsPerBlock,
                    completedAt: completedAt
                )
            }

            sessions.append(
                CompletedSession(
                    planID: UUID(),
                    templateID: UUID(),
                    templateNameSnapshot: "Benchmark Template \(sessionIndex % 8)",
                    completedAt: completedAt,
                    exercises: blocks
                )
            )
        }

        return sessions
    }

    static func makeCompletedSessions(
        from plans: [Plan],
        profiles: [ExerciseProfile],
        sessionCount: Int
    ) -> [CompletedSession] {
        let references = plans.flatMap { plan in
            plan.templates.map { (planID: plan.id, template: $0) }
        }

        guard !references.isEmpty else {
            return []
        }

        var sessions: [CompletedSession] = []
        sessions.reserveCapacity(sessionCount)

        for sessionIndex in 0..<sessionCount {
            let reference = references[sessionIndex % references.count]
            let completedAt = referenceNow.addingTimeInterval(TimeInterval(sessionIndex - sessionCount) * 86_400)
            let draft = completedDraft(
                from: makeDraft(
                    planID: reference.planID,
                    template: reference.template,
                    profiles: profiles,
                    startedAt: completedAt.addingTimeInterval(-3_600)
                ),
                completedAt: completedAt
            )

            sessions.append(
                SessionEngine.finishSession(
                    draft: draft,
                    completedAt: completedAt
                )
            )
        }

        return sessions
    }

    static func makePlans(
        planCount: Int,
        templatesPerPlan: Int,
        blocksPerTemplate: Int,
        targetsPerBlock: Int
    ) -> [Plan] {
        (0..<planCount).map { planIndex in
            let templates = (0..<templatesPerPlan).map { templateIndex in
                WorkoutTemplate(
                    name: "Benchmark Template \(planIndex)-\(templateIndex)",
                    scheduledWeekdays: weekdayPatterns[(planIndex + templateIndex) % weekdayPatterns.count],
                    exercises: (0..<blocksPerTemplate).map { blockIndex in
                        makeExerciseBlock(
                            planIndex: planIndex,
                            templateIndex: templateIndex,
                            blockIndex: blockIndex,
                            targetsPerBlock: targetsPerBlock
                        )
                    },
                    lastStartedAt: referenceNow.addingTimeInterval(
                        TimeInterval(-((planIndex * templatesPerPlan) + templateIndex) * 86_400)
                    )
                )
            }

            return Plan(
                name: "Benchmark Plan \(planIndex)",
                createdAt: referenceNow.addingTimeInterval(TimeInterval(-planIndex * 86_400)),
                pinnedTemplateID: templates.first?.id,
                templates: templates
            )
        }
    }

    static func makeProfiles(for exercises: [ExerciseCatalogItem] = catalog) -> [ExerciseProfile] {
        exercises.enumerated().map { index, exercise in
            ExerciseProfile(
                exerciseID: exercise.id,
                trainingMax: 175 + Double(index * 15),
                preferredIncrement: index.isMultiple(of: 2) ? 5 : 2.5
            )
        }
    }

    static func makeProgressivePlan(
        blockCount: Int,
        targetsPerBlock: Int,
        name: String = "Benchmark Progressive Plan",
        templateName: String = "Benchmark Progression Day"
    ) -> Plan {
        let template = WorkoutTemplate(
            name: templateName,
            scheduledWeekdays: [.monday, .thursday],
            exercises: (0..<blockCount).map { blockIndex in
                makeProgressiveBlock(
                    blockIndex: blockIndex,
                    targetsPerBlock: targetsPerBlock
                )
            },
            lastStartedAt: referenceNow.addingTimeInterval(-86_400)
        )

        return Plan(
            name: name,
            createdAt: referenceNow.addingTimeInterval(-7 * 86_400),
            pinnedTemplateID: template.id,
            templates: [template]
        )
    }

    static func makeDraft(
        planID: UUID?,
        template: WorkoutTemplate,
        profiles: [ExerciseProfile],
        startedAt: Date = referenceNow
    ) -> SessionDraft {
        let profilesByExerciseID = Dictionary(uniqueKeysWithValues: profiles.map { ($0.exerciseID, $0) })
        return SessionEngine.startSession(
            planID: planID,
            template: template,
            profilesByExerciseID: profilesByExerciseID,
            warmupRamp: WarmupDefaults.ramp,
            startedAt: startedAt
        )
    }

    static func completedDraft(
        from draft: SessionDraft,
        completedAt: Date = referenceNow
    ) -> SessionDraft {
        var completedDraft = draft

        for blockIndex in completedDraft.exercises.indices {
            for setIndex in completedDraft.exercises[blockIndex].sets.indices {
                let target = completedDraft.exercises[blockIndex].sets[setIndex].target
                completedDraft.exercises[blockIndex].sets[setIndex].log.weight = target.targetWeight ?? 135
                completedDraft.exercises[blockIndex].sets[setIndex].log.reps = target.repRange.upperBound
                completedDraft.exercises[blockIndex].sets[setIndex].log.completedAt = completedAt
                completedDraft.exercises[blockIndex].sets[setIndex].log.rir = target.rir
            }
        }

        completedDraft.lastUpdatedAt = completedAt
        completedDraft.restTimerEndsAt = nil
        completedDraft.restTimerBeganAt = nil
        return completedDraft
    }

    static func seedContainer(
        _ container: ModelContainer,
        catalog: [ExerciseCatalogItem] = catalog,
        plans: [Plan] = [],
        profiles: [ExerciseProfile] = [],
        activeDraft: SessionDraft? = nil,
        completedSessions: [CompletedSession] = []
    ) -> Bool {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let planRepository = PlanRepository(modelContext: context)
        let sessionRepository = SessionRepository(modelContext: context)

        guard planRepository.saveCatalog(catalog) else {
            return false
        }

        guard planRepository.savePlans(plans) else {
            return false
        }

        guard planRepository.saveProfiles(profiles) else {
            return false
        }

        for session in completedSessions {
            guard sessionRepository.persistCompletedSessionAndClearActiveDraft(session) else {
                return false
            }
        }

        if let activeDraft {
            return sessionRepository.saveActiveDraft(activeDraft)
        }

        return true
    }

    private static func makeCompletedBlock(
        sessionIndex: Int,
        blockIndex: Int,
        setsPerBlock: Int,
        completedAt: Date
    ) -> CompletedSessionExercise {
        let exercise = catalog[(sessionIndex + blockIndex) % catalog.count]
        let baseWeight = 95.0 + Double(((sessionIndex * 3) + blockIndex) % 20) * 5
        let sets = (0..<setsPerBlock).map { setIndex in
            makeCompletedRow(
                sessionIndex: sessionIndex,
                setIndex: setIndex,
                baseWeight: baseWeight,
                completedAt: completedAt
            )
        }

        return CompletedSessionExercise(
            exerciseID: exercise.id,
            exerciseNameSnapshot: exercise.name,
            sets: sets
        )
    }

    private static func makeCompletedRow(
        sessionIndex: Int,
        setIndex: Int,
        baseWeight: Double,
        completedAt: Date
    ) -> SessionSetRow {
        let setKind: SetKind = setIndex == 0 ? .warmup : .working
        let targetWeight = setKind == .warmup ? baseWeight * 0.6 : baseWeight + Double(setIndex - 1) * 5
        let reps = setKind == .warmup ? 8 : 5 + ((sessionIndex + setIndex) % 4)
        let target = SetTarget(
            setKind: setKind,
            targetWeight: targetWeight,
            repRange: RepRange(reps, reps),
            restSeconds: 90
        )

        return SessionSetRow(
            target: target,
            log: SetLog(
                setTargetID: target.id,
                weight: targetWeight,
                reps: reps,
                completedAt: completedAt
            )
        )
    }

    private static func makeExerciseBlock(
        planIndex: Int,
        templateIndex: Int,
        blockIndex: Int,
        targetsPerBlock: Int
    ) -> TemplateExercise {
        let exercise = catalog[(planIndex + templateIndex + blockIndex) % catalog.count]
        let baseWeight = 115.0 + Double(((planIndex + templateIndex + blockIndex) % 16) * 5)
        let targets = (0..<targetsPerBlock).map { targetIndex in
            let targetWeight = baseWeight + Double(targetIndex) * 5
            let reps = 5 + ((planIndex + targetIndex) % 3)

            return SetTarget(
                targetWeight: targetWeight,
                repRange: RepRange(reps, reps + 1),
                restSeconds: 90
            )
        }

        return TemplateExercise(
            exerciseID: exercise.id,
            exerciseNameSnapshot: exercise.name,
            restSeconds: 90,
            progressionRule: .manual,
            targets: targets
        )
    }

    private static func makeProgressiveBlock(
        blockIndex: Int,
        targetsPerBlock: Int
    ) -> TemplateExercise {
        let exercise = catalog[blockIndex % catalog.count]
        let baseWeight = 135.0 + Double((blockIndex % 10) * 10)

        switch blockIndex % 3 {
        case 0:
            return TemplateExercise(
                exerciseID: exercise.id,
                exerciseNameSnapshot: exercise.name,
                restSeconds: 120,
                progressionRule: SessionEngine.defaultDoubleProgressionRule(
                    exerciseName: exercise.name,
                    preferredIncrement: 5
                ),
                targets: (0..<targetsPerBlock).map { targetIndex in
                    SetTarget(
                        setKind: .working,
                        targetWeight: baseWeight + Double(targetIndex) * 5,
                        repRange: DoubleProgressionDefaults.repRange,
                        restSeconds: 120
                    )
                }
            )

        case 1:
            let waveRule = PercentageWaveRule.fiveThreeOne(
                trainingMax: baseWeight + 40,
                cycleIncrement: 10
            )
            return TemplateExercise(
                exerciseID: exercise.id,
                exerciseNameSnapshot: exercise.name,
                restSeconds: 150,
                progressionRule: ProgressionRule(kind: .percentageWave, percentageWave: waveRule),
                targets: waveRule.weeks[waveRule.currentWeekIndex].sets.map { waveSet in
                    SetTarget(
                        setKind: .working,
                        targetWeight: (waveRule.trainingMax ?? 0) * waveSet.percentage,
                        repRange: waveSet.repRange,
                        restSeconds: 150,
                        note: waveSet.note
                    )
                }
            )

        default:
            return TemplateExercise(
                exerciseID: exercise.id,
                exerciseNameSnapshot: exercise.name,
                restSeconds: 90,
                progressionRule: .manual,
                targets: (0..<targetsPerBlock).map { targetIndex in
                    let reps = 5 + ((blockIndex + targetIndex) % 4)
                    return SetTarget(
                        setKind: .working,
                        targetWeight: baseWeight + Double(targetIndex) * 5,
                        repRange: RepRange(reps, reps + 1),
                        restSeconds: 90
                    )
                }
            )
        }
    }
}
