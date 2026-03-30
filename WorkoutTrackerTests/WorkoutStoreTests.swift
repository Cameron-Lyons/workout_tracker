import SwiftData
import XCTest

@testable import WorkoutTracker

final class WorkoutStoreTests: XCTestCase {
    var defaultsSuiteName: String!
    var testDefaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaultsSuiteName = "WorkoutStoreTests.\(name.replacingOccurrences(of: " ", with: "_")).\(UUID().uuidString)"
        testDefaults = UserDefaults(suiteName: defaultsSuiteName)
        testDefaults.removePersistentDomain(forName: defaultsSuiteName)
        _ = WorkoutModelContainerFactory.consumeStartupIssue()
    }

    override func tearDown() {
        testDefaults?.removePersistentDomain(forName: defaultsSuiteName)
        testDefaults = nil
        defaultsSuiteName = nil
        _ = WorkoutModelContainerFactory.consumeStartupIssue()
        super.tearDown()
    }

    @MainActor
    func makeStore(
        container: ModelContainer = WorkoutModelContainerFactory.makeContainer(isStoredInMemoryOnly: true),
        launchArguments: Set<String> = []
    ) -> AppStore {
        AppStore(
            modelContainer: container,
            launchArguments: launchArguments,
            settingsStore: SettingsStore(defaults: testDefaults)
        )
    }

    @MainActor
    func makeSingleTemplatePlan(
        name: String,
        templateName: String,
        store: AppStore,
        weight: Double
    ) -> Plan {
        var plan = store.makePlan(name: name)
        let block = ExerciseBlock(
            exerciseID: CatalogSeed.benchPress,
            exerciseNameSnapshot: store.plansStore.exerciseName(for: CatalogSeed.benchPress),
            restSeconds: 90,
            progressionRule: .manual,
            targets: [
                SetTarget(
                    setKind: .working,
                    targetWeight: weight,
                    repRange: RepRange(5, 5),
                    restSeconds: 90
                )
            ]
        )
        let template = WorkoutTemplate(name: templateName, blocks: [block])
        plan.templates = [template]
        plan.pinnedTemplateID = template.id
        return plan
    }

    func makeStartingStrengthPlan() -> Plan {
        let dayA = WorkoutTemplate(
            name: "Workout A",
            scheduledWeekdays: [.monday, .friday],
            blocks: [
                makeStartingStrengthBlock(id: CatalogSeed.backSquat, name: "Back Squat"),
                makeStartingStrengthBlock(id: CatalogSeed.benchPress, name: "Bench Press"),
                makeStartingStrengthBlock(id: CatalogSeed.deadlift, name: "Deadlift"),
            ]
        )
        let dayB = WorkoutTemplate(
            name: "Workout B",
            scheduledWeekdays: [.wednesday],
            blocks: [
                makeStartingStrengthBlock(id: CatalogSeed.backSquat, name: "Back Squat"),
                makeStartingStrengthBlock(id: CatalogSeed.overheadPress, name: "Overhead Press"),
                makeStartingStrengthBlock(id: CatalogSeed.powerClean, name: "Power Clean"),
            ]
        )

        return Plan(
            name: PresetPack.startingStrength.displayName,
            pinnedTemplateID: dayA.id,
            templates: [dayA, dayB]
        )
    }

    func makeCustomNamedWorkoutABPlan() -> Plan {
        let dayA = WorkoutTemplate(
            name: "Workout A",
            scheduledWeekdays: [.monday, .friday],
            blocks: [
                ExerciseBlock(
                    exerciseID: CatalogSeed.pullUp,
                    exerciseNameSnapshot: "Pull Up",
                    restSeconds: 90,
                    progressionRule: .manual,
                    targets: []
                )
            ]
        )
        let dayB = WorkoutTemplate(
            name: "Workout B",
            scheduledWeekdays: [.wednesday],
            blocks: [
                ExerciseBlock(
                    exerciseID: CatalogSeed.dips,
                    exerciseNameSnapshot: "Dips",
                    restSeconds: 90,
                    progressionRule: .manual,
                    targets: []
                )
            ]
        )

        return Plan(
            name: "Custom A/B",
            pinnedTemplateID: dayA.id,
            templates: [dayA, dayB]
        )
    }

    func makeStartingStrengthBlock(id: UUID, name: String) -> ExerciseBlock {
        ExerciseBlock(
            exerciseID: id,
            exerciseNameSnapshot: name,
            restSeconds: 90,
            progressionRule: .manual,
            targets: []
        )
    }

    func makeReference(plan: Plan, template: WorkoutTemplate) -> TemplateReference {
        TemplateReference(
            planID: plan.id,
            planName: plan.name,
            templateID: template.id,
            templateName: template.name,
            scheduledWeekdays: template.scheduledWeekdays,
            lastStartedAt: template.lastStartedAt
        )
    }

    func makeCompletedSession(
        date: Date,
        exerciseID: UUID,
        exerciseName: String,
        rows: [SessionSetRow]
    ) -> CompletedSession {
        CompletedSession(
            planID: UUID(),
            templateID: UUID(),
            templateNameSnapshot: "Template",
            completedAt: date,
            blocks: [
                CompletedSessionBlock(
                    exerciseID: exerciseID,
                    exerciseNameSnapshot: exerciseName,
                    sets: rows
                )
            ]
        )
    }

    func makeCompletedSession(
        id: UUID = UUID(),
        planID: UUID? = UUID(),
        templateID: UUID,
        templateNameSnapshot: String,
        date: Date,
        blocks: [CompletedSessionBlock] = []
    ) -> CompletedSession {
        CompletedSession(
            id: id,
            planID: planID,
            templateID: templateID,
            templateNameSnapshot: templateNameSnapshot,
            completedAt: date,
            blocks: blocks
        )
    }

    func makeRow(
        kind: SetKind,
        weight: Double,
        reps: Int,
        completedAt: Date? = .now
    ) -> SessionSetRow {
        let target = SetTarget(setKind: kind, targetWeight: weight, repRange: RepRange(reps, reps))
        return SessionSetRow(
            target: target,
            log: SetLog(setTargetID: target.id, weight: weight, reps: reps, completedAt: completedAt)
        )
    }

}
