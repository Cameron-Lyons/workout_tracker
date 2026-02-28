import Foundation

enum VoiceParser {
    struct ParsedWeight {
        var value: Double
        var unit: WeightUnit?
    }

    private enum Patterns {
        static let number = makeRegex("\\d+(?:\\.\\d+)?")
        static let explicitWeight = makeRegex("(\\d+(?:\\.\\d+)?)\\s*(lb|lbs|pounds?|kg|kgs|kilograms?)")
        static let explicitRepsPrefix = makeRegex("(?:for|x|times?|reps?)\\s*(\\d+)")
        static let explicitRepsSuffix = makeRegex("(\\d+)\\s*(?:reps?|times?)")

        private static func makeRegex(_ pattern: String) -> NSRegularExpression {
            // These patterns are static and validated at startup.
            guard let regex = try? NSRegularExpression(pattern: pattern) else {
                preconditionFailure("Invalid regex pattern: \(pattern)")
            }
            return regex
        }
    }

    static func parseWeightAndReps(from transcript: String) -> (weight: ParsedWeight?, reps: Int?) {
        let normalized = transcript
            .lowercased()
            .replacingOccurrences(of: ",", with: ".")

        var weight: ParsedWeight?
        var reps: Int?

        if let explicit = explicitWeight(in: normalized) {
            weight = explicit
        }

        if let explicitReps = firstCapture(
            regex: Patterns.explicitRepsPrefix,
            in: normalized
        ) {
            reps = Int(explicitReps)
        } else if let suffixReps = firstCapture(
            regex: Patterns.explicitRepsSuffix,
            in: normalized
        ) {
            reps = Int(suffixReps)
        }

        if weight == nil || reps == nil {
            let numbers = extractNumberStrings(in: normalized)
                .compactMap(Double.init)

            if weight == nil {
                if let first = numbers.first {
                    weight = ParsedWeight(value: first, unit: nil)
                }
            }

            if reps == nil, numbers.count >= 2 {
                reps = Int(numbers[1])
            }
        }

        return (weight, reps)
    }

    private static func explicitWeight(in text: String) -> ParsedWeight? {
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = Patterns.explicitWeight.firstMatch(in: text, range: nsRange),
              let valueRange = Range(match.range(at: 1), in: text),
              let unitRange = Range(match.range(at: 2), in: text),
              let value = Double(text[valueRange]) else {
            return nil
        }

        let unitToken = String(text[unitRange])
        let unit: WeightUnit?
        if unitToken.hasPrefix("kg") || unitToken.hasPrefix("kilogram") {
            unit = .kilograms
        } else if unitToken.hasPrefix("lb") || unitToken.hasPrefix("pound") {
            unit = .pounds
        } else {
            unit = nil
        }

        return ParsedWeight(value: value, unit: unit)
    }

    private static func extractNumberStrings(in text: String) -> [String] {
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)

        return Patterns.number.matches(in: text, range: nsRange).compactMap { match in
            guard let range = Range(match.range, in: text) else { return nil }
            return String(text[range])
        }
    }

    private static func firstCapture(regex: NSRegularExpression, in text: String) -> String? {
        let nsRange = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: nsRange),
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }

        return String(text[range])
    }
}
