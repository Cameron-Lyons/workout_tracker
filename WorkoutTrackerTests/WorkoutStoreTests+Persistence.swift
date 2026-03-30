import SwiftData
import XCTest

@testable import WorkoutTracker

extension WorkoutStoreTests {
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

    func testCustomWorkoutABNamesUseWeekdayScheduleInsteadOfAlternatingRotation() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let friday = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 13))
        )
        let completedAt = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 9))
        )

        let plan = makeCustomNamedWorkoutABPlan()
        let references = plan.templates.map { template in
            makeReference(plan: plan, template: template)
        }
        let sessions = [
            CompletedSession(
                planID: plan.id,
                templateID: try XCTUnwrap(plan.templates.first(where: { $0.name == "Workout A" })?.id),
                templateNameSnapshot: "Workout A",
                completedAt: completedAt,
                blocks: []
            )
        ]

        let pinned = try XCTUnwrap(
            TemplateReferenceSelection.pinnedTemplate(
                from: [plan],
                references: references,
                sessions: sessions,
                now: friday,
                calendar: calendar
            )
        )

        XCTAssertFalse(TemplateReferenceSelection.isAlternatingPlan(plan))
        XCTAssertEqual(pinned.templateName, "Workout A")
    }

    @MainActor
    func testPlanRepositoryLoadPlanSummariesPreservesStartingStrengthRotation() throws {
        let container = WorkoutModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let repository = PlanRepository(modelContext: context)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let monday = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 9))
        )
        let completedAt = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 6))
        )

        let plan = makeStartingStrengthPlan()
        XCTAssertTrue(repository.savePlans([plan]))

        let summary = try XCTUnwrap(repository.loadPlanSummaries().first)
        let references = plan.templates.map { template in
            makeReference(plan: plan, template: template)
        }
        let sessions = [
            CompletedSession(
                planID: plan.id,
                templateID: try XCTUnwrap(plan.templates.first(where: { $0.name == "Workout A" })?.id),
                templateNameSnapshot: "Workout A",
                completedAt: completedAt,
                blocks: []
            )
        ]

        let pinned = try XCTUnwrap(
            TemplateReferenceSelection.pinnedTemplate(
                from: [summary],
                references: references,
                sessions: sessions,
                now: monday,
                calendar: calendar
            )
        )

        XCTAssertTrue(TemplateReferenceSelection.isAlternatingPlan(summary))
        XCTAssertEqual(pinned.templateName, "Workout B")
    }

    @MainActor
    func testPlanRepositoryLoadPlanSummariesKeepsCustomWorkoutABNonAlternating() throws {
        let container = WorkoutModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let repository = PlanRepository(modelContext: context)

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(secondsFromGMT: 0))
        let friday = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 13))
        )
        let completedAt = try XCTUnwrap(
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 9))
        )

        let plan = makeCustomNamedWorkoutABPlan()
        XCTAssertTrue(repository.savePlans([plan]))

        let summary = try XCTUnwrap(repository.loadPlanSummaries().first)
        let references = plan.templates.map { template in
            makeReference(plan: plan, template: template)
        }
        let sessions = [
            CompletedSession(
                planID: plan.id,
                templateID: try XCTUnwrap(plan.templates.first(where: { $0.name == "Workout A" })?.id),
                templateNameSnapshot: "Workout A",
                completedAt: completedAt,
                blocks: []
            )
        ]

        let pinned = try XCTUnwrap(
            TemplateReferenceSelection.pinnedTemplate(
                from: [summary],
                references: references,
                sessions: sessions,
                now: friday,
                calendar: calendar
            )
        )

        XCTAssertFalse(TemplateReferenceSelection.isAlternatingPlan(summary))
        XCTAssertEqual(pinned.templateName, "Workout A")
    }

    @MainActor
    func testPlanRepositoryLoadPlanSummariesSkipsBlockExerciseIDsForPlansWithMoreThanTwoTemplates() throws {
        let container = WorkoutModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        context.autosaveEnabled = false
        let repository = PlanRepository(modelContext: context)

        let firstTemplate = WorkoutTemplate(
            name: "Day 1",
            blocks: [makeStartingStrengthBlock(id: CatalogSeed.backSquat, name: "Back Squat")]
        )
        let secondTemplate = WorkoutTemplate(
            name: "Day 2",
            blocks: [makeStartingStrengthBlock(id: CatalogSeed.benchPress, name: "Bench Press")]
        )
        let thirdTemplate = WorkoutTemplate(
            name: "Day 3",
            blocks: [makeStartingStrengthBlock(id: CatalogSeed.deadlift, name: "Deadlift")]
        )
        let plan = Plan(
            name: "Three Day Split",
            pinnedTemplateID: firstTemplate.id,
            templates: [firstTemplate, secondTemplate, thirdTemplate]
        )

        XCTAssertTrue(repository.savePlans([plan]))

        let summary = try XCTUnwrap(repository.loadPlanSummaries().first)
        XCTAssertTrue(summary.templates.allSatisfy { $0.blockExerciseIDs.isEmpty })
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
    func testPlanRepositoryDropsBlocksWithInvalidProgressionRulePayloads() throws {
        let container = WorkoutModelContainerFactory.makeContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        context.autosaveEnabled = false

        let plan = StoredPlan(
            id: UUID(),
            name: "Starter",
            createdAt: .now,
            pinnedTemplateID: nil
        )
        let template = StoredTemplate(
            id: UUID(),
            name: "Bench Day",
            note: "",
            scheduledWeekdaysData: Data("[]".utf8),
            lastStartedAt: nil,
            orderIndex: 0
        )
        let block = StoredTemplateBlock(
            id: UUID(),
            exerciseID: CatalogSeed.benchPress,
            exerciseNameSnapshot: "Bench Press",
            blockNote: "",
            restSeconds: 90,
            supersetGroup: nil,
            allowsAutoWarmups: true,
            orderIndex: 0,
            progressionRuleData: Data("invalid".utf8)
        )

        template.plan = plan
        template.blocks = [block]
        block.template = template

        context.insert(plan)
        context.insert(template)
        context.insert(block)
        try context.save()

        let repository = PlanRepository(modelContext: context)
        let loadedPlan = try XCTUnwrap(repository.loadPlans().first)
        let loadedTemplate = try XCTUnwrap(loadedPlan.templates.first)

        XCTAssertEqual(loadedPlan.name, "Starter")
        XCTAssertEqual(loadedTemplate.name, "Bench Day")
        XCTAssertTrue(loadedTemplate.blocks.isEmpty)
    }

    @MainActor
    func testContainerFactoryFallsBackWithoutResetForInvalidPersistentStorePath() throws {
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

        XCTAssertEqual(issue.title, "Storage Unavailable")
        XCTAssertNil(issue.recoveryDirectoryURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: storeURL.path))
        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: storeDirectory.appendingPathComponent("Recovery").path
            )
        )
        XCTAssertTrue(repository.saveCatalog([catalogItem]))
        XCTAssertEqual(repository.loadCatalog().first?.name, "Bench Press")
    }
}
