import XCTest

@testable import WorkoutTracker

final class WeightLogicTests: XCTestCase {
    func testParseDisplayValueHandlesCommaWhitespaceAndZeroFlag() {
        XCTAssertEqual(WeightInputParser.parseDisplayValue(" 82,5 "), 82.5)
        XCTAssertNil(WeightInputParser.parseDisplayValue("0"))
        XCTAssertEqual(WeightInputParser.parseDisplayValue("0", allowsZero: true), 0)
        XCTAssertNil(WeightInputParser.parseDisplayValue("-5", allowsZero: true))
    }

    func testParseStoredPoundsConvertsFromKilograms() {
        let pounds = WeightInputConversion.parseStoredPounds(from: "100", unit: .kilograms)
        XCTAssertEqual(pounds ?? 0, 220.46226218, accuracy: 0.0000001)
    }

    func testFormatterProducesExpectedStrings() {
        XCTAssertEqual(WeightFormatter.displayString(displayValue: 100.0, unit: .pounds), "100")
        XCTAssertEqual(WeightFormatter.displayString(displayValue: 102.5, unit: .kilograms), "102.5")
        XCTAssertEqual(WeightFormatter.displayString(225.0, unit: .kilograms), "102.5")
    }

    func testConvertedDisplayStringBetweenUnits() {
        XCTAssertEqual(
            WeightInputConversion.convertedDisplayString(
                from: "225",
                oldUnit: .pounds,
                newUnit: .kilograms
            ),
            "102.5"
        )

        XCTAssertNil(
            WeightInputConversion.convertedDisplayString(
                from: "abc",
                oldUnit: .pounds,
                newUnit: .kilograms
            )
        )
    }

    func testRoundedForGymDisplayUsesExpectedIncrement() {
        XCTAssertEqual(WeightUnit.pounds.roundedForGymDisplay(226.1), 225.0)
        XCTAssertEqual(WeightUnit.pounds.roundedForGymDisplay(227.4), 227.5)
    }

    func testExerciseClassificationDetectsLowerBodyNames() {
        XCTAssertTrue(ExerciseClassification.isLowerBody("Front Squat"))
        XCTAssertTrue(ExerciseClassification.isLowerBody("Romanian Deadlift"))
        XCTAssertFalse(ExerciseClassification.isLowerBody("Bench Press"))
    }
}
