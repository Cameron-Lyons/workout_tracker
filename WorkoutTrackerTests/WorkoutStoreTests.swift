import SwiftData
import XCTest

@testable import WorkoutTracker

final class WorkoutStoreTests: XCTestCase {
    override func setUp() {
        super.setUp()
        resetDefaults()
        _ = WorkoutModelContainerFactory.consumeStartupIssue()
    }

    override func tearDown() {
        resetDefaults()
        _ = WorkoutModelContainerFactory.consumeStartupIssue()
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
    func testEmptySessionDoesNotFinishOrPersist() async throws {
        let store = makeStore()
        await store.hydrateIfNeeded()
        store.completeOnboarding(with: nil)

        let plan = makeSingleTemplatePlan(
            name: "Test Plan",
            templateName: "Upper 1",
            store: store,
            weight: 185
        )
        store.savePlan(plan)
        let templateID = try XCTUnwrap(plan.templates.first?.id)

        store.startSession(planID: plan.id, templateID: templateID)

        XCTAssertFalse(store.finishActiveSession())
        XCTAssertNotNil(store.sessionStore.activeDraft)
        XCTAssertTrue(store.sessionStore.completedSessions.isEmpty)
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
        let row = try XCTUnwrap(block.sets.first(where: { $0.target.setKind == .working }))

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

    @MainActor
    func testExerciseRenameUpdatesTemplateAndActiveDraftSnapshots() async throws {
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
        let templateID = try XCTUnwrap(plan.templates.first?.id)

        store.startSession(planID: plan.id, templateID: templateID)
        store.updateCatalogItem(
            itemID: CatalogSeed.benchPress,
            name: "Competition Bench Press",
            aliases: ["Barbell Bench"],
            category: .chest
        )

        let updatedPlan = try XCTUnwrap(store.plansStore.plan(for: plan.id))

        XCTAssertEqual(updatedPlan.templates.first?.blocks.first?.exerciseNameSnapshot, "Competition Bench Press")
        XCTAssertEqual(store.sessionStore.activeDraft?.blocks.first?.exerciseNameSnapshot, "Competition Bench Press")
    }

    @MainActor
    func testStartingAnotherTemplateResumesCurrentDraftUntilUserReplacesIt() async throws {
        let store = makeStore()
        await store.hydrateIfNeeded()
        store.completeOnboarding(with: nil)

        let firstPlan = makeSingleTemplatePlan(
            name: "Plan A",
            templateName: "Bench Day",
            store: store,
            weight: 185
        )
        let secondPlan = makeSingleTemplatePlan(
            name: "Plan B",
            templateName: "Press Day",
            store: store,
            weight: 135
        )
        store.savePlan(firstPlan)
        store.savePlan(secondPlan)

        let firstTemplateID = try XCTUnwrap(firstPlan.templates.first?.id)
        let secondTemplateID = try XCTUnwrap(secondPlan.templates.first?.id)

        store.startSession(planID: firstPlan.id, templateID: firstTemplateID)
        store.updateActiveSessionNotes("Keep me")
        store.startSession(planID: secondPlan.id, templateID: secondTemplateID)

        XCTAssertEqual(store.sessionStore.activeDraft?.templateID, firstTemplateID)
        XCTAssertEqual(store.sessionStore.activeDraft?.templateNameSnapshot, "Bench Day")
        XCTAssertEqual(store.sessionStore.activeDraft?.notes, "Keep me")
        XCTAssertNil(store.plansStore.plan(for: secondPlan.id)?.templates.first?.lastStartedAt)

        store.replaceActiveSessionAndStart(planID: secondPlan.id, templateID: secondTemplateID)

        XCTAssertEqual(store.sessionStore.activeDraft?.templateID, secondTemplateID)
        XCTAssertEqual(store.sessionStore.activeDraft?.templateNameSnapshot, "Press Day")
        XCTAssertEqual(store.sessionStore.activeDraft?.notes, "")
        XCTAssertNotNil(store.plansStore.plan(for: secondPlan.id)?.templates.first?.lastStartedAt)
    }

    @MainActor
    func testWavePresetPacksSeedDefaultTrainingMaxTargets() async throws {
        let store = makeStore()
        await store.hydrateIfNeeded()
        store.completeOnboarding(with: nil)

        store.plansStore.addPresetPack(.fiveThreeOne, settings: store.settingsStore)
        store.plansStore.addPresetPack(.boringButBig, settings: store.settingsStore)
        await store.refreshDerivedStores()

        for planName in [PresetPack.fiveThreeOne.displayName, PresetPack.boringButBig.displayName] {
            let plan = try XCTUnwrap(store.plansStore.plans.first(where: { $0.name == planName }))
            let template = try XCTUnwrap(plan.templates.first)
            let waveBlock = try XCTUnwrap(template.blocks.first)

            XCTAssertNotNil(waveBlock.progressionRule.percentageWave?.trainingMax)
            XCTAssertFalse(waveBlock.targets.isEmpty)
            XCTAssertNotNil(waveBlock.targets.first?.targetWeight)

            store.startSession(planID: plan.id, templateID: template.id)
            XCTAssertNotNil(store.sessionStore.activeDraft?.blocks.first?.sets.first?.target.targetWeight)
            store.discardActiveSession()
        }
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
                    makeRow(kind: .working, weight: 225, reps: 5),
                ]
            ),
            makeCompletedSession(
                date: .now,
                exerciseID: CatalogSeed.backSquat,
                exerciseName: "Back Squat",
                rows: [
                    makeRow(kind: .warmup, weight: 115, reps: 5),
                    makeRow(kind: .working, weight: 235, reps: 5),
                ]
            ),
        ]

