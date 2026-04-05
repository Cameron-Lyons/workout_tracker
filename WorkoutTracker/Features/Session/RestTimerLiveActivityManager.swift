@preconcurrency import ActivityKit
import Foundation

@MainActor
final class RestTimerLiveActivityManager {
    private typealias RestTimerActivity = Activity<WorkoutRestLiveActivityAttributes>

    func sync(with draft: SessionDraft?) async {
        let existingActivities = RestTimerActivity.activities
        // #region agent log
        var entryData: [String: Any] = [
            "activitiesEnabled": ActivityAuthorizationInfo().areActivitiesEnabled,
            "existingActivityCount": existingActivities.count,
        ]
        if let end = draft?.restTimerEndsAt {
            entryData["draftRestEndMs"] = Int(end.timeIntervalSince1970 * 1000)
        }
        if let began = draft?.restTimerBeganAt {
            entryData["draftRestBeganMs"] = Int(began.timeIntervalSince1970 * 1000)
        }
        AgentSessionDebugLog.append(
            hypothesisId: "C",
            location: "RestTimerLiveActivityManager.swift:sync(entry)",
            message: "sync entered",
            data: entryData
        )
        // #endregion
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
                // #region agent log
                AgentSessionDebugLog.append(
                    hypothesisId: "C",
                    location: "RestTimerLiveActivityManager.swift:sync(skipUpdate)",
                    message: "shouldUpdate false",
                    data: [
                        "stateStartMs": Int(matchingActivity.content.state.startDate.timeIntervalSince1970 * 1000),
                        "stateEndMs": Int(matchingActivity.content.state.endDate.timeIntervalSince1970 * 1000),
                        "targetStartMs": Int(target.content.state.startDate.timeIntervalSince1970 * 1000),
                        "targetEndMs": Int(target.content.state.endDate.timeIntervalSince1970 * 1000),
                    ]
                )
                // #endregion
                return
            }

            // #region agent log
            AgentSessionDebugLog.append(
                hypothesisId: "C",
                location: "RestTimerLiveActivityManager.swift:sync(update)",
                message: "activity.update",
                data: [
                    "startMs": Int(target.content.state.startDate.timeIntervalSince1970 * 1000),
                    "endMs": Int(target.content.state.endDate.timeIntervalSince1970 * 1000),
                    "staleMs": Int((target.content.staleDate ?? target.content.state.endDate).timeIntervalSince1970 * 1000),
                ]
            )
            // #endregion
            await matchingActivity.update(target.content)
            return
        }

        do {
            // #region agent log
            AgentSessionDebugLog.append(
                hypothesisId: "C",
                location: "RestTimerLiveActivityManager.swift:sync(request)",
                message: "activity.request",
                data: [
                    "startMs": Int(target.content.state.startDate.timeIntervalSince1970 * 1000),
                    "endMs": Int(target.content.state.endDate.timeIntervalSince1970 * 1000),
                    "staleMs": Int((target.content.staleDate ?? target.content.state.endDate).timeIntervalSince1970 * 1000),
                ]
            )
            // #endregion
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

        let now = Date()
        let restStart: Date
        if let began = draft.restTimerBeganAt {
            restStart = began
        } else {
            let remaining = restTimerEndsAt.timeIntervalSince(now)
            if remaining > 0 {
                restStart = restTimerEndsAt.addingTimeInterval(-remaining)
            } else {
                restStart = restTimerEndsAt.addingTimeInterval(-1)
            }
        }
        let clampedStart = restStart >= restTimerEndsAt
            ? restTimerEndsAt.addingTimeInterval(-1)
            : restStart

        return (
            attributes: WorkoutRestLiveActivityAttributes(
                sessionID: draft.id,
                workoutName: draft.templateNameSnapshot
            ),
            content: ActivityContent(
                state: WorkoutRestLiveActivityAttributes.ContentState(
                    startDate: clampedStart,
                    endDate: restTimerEndsAt
                ),
                staleDate: nil
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
