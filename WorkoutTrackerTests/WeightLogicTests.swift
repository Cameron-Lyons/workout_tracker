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
    func testSettingsStorePreferredIncrementUsesExerciseSpecificIncrement() throws {
        let suiteName = "WeightLogicTests.SettingsStorePreferredIncrement.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        let settings = SettingsStore(defaults: defaults)
        settings.upperBodyIncrement = 5
        settings.lowerBodyIncrement = 10

        XCTAssertEqual(settings.preferredIncrement(for: "Bench Press"), 5)
        XCTAssertEqual(settings.preferredIncrement(for: "Back Squat"), 10)
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

    func testTemplateProfileResolverPreservesExistingProfileWhenTemplateLeavesOverridesBlank() {
        let existingProfile = ExerciseProfile(
            exerciseID: CatalogSeed.benchPress,
            trainingMax: 235,
            preferredIncrement: 5
        )

        let mergedProfile = TemplateProfileResolver.mergedProfile(
            existing: existingProfile,
            exerciseID: CatalogSeed.benchPress,
            trainingMax: nil,
            preferredIncrement: nil
        )

        XCTAssertEqual(mergedProfile, existingProfile)
    }

    func testTemplateExerciseSelectionResolverReplacesProfileFieldsWhenSwitchingExercises() {
        let squatProfile = ExerciseProfile(
            exerciseID: CatalogSeed.backSquat,
            trainingMax: 315,
            preferredIncrement: 10
        )

        let resolvedFields = TemplateExerciseSelectionResolver.resolvedFields(
            previousExerciseID: CatalogSeed.benchPress,
            newExerciseID: CatalogSeed.backSquat,
            currentTrainingMaxText: "235",
            currentPreferredIncrementText: "5",
            currentIncrementText: "2.5",
            progressionKind: .doubleProgression,
            existingProfile: squatProfile,
            defaultIncrement: 5,
            weightUnit: .pounds
        )

        XCTAssertEqual(
            resolvedFields,
            .init(
                trainingMaxText: "315",
                preferredIncrementText: "10",
                incrementText: "5"
            )
        )
    }

    func testTemplateExerciseSelectionResolverPreservesTypedValuesOnFirstSelection() {
        let resolvedFields = TemplateExerciseSelectionResolver.resolvedFields(
            previousExerciseID: nil,
            newExerciseID: CatalogSeed.benchPress,
            currentTrainingMaxText: "225",
            currentPreferredIncrementText: "2.5",
            currentIncrementText: "1.25",
            progressionKind: .doubleProgression,
            existingProfile: ExerciseProfile(
                exerciseID: CatalogSeed.benchPress,
                trainingMax: 235,
                preferredIncrement: 5
            ),
            defaultIncrement: 2.5,
            weightUnit: .pounds
        )

        XCTAssertEqual(
            resolvedFields,
            .init(
                trainingMaxText: "225",
                preferredIncrementText: "2.5",
                incrementText: "1.25"
            )
        )
    }
}