        let snapshot = analytics.makeSessionAnalyticsSnapshot(sessions: sessions, catalogByID: catalog)
        let overview = snapshot.overview
        let summaries = snapshot.exerciseSummaries
        let records = snapshot.personalRecords

        XCTAssertEqual(overview.totalSessions, 2)
        XCTAssertGreaterThan(overview.totalVolume, 0)
        XCTAssertEqual(summaries.first?.pointCount, 2)
        XCTAssertGreaterThan(summaries.first?.totalVolume ?? 0, 0)
        XCTAssertEqual(records.last?.weight, 235)
    }

    func testAnalyticsIgnoreIncompleteRowsForProgressAndVolume() {
        let analytics = AnalyticsRepository()
        let session = makeCompletedSession(
            date: .now,
            exerciseID: CatalogSeed.benchPress,
            exerciseName: "Bench Press",
            rows: [
                makeRow(kind: .working, weight: 225, reps: 5),
                makeRow(kind: .working, weight: 315, reps: 1, completedAt: nil),
            ]
        )

        let records = analytics.finishSummary(
            for: session,
            previousBestByExerciseID: [:],
            catalogByID: [:]
        ).personalRecords
        let payload = analytics.sessionExercisePayloads(from: session).first

        XCTAssertEqual(analytics.volume(for: session), 1_125)
        XCTAssertEqual(records.last?.weight, 225)
        XCTAssertEqual(payload?.topWeight, 225)
    }

    func testAnalyticsCurrentPRPrefersHigherEstimatedOneRepMaxOverHeavierSingle() throws {
        let analytics = AnalyticsRepository()
        let catalog = [
            CatalogSeed.benchPress: ExerciseCatalogItem(id: CatalogSeed.benchPress, name: "Bench Press", category: .chest)
        ]
        let sessions = [
            makeCompletedSession(
                date: .now.addingTimeInterval(-86_400),
                exerciseID: CatalogSeed.benchPress,
                exerciseName: "Bench Press",
                rows: [makeRow(kind: .working, weight: 225, reps: 1)]
            ),
            makeCompletedSession(
                date: .now,
                exerciseID: CatalogSeed.benchPress,
                exerciseName: "Bench Press",
                rows: [makeRow(kind: .working, weight: 215, reps: 5)]
            ),
        ]

        let snapshot = analytics.makeSessionAnalyticsSnapshot(sessions: sessions, catalogByID: catalog)
        let summary = try XCTUnwrap(snapshot.exerciseSummaries.first)
        let currentPR = try XCTUnwrap(summary.currentPR)

        XCTAssertEqual(currentPR.weight, 215)
        XCTAssertEqual(currentPR.reps, 5)
        XCTAssertGreaterThan(currentPR.estimatedOneRepMax, 225)
    }

    func testAnalyticsReserveRecordsAndProgressPointsForWorkingSets() {
        let analytics = AnalyticsRepository()
        let session = makeCompletedSession(
            date: .now,
            exerciseID: CatalogSeed.backSquat,
            exerciseName: "Back Squat",
            rows: [
                makeRow(kind: .warmup, weight: 315, reps: 1),
                makeRow(kind: .dropSet, weight: 185, reps: 12),
                makeRow(kind: .working, weight: 225, reps: 5),
            ]
        )

        let summary = analytics.finishSummary(
            for: session,
            previousBestByExerciseID: [:],
            catalogByID: [:]
        )
        let payload = analytics.sessionExercisePayloads(from: session).first

        XCTAssertEqual(summary.personalRecords.last?.weight, 225)
        XCTAssertEqual(payload?.topWeight, 225)
        XCTAssertEqual(summary.totalVolume, 3_660)
    }

    func testAnalyticsAggregateDuplicateExerciseBlocksIntoSingleProgressPointPerSession() throws {
        let analytics = AnalyticsRepository()
        let completedAt = Date(timeIntervalSince1970: 1_741_478_400)
        let session = CompletedSession(
            planID: UUID(),
            templateID: UUID(),
            templateNameSnapshot: "BBB Bench Day",
            startedAt: completedAt.addingTimeInterval(-3_600),
            completedAt: completedAt,
            blocks: [
                CompletedSessionBlock(
                    exerciseID: CatalogSeed.benchPress,
                    exerciseNameSnapshot: "Bench Press",
                    blockNote: "Main work",
                    restSeconds: 180,
                    supersetGroup: nil,
                    progressionRule: .manual,
                    sets: [makeRow(kind: .working, weight: 225, reps: 5)]
                ),
                CompletedSessionBlock(
                    exerciseID: CatalogSeed.benchPress,
                    exerciseNameSnapshot: "Bench Press",
                    blockNote: "Supplemental",
                    restSeconds: 120,
                    supersetGroup: nil,
                    progressionRule: .manual,
                    sets: [makeRow(kind: .working, weight: 185, reps: 10)]
                ),
            ]
        )

        let payloads = analytics.sessionExercisePayloads(from: session)
        let payload = try XCTUnwrap(payloads.first)
        let snapshot = analytics.makeSessionAnalyticsSnapshot(
            sessions: [session],
            catalogByID: [
                CatalogSeed.benchPress: ExerciseCatalogItem(
                    id: CatalogSeed.benchPress,
                    name: "Bench Press",
                    category: .chest
                )
            ],
            now: completedAt
        )
        let summary = try XCTUnwrap(
            snapshot.exerciseSummaries.first(where: { $0.exerciseID == CatalogSeed.benchPress })
        )

        XCTAssertEqual(payloads.count, 1)
        XCTAssertEqual(payload.topWeight, 225)
        XCTAssertEqual(payload.volume, 2_975)
        XCTAssertEqual(summary.pointCount, 1)
        XCTAssertEqual(summary.points.count, 1)
        XCTAssertEqual(summary.points.first?.topWeight, 225)
        XCTAssertEqual(summary.points.first?.volume, 2_975)
        XCTAssertEqual(summary.totalVolume, 2_975)
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
                ),
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
            ),
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
                            makeRow(kind: .working, weight: 185, reps: 5),
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
            ),
        ]
        let catalog = [
            CatalogSeed.benchPress: ExerciseCatalogItem(id: CatalogSeed.benchPress, name: "Bench Press", category: .chest),
            CatalogSeed.backSquat: ExerciseCatalogItem(id: CatalogSeed.backSquat, name: "Back Squat", category: .legs),
        ]

        let sessionAnalytics = analytics.makeSessionAnalyticsSnapshot(
            sessions: sessions,
            catalogByID: catalog,
            now: now
        )
        let combined = analytics.makeDerivedStoreSnapshot(
            plans: [plan],
            references: references,
            sessions: sessions,
            sessionAnalytics: sessionAnalytics,
            selectedExerciseID: CatalogSeed.backSquat,
            now: now
        )
        let today = analytics.makeTodaySnapshot(
            plans: [plan],
            references: references,
            sessions: sessions,
            sessionAnalytics: sessionAnalytics,
            now: now
        )
        let progress = analytics.makeProgressSnapshot(
            sessionAnalytics: sessionAnalytics,
            selectedExerciseID: CatalogSeed.backSquat,
        )

        let recordSignature: (PersonalRecord) -> String = {
            [
                $0.sessionID.uuidString,
                $0.exerciseID.uuidString,
                $0.displayName,
                String($0.weight),
                String($0.reps),
                String($0.estimatedOneRepMax),
                String($0.achievedAt.timeIntervalSinceReferenceDate),
            ].joined(separator: "|")
        }
        let pointSignature: (ProgressPoint) -> String = {
            [
                $0.sessionID.uuidString,
                String($0.date.timeIntervalSinceReferenceDate),
                String($0.topWeight),
                String($0.estimatedOneRepMax),
                String($0.volume),
            ].joined(separator: "|")
        }
        let summarySignature: (ExerciseAnalyticsSummary) -> String = {
            [
                $0.exerciseID.uuidString,
                $0.displayName,
                String($0.pointCount),
                String($0.totalVolume),
                $0.currentPR.map(recordSignature) ?? "nil",
                $0.points.map(pointSignature).joined(separator: ","),
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

    func testPinnedTemplateUsesStartingStrengthRotationInsteadOfStaticWeekdaySchedule() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let monday = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 9))
        )
        let completedAt = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 6))
        )

        let plan = makeStartingStrengthPlan()
        let references = plan.templates.map { template in
            makeReference(plan: plan, template: template)
        }
        let sessions = [
            CompletedSession(
                planID: plan.id,
                templateID: try XCTUnwrap(plan.templates.first(where: { $0.name == "Workout A" })?.id),
                templateNameSnapshot: "Workout A",
                startedAt: completedAt.addingTimeInterval(-5_400),
                completedAt: completedAt,
                blocks: []
            )
        ]

        let pinned = try XCTUnwrap(
            TemplateReferenceSelection.pinnedTemplate(
                from: [plan],
                references: references,
                sessions: sessions,
                now: monday,
                calendar: calendar
            )
        )

        XCTAssertEqual(pinned.templateName, "Workout B")
    }

    @MainActor
    func testPinningTemplateMakesItTodayDefaultAndClearsOlderPins() async throws {
        let store = makeStore()
        await store.hydrateIfNeeded()
        store.completeOnboarding(with: nil)

        let firstPlan = makeSingleTemplatePlan(
            name: "Plan A",
            templateName: "Bench Day",
            store: store,
            weight: 185
        )
        let secondPlan = makeSingleTemplatePlan(
            name: "Plan B",
            templateName: "Press Day",
            store: store,
            weight: 135
        )
        store.savePlan(firstPlan)
        store.savePlan(secondPlan)

        let secondTemplateID = try XCTUnwrap(secondPlan.templates.first?.id)
        store.pinTemplate(planID: secondPlan.id, templateID: secondTemplateID)

        XCTAssertEqual(store.todayStore.pinnedTemplate?.templateID, secondTemplateID)
        XCTAssertNil(store.plansStore.plan(for: firstPlan.id)?.pinnedTemplateID)
        XCTAssertEqual(store.plansStore.plan(for: secondPlan.id)?.pinnedTemplateID, secondTemplateID)
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
            category: .chest
        )
        let migratedProfile = ExerciseProfile(
            exerciseID: CatalogSeed.benchPress,
            trainingMax: 225,
            preferredIncrement: 5
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
    func testDiskStoreMigratesV1SchemaToV2RelationalModels() throws {
        let storeDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let storeURL = storeDirectory.appendingPathComponent("WorkoutTracker.store")
        let encoder = JSONEncoder()

        try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: storeDirectory)
        }

        let exerciseID = CatalogSeed.benchPress
        let profileID = UUID()
        let planID = UUID()
        let templateID = UUID()
        let templateBlockID = UUID()
        let templateTargetID = UUID()
        let activeSessionID = UUID()
        let activeBlockID = UUID()
        let activeRowID = UUID()
        let completedSessionID = UUID()
        let completedBlockID = UUID()
        let completedRowID = UUID()
        let now = Date(timeIntervalSince1970: 1_741_478_400)

        do {
            let v1Container = try makeDiskBackedContainer(
                schema: Schema(versionedSchema: WorkoutSchemaV1.self),
                url: storeURL
            )
            let context = ModelContext(v1Container)
            context.autosaveEnabled = false

            let catalogItem = WorkoutSchemaV1.StoredCatalogItem(
                id: exerciseID,
                name: "Bench Press",
                aliasesData: try encoder.encode(["Barbell Bench"]),
                categoryRaw: ExerciseCategory.chest.rawValue,
                equipment: "Barbell",
                isCustom: true
            )

            let profile = WorkoutSchemaV1.StoredExerciseProfile(
                id: profileID,
                exerciseID: exerciseID,
                trainingMax: 225,
                preferredIncrement: 5,
                notes: "legacy notes"
            )

            let plan = WorkoutSchemaV1.StoredPlan(
                id: planID,
                name: "Migrated Plan",
                createdAt: now,
                pinnedTemplateID: templateID,
                presetPackID: "generalGym"
            )
            let template = WorkoutSchemaV1.StoredTemplate(
                id: templateID,
                name: "Bench Day",
                note: "Primary day",
                scheduledWeekdaysData: try encoder.encode([Weekday.monday]),
                lastStartedAt: now,
                orderIndex: 0
            )
            let templateBlock = WorkoutSchemaV1.StoredTemplateBlock(
                id: templateBlockID,
                exerciseID: exerciseID,
                exerciseNameSnapshot: "Bench Press",
                blockNote: "Top set",
                restSeconds: 120,
                supersetGroup: nil,
                allowsAutoWarmups: true,
                orderIndex: 0,
                progressionRuleData: try encoder.encode(ProgressionRule.manual)
            )
            let templateTarget = WorkoutSchemaV1.StoredTemplateTarget(
                id: templateTargetID,
                orderIndex: 0,
                setKindRaw: SetKind.working.rawValue,
                targetWeight: 185,
                repLower: 5,
                repUpper: 5,
                rir: nil,
                restSeconds: 120,
                note: nil
            )

            templateTarget.block = templateBlock
            templateBlock.targets = [templateTarget]
            templateBlock.template = template
            template.blocks = [templateBlock]
            template.plan = plan
            plan.templates = [template]

            let activeSession = WorkoutSchemaV1.StoredActiveSession(
                id: activeSessionID,
                planID: planID,
                templateID: templateID,
                templateNameSnapshot: "Bench Day",
                startedAt: now,
                lastUpdatedAt: now,
                notes: "Session note",
                restTimerEndsAt: now.addingTimeInterval(90)
            )
            let activeBlock = WorkoutSchemaV1.StoredActiveSessionBlock(
                id: activeBlockID,
                orderIndex: 0,
                sourceBlockID: templateBlockID,
                exerciseID: exerciseID,
                exerciseNameSnapshot: "Bench Press",
                blockNote: "Active block",
                restSeconds: 120,
                supersetGroup: nil,
                progressionRuleData: try encoder.encode(ProgressionRule.manual)
            )
            let activeRow = WorkoutSchemaV1.StoredActiveSessionRow(
                id: activeRowID,
                orderIndex: 0,
                targetID: UUID(),
                targetSetKindRaw: SetKind.working.rawValue,
                targetWeight: 185,
                targetRepLower: 5,
                targetRepUpper: 5,
                targetRir: nil,
                targetRestSeconds: 120,
                targetNote: nil,
                logID: UUID(),
                logWeight: 185,
                logReps: 5,
                logRir: nil,
                logCompletedAt: now
            )

            activeRow.block = activeBlock
            activeBlock.rows = [activeRow]
            activeBlock.session = activeSession
            activeSession.blocks = [activeBlock]

            let completedSession = WorkoutSchemaV1.StoredCompletedSession(
                id: completedSessionID,
                planID: planID,
                templateID: templateID,
                templateNameSnapshot: "Bench Day",
                startedAt: now.addingTimeInterval(-3_600),
                completedAt: now,
                notes: "Completed note"
            )
            let completedBlock = WorkoutSchemaV1.StoredCompletedSessionBlock(
                id: completedBlockID,
                orderIndex: 0,
                exerciseID: exerciseID,
                exerciseNameSnapshot: "Bench Press",
                blockNote: "Completed block",
                restSeconds: 120,
                supersetGroup: nil,
                progressionRuleData: try encoder.encode(ProgressionRule.manual)
            )
            let completedRow = WorkoutSchemaV1.StoredCompletedSessionRow(
                id: completedRowID,
                orderIndex: 0,
                targetID: UUID(),
                targetSetKindRaw: SetKind.working.rawValue,
                targetWeight: 185,
                targetRepLower: 5,
                targetRepUpper: 5,
                targetRir: nil,
                targetRestSeconds: 120,
                targetNote: nil,
                logID: UUID(),
                logWeight: 185,
                logReps: 5,
                logRir: nil,
                logCompletedAt: now
            )

            completedRow.block = completedBlock
            completedBlock.rows = [completedRow]
            completedBlock.session = completedSession
            completedSession.blocks = [completedBlock]

            context.insert(catalogItem)
            context.insert(profile)
            context.insert(plan)
            context.insert(template)
            context.insert(templateBlock)
            context.insert(templateTarget)
            context.insert(activeSession)
            context.insert(activeBlock)
            context.insert(activeRow)
            context.insert(completedSession)
            context.insert(completedBlock)
            context.insert(completedRow)

            try context.save()
        }

        let migratedContainer = try makeDiskBackedContainer(
            schema: Schema(versionedSchema: WorkoutSchemaV2.self),
            migrationPlan: WorkoutSchemaMigrationPlan.self,
            url: storeURL
        )
        let planContext = ModelContext(migratedContainer)
        let sessionContext = ModelContext(migratedContainer)
        planContext.autosaveEnabled = false
        sessionContext.autosaveEnabled = false

        let planRepository = PlanRepository(modelContext: planContext)
        let sessionRepository = SessionRepository(modelContext: sessionContext)

        let migratedPlan = try XCTUnwrap(planRepository.loadPlans().first)
        XCTAssertEqual(migratedPlan.name, "Migrated Plan")
        XCTAssertEqual(migratedPlan.pinnedTemplateID, templateID)
        XCTAssertEqual(migratedPlan.templates.first?.name, "Bench Day")

        let migratedCatalog = try XCTUnwrap(planRepository.loadCatalog().first)
        XCTAssertEqual(migratedCatalog.name, "Bench Press")
        XCTAssertEqual(migratedCatalog.aliases, ["Barbell Bench"])

        let migratedProfile = try XCTUnwrap(planRepository.loadProfiles().first)
        XCTAssertEqual(migratedProfile.exerciseID, exerciseID)
        XCTAssertEqual(migratedProfile.trainingMax, 225)
        XCTAssertEqual(migratedProfile.preferredIncrement, 5)

        let activeDraft = try XCTUnwrap(sessionRepository.loadActiveDraft())
        XCTAssertEqual(activeDraft.templateNameSnapshot, "Bench Day")
        XCTAssertEqual(activeDraft.notes, "Session note")
        XCTAssertEqual(activeDraft.blocks.first?.exerciseID, exerciseID)

        let completed = try XCTUnwrap(sessionRepository.loadCompletedSessions().first)
        XCTAssertEqual(completed.templateNameSnapshot, "Bench Day")
        XCTAssertEqual(completed.notes, "Completed note")
        XCTAssertEqual(completed.blocks.first?.exerciseID, exerciseID)
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
    func testContainerFactoryRecoversFromInvalidPersistentStorePath() throws {
        let storeDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let storeURL = storeDirectory.appendingPathComponent("WorkoutTracker.store")

        try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: storeURL, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: storeDirectory)
            _ = WorkoutModelContainerFactory.consumeStartupIssue()
        }

        let container = WorkoutModelContainerFactory.makeContainer(storeURL: storeURL)
        let issue = try XCTUnwrap(WorkoutModelContainerFactory.consumeStartupIssue())
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let repository = PlanRepository(modelContext: context)
        let catalogItem = ExerciseCatalogItem(
            id: CatalogSeed.benchPress,
            name: "Bench Press",
            category: .chest
        )

        XCTAssertEqual(issue.title, "Storage Reset")
        XCTAssertTrue(repository.saveCatalog([catalogItem]))
        XCTAssertEqual(repository.loadCatalog().first?.name, "Bench Press")
    }

    @MainActor
    func testDeferredDraftMutationsPersistWhenFlushed() throws {
        let container = WorkoutModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let repository = SessionRepository(modelContext: context)
        let store = SessionStore(
            repository: repository,
            persistenceController: SessionPersistenceControllerRegistry.controller(for: container)
        )
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
            ),
        ]

        let sessionAnalytics = analytics.makeSessionAnalyticsSnapshot(
            sessions: sessions,
            catalogByID: [:],
            now: dayTwo
        )

        progressStore.apply(
            analytics.makeProgressSnapshot(
                sessionAnalytics: sessionAnalytics,
                selectedExerciseID: nil
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
        let sessionAnalytics = analytics.makeSessionAnalyticsSnapshot(
            sessions: sessions,
            catalogByID: [
                CatalogSeed.benchPress: ExerciseCatalogItem(
                    id: CatalogSeed.benchPress,
                    name: "Bench Press",
                    category: .chest
                )
            ],
            now: start.addingTimeInterval(Double(sessions.count) * 86_400)
        )
        let snapshot = analytics.makeProgressSnapshot(
            sessionAnalytics: sessionAnalytics,
            selectedExerciseID: CatalogSeed.benchPress
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
            ),
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

    func testCalendarMonthLayoutWrapsLeadingDaysForMondayFirstCalendars() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        calendar.firstWeekday = 2

        let displayedMonth = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 15))
        )

        let layout = AppCalendarMonthLayout.make(
            for: displayedMonth,
            workoutDays: [],
            calendar: calendar
        )

        XCTAssertEqual(layout.dayEntries.count, 37)
        XCTAssertEqual(layout.dayEntries.prefix(6).compactMap(\.dayNumber), [])
        XCTAssertEqual(layout.dayEntries[6].dayNumber, 1)
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
        let row = try XCTUnwrap(block.sets.first(where: { $0.target.setKind == .working }))
        store.toggleSetCompletion(blockID: block.id, setID: row.id)
        store.finishActiveSession()

        XCTAssertEqual(store.todayStore.recentSessions.first?.templateNameSnapshot, "Bench Day")
        XCTAssertEqual(store.todayStore.recentPersonalRecords.count, 1)
        XCTAssertEqual(store.progressStore.personalRecords.count, 1)
        XCTAssertEqual(store.progressStore.exerciseSummaries.first?.pointCount, 1)
        XCTAssertEqual(store.progressStore.overview.totalSessions, 1)
    }

    @MainActor
    func testDuplicateExerciseBlocksOnlyAdvanceMatchedTemplateProgressionOnce() async throws {
        let store = makeStore()
        await store.hydrateIfNeeded()
        store.completeOnboarding(with: nil)

        var plan = store.makePlan(name: "Duplicate Bench")
        let template = WorkoutTemplate(
            name: "Bench Day",
            blocks: [
                ExerciseBlock(
                    exerciseID: CatalogSeed.benchPress,
                    exerciseNameSnapshot: "Bench Press",
                    progressionRule: ProgressionRule(
                        kind: .percentageWave,
                        percentageWave: PercentageWaveRule.fiveThreeOne(trainingMax: 200, cycleIncrement: 5)
                    ),
                    targets: []
                ),
                ExerciseBlock(
                    exerciseID: CatalogSeed.benchPress,
                    exerciseNameSnapshot: "Bench Press",
                    progressionRule: .manual,
                    targets: [
                        SetTarget(targetWeight: 185, repRange: RepRange(10, 10))
                    ],
                    allowsAutoWarmups: false
                ),
            ]
        )
        plan.templates = [template]
        plan.pinnedTemplateID = template.id
        store.savePlan(plan)

        store.startSession(planID: plan.id, templateID: template.id)
        let activeBlocks = try XCTUnwrap(store.sessionStore.activeDraft?.blocks)
        let mainSessionBlock = try XCTUnwrap(activeBlocks.first)
        for row in mainSessionBlock.sets where row.target.setKind == .working {
            store.toggleSetCompletion(blockID: mainSessionBlock.id, setID: row.id)
        }
        store.finishActiveSession()

        let updatedTemplate = try XCTUnwrap(store.plansStore.plan(for: plan.id)?.templates.first)
        let mainBlock = try XCTUnwrap(updatedTemplate.blocks.first)
        let supplementalBlock = try XCTUnwrap(updatedTemplate.blocks.dropFirst().first)

        XCTAssertEqual(mainBlock.progressionRule.percentageWave?.currentWeekIndex, 1)
        XCTAssertEqual(mainBlock.progressionRule.percentageWave?.cycle, 1)
        XCTAssertEqual(supplementalBlock.progressionRule.kind, .manual)
        XCTAssertEqual(supplementalBlock.targets.first?.targetWeight, 185)
    }

    @MainActor
    func testFinishingStartingStrengthSessionPinsTheAlternateWorkout() async throws {
        let store = makeStore()
        await store.hydrateIfNeeded()
        store.completeOnboarding(with: .startingStrength)

        let initialPinned = try XCTUnwrap(store.todayStore.pinnedTemplate)
        XCTAssertEqual(initialPinned.templateName, "Workout A")

        store.startSession(planID: initialPinned.planID, templateID: initialPinned.templateID)
        let block = try XCTUnwrap(store.sessionStore.activeDraft?.blocks.first)
        let row = try XCTUnwrap(block.sets.first(where: { $0.target.setKind == .working }))
        store.toggleSetCompletion(blockID: block.id, setID: row.id)
        store.finishActiveSession()

        let rotatedPinned = try XCTUnwrap(store.todayStore.pinnedTemplate)
        let updatedPlan = try XCTUnwrap(store.plansStore.plan(for: initialPinned.planID))

        XCTAssertEqual(rotatedPinned.templateName, "Workout B")
        XCTAssertEqual(updatedPlan.pinnedTemplateID, rotatedPinned.templateID)
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
            let row = try XCTUnwrap(block.sets.first(where: { $0.target.setKind == .working }))
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

    private func makeStartingStrengthPlan() -> Plan {
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

    private func makeStartingStrengthBlock(id: UUID, name: String) -> ExerciseBlock {
        ExerciseBlock(
            exerciseID: id,
            exerciseNameSnapshot: name,
            restSeconds: 90,
            progressionRule: .manual,
            targets: []
        )
    }

    private func makeReference(plan: Plan, template: WorkoutTemplate) -> TemplateReference {
        TemplateReference(
            planID: plan.id,
            planName: plan.name,
            templateID: template.id,
            templateName: template.name,
            scheduledWeekdays: template.scheduledWeekdays,
            lastStartedAt: template.lastStartedAt
        )
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

    private func makeRow(
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

    private func makeDiskBackedContainer(
        schema: Schema,
        migrationPlan: (any SchemaMigrationPlan.Type)? = nil,
        url: URL
    ) throws -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema, url: url)
        return try ModelContainer(
            for: schema,
            migrationPlan: migrationPlan,
            configurations: configuration
        )
    }

    private func resetDefaults() {
        SettingsStore.resetPersistedSettings()
        UserDefaults.standard.removeObject(forKey: "workout_tracker_storage_version_v3")
        UserDefaults.standard.removeObject(forKey: "workout_tracker_storage_version_v4")
        UserDefaults.standard.removeObject(forKey: "workout_tracker_storage_version_v5")
    }
}
