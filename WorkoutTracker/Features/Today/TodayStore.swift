import Foundation
import Observation

@MainActor
@Observable
final class TodayStore {
    var pinnedTemplate: TemplateReference?
    var quickStartTemplates: [TemplateReference] = []
    var templateReferenceCount = 0
    var sessionsLast30Days = 0
    var recentPersonalRecords: [PersonalRecord] = []
    var recentSessions: [CompletedSession] = []

    func apply(_ snapshot: AnalyticsRepository.TodaySnapshot) {
        pinnedTemplate = snapshot.pinnedTemplate
        quickStartTemplates = snapshot.quickStartTemplates
        templateReferenceCount = snapshot.templateReferenceCount
        sessionsLast30Days = snapshot.sessionsLast30Days
        recentPersonalRecords = snapshot.recentPersonalRecords
        recentSessions = snapshot.recentSessions
    }

    func recordCompletedSession(
        _ session: CompletedSession,
        planSummaries: [PlanSummary],
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

        let selection = TemplateReferenceSelection.todaySelection(
            planSummaries: planSummaries,
            references: references,
            sessions: allSessions,
            now: now
        )
        pinnedTemplate = selection.pinnedTemplate
        quickStartTemplates = selection.quickStartTemplates
        templateReferenceCount = references.count
        sessionsLast30Days = AnalyticsRepository().makeOverview(sessions: allSessions, now: now).sessionsLast30Days
    }
}
