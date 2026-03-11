import XCTest

final class WorkoutTrackerUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testOnboardingPresetStartAndFinishWorkoutUpdatesProgress() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "--uitesting",
            "--uitesting-in-memory",
            "--uitesting-empty-store",
        ]
        app.launch()

        let presetButton = app.buttons["onboarding.preset.generalGym"]
        XCTAssertTrue(presetButton.waitForExistence(timeout: 8))
        presetButton.tap()

        let pinnedStart = app.buttons["today.pinnedStartButton"]
        XCTAssertTrue(pinnedStart.waitForExistence(timeout: 8))
        pinnedStart.tap()

        let completeSetButton = app.firstButton(withIdentifierPrefix: "session.completeSet.")
        XCTAssertTrue(completeSetButton.waitForExistence(timeout: 8))
        completeSetButton.tap()

        let finishButton = app.buttons["session.finishButton"]
        XCTAssertTrue(finishButton.waitForExistence(timeout: 8))
        finishButton.tap()

        let doneButton = app.buttons["Done"]
        XCTAssertTrue(doneButton.waitForExistence(timeout: 8))
        doneButton.tap()

        let progressTab = app.tabBars.buttons["Progress"]
        XCTAssertTrue(progressTab.waitForExistence(timeout: 4))
        progressTab.tap()

        XCTAssertTrue(app.staticTexts["1 sessions logged"].waitForExistence(timeout: 8))
    }

    @MainActor
    func testSessionCanBeClosedAndResumedFromToday() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "--uitesting",
            "--uitesting-in-memory",
            "--uitesting-empty-store",
        ]
        app.launch()

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
        let app = XCUIApplication()
        app.launchArguments += [
            "--uitesting",
            "--uitesting-in-memory",
            "--uitesting-empty-store",
        ]
        app.launch()

        let blankButton = app.buttons["onboarding.startBlank"]
        XCTAssertTrue(blankButton.waitForExistence(timeout: 8))
        blankButton.tap()

        let plansTab = app.tabBars.buttons["Plans"]
        XCTAssertTrue(plansTab.waitForExistence(timeout: 4))
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
        XCTAssertTrue(startButton.waitForExistence(timeout: 6))
        startButton.tap()

        XCTAssertTrue(app.buttons["session.finishButton"].waitForExistence(timeout: 8))
    }
}

private extension XCUIApplication {
    func firstButton(withIdentifierPrefix prefix: String) -> XCUIElement {
        buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix)).firstMatch
    }

    func revealIfNeeded(_ element: XCUIElement, maxSwipes: Int = 6) {
        var swipeCount = 0
        while !element.exists && swipeCount < maxSwipes {
            swipeUp()
            swipeCount += 1
        }
    }
}
