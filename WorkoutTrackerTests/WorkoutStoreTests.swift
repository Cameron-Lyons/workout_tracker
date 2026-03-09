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
    func testSessionDraftPersistsAcrossStoreRehydration() async throws {
        let container = WorkoutModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let firstStore = makeStore(container: container)
        await firstStore.hydrateIfNeeded()
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
        await rehydratedStore.hydrateIfNeeded()

        XCTAssertEqual(rehydratedStore.sessionStore.activeDraft?.templateNameSnapshot, "Upper 1")
        XCTAssertEqual(rehydratedStore.sessionStore.activeDraft?.blocks.count, 1)
    }

    @MainActor
    func testExerciseRenamePreservesAnalyticsContinuityAndSnapshots() async throws {
        let store = makeStore()
        await store.hydrateIfNeeded()
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
        await store.refreshDerivedStores()

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

    func testDerivedStoreSnapshotMatchesStandaloneTodayAndProgressSnapshots() {
        let analytics = AnalyticsRepository()
        let now = Date(timeIntervalSince1970: 1_741_478_400)
        let benchTemplateID = UUID()
        let squatTemplateID = UUID()
        let plan = Plan(
            name: "Strength",
            pinnedTemplateID: benchTemplateID,
            templates: [
                WorkoutTemplate(
                    id: benchTemplateID,
                    name: "Bench Day",
                    scheduledWeekdays: [.monday],
                    blocks: [],
                    lastStartedAt: now.addingTimeInterval(-86_400)
                ),
                WorkoutTemplate(
                    id: squatTemplateID,
                    name: "Squat Day",
                    scheduledWeekdays: [.thursday],
                    blocks: [],
                    lastStartedAt: now.addingTimeInterval(-172_800)
                )
            ]
        )
        let references = [
            TemplateReference(
                planID: plan.id,
                planName: plan.name,
                templateID: benchTemplateID,
                templateName: "Bench Day",
                scheduledWeekdays: [.monday],
                lastStartedAt: now.addingTimeInterval(-86_400)
            ),
            TemplateReference(
                planID: plan.id,
                planName: plan.name,
                templateID: squatTemplateID,
                templateName: "Squat Day",
                scheduledWeekdays: [.thursday],
                lastStartedAt: now.addingTimeInterval(-172_800)
            )
        ]
        let sessions = [
            CompletedSession(
                planID: plan.id,
                templateID: benchTemplateID,
                templateNameSnapshot: "Bench Day",
                startedAt: now.addingTimeInterval(-180_000),
                completedAt: now.addingTimeInterval(-172_800),
                blocks: [
                    CompletedSessionBlock(
                        exerciseID: CatalogSeed.benchPress,
                        exerciseNameSnapshot: "Bench Press",
                        blockNote: "",
                        restSeconds: 90,
                        supersetGroup: nil,
                        progressionRule: .manual,
                        sets: [
                            makeRow(kind: .warmup, weight: 95, reps: 5),
                            makeRow(kind: .working, weight: 185, reps: 5)
                        ]
                    )
                ]
            ),
            CompletedSession(
                planID: plan.id,
                templateID: squatTemplateID,
                templateNameSnapshot: "Squat Day",
                startedAt: now.addingTimeInterval(-93_600),
                completedAt: now.addingTimeInterval(-86_400),
                blocks: [
                    CompletedSessionBlock(
                        exerciseID: CatalogSeed.backSquat,
                        exerciseNameSnapshot: "Back Squat",
                        blockNote: "",
                        restSeconds: 120,
                        supersetGroup: nil,
                        progressionRule: .manual,
                        sets: [
                            makeRow(kind: .working, weight: 225, reps: 5)
                        ]
                    )
                ]
            )
        ]
        let catalog = [
            CatalogSeed.benchPress: ExerciseCatalogItem(id: CatalogSeed.benchPress, name: "Bench Press", category: .chest),
            CatalogSeed.backSquat: ExerciseCatalogItem(id: CatalogSeed.backSquat, name: "Back Squat", category: .legs)
        ]

        let combined = analytics.makeDerivedStoreSnapshot(
            plans: [plan],
            references: references,
            sessions: sessions,
            catalogByID: catalog,
            selectedExerciseID: CatalogSeed.backSquat,
            now: now
        )
        let today = analytics.makeTodaySnapshot(
            plans: [plan],
            references: references,
            sessions: sessions,
            catalogByID: catalog,
            now: now
        )
        let progress = analytics.makeProgressSnapshot(
            sessions: sessions,
            catalogByID: catalog,
            selectedExerciseID: CatalogSeed.backSquat,
            now: now
        )

        let recordSignature: (PersonalRecord) -> String = {
            [
                $0.sessionID.uuidString,
                $0.exerciseID.uuidString,
                $0.displayName,
                String($0.weight),
                String($0.reps),
                String($0.estimatedOneRepMax),
                String($0.achievedAt.timeIntervalSinceReferenceDate)
            ].joined(separator: "|")
        }
        let pointSignature: (ProgressPoint) -> String = {
            [
                $0.sessionID.uuidString,
                String($0.date.timeIntervalSinceReferenceDate),
                String($0.topWeight),
                String($0.estimatedOneRepMax),
                String($0.volume)
            ].joined(separator: "|")
        }
        let summarySignature: (ExerciseAnalyticsSummary) -> String = {
            [
                $0.exerciseID.uuidString,
                $0.displayName,
                String($0.pointCount),
                String($0.totalVolume),
                $0.currentPR.map(recordSignature) ?? "nil",
                $0.points.map(pointSignature).joined(separator: ",")
            ].joined(separator: "||")
        }

        XCTAssertEqual(combined.today.pinnedTemplate, today.pinnedTemplate)
        XCTAssertEqual(combined.today.quickStartTemplates, today.quickStartTemplates)
        XCTAssertEqual(combined.today.recentSessions, today.recentSessions)
        XCTAssertEqual(combined.today.recentPersonalRecords.map(recordSignature), today.recentPersonalRecords.map(recordSignature))

        XCTAssertEqual(combined.progress.overview, progress.overview)
        XCTAssertEqual(combined.progress.selectedExerciseID, progress.selectedExerciseID)
        XCTAssertEqual(combined.progress.personalRecords.map(recordSignature), progress.personalRecords.map(recordSignature))
        XCTAssertEqual(combined.progress.exerciseSummaries.map(summarySignature), progress.exerciseSummaries.map(summarySignature))
    }

    @MainActor
    func testBlobStoreMigrationPreservesCurrentData() async throws {
        let container = WorkoutModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let encoder = JSONEncoder()

        let migratedPlan = Plan(
            name: "Migrated Plan",
            templates: [
                WorkoutTemplate(
                    name: "Bench Day",
                    blocks: [
                        ExerciseBlock(
                            exerciseID: CatalogSeed.benchPress,
                            exerciseNameSnapshot: "Bench Press",
                            progressionRule: .manual,
                            targets: [SetTarget(targetWeight: 185, repRange: RepRange(5, 5))]
                        )
                    ]
                )
            ]
        )
        let migratedCatalogItem = ExerciseCatalogItem(
            id: CatalogSeed.benchPress,
            name: "Bench Press",
            category: .chest,
            equipment: "Barbell"
        )
        let migratedProfile = ExerciseProfile(
            exerciseID: CatalogSeed.benchPress,
            trainingMax: 225,
            preferredIncrement: 5,
            notes: "legacy"
        )
        let migratedDraft = SessionDraft(
            planID: migratedPlan.id,
            templateID: try XCTUnwrap(migratedPlan.templates.first?.id),
            templateNameSnapshot: "Bench Day",
            blocks: []
        )
        let migratedCompletedSession = makeCompletedSession(
            date: .now,
            exerciseID: CatalogSeed.benchPress,
            exerciseName: "Bench Press",
            rows: [makeRow(kind: .working, weight: 185, reps: 5)]
        )

        context.insert(
            StoredExerciseCatalogRecord(
                id: migratedCatalogItem.id,
                payload: try encoder.encode(migratedCatalogItem),
                sortOrder: 0
            )
        )
        context.insert(StoredPlanRecord(id: migratedPlan.id, payload: try encoder.encode(migratedPlan)))
        context.insert(
            StoredExerciseProfileRecord(
                id: migratedProfile.id,
                exerciseID: migratedProfile.exerciseID,
                payload: try encoder.encode(migratedProfile)
            )
        )
        context.insert(StoredActiveSessionRecord(id: migratedDraft.id, payload: try encoder.encode(migratedDraft)))
        context.insert(
            StoredCompletedSessionRecord(
                id: migratedCompletedSession.id,
                completedAt: migratedCompletedSession.completedAt,
                payload: try encoder.encode(migratedCompletedSession)
            )
        )
        try context.save()
        UserDefaults.standard.set(true, forKey: "workout_tracker_v2_completed_onboarding")

        let store = makeStore(container: container)
        await store.hydrateIfNeeded()

        XCTAssertEqual(store.plansStore.plans.first?.name, migratedPlan.name)
        XCTAssertEqual(store.plansStore.catalog.first?.name, migratedCatalogItem.name)
        XCTAssertEqual(store.plansStore.profile(for: migratedProfile.exerciseID)?.trainingMax, migratedProfile.trainingMax)
        XCTAssertEqual(store.sessionStore.activeDraft?.templateNameSnapshot, migratedDraft.templateNameSnapshot)
        XCTAssertEqual(store.sessionStore.completedSessions.first?.templateNameSnapshot, migratedCompletedSession.templateNameSnapshot)
        XCTAssertFalse(store.shouldShowOnboarding)

        let migratedContext = ModelContext(container)
        XCTAssertEqual(try migratedContext.fetch(FetchDescriptor<StoredPlanRecord>()).count, 0)
        XCTAssertEqual(try migratedContext.fetch(FetchDescriptor<StoredPlan>()).count, 1)
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

        let records = try context.fetch(FetchDescriptor<StoredPlan>())
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

        let records = try context.fetch(FetchDescriptor<StoredActiveSession>())
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(repository.loadActiveDraft()?.notes, "Felt strong")
    }

    @MainActor
    func testDeferredDraftMutationsPersistWhenFlushed() throws {
        let container = WorkoutModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let repository = SessionRepository(modelContext: context)
        let store = SessionStore(repository: repository)
        let row = SessionSetRow(
            target: SetTarget(
                setKind: .working,
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
        let draft = SessionDraft(
            planID: nil,
            templateID: UUID(),
            templateNameSnapshot: "Bench Day",
            blocks: [block]
        )

        store.beginSession(draft)
        store.pushMutation(persistence: .deferred) { updatedDraft in
            SessionEngine.adjustWeight(by: 5, setID: row.id, in: block.id, draft: &updatedDraft)
        }

        XCTAssertEqual(store.activeDraft?.blocks.first?.sets.first?.log.weight, 190)
        XCTAssertNil(repository.loadActiveDraft()?.blocks.first?.sets.first?.log.weight)

        store.flushPendingDraftSave()

        XCTAssertEqual(repository.loadActiveDraft()?.blocks.first?.sets.first?.log.weight, 190)
    }

    @MainActor
    func testProgressStoreCachesHistorySessionsBySelectedDay() {
        let analytics = AnalyticsRepository()
        let progressStore = ProgressStore()
        let dayOne = Date(timeIntervalSince1970: 1_741_478_400)
        let dayTwo = dayOne.addingTimeInterval(86_400)
        let sessions = [
            CompletedSession(
                planID: nil,
                templateID: UUID(),
                templateNameSnapshot: "Day One AM",
                startedAt: dayOne.addingTimeInterval(-3_600),
                completedAt: dayOne,
                blocks: []
            ),
            CompletedSession(
                planID: nil,
                templateID: UUID(),
                templateNameSnapshot: "Day One PM",
                startedAt: dayOne.addingTimeInterval(3_600),
                completedAt: dayOne.addingTimeInterval(7_200),
                blocks: []
            ),
            CompletedSession(
                planID: nil,
                templateID: UUID(),
                templateNameSnapshot: "Day Two",
                startedAt: dayTwo.addingTimeInterval(-3_600),
                completedAt: dayTwo,
                blocks: []
            )
        ]

        progressStore.apply(
            analytics.makeProgressSnapshot(
                sessions: sessions,
                catalogByID: [:],
                selectedExerciseID: nil,
                now: dayTwo
            ),
            completedSessions: sessions
        )

        XCTAssertEqual(progressStore.historySessions.map(\.templateNameSnapshot), ["Day Two", "Day One PM", "Day One AM"])
        XCTAssertEqual(progressStore.workoutDays.count, 2)

        progressStore.selectDay(dayOne)
        XCTAssertEqual(progressStore.historySessions.map(\.templateNameSnapshot), ["Day One PM", "Day One AM"])

        progressStore.selectDay(nil)
        XCTAssertEqual(progressStore.historySessions.map(\.templateNameSnapshot), ["Day Two", "Day One PM", "Day One AM"])
    }

    @MainActor
    func testProgressStoreSamplesDenseExerciseTrendCharts() throws {
        let analytics = AnalyticsRepository()
        let progressStore = ProgressStore()
        let start = Date(timeIntervalSince1970: 1_741_478_400)
        let sessions = (0..<240).map { index in
            makeCompletedSession(
                date: start.addingTimeInterval(Double(index) * 86_400),
                exerciseID: CatalogSeed.benchPress,
                exerciseName: "Bench Press",
                rows: [makeRow(kind: .working, weight: Double(135 + index), reps: 5)]
            )
        }
        let snapshot = analytics.makeProgressSnapshot(
            sessions: sessions,
            catalogByID: [
                CatalogSeed.benchPress: ExerciseCatalogItem(
                    id: CatalogSeed.benchPress,
                    name: "Bench Press",
                    category: .chest
                )
            ],
            selectedExerciseID: CatalogSeed.benchPress,
            now: start.addingTimeInterval(Double(sessions.count) * 86_400)
        )

        progressStore.apply(snapshot, completedSessions: sessions)

        let chartSeries = try XCTUnwrap(progressStore.selectedExerciseChartSeries)
        XCTAssertTrue(chartSeries.isSampled)
        XCTAssertLessThanOrEqual(chartSeries.trendPoints.count, 160)
        XCTAssertLessThanOrEqual(chartSeries.markerPoints.count, 24)
        XCTAssertEqual(chartSeries.trendPoints.first?.sessionID, snapshot.exerciseSummaries.first?.points.first?.sessionID)
        XCTAssertEqual(chartSeries.trendPoints.last?.sessionID, snapshot.exerciseSummaries.first?.points.last?.sessionID)
    }

    func testExercisePickerSearchIndexMatchesAliasesAndDiacritics() {
        let catalog = [
            ExerciseCatalogItem(
                id: UUID(),
                name: "Bench Press",
                aliases: ["Barbell Bench"],
                category: .chest
            ),
            ExerciseCatalogItem(
                id: UUID(),
                name: "Développé Couché",
                aliases: ["Développé Couché", "Presse poitrine"],
                category: .chest
            ),
            ExerciseCatalogItem(
                id: UUID(),
                name: "Back Squat",
                aliases: ["High Bar"],
                category: .legs
            )
        ]
        let index = ExercisePickerSearchIndex(catalog: catalog)

        XCTAssertEqual(index.filter(query: "barbell").map(\.name), ["Bench Press"])
        XCTAssertEqual(index.filter(query: "developpe").map(\.name), ["Développé Couché"])
        XCTAssertEqual(index.filter(query: "high bar").map(\.name), ["Back Squat"])
        XCTAssertEqual(index.filter(query: "   ").map(\.name), catalog.map(\.name))
    }

    func testCalendarMonthLayoutPrecomputesWorkoutDays() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        calendar.firstWeekday = 1

        let displayedMonth = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 15))
        )
        let workoutDay = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 9))
        )

        let layout = AppCalendarMonthLayout.make(
            for: displayedMonth,
            workoutDays: [workoutDay],
            calendar: calendar
        )

        XCTAssertEqual(layout.monthStart, calendar.date(from: DateComponents(year: 2026, month: 3, day: 1)))
        XCTAssertEqual(layout.dayEntries.count, 31)
        XCTAssertTrue(layout.dayEntries.contains(where: { $0.date == workoutDay && $0.hasWorkout }))
        XCTAssertEqual(layout.dayEntries.first?.dayNumber, 1)
        XCTAssertEqual(layout.dayEntries.last?.dayNumber, 31)
    }

    @MainActor
    func testFinishSessionIncrementallyUpdatesTodayAndProgressStores() async throws {
        let store = makeStore()
        await store.hydrateIfNeeded()
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
    func testQuickStartsStayDeduplicatedAfterRepeatedTemplateCompletion() async throws {
        let store = makeStore()
        await store.hydrateIfNeeded()
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
        UserDefaults.standard.removeObject(forKey: "workout_tracker_storage_version_v4")
    }
}
