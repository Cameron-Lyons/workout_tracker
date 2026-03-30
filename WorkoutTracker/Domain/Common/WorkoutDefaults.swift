import Foundation

enum StrengthProgressionDefaults {
    static let gymRoundingIncrement = 2.5
    static let upperBodyIncreaseInPounds = 2.5
    static let lowerBodyIncreaseInPounds = 5.0
}

enum ExerciseBlockDefaults {
    static let restSeconds = 90
    static let setCount = 3
    static let repRange = RepRange(8, 12)
}

enum DoubleProgressionDefaults {
    static let repRange = RepRange(6, 10)
}

enum WarmupDefaults {
    static let note = "Auto warmup"
    static let ramp = [
        WarmupRampStep(percentage: 0.40, reps: 5),
        WarmupRampStep(percentage: 0.60, reps: 3),
    ]
}

enum AnalyticsDefaults {
    static let rollingWindowDays = 30
    static let recentActivityLimit = 5
    static let quickStartLimit = 4
    static let secondsPerWeek: TimeInterval = 60 * 60 * 24 * 7
    static let oneRepMaxDivisor = 30.0

    static func rollingWindowStart(from startOfToday: Date, calendar: Calendar) -> Date {
        calendar.date(byAdding: .day, value: -rollingWindowDays, to: startOfToday) ?? startOfToday
    }

    static func weeksSpan(from firstSessionDate: Date, to startOfToday: Date) -> Double {
        max(1.0, startOfToday.timeIntervalSince(firstSessionDate) / secondsPerWeek)
    }
}
