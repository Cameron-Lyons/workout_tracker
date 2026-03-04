import XCTest
@testable import WorkoutTracker

final class WeightLogicTests: XCTestCase {
    func testParseDisplayValueHandlesCommaWhitespaceAndZeroFlag() {
        XCTAssertEqual(WeightInputParser.parseDisplayValue(" 82,5 "), 82.5)
        XCTAssertNil(WeightInputParser.parseDisplayValue("0"))
        XCTAssertEqual(WeightInputParser.parseDisplayValue("0", allowsZero: true), 0)
        XCTAssertNil(WeightInputParser.parseDisplayValue("-5", allowsZero: true))
    }

    func testParseStoredPoundsConvertsFromKilograms() throws {
        let pounds = WeightInputConversion.parseStoredPounds(
            from: "100",
            unit: .kilograms
        )

        XCTAssertEqual(try XCTUnwrap(pounds), 220.46226218, accuracy: 0.0000001)
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

    func testNormalizedDisplayIncreaseAppliesFloorAndGymRounding() {
        XCTAssertEqual(WeightUnit.pounds.normalizedDisplayIncrease(0.5), 2.5)
        XCTAssertEqual(WeightUnit.pounds.normalizedDisplayIncrease(4.0), 5.0)
    }

    func testWeightUnitTransitionOnlyReturnsChangedPair() {
        var current = WeightUnit.pounds

        let changed = WeightUnitTransition.changedUnits(previous: &current, next: .kilograms)
        XCTAssertEqual(changed?.old, .pounds)
        XCTAssertEqual(changed?.new, .kilograms)

        let unchanged = WeightUnitTransition.changedUnits(previous: &current, next: .kilograms)
        XCTAssertNil(unchanged)
    }

    func testLiftClassifierDetectsLowerBodyNames() {
        XCTAssertTrue(LiftClassifier.isLowerBodyLift("Front Squat"))
        XCTAssertTrue(LiftClassifier.isLowerBodyLift("Romanian Deadlift"))
        XCTAssertFalse(LiftClassifier.isLowerBodyLift("Bench Press"))
    }
}
