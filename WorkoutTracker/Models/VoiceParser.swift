import Foundation

enum VoiceParser {
    private enum Patterns {
        static let number = makeRegex("\\d+(?:\\.\\d+)?")
        static let explicitWeight = makeRegex("(\\d+(?:\\.\\d+)?)\\s*(?:lb|lbs|pounds?|kg|kgs|kilograms?)")
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

    static func parseWeightAndReps(from transcript: String) -> (weight: Double?, reps: Int?) {
        let normalized = transcript
            .lowercased()
            .replacingOccurrences(of: ",", with: ".")

        let numbers = extractNumberStrings(in: normalized)
            .compactMap(Double.init)

        var weight: Double?
        var reps: Int?

        if let explicitWeight = firstCapture(
            regex: Patterns.explicitWeight,
            in: normalized
        ) {
            weight = Double(explicitWeight)
        } else {
            weight = numbers.first
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
        } else if numbers.count >= 2 {
            reps = Int(numbers[1])
        }

        return (weight, reps)
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
