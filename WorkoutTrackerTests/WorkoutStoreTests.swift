import SwiftData
import XCTest
@testable import WorkoutTracker

final class WorkoutStoreTests: XCTestCase {
    override func setUp() {
        super.setUp()
        resetDefaults()
    }

    override func tearDown() {
        resetDefaults()
        super.tearDown()
    }

    @MainActor
    func testSessionDraftPersistsAcrossStoreRehydration() throws {
        let container = WorkoutModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let firstStore = makeStore(container: container)
        firstStore.hydrateIfNeeded()
        firstStore.completeOnboarding(with: nil)

        let plan = makeSingleTemplatePlan(
            name: "Test Plan",
            templateName: "Upper 1",
            store: firstStore,
            weight: 185
        )
        firstStore.savePlan(plan)
        firstStore.startSession(planID: plan.id, templateID: try XCTUnwrap(plan.templates.first?.id))

        let rehydratedStore = makeStore(container: container)
        rehydratedStore.hydrateIfNeeded()

        XCTAssertEqual(rehydratedStore.sessionStore.activeDraft?.templateNameSnapshot, "Upper 1")
        XCTAssertEqual(rehydratedStore.sessionStore.activeDraft?.blocks.count, 1)
    }

    @MainActor
    func testExerciseRenamePreservesAnalyticsContinuityAndSnapshots() throws {
        let store = makeStore()
        store.hydrateIfNeeded()
        store.completeOnboarding(with: nil)

        let plan = makeSingleTemplatePlan(
            name: "Pressing",
            templateName: "Bench Day",
            store: store,
            weight: 185
        )
        store.savePlan(plan)
        store.startSession(planID: plan.id, templateID: try XCTUnwrap(plan.templates.first?.id))

        let draft = try XCTUnwrap(store.sessionStore.activeDraft)
        let block = try XCTUnwrap(draft.blocks.first)
        let row = try XCTUnwrap(block.sets.first)

        store.toggleSetCompletion(blockID: block.id, setID: row.id)
        store.finishActiveSession()

        store.updateCatalogItem(
            itemID: CatalogSeed.benchPress,
            name: "Competition Bench Press",
            aliases: ["Barbell Bench"],
            category: .chest
        )
        store.refreshDerivedStores()

        let summary = try XCTUnwrap(
            store.progressStore.exerciseSummaries.first(where: { $0.exerciseID == CatalogSeed.benchPress })
        )

        XCTAssertEqual(summary.displayName, "Competition Bench Press")
        XCTAssertEqual(summary.pointCount, 1)
        XCTAssertEqual(store.sessionStore.completedSessions.first?.blocks.first?.exerciseNameSnapshot, "Bench Press")
        XCTAssertTrue(store.plansStore.exerciseItem(for: CatalogSeed.benchPress)?.aliases.contains("Bench Press") == true)
    }

    func testAnalyticsSummariesHandleWarmupsAndVolume() {
        let analytics = AnalyticsRepository()
        let catalog = [
            CatalogSeed.backSquat: ExerciseCatalogItem(id: CatalogSeed.backSquat, name: "Back Squat", category: .legs)
        ]
        let sessions = [
            makeCompletedSession(
                date: .now.addingTimeInterval(-86_400),
                exerciseID: CatalogSeed.backSquat,
                exerciseName: "Back Squat",
                rows: [
                    makeRow(kind: .warmup, weight: 95, reps: 5),
                    makeRow(kind: .working, weight: 225, reps: 5)
                ]
            ),
            makeCompletedSession(
                date: .now,
                exerciseID: CatalogSeed.backSquat,
                exerciseName: "Back Squat",
                rows: [
                    makeRow(kind: .warmup, weight: 115, reps: 5),
                    makeRow(kind: .working, weight: 235, reps: 5)
                ]
            )
        ]

        let overview = analytics.buildOverview(from: sessions)
        let summaries = analytics.exerciseSummaries(from: sessions, catalogByID: catalog)
        let records = analytics.personalRecords(from: sessions, catalogByID: catalog)

        XCTAssertEqual(overview.totalSessions, 2)
        XCTAssertGreaterThan(overview.totalVolume, 0)
        XCTAssertEqual(summaries.first?.pointCount, 2)
        XCTAssertGreaterThan(summaries.first?.totalVolume ?? 0, 0)
        XCTAssertEqual(records.last?.weight, 235)
    }

    @MainActor
    func testCompatibilityResetClearsDataAndReturnsToOnboarding() {
        let container = WorkoutModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let firstStore = makeStore(container: container)
        firstStore.hydrateIfNeeded()
        firstStore.completeOnboarding(with: .generalGym)

        XCTAssertFalse(firstStore.plansStore.plans.isEmpty)
        UserDefaults.standard.set(0, forKey: "workout_tracker_storage_version_v3")

        let secondStore = makeStore(container: container)
        secondStore.hydrateIfNeeded()

        XCTAssertTrue(secondStore.plansStore.plans.isEmpty)
        XCTAssertTrue(secondStore.shouldShowOnboarding)
    }

