import Foundation

enum WeightUnit: String, CaseIterable, Codable, Sendable {
    case pounds
    case kilograms

    static let settingsKey = "workout_tracker_weight_unit"

    private static let poundsPerKilogram = 2.2046226218
    private static let minimumRoundingIncrement = 0.000_1

    var symbol: String {
        switch self {
        case .pounds:
            return "lb"
        case .kilograms:
            return "kg"
        }
    }

    var defaultUpperBodyIncrement: Double {
        switch self {
        case .pounds:
            return StrengthProgressionDefaults.upperBodyIncreaseInPounds
        case .kilograms:
            return 1.25
        }
    }

    var defaultLowerBodyIncrement: Double {
        switch self {
        case .pounds:
            return StrengthProgressionDefaults.lowerBodyIncreaseInPounds
        case .kilograms:
            return 2.5
        }
    }

    private var defaultDisplayRoundingIncrement: Double {
        switch self {
        case .pounds:
            return StrengthProgressionDefaults.gymRoundingIncrement
        case .kilograms:
            return defaultUpperBodyIncrement
        }
    }

    func storedPounds(fromDisplayValue value: Double) -> Double {
        switch self {
        case .pounds:
            return value
        case .kilograms:
            return value * Self.poundsPerKilogram
        }
    }

    func displayValue(fromStoredPounds pounds: Double, snapToGymIncrement: Bool = true) -> Double {
        let converted: Double

        switch self {
        case .pounds:
            converted = pounds
        case .kilograms:
            converted = pounds / Self.poundsPerKilogram
        }

        if snapToGymIncrement {
            return roundedForGymDisplay(converted)
        }

        return converted
    }

    func roundedForGymDisplay(_ value: Double, increment: Double? = nil) -> Double {
        let safeIncrement = max(increment ?? defaultDisplayRoundingIncrement, Self.minimumRoundingIncrement)
        return (value / safeIncrement).rounded() * safeIncrement
    }
}

enum WeightFormatter {
    static func displayString(_ storedWeightInPounds: Double?, unit: WeightUnit = .pounds) -> String {
        guard let storedWeightInPounds else {
            return ""
        }

        return displayString(
            displayValue: unit.displayValue(fromStoredPounds: storedWeightInPounds),
            unit: unit
        )
    }

    static func displayString(displayValue value: Double, unit: WeightUnit) -> String {
        let roundedValue = unit.roundedForGymDisplay(value)

        if roundedValue.rounded() == roundedValue {
            return String(Int(roundedValue))
        }

        if (roundedValue * 10).rounded() == roundedValue * 10 {
            return String(format: "%.1f", roundedValue)
        }

        return String(format: "%.2f", roundedValue)
    }
}

enum WeightInputParser {
    static func parseDisplayValue(_ text: String, allowsZero: Bool = false) -> Double? {
        let sanitized =
            text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")

        guard !sanitized.isEmpty, let value = Double(sanitized) else {
            return nil
        }

        if allowsZero {
            return value >= 0 ? value : nil
        }

        return value > 0 ? value : nil
    }
}

enum WeightInputConversion {
    static func parseStoredPounds(
        from text: String,
        unit: WeightUnit,
        allowsZero: Bool = false
    ) -> Double? {
        guard let displayValue = WeightInputParser.parseDisplayValue(text, allowsZero: allowsZero) else {
            return nil
        }

        return unit.storedPounds(fromDisplayValue: displayValue)
    }

    static func convertedDisplayString(
        from text: String,
        oldUnit: WeightUnit,
        newUnit: WeightUnit
    ) -> String? {
        guard let oldDisplayValue = WeightInputParser.parseDisplayValue(text, allowsZero: true) else {
            return nil
        }

        let storedWeight = oldUnit.storedPounds(fromDisplayValue: oldDisplayValue)
        return WeightFormatter.displayString(storedWeight, unit: newUnit)
    }
}
