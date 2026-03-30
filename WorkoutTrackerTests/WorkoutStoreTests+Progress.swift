import SwiftData
import XCTest

@testable import WorkoutTracker

extension WorkoutStoreTests {
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
                completedAt: dayOne,
                blocks: []
            ),
            CompletedSession(
                planID: nil,
                templateID: UUID(),
                templateNameSnapshot: "Day One PM",
                completedAt: dayOne.addingTimeInterval(7_200),
                blocks: []
            ),
            CompletedSession(
                planID: nil,
                templateID: UUID(),
                templateNameSnapshot: "Day Two",
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

    @MainActor
    func testProgressStoreRecordCompletedSessionRebuildsCachesAndKeepsSelectedExerciseSeriesSorted() throws {
        let analytics = AnalyticsRepository()
        let progressStore = ProgressStore()
        let dayOne = Date(timeIntervalSince1970: 1_741_478_400)
        let dayTwo = dayOne.addingTimeInterval(86_400)
        let dayThree = dayTwo.addingTimeInterval(86_400)
        let olderBenchSession = makeCompletedSession(
            date: dayOne,
            exerciseID: CatalogSeed.benchPress,
            exerciseName: "Bench Press",
            rows: [makeRow(kind: .working, weight: 185, reps: 5)]
        )
        let newerBenchSession = makeCompletedSession(
            date: dayTwo,
            exerciseID: CatalogSeed.benchPress,
            exerciseName: "Bench Press",
            rows: [makeRow(kind: .working, weight: 205, reps: 5)]
        )
        let laterSquatSession = makeCompletedSession(
            date: dayThree,
            exerciseID: CatalogSeed.backSquat,
            exerciseName: "Back Squat",
            rows: [makeRow(kind: .working, weight: 275, reps: 5)]
        )
        let catalogByID = [
            CatalogSeed.backSquat: ExerciseCatalogItem(
                id: CatalogSeed.backSquat,
                name: "Back Squat",
                category: .legs
            ),
            CatalogSeed.benchPress: ExerciseCatalogItem(
                id: CatalogSeed.benchPress,
                name: "Bench Press",
                category: .chest
            ),
        ]
        let sessionAnalytics = analytics.makeSessionAnalyticsSnapshot(
            sessions: [newerBenchSession],
            catalogByID: catalogByID,
            now: dayThree
        )

        progressStore.apply(
            analytics.makeProgressSnapshot(
                sessionAnalytics: sessionAnalytics,
                selectedExerciseID: nil
            ),
            completedSessions: [newerBenchSession]
        )

        progressStore.selectExercise(CatalogSeed.benchPress)
        XCTAssertEqual(progressStore.selectedExerciseSummary?.points.map(\.date), [dayTwo])

        progressStore.recordCompletedSession(
            olderBenchSession,
            completedSessions: [olderBenchSession, newerBenchSession, laterSquatSession],
            analytics: analytics,
            catalogByID: catalogByID,
            finishSummary: nil,
            payloads: analytics.sessionExercisePayloads(from: olderBenchSession)
        )

        let summary = try XCTUnwrap(progressStore.selectedExerciseSummary)
        let chartSeries = try XCTUnwrap(progressStore.selectedExerciseChartSeries)

        XCTAssertEqual(progressStore.selectedExerciseID, CatalogSeed.benchPress)
        XCTAssertEqual(summary.displayName, "Bench Press")
        XCTAssertEqual(summary.pointCount, 2)
        XCTAssertEqual(summary.points.map(\.date), [dayOne, dayTwo])
        XCTAssertEqual(chartSeries.trendPoints.map(\.date), [dayOne, dayTwo])
        XCTAssertEqual(progressStore.workoutDays.count, 3)

        progressStore.selectDay(dayOne)
        XCTAssertEqual(progressStore.historySessions.map(\.completedAt), [dayOne])
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

    func testCalendarMonthLayoutRotatesWeekdaySymbolsForMondayFirstCalendars() throws {
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

        let symbols = calendar.shortStandaloneWeekdaySymbols
        XCTAssertEqual(layout.weekdaySymbols, Array(symbols[1...]) + Array(symbols[..<1]))
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
    func testAdHocDuplicateExerciseBlockDoesNotAdvanceTemplateProgressionTwice() async throws {
        let store = makeStore()
        await store.hydrateIfNeeded()
        store.completeOnboarding(with: nil)

        var plan = store.makePlan(name: "Ad Hoc Bench")
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
                )
            ]
        )
        plan.templates = [template]
        plan.pinnedTemplateID = template.id
        store.savePlan(plan)

        store.startSession(planID: plan.id, templateID: template.id)

        let startedBlock = try XCTUnwrap(store.sessionStore.activeDraft?.blocks.first)
        for row in startedBlock.sets where row.target.setKind == .working {
            store.toggleSetCompletion(blockID: startedBlock.id, setID: row.id)
        }

        store.addExerciseToActiveSession(exerciseID: CatalogSeed.benchPress)
        let addedBlock = try XCTUnwrap(store.sessionStore.activeDraft?.blocks.last)
        let addedRow = try XCTUnwrap(addedBlock.sets.first(where: { $0.target.setKind == .working }))
        store.toggleSetCompletion(blockID: addedBlock.id, setID: addedRow.id)

        XCTAssertTrue(store.finishActiveSession())

        let updatedTemplate = try XCTUnwrap(store.plansStore.plan(for: plan.id)?.templates.first)
        XCTAssertEqual(updatedTemplate.blocks.first?.progressionRule.percentageWave?.currentWeekIndex, 1)
        XCTAssertEqual(updatedTemplate.blocks.first?.progressionRule.percentageWave?.cycle, 1)
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
    func testFinishingStrongLiftsSessionPinsTheAlternateWorkout() async throws {
        let store = makeStore()
        await store.hydrateIfNeeded()
        store.completeOnboarding(with: .strongLiftsFiveByFive)

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

    func testTemplateReferenceSelectionQuickStartsPreferRecentUniqueTemplatesThenBackfill() throws {
        let alternatingPlan = makeStartingStrengthPlan()
        let dayA = try XCTUnwrap(alternatingPlan.templates.first)
        let dayB = try XCTUnwrap(alternatingPlan.templates.last)
        let accessoryTemplate = WorkoutTemplate(
            name: "Accessory Day",
            blocks: []
        )
        let accessoryPlan = Plan(
            name: "Accessory",
            pinnedTemplateID: accessoryTemplate.id,
            templates: [accessoryTemplate]
        )
        let references = [
            makeReference(plan: alternatingPlan, template: dayA),
            makeReference(plan: alternatingPlan, template: dayB),
            makeReference(plan: accessoryPlan, template: accessoryTemplate),
        ]
        let start = Date(timeIntervalSince1970: 1_741_478_400)
        let sessions = [
            makeCompletedSession(
                planID: alternatingPlan.id,
                templateID: dayA.id,
                templateNameSnapshot: dayA.name,
                date: start
            ),
            makeCompletedSession(
                planID: alternatingPlan.id,
                templateID: dayA.id,
                templateNameSnapshot: dayA.name,
                date: start.addingTimeInterval(86_400)
            ),
            makeCompletedSession(
                planID: alternatingPlan.id,
                templateID: dayB.id,
                templateNameSnapshot: dayB.name,
                date: start.addingTimeInterval(172_800)
            ),
        ]

        let quickStarts = TemplateReferenceSelection.quickStarts(
            references: references,
            sessions: sessions,
            limit: 3
        )

        XCTAssertEqual(quickStarts.map(\.templateID), [dayB.id, dayA.id, accessoryTemplate.id])
    }
}
