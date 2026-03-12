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

    func testKilogramDisplayRoundingUsesOnePointTwoFiveIncrement() {
        XCTAssertEqual(WeightUnit.kilograms.roundedForGymDisplay(81.8), 81.25)
        XCTAssertEqual(WeightFormatter.displayString(displayValue: 81.3, unit: .kilograms), "81.25")
    }

    func testExerciseClassificationDetectsLowerBodyNames() {
        XCTAssertTrue(ExerciseClassification.isLowerBody("Front Squat"))
        XCTAssertTrue(ExerciseClassification.isLowerBody("Romanian Deadlift"))
        XCTAssertFalse(ExerciseClassification.isLowerBody("Bench Press"))
    }

    @MainActor
    func testActiveSessionWeightStepUsesExerciseSpecificIncrement() throws {
        let suiteName = "WeightLogicTests.ActiveSessionWeightStep.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let settings = SettingsStore(defaults: defaults)
        settings.upperBodyIncrement = 5
        settings.lowerBodyIncrement = 10

        let benchBlock = SessionBlock(
            exerciseID: CatalogSeed.benchPress,
            exerciseNameSnapshot: "Bench Press",
            restSeconds: 90,
            progressionRule: .manual,
            sets: []
        )
        let squatBlock = SessionBlock(
            exerciseID: CatalogSeed.backSquat,
            exerciseNameSnapshot: "Back Squat",
            restSeconds: 120,
            progressionRule: .manual,
            sets: []
        )

        XCTAssertEqual(ActiveSessionWeightStep.resolve(for: benchBlock, settings: settings), 5)
        XCTAssertEqual(ActiveSessionWeightStep.resolve(for: squatBlock, settings: settings), 10)
    }

    @MainActor
    func testSettingsStoreUsesKilogramDefaultsWhenWeightUnitIsKilograms() throws {
        let suiteName = "WeightLogicTests.SettingsStoreKilogramDefaults.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.set(WeightUnit.kilograms.rawValue, forKey: WeightUnit.settingsKey)
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let settings = SettingsStore(defaults: defaults)

        XCTAssertEqual(settings.weightUnit, .kilograms)
        XCTAssertEqual(settings.upperBodyIncrement, WeightUnit.kilograms.defaultUpperBodyIncrement)
        XCTAssertEqual(settings.lowerBodyIncrement, WeightUnit.kilograms.defaultLowerBodyIncrement)
    }
}
