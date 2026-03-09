import Foundation
import Observation

@MainActor
@Observable
final class TodayStore {
    var pinnedTemplate: TemplateReference?
    var quickStartTemplates: [TemplateReference] = []
    var recentPersonalRecords: [PersonalRecord] = []
    var recentSessions: [CompletedSession] = []

    func apply(_ snapshot: AnalyticsRepository.TodaySnapshot) {
        pinnedTemplate = snapshot.pinnedTemplate
        quickStartTemplates = snapshot.quickStartTemplates
        recentPersonalRecords = snapshot.recentPersonalRecords
        recentSessions = snapshot.recentSessions
    }

    func recordCompletedSession(
        _ session: CompletedSession,
        plans: [Plan],
        references: [TemplateReference],
        allSessions: [CompletedSession],
        finishSummary: SessionFinishSummary?,
        now: Date = .now
    ) {
        recentSessions = Array(([session] + recentSessions).prefix(AnalyticsDefaults.recentActivityLimit))

        if let finishSummary, !finishSummary.personalRecords.isEmpty {
            recentPersonalRecords = PersonalRecordSelection.mergedNewestFirst(
                finishSummary.personalRecords,
                existingRecords: recentPersonalRecords,
                limit: AnalyticsDefaults.recentActivityLimit
            )
        }

        pinnedTemplate = TemplateReferenceSelection.pinnedTemplate(
            from: plans,
            references: references,
            now: now
        )
        quickStartTemplates = TemplateReferenceSelection.quickStarts(
            references: references,
            sessions: allSessions
        )
    }
}
