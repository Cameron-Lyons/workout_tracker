import SwiftData
import XCTest

@testable import WorkoutTracker

extension WorkoutStoreTests {
    private struct LoadIssueModelContainerError: Error, CustomStringConvertible {
        let description: String
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
                completedAt: completedAt,
                exercises: []
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
                exercises: []
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
                exercises: []
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
                exercises: []
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
            exercises: [makeStartingStrengthBlock(id: CatalogSeed.backSquat, name: "Back Squat")]
        )
        let secondTemplate = WorkoutTemplate(
            name: "Day 2",
            exercises: [makeStartingStrengthBlock(id: CatalogSeed.benchPress, name: "Bench Press")]
        )
        let thirdTemplate = WorkoutTemplate(
            name: "Day 3",
            exercises: [makeStartingStrengthBlock(id: CatalogSeed.deadlift, name: "Deadlift")]
        )
        let plan = Plan(
            name: "Three Day Split",
            pinnedTemplateID: firstTemplate.id,
            templates: [firstTemplate, secondTemplate, thirdTemplate]
        )

        XCTAssertTrue(repository.savePlans([plan]))

        let summary = try XCTUnwrap(repository.loadPlanSummaries().first)
        XCTAssertTrue(summary.templates.allSatisfy { $0.exerciseIDs.isEmpty })
    }

    @MainActor
    func testPinningTemplateMakesItTodayDefaultAndClearsOlderPins() async throws {
        let store = makeStore()
        await store.hydrateIfNeeded()
        store.send(.completeOnboarding(nil))

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
        store.send(.savePlan(firstPlan))
        store.send(.savePlan(secondPlan))

        let secondTemplateID = try XCTUnwrap(secondPlan.templates.first?.id)
        store.send(.pinTemplate(planID: secondPlan.id, templateID: secondTemplateID))

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
            exercises: []
        )
        repository.saveActiveDraft(draft)

        draft.templateNameSnapshot = "Lower"
        repository.saveActiveDraft(draft)

        let records = try context.fetch(FetchDescriptor<StoredActiveSession>())
        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(repository.loadActiveDraft()?.templateNameSnapshot, "Lower")
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

    func testRecoveryClassifierResetsForSwiftDataLoadIssueWhenStoreFileExists() throws {
        let storeDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let storeURL = storeDirectory.appendingPathComponent("WorkoutTracker.store")

        try FileManager.default.createDirectory(at: storeDirectory, withIntermediateDirectories: true)
        try Data("legacy-store".utf8).write(to: storeURL)
        defer { try? FileManager.default.removeItem(at: storeDirectory) }

        let error = LoadIssueModelContainerError(
            description: "SwiftDataError(_error: SwiftData.SwiftDataError._Error.loadIssueModelContainer, _explanation: nil)"
        )

        XCTAssertTrue(
            PersistenceRecoveryClassifier.shouldAttemptReset(
                after: error,
                storeURL: storeURL
            )
        )
    }

    func testRecoveryClassifierDoesNotResetSwiftDataLoadIssueForDirectoryPath() throws {
        let storeDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let storeURL = storeDirectory.appendingPathComponent("WorkoutTracker.store", isDirectory: true)

        try FileManager.default.createDirectory(at: storeURL, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: storeDirectory) }

        let error = LoadIssueModelContainerError(
            description: "SwiftDataError(_error: SwiftData.SwiftDataError._Error.loadIssueModelContainer, _explanation: nil)"
        )

        XCTAssertFalse(
            PersistenceRecoveryClassifier.shouldAttemptReset(
                after: error,
                storeURL: storeURL
            )
        )
    }
}
