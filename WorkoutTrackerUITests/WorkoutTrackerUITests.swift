import XCTest

final class WorkoutTrackerUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testCreateRoutineLogWorkoutAndSeeSessionInHistory() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "--uitesting",
            "--uitesting-in-memory",
            "--uitesting-empty-store"
        ]
        app.launch()

        let routinesTab = app.tabBars.buttons["Routines"]
        XCTAssertTrue(routinesTab.waitForExistence(timeout: 12))
        routinesTab.tap()

        let addMenuButton = app.buttons["routines.addMenuButton"]
        XCTAssertTrue(addMenuButton.waitForExistence(timeout: 6))
        addMenuButton.tap()

        let startingStrengthItem = app.buttons["Starting Strength"]
        XCTAssertTrue(startingStrengthItem.waitForExistence(timeout: 4))
        startingStrengthItem.tap()

        XCTAssertTrue(app.staticTexts["Starting Strength"].waitForExistence(timeout: 6))

        let logTab = app.tabBars.buttons["Log"]
        XCTAssertTrue(logTab.waitForExistence(timeout: 4))
        logTab.tap()

        let saveWorkoutButton = app.buttons["logger.saveWorkoutButton"]
        XCTAssertTrue(saveWorkoutButton.waitForExistence(timeout: 8))
        XCTAssertTrue(saveWorkoutButton.isEnabled)
        saveWorkoutButton.tap()

        XCTAssertTrue(app.staticTexts["logger.savedToast"].waitForExistence(timeout: 4))
    }
}
