import ActivityKit
import Foundation

struct WorkoutRestLiveActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        /// Live Activities update `Text(timerInterval:countsDown:)` on the lock screen; `TimelineView` does not tick reliably there.
        var startDate: Date
        var endDate: Date
    }

    var sessionID: UUID
    var workoutName: String
}