    @MainActor
    func testPlanRepositoryUpsertsExistingRecords() throws {
        let container = WorkoutModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let repository = PlanRepository(modelContext: context)

        var plan = Plan(name: "Starter", templates: [])
        repository.savePlans([plan])

        plan.name = "Starter Updated"
        repository.savePlans([plan])

        let records = try context.fetch(FetchDescriptor<StoredPlanRecord>())
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(try XCTUnwrap(repository.loadPlans().first).name, "Starter Updated")
    }

    @MainActor
    func testSessionRepositoryKeepsSingleActiveDraftRecordAcrossUpdates() throws {
        let container = WorkoutModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let repository = SessionRepository(modelContext: context)

        var draft = SessionDraft(
            planID: nil,
            templateID: UUID(),
            templateNameSnapshot: "Upper",
            blocks: []
        )
        repository.saveActiveDraft(draft)

        draft.notes = "Felt strong"
        repository.saveActiveDraft(draft)

        let records = try context.fetch(FetchDescriptor<StoredActiveSessionRecord>())
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(repository.loadActiveDraft()?.notes, "Felt strong")
    }

    @MainActor
    func testFinishSessionIncrementallyUpdatesTodayAndProgressStores() throws {
        let store = makeStore()
        store.hydrateIfNeeded()
        store.completeOnboarding(with: nil)

        let plan = makeSingleTemplatePlan(
            name: "Bench Focus",
            templateName: "Bench Day",
            store: store,
            weight: 185
        )
        store.savePlan(plan)
        store.startSession(planID: plan.id, templateID: try XCTUnwrap(plan.templates.first?.id))

        let block = try XCTUnwrap(store.sessionStore.activeDraft?.blocks.first)
        let row = try XCTUnwrap(block.sets.first)
        store.toggleSetCompletion(blockID: block.id, setID: row.id)
        store.finishActiveSession()

        XCTAssertEqual(store.todayStore.recentSessions.first?.templateNameSnapshot, "Bench Day")
        XCTAssertEqual(store.todayStore.recentPersonalRecords.count, 1)
        XCTAssertEqual(store.progressStore.personalRecords.count, 1)
        XCTAssertEqual(store.progressStore.exerciseSummaries.first?.pointCount, 1)
        XCTAssertEqual(store.progressStore.overview.totalSessions, 1)
    }

    @MainActor
    func testQuickStartsStayDeduplicatedAfterRepeatedTemplateCompletion() throws {
        let store = makeStore()
        store.hydrateIfNeeded()
        store.completeOnboarding(with: .generalGym)

        let reference = try XCTUnwrap(store.todayStore.quickStartTemplates.first)

        for _ in 0..<2 {
            store.startSession(planID: reference.planID, templateID: reference.templateID)
            let block = try XCTUnwrap(store.sessionStore.activeDraft?.blocks.first)
            let row = try XCTUnwrap(block.sets.first)
            store.toggleSetCompletion(blockID: block.id, setID: row.id)
            store.finishActiveSession()
        }

        let quickStartIDs = store.todayStore.quickStartTemplates.map(\.templateID)
        XCTAssertEqual(Set(quickStartIDs).count, quickStartIDs.count)
        XCTAssertEqual(store.todayStore.quickStartTemplates.first?.templateID, reference.templateID)
    }

    @MainActor
    private func makeStore(
        container: ModelContainer = WorkoutModelContainerFactory.makeContainer(isStoredInMemoryOnly: true),
        launchArguments: Set<String> = []
    ) -> AppStore {
        AppStore(modelContainer: container, launchArguments: launchArguments)
    }

    @MainActor
    private func makeSingleTemplatePlan(
        name: String,
        templateName: String,
        store: AppStore,
        weight: Double
    ) -> Plan {
        var plan = store.makePlan(name: name)
        let block = store.makeBlock(
            exerciseID: CatalogSeed.benchPress,
            setCount: 1,
            repRange: RepRange(5, 5),
            targetWeight: weight,
            restSeconds: 90,
            progressionRule: .manual
        )
        let template = store.makeTemplate(name: templateName, blocks: [block])
        plan.templates = [template]
        plan.pinnedTemplateID = template.id
        return plan
    }

    private func makeCompletedSession(
        date: Date,
        exerciseID: UUID,
        exerciseName: String,
        rows: [SessionSetRow]
    ) -> CompletedSession {
        CompletedSession(
            planID: UUID(),
            templateID: UUID(),
            templateNameSnapshot: "Template",
            startedAt: date.addingTimeInterval(-3_600),
            completedAt: date,
            blocks: [
                CompletedSessionBlock(
                    exerciseID: exerciseID,
                    exerciseNameSnapshot: exerciseName,
                    blockNote: "",
                    restSeconds: 90,
                    supersetGroup: nil,
                    progressionRule: .manual,
                    sets: rows
                )
            ]
        )
    }

    private func makeRow(kind: SetKind, weight: Double, reps: Int) -> SessionSetRow {
        let target = SetTarget(setKind: kind, targetWeight: weight, repRange: RepRange(reps, reps))
        return SessionSetRow(
            target: target,
            log: SetLog(setTargetID: target.id, weight: weight, reps: reps, completedAt: .now)
        )
    }

    private func resetDefaults() {
        SettingsStore.resetPersistedSettings()
        UserDefaults.standard.removeObject(forKey: "workout_tracker_storage_version_v3")
    }
}
