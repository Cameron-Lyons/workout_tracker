import ActivityKit
import Foundation

struct WorkoutRestLiveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var endDate: Date
    }

    var sessionID: UUID
    var workoutName: String
}
