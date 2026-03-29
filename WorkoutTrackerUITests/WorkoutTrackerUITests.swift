import XCTest

final class WorkoutTrackerUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launchAppForUITest(
        extraArguments: [String] = [],
        languageCode: String? = nil,
        localeIdentifier: String? = nil
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += [
            "--uitesting",
            "--uitesting-in-memory",
            "--uitesting-empty-store",
        ]

        if let languageCode {
            app.launchArguments += ["-AppleLanguages", "(\(languageCode))"]
        }

        if let localeIdentifier {
            app.launchArguments += ["-AppleLocale", localeIdentifier]
        }

        app.launchArguments += extraArguments
        app.launch()
        return app
    }

    @MainActor
    private func attachScreenshot(named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    func testFinishableSessionCanBeCompletedAndUpdatesProgress() throws {
        let app = launchAppForUITest(extraArguments: ["--uitesting-seed-finishable-session"])

        let finishButton = app.buttons["session.finishButton"]
        XCTAssertTrue(finishButton.waitForExistence(timeout: 8))
        finishButton.tap()

        let doneButton = app.buttons["Done"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 8))
        doneButton.tap()

        let progressTab = app.tabButton(named: "Progress")
        XCTAssertTrue(progressTab.waitForExistence(timeout: 4))
        progressTab.tap()

        XCTAssertTrue(app.staticTexts["1 sessions logged"].waitForExistence(timeout: 8))
    }

    @MainActor
    func testSessionCanBeClosedAndResumedFromToday() throws {
        let app = launchAppForUITest()

        app.buttons["onboarding.preset.generalGym"].tap()
        app.buttons["today.pinnedStartButton"].tap()

        let closeButton = app.buttons["Close"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 6))
        closeButton.tap()

        let resumeButton = app.buttons["today.resumeSessionButton"]
        XCTAssertTrue(resumeButton.waitForExistence(timeout: 6))
        resumeButton.tap()

        XCTAssertTrue(app.buttons["session.finishButton"].waitForExistence(timeout: 6))
    }

    @MainActor
    func testCreateCustomTemplateAndLaunchIt() throws {
        let app = launchAppForUITest(extraArguments: ["--uitesting-complete-onboarding"])

        let plansTab = app.tabButton(named: "Plans")
        XCTAssertTrue(plansTab.waitForExistence(timeout: 8))
        plansTab.tap()

        let addPlanButton = app.buttons["plans.addPlanButton"]
        XCTAssertTrue(addPlanButton.waitForExistence(timeout: 4))
        addPlanButton.tap()

        let planNameField = app.textFields["Plan name"]
        XCTAssertTrue(planNameField.waitForExistence(timeout: 4))
        planNameField.tap()
        planNameField.typeText("Custom Plan")
        app.buttons["Save"].tap()

        let addTemplateButton = app.firstButton(withIdentifierPrefix: "plans.addTemplateButton.")
        XCTAssertTrue(addTemplateButton.waitForExistence(timeout: 4))
        addTemplateButton.tap()

        let templateNameField = app.textFields["Template name"]
        XCTAssertTrue(templateNameField.waitForExistence(timeout: 4))
        templateNameField.tap()
        templateNameField.typeText("Upper Builder")

        let addBlockButton = app.buttons["plans.template.addBlockButton"]
        XCTAssertTrue(addBlockButton.waitForExistence(timeout: 4))
        addBlockButton.tap()

        let pickButton = app.buttons["plans.template.pickExerciseButton"].firstMatch
        app.revealIfNeeded(pickButton)
        XCTAssertTrue(pickButton.waitForExistence(timeout: 4))
        pickButton.tap()

        let benchOption = app.buttons["exercisePicker.item.Bench Press"]
        XCTAssertTrue(benchOption.waitForExistence(timeout: 4))
        benchOption.tap()

        let saveTemplateButton = app.buttons["plans.template.saveButton"]
        XCTAssertTrue(saveTemplateButton.waitForExistence(timeout: 4))
        saveTemplateButton.tap()

        let startButton = app.firstButton(withIdentifierPrefix: "plans.startTemplate.")
        app.revealIfNeeded(startButton)
        XCTAssertTrue(startButton.waitForExistence(timeout: 6))
        startButton.tap()

        XCTAssertTrue(app.buttons["session.finishButton"].waitForExistence(timeout: 8))
    }

    @MainActor
    func testFinishButtonRequiresCompletedWorkingSet() throws {
        let app = launchAppForUITest()

        let presetButton = app.buttons["onboarding.preset.generalGym"]
        XCTAssertTrue(presetButton.waitForExistence(timeout: 8))
        presetButton.tap()

        let pinnedStart = app.buttons["today.pinnedStartButton"]
        XCTAssertTrue(pinnedStart.waitForExistence(timeout: 8))
        pinnedStart.tap()
        app.swipeUp()

        let finishButton = app.buttons["session.finishButton"]
        XCTAssertTrue(finishButton.waitForExistence(timeout: 8))
        XCTAssertFalse(finishButton.isEnabled)
        app.terminate()

        let finishableApp = launchAppForUITest(extraArguments: ["--uitesting-seed-finishable-session"])
        let seededFinishButton = finishableApp.buttons["session.finishButton"]
        XCTAssertTrue(seededFinishButton.waitForExistence(timeout: 8))
        XCTAssertTrue(seededFinishButton.isEnabled)
    }

    @MainActor
    func testCreateCustomExerciseTemplateAndSaveIt() throws {
        let app = launchAppForUITest(extraArguments: ["--uitesting-complete-onboarding"])

        let plansTab = app.tabButton(named: "Plans")
        XCTAssertTrue(plansTab.waitForExistence(timeout: 8))
        plansTab.tap()

        let addPlanButton = app.buttons["plans.addPlanButton"]
        XCTAssertTrue(addPlanButton.waitForExistence(timeout: 4))
        addPlanButton.tap()

        let planNameField = app.textFields["Plan name"]
        XCTAssertTrue(planNameField.waitForExistence(timeout: 4))
        planNameField.tap()
        planNameField.typeText("Custom Exercise Plan")
        app.buttons["Save"].tap()

        let addTemplateButton = app.firstButton(withIdentifierPrefix: "plans.addTemplateButton.")
        XCTAssertTrue(addTemplateButton.waitForExistence(timeout: 4))
        addTemplateButton.tap()

        let templateNameField = app.textFields["Template name"]
        XCTAssertTrue(templateNameField.waitForExistence(timeout: 4))
        templateNameField.tap()
        templateNameField.typeText("Cable Builder")

        let addBlockButton = app.buttons["plans.template.addBlockButton"]
        XCTAssertTrue(addBlockButton.waitForExistence(timeout: 4))
        addBlockButton.tap()

        let pickButton = app.buttons["plans.template.pickExerciseButton"].firstMatch
        app.revealIfNeeded(pickButton)
        XCTAssertTrue(pickButton.waitForExistence(timeout: 4))
        pickButton.tap()

        let createCustomButton = app.buttons["Create Custom Exercise"]
        XCTAssertTrue(createCustomButton.waitForExistence(timeout: 4))
        XCTAssertFalse(createCustomButton.isEnabled)

        let customExerciseField = app.textFields["New custom exercise"]
        XCTAssertTrue(customExerciseField.waitForExistence(timeout: 4))
        customExerciseField.tap()
        customExerciseField.typeText("Cable Fly Variation")

        XCTAssertTrue(createCustomButton.isEnabled)
        createCustomButton.tap()

        let saveTemplateButton = app.buttons["plans.template.saveButton"]
        XCTAssertTrue(saveTemplateButton.waitForExistence(timeout: 4))
        saveTemplateButton.tap()

        XCTAssertTrue(app.buttons["plans.addPlanButton"].waitForExistence(timeout: 6))
    }

    @MainActor
    func testPinnedTemplateAccessibilityLabelUpdates() throws {
        let app = launchAppForUITest()

        let presetButton = app.buttons["onboarding.preset.generalGym"]
        XCTAssertTrue(presetButton.waitForExistence(timeout: 8))
        presetButton.tap()

        let plansTab = app.tabButton(named: "Plans")
        XCTAssertTrue(plansTab.waitForExistence(timeout: 8))
        plansTab.tap()

        let pinButtons = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", "plans.pinTemplate."))
        XCTAssertGreaterThanOrEqual(pinButtons.count, 2)

        let pinnedButton = try XCTUnwrap(pinButtons.allElementsBoundByIndex.first(where: { $0.label == "Pinned to Today" }))
        let unpinnedButton = try XCTUnwrap(pinButtons.allElementsBoundByIndex.first(where: { $0.label == "Pin to Today" }))
        let updatedButtonIdentifier = unpinnedButton.identifier

        attachScreenshot(named: "accessibility-plans-before-repin")
        unpinnedButton.tap()

        let updatedButton = app.buttons[updatedButtonIdentifier]
        XCTAssertTrue(updatedButton.waitForExistence(timeout: 4))
        XCTAssertEqual(updatedButton.label, "Pinned to Today")
        XCTAssertNotEqual(pinnedButton.identifier, updatedButtonIdentifier)
    }

    @MainActor
    func testLayoutSmokeEmptyStatesAcrossDeviceClasses() throws {
        let app = launchAppForUITest(extraArguments: ["--uitesting-complete-onboarding"])

        let todayTab = app.tabButton(named: "Today")
        XCTAssertTrue(todayTab.waitForExistence(timeout: 8))
        todayTab.tap()
        XCTAssertTrue(app.staticTexts["Start from a plan"].waitForExistence(timeout: 8))
        attachScreenshot(named: "layout-empty-today")

        let plansTab = app.tabButton(named: "Plans")
        XCTAssertTrue(plansTab.waitForExistence(timeout: 4))
        plansTab.tap()
        XCTAssertTrue(app.staticTexts["No plans yet"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["plans.addPlanButton"].waitForExistence(timeout: 4))
        attachScreenshot(named: "layout-empty-plans")

        let progressTab = app.tabButton(named: "Progress")
        XCTAssertTrue(progressTab.waitForExistence(timeout: 4))
        progressTab.tap()
        XCTAssertTrue(app.staticTexts["No progress yet"].waitForExistence(timeout: 8))
        attachScreenshot(named: "layout-empty-progress")
    }

    @MainActor
    func testLayoutSmokeSeededSessionFlowAcrossDeviceClasses() throws {
        let app = launchAppForUITest()

        let presetButton = app.buttons["onboarding.preset.generalGym"]
        XCTAssertTrue(presetButton.waitForExistence(timeout: 8))
        presetButton.tap()

        let todayTab = app.tabButton(named: "Today")
        XCTAssertTrue(todayTab.waitForExistence(timeout: 8))
        todayTab.tap()

        let pinnedStart = app.buttons["today.pinnedStartButton"]
        XCTAssertTrue(pinnedStart.waitForExistence(timeout: 8))
        pinnedStart.tap()
        app.swipeUp()

        let completeSetButton = app.firstButton(withIdentifierPrefix: "session.completeSet.")
        app.revealIfNeeded(completeSetButton)
        XCTAssertTrue(completeSetButton.waitForExistence(timeout: 8))

        let finishButton = app.buttons["session.finishButton"]
        XCTAssertTrue(finishButton.waitForExistence(timeout: 8))
        attachScreenshot(named: "layout-active-session")

        let closeButton = app.buttons["Close"]
        XCTAssertTrue(closeButton.waitForExistence(timeout: 8))
        closeButton.tap()

        let resumeButton = app.buttons["today.resumeSessionButton"]
        XCTAssertTrue(resumeButton.waitForExistence(timeout: 8))
        attachScreenshot(named: "layout-resume-session")
    }

    @MainActor
    func testSpanishLocaleSessionSmokeUsesStableIdentifiers() throws {
        let app = launchAppForUITest(languageCode: "es", localeIdentifier: "es_ES")

        let presetButton = app.buttons["onboarding.preset.generalGym"]
        XCTAssertTrue(presetButton.waitForExistence(timeout: 8))
        presetButton.tap()

        let pinnedStart = app.buttons["today.pinnedStartButton"]
        XCTAssertTrue(pinnedStart.waitForExistence(timeout: 8))
        attachScreenshot(named: "locale-es-today")
        pinnedStart.tap()
        app.swipeUp()

        let finishButton = app.buttons["session.finishButton"]
        XCTAssertTrue(finishButton.waitForExistence(timeout: 8))
        let completeSetButton = app.firstButton(withIdentifierPrefix: "session.completeSet.")
        app.revealIfNeeded(completeSetButton)
        XCTAssertTrue(completeSetButton.waitForExistence(timeout: 8))
        attachScreenshot(named: "locale-es-session")
    }

    @MainActor
    func testProfileLoggerHotPath() throws {
        let app = launchAppForUITest()

        let presetButton = app.buttons["onboarding.preset.generalGym"]
        XCTAssertTrue(presetButton.waitForExistence(timeout: 8))
        presetButton.tap()

        let pinnedStart = app.buttons["today.pinnedStartButton"]
        XCTAssertTrue(pinnedStart.waitForExistence(timeout: 8))
        pinnedStart.tap()
        app.swipeUp()

        let loadIncreaseButton = app.firstButton(
            withIdentifierPrefix: "session.adjust.load.",
            suffix: ".increase"
        )
        app.revealIfNeeded(loadIncreaseButton)
        XCTAssertTrue(loadIncreaseButton.waitForExistence(timeout: 8))
        for _ in 0..<8 {
            loadIncreaseButton.tap()
        }

        let repsIncreaseButton = app.firstButton(
            withIdentifierPrefix: "session.adjust.reps.",
            suffix: ".increase"
        )
        app.revealIfNeeded(repsIncreaseButton)
        XCTAssertTrue(repsIncreaseButton.waitForExistence(timeout: 4))
        for _ in 0..<4 {
            repsIncreaseButton.tap()
        }

        let addSetButton = app.buttons["Add Set"].firstMatch
        XCTAssertTrue(addSetButton.waitForExistence(timeout: 4))
        addSetButton.tap()

        let copyLastButton = app.buttons["Copy Last"].firstMatch
        XCTAssertTrue(copyLastButton.waitForExistence(timeout: 4))
        copyLastButton.tap()

        let undoButton = app.buttons["Undo"]
        XCTAssertTrue(undoButton.waitForExistence(timeout: 4))
        undoButton.tap()
        undoButton.tap()
        undoButton.tap()

        XCTAssertTrue(app.buttons["session.finishButton"].waitForExistence(timeout: 4))
    }

    @MainActor
    func testProfileForegroundRefreshNoOp() throws {
        let app = launchAppForUITest()

        let presetButton = app.buttons["onboarding.preset.generalGym"]
        XCTAssertTrue(presetButton.waitForExistence(timeout: 8))
        presetButton.tap()

        let todayTab = app.tabButton(named: "Today")
        XCTAssertTrue(todayTab.waitForExistence(timeout: 4))
        todayTab.tap()

        for _ in 0..<3 {
            XCUIDevice.shared.press(.home)
            app.activate()
            XCTAssertTrue(todayTab.waitForExistence(timeout: 6))
        }

        XCTAssertTrue(app.buttons["today.pinnedStartButton"].waitForExistence(timeout: 6))
    }
}

private extension XCUIApplication {
    func tabButton(named label: String) -> XCUIElement {
        buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch
    }

    func firstButton(withIdentifierPrefix prefix: String) -> XCUIElement {
        descendants(matching: .any)
            .matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix))
            .firstMatch
    }

    func firstButton(withIdentifierPrefix prefix: String, suffix: String) -> XCUIElement {
        descendants(matching: .any)
            .matching(
                NSPredicate(
                    format: "identifier BEGINSWITH %@ AND identifier ENDSWITH %@",
                    prefix,
                    suffix
                )
            )
            .firstMatch
    }

    func revealIfNeeded(_ element: XCUIElement, maxSwipes: Int = 6) {
        var swipeCount = 0
        while (!element.exists || !element.isHittable) && swipeCount < maxSwipes {
            swipeUp()
            swipeCount += 1
        }
    }
}
