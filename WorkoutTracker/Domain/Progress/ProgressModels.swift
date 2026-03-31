import Foundation

struct TemplateReference: Identifiable, Equatable, Sendable {
    var id: UUID { templateID }
    var planID: UUID
    var planName: String
    var templateID: UUID
    var templateName: String
    var scheduledWeekdays: [Weekday]
    var lastStartedAt: Date?
}

struct ProgressPoint: Identifiable, Equatable, Sendable {
    var id: UUID
    var sessionID: UUID
    var date: Date
    var topWeight: Double
    var estimatedOneRepMax: Double
    var volume: Double

    init(
        id: UUID = UUID(),
        sessionID: UUID,
        date: Date,
        topWeight: Double,
        estimatedOneRepMax: Double,
        volume: Double
    ) {
        self.id = id
        self.sessionID = sessionID
        self.date = date
        self.topWeight = topWeight
        self.estimatedOneRepMax = estimatedOneRepMax
        self.volume = volume
    }
}

struct PersonalRecord: Identifiable, Equatable, Sendable {
    var id: UUID
    var sessionID: UUID
    var exerciseID: UUID
    var displayName: String
    var weight: Double
    var reps: Int
    var estimatedOneRepMax: Double
    var achievedAt: Date

    init(
        id: UUID = UUID(),
        sessionID: UUID,
        exerciseID: UUID,
        displayName: String,
        weight: Double,
        reps: Int,
        estimatedOneRepMax: Double,
        achievedAt: Date
    ) {
        self.id = id
        self.sessionID = sessionID
        self.exerciseID = exerciseID
        self.displayName = displayName
        self.weight = weight
        self.reps = reps
        self.estimatedOneRepMax = estimatedOneRepMax
        self.achievedAt = achievedAt
    }
}

struct ExerciseAnalyticsSummary: Identifiable, Equatable, Sendable {
    var id: UUID { exerciseID }
    var exerciseID: UUID
    var displayName: String
    var pointCount: Int
    var totalVolume: Double
    var currentPR: PersonalRecord?
    var points: [ProgressPoint]
}

struct ProgressOverview: Equatable, Sendable {
    var totalSessions: Int
    var sessionsThisWeek: Int
    var sessionsLast30Days: Int
    var totalVolume: Double
    var averageSessionsPerWeek: Double

    static let empty = ProgressOverview(
        totalSessions: 0,
        sessionsThisWeek: 0,
        sessionsLast30Days: 0,
        totalVolume: 0,
        averageSessionsPerWeek: 0
    )
}

struct SessionFinishSummary: Identifiable, Equatable, Sendable {
    var id: UUID
    var templateName: String
    var completedAt: Date
    var completedSetCount: Int
    var totalVolume: Double
    var personalRecords: [PersonalRecord]

    init(
        id: UUID = UUID(),
        templateName: String,
        completedAt: Date,
        completedSetCount: Int,
        totalVolume: Double,
        personalRecords: [PersonalRecord]
    ) {
        self.id = id
        self.templateName = templateName
        self.completedAt = completedAt
        self.completedSetCount = completedSetCount
        self.totalVolume = totalVolume
        self.personalRecords = personalRecords
    }
}
