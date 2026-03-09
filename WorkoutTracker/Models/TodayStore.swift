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
        recentSessions = Array(([session] + recentSessions).prefix(5))

        if let finishSummary, !finishSummary.personalRecords.isEmpty {
            let mergedRecords = finishSummary.personalRecords.reversed() + recentPersonalRecords
            var seenRecordIDs: Set<UUID> = []
            recentPersonalRecords = mergedRecords.filter { record in
                seenRecordIDs.insert(record.id).inserted
            }
            .prefix(5)
            .map { $0 }
        }

        pinnedTemplate = resolvePinnedTemplate(from: plans, references: references, now: now)
        quickStartTemplates = resolveQuickStarts(
            references: references,
            sessions: allSessions
        )
    }

    private func resolvePinnedTemplate(
        from plans: [Plan],
        references: [TemplateReference],
        now: Date
    ) -> TemplateReference? {
        let referencesByTemplateID = Dictionary(uniqueKeysWithValues: references.map { ($0.templateID, $0) })
        let weekday = Weekday(rawValue: Calendar.autoupdatingCurrent.component(.weekday, from: now))

        if let weekday {
            if let scheduledToday = references.first(where: { $0.scheduledWeekdays.contains(weekday) }) {
                return scheduledToday
            }
        }

        for plan in plans {
            if let pinnedTemplateID = plan.pinnedTemplateID,
               let pinned = referencesByTemplateID[pinnedTemplateID] {
                return pinned
            }
        }

        return references.max(by: {
            ($0.lastStartedAt ?? .distantPast) < ($1.lastStartedAt ?? .distantPast)
        }) ?? references.first
    }

    private func resolveQuickStarts(
        references: [TemplateReference],
        sessions: [CompletedSession]
    ) -> [TemplateReference] {
        let referencesByTemplateID = Dictionary(uniqueKeysWithValues: references.map { ($0.templateID, $0) })
        let recentTemplateIDs = sessions.reversed().map(\.templateID)
        var resolved: [TemplateReference] = []
        var seenTemplateIDs: Set<UUID> = []

        for templateID in recentTemplateIDs {
            guard let match = referencesByTemplateID[templateID],
                  seenTemplateIDs.insert(match.templateID).inserted else {
                continue
            }

            resolved.append(match)
            if resolved.count == 4 {
                return resolved
            }
        }

        for reference in references where seenTemplateIDs.insert(reference.templateID).inserted {
            resolved.append(reference)
            if resolved.count == 4 {
                break
            }
        }

        return resolved
    }
}
