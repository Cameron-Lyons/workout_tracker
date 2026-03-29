@preconcurrency import ActivityKit
import Foundation

@MainActor
final class RestTimerLiveActivityManager {
    private typealias RestTimerActivity = Activity<WorkoutRestLiveActivityAttributes>

    func sync(with draft: SessionDraft?) async {
        let existingActivities = RestTimerActivity.activities
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            await end(activities: existingActivities)
            return
        }

        guard let target = desiredActivity(from: draft) else {
            await end(activities: existingActivities)
            return
        }

        let matchingActivity = existingActivities.first(where: { $0.attributes.sessionID == target.attributes.sessionID })
        let staleActivities = existingActivities.filter { $0.attributes.sessionID != target.attributes.sessionID }
        await end(activities: staleActivities)

        if let matchingActivity {
            guard shouldUpdate(matchingActivity, with: target.content) else {
                return
            }

            await matchingActivity.update(target.content)
            return
        }

        do {
            _ = try RestTimerActivity.request(
                attributes: target.attributes,
                content: target.content,
                pushType: nil
            )
        } catch {
            PersistenceDiagnostics.record("Failed to start rest timer Live Activity", error: error)
        }
    }

    private func desiredActivity(from draft: SessionDraft?) -> (
        attributes: WorkoutRestLiveActivityAttributes,
        content: ActivityContent<WorkoutRestLiveActivityAttributes.ContentState>
    )? {
        guard let draft, let restTimerEndsAt = draft.restTimerEndsAt else {
            return nil
        }

        return (
            attributes: WorkoutRestLiveActivityAttributes(
                sessionID: draft.id,
                workoutName: draft.templateNameSnapshot
            ),
            content: ActivityContent(
                state: WorkoutRestLiveActivityAttributes.ContentState(endDate: restTimerEndsAt),
                staleDate: restTimerEndsAt
            )
        )
    }

    private func end(activities: [RestTimerActivity]) async {
        for activity in activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }

    private func shouldUpdate(
        _ activity: RestTimerActivity,
        with content: ActivityContent<WorkoutRestLiveActivityAttributes.ContentState>
    ) -> Bool {
        activity.content.state != content.state
            || activity.content.staleDate != content.staleDate
            || activity.content.relevanceScore != content.relevanceScore
    }
}
