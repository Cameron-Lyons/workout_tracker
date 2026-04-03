import Foundation

enum TemplateReferenceSelection {
    private struct Lookup {
        var referencesByTemplateID: [UUID: TemplateReference]
        var recentTemplateIDs: [UUID]
        var lastCompletedTemplateIDByPlan: [UUID: UUID]

        init(references: [TemplateReference], sessions: [CompletedSession]) {
            referencesByTemplateID = Dictionary(uniqueKeysWithValues: references.map { ($0.templateID, $0) })
            recentTemplateIDs = []
            recentTemplateIDs.reserveCapacity(min(sessions.count, AnalyticsDefaults.quickStartLimit))
            lastCompletedTemplateIDByPlan = [:]
            lastCompletedTemplateIDByPlan.reserveCapacity(min(sessions.count, references.count))
            let trackedPlanIDs = Set(references.map(\.planID))
            var unresolvedPlanIDs = trackedPlanIDs
            var seenRecentTemplateIDs: Set<UUID> = []
            seenRecentTemplateIDs.reserveCapacity(min(sessions.count, AnalyticsDefaults.quickStartLimit))
            let recentTemplateLimit = min(AnalyticsDefaults.quickStartLimit, referencesByTemplateID.count)

            for session in sessions.reversed() {
                if recentTemplateIDs.count < recentTemplateLimit,
                    referencesByTemplateID[session.templateID] != nil,
                    seenRecentTemplateIDs.insert(session.templateID).inserted
                {
                    recentTemplateIDs.append(session.templateID)
                }

                guard let planID = session.planID,
                    unresolvedPlanIDs.contains(planID)
                else {
                    if recentTemplateIDs.count == recentTemplateLimit,
                        unresolvedPlanIDs.isEmpty
                    {
                        break
                    }

                    continue
                }

                lastCompletedTemplateIDByPlan[planID] = session.templateID
                unresolvedPlanIDs.remove(planID)

                if recentTemplateIDs.count == recentTemplateLimit,
                    unresolvedPlanIDs.isEmpty
                {
                    break
                }
            }
        }
    }

    static func todaySelection(
        plans: [Plan],
        references: [TemplateReference],
        sessions: [CompletedSession],
        now: Date,
        limit: Int = AnalyticsDefaults.quickStartLimit,
        calendar: Calendar = .autoupdatingCurrent
    ) -> (pinnedTemplate: TemplateReference?, quickStartTemplates: [TemplateReference]) {
        let lookup = Lookup(references: references, sessions: sessions)
        return (
            pinnedTemplate: pinnedTemplate(from: plans, references: references, lookup: lookup, now: now, calendar: calendar),
            quickStartTemplates: quickStarts(references: references, lookup: lookup, limit: limit)
        )
    }

    static func pinnedTemplate(
        from plans: [Plan],
        references: [TemplateReference],
        sessions: [CompletedSession] = [],
        now: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> TemplateReference? {
        pinnedTemplate(
            from: plans,
            references: references,
            lookup: Lookup(references: references, sessions: sessions),
            now: now,
            calendar: calendar
        )
    }

    static func todaySelection(
        planSummaries: [PlanSummary],
        references: [TemplateReference],
        sessions: [CompletedSession],
        now: Date,
        limit: Int = AnalyticsDefaults.quickStartLimit,
        calendar: Calendar = .autoupdatingCurrent
    ) -> (pinnedTemplate: TemplateReference?, quickStartTemplates: [TemplateReference]) {
        let lookup = Lookup(references: references, sessions: sessions)
        return (
            pinnedTemplate: pinnedTemplate(
                from: planSummaries,
                references: references,
                lookup: lookup,
                now: now,
                calendar: calendar
            ),
            quickStartTemplates: quickStarts(references: references, lookup: lookup, limit: limit)
        )
    }

    static func pinnedTemplate(
        from planSummaries: [PlanSummary],
        references: [TemplateReference],
        sessions: [CompletedSession] = [],
        now: Date,
        calendar: Calendar = .autoupdatingCurrent
    ) -> TemplateReference? {
        pinnedTemplate(
            from: planSummaries,
            references: references,
            lookup: Lookup(references: references, sessions: sessions),
            now: now,
            calendar: calendar
        )
    }

    static func isAlternatingPlan(_ plan: Plan?) -> Bool {
        guard let plan else {
            return false
        }

        return alternatingTemplatePair(in: plan) != nil
    }

    static func isAlternatingPlan(_ plan: PlanSummary?) -> Bool {
        guard let plan else {
            return false
        }

        return alternatingTemplatePair(in: plan) != nil
    }

    static func nextAlternatingTemplateID(in plan: Plan, after completedTemplateID: UUID) -> UUID? {
        guard let pair = alternatingTemplatePair(in: plan) else {
            return nil
        }

        switch completedTemplateID {
        case pair.dayA.id:
            return pair.dayB.id
        case pair.dayB.id:
            return pair.dayA.id
        default:
            return nil
        }
    }

    static func quickStarts(
        references: [TemplateReference],
        sessions: [CompletedSession],
        limit: Int = AnalyticsDefaults.quickStartLimit
    ) -> [TemplateReference] {
        quickStarts(
            references: references,
            lookup: Lookup(references: references, sessions: sessions),
            limit: limit
        )
    }

    private static func pinnedTemplate(
        from plans: [Plan],
        references: [TemplateReference],
        lookup: Lookup,
        now: Date,
        calendar: Calendar
    ) -> TemplateReference? {
        let weekday = Weekday(rawValue: calendar.component(.weekday, from: now))

        for plan in plans {
            if let scheduledToday = scheduledTemplate(
                for: plan,
                lookup: lookup,
                weekday: weekday
            ) {
                return scheduledToday
            }
        }

        for plan in plans {
            if let pinned = preferredPinnedTemplate(
                for: plan,
                lookup: lookup
            ) {
                return pinned
            }
        }

        return references.max(by: {
            ($0.lastStartedAt ?? .distantPast) < ($1.lastStartedAt ?? .distantPast)
        }) ?? references.first
    }

    private static func pinnedTemplate(
        from planSummaries: [PlanSummary],
        references: [TemplateReference],
        lookup: Lookup,
        now: Date,
        calendar: Calendar
    ) -> TemplateReference? {
        let weekday = Weekday(rawValue: calendar.component(.weekday, from: now))

        for plan in planSummaries {
            if let scheduledToday = scheduledTemplate(
                for: plan,
                lookup: lookup,
                weekday: weekday
            ) {
                return scheduledToday
            }
        }

        for plan in planSummaries {
            if let pinned = preferredPinnedTemplate(
                for: plan,
                lookup: lookup
            ) {
                return pinned
            }
        }

        return references.max(by: {
            ($0.lastStartedAt ?? .distantPast) < ($1.lastStartedAt ?? .distantPast)
        }) ?? references.first
    }

    private static func quickStarts(
        references: [TemplateReference],
        lookup: Lookup,
        limit: Int
    ) -> [TemplateReference] {
        var resolved: [TemplateReference] = []
        var seenTemplateIDs: Set<UUID> = []

        for templateID in lookup.recentTemplateIDs {
            guard let match = lookup.referencesByTemplateID[templateID],
                seenTemplateIDs.insert(match.templateID).inserted
            else {
                continue
            }

            resolved.append(match)
            if resolved.count == limit {
                return resolved
            }
        }

        for reference in references where seenTemplateIDs.insert(reference.templateID).inserted {
            resolved.append(reference)
            if resolved.count == limit {
                break
            }
        }

        return resolved
    }

    private static func scheduledTemplate(
        for plan: Plan,
        lookup: Lookup,
        weekday: Weekday?
    ) -> TemplateReference? {
        guard let weekday else {
            return nil
        }

        if isAlternatingPlan(plan) {
            guard plan.templates.contains(where: { $0.scheduledWeekdays.contains(weekday) }) else {
                return nil
            }

            guard let templateID = nextAlternatingTemplateID(in: plan, lookup: lookup) else {
                return nil
            }

            return lookup.referencesByTemplateID[templateID]
        }

        guard let template = plan.templates.first(where: { $0.scheduledWeekdays.contains(weekday) }) else {
            return nil
        }

        return lookup.referencesByTemplateID[template.id]
    }

    private static func scheduledTemplate(
        for plan: PlanSummary,
        lookup: Lookup,
        weekday: Weekday?
    ) -> TemplateReference? {
        guard let weekday else {
            return nil
        }

        if isAlternatingPlan(plan) {
            guard plan.templates.contains(where: { $0.scheduledWeekdays.contains(weekday) }) else {
                return nil
            }

            guard let templateID = nextAlternatingTemplateID(in: plan, lookup: lookup) else {
                return nil
            }

            return lookup.referencesByTemplateID[templateID]
        }

        guard let template = plan.templates.first(where: { $0.scheduledWeekdays.contains(weekday) }) else {
            return nil
        }

        return lookup.referencesByTemplateID[template.id]
    }

    private static func preferredPinnedTemplate(
        for plan: Plan,
        lookup: Lookup
    ) -> TemplateReference? {
        if let templateID = nextAlternatingTemplateID(in: plan, lookup: lookup) {
            return lookup.referencesByTemplateID[templateID]
        }

        guard let pinnedTemplateID = plan.pinnedTemplateID else {
            return nil
        }

        return lookup.referencesByTemplateID[pinnedTemplateID]
    }

    private static func preferredPinnedTemplate(
        for plan: PlanSummary,
        lookup: Lookup
    ) -> TemplateReference? {
        if let templateID = nextAlternatingTemplateID(in: plan, lookup: lookup) {
            return lookup.referencesByTemplateID[templateID]
        }

        guard let pinnedTemplateID = plan.pinnedTemplateID else {
            return nil
        }

        return lookup.referencesByTemplateID[pinnedTemplateID]
    }

    private static func nextAlternatingTemplateID(in plan: Plan, lookup: Lookup) -> UUID? {
        nextAlternatingTemplateID(in: plan, lastCompletedTemplateID: lookup.lastCompletedTemplateIDByPlan[plan.id])
    }

    private static func nextAlternatingTemplateID(in plan: PlanSummary, lookup: Lookup) -> UUID? {
        nextAlternatingTemplateID(in: plan, lastCompletedTemplateID: lookup.lastCompletedTemplateIDByPlan[plan.id])
    }

    private static func nextAlternatingTemplateID(in plan: Plan, lastCompletedTemplateID: UUID?) -> UUID? {
        guard let pair = alternatingTemplatePair(in: plan) else {
            return nil
        }

        switch lastCompletedTemplateID {
        case pair.dayA.id:
            return pair.dayB.id
        case pair.dayB.id:
            return pair.dayA.id
        default:
            if let pinnedTemplateID = plan.pinnedTemplateID,
                pinnedTemplateID == pair.dayA.id || pinnedTemplateID == pair.dayB.id
            {
                return pinnedTemplateID
            }

            return pair.dayA.id
        }
    }

    private static func nextAlternatingTemplateID(in plan: PlanSummary, lastCompletedTemplateID: UUID?) -> UUID? {
        guard let pair = alternatingTemplatePair(in: plan) else {
            return nil
        }

        switch lastCompletedTemplateID {
        case pair.dayA.id:
            return pair.dayB.id
        case pair.dayB.id:
            return pair.dayA.id
        default:
            if let pinnedTemplateID = plan.pinnedTemplateID,
                pinnedTemplateID == pair.dayA.id || pinnedTemplateID == pair.dayB.id
            {
                return pinnedTemplateID
            }

            return pair.dayA.id
        }
    }

    private static func alternatingTemplatePair(in plan: Plan) -> (dayA: WorkoutTemplate, dayB: WorkoutTemplate)? {
        guard plan.templates.count == 2 else {
            return nil
        }

        guard let dayA = plan.templates.first(where: isAlternatingDayA),
            let dayB = plan.templates.first(where: isAlternatingDayB)
        else {
            return nil
        }

        return (dayA, dayB)
    }

    private static func alternatingTemplatePair(in plan: PlanSummary) -> (dayA: TemplateSummary, dayB: TemplateSummary)? {
        guard plan.templates.count == 2 else {
            return nil
        }

        guard let dayA = plan.templates.first(where: isAlternatingDayA),
            let dayB = plan.templates.first(where: isAlternatingDayB)
        else {
            return nil
        }

        return (dayA, dayB)
    }

    private static func isAlternatingDayA(_ template: WorkoutTemplate) -> Bool {
        isStartingStrengthStyleDayA(template) || isClassicLinearProgressionDayA(template)
    }

    private static func isAlternatingDayB(_ template: WorkoutTemplate) -> Bool {
        isStartingStrengthStyleDayB(template) || isClassicLinearProgressionDayB(template)
    }

    private static func isStartingStrengthStyleDayA(_ template: WorkoutTemplate) -> Bool {
        let exerciseIDs = Set(template.exercises.map(\.exerciseID))
        let requiredExerciseIDs: Set<UUID> = [CatalogSeed.backSquat, CatalogSeed.benchPress, CatalogSeed.deadlift]
        return requiredExerciseIDs.isSubset(of: exerciseIDs)
    }

    private static func isStartingStrengthStyleDayB(_ template: WorkoutTemplate) -> Bool {
        let exerciseIDs = Set(template.exercises.map(\.exerciseID))
        let requiredExerciseIDs: Set<UUID> = [CatalogSeed.backSquat, CatalogSeed.overheadPress, CatalogSeed.powerClean]
        return requiredExerciseIDs.isSubset(of: exerciseIDs)
    }

    private static func isClassicLinearProgressionDayA(_ template: WorkoutTemplate) -> Bool {
        let exerciseIDs = Set(template.exercises.map(\.exerciseID))
        let requiredExerciseIDs: Set<UUID> = [CatalogSeed.backSquat, CatalogSeed.benchPress, CatalogSeed.barbellRow]
        return requiredExerciseIDs.isSubset(of: exerciseIDs)
    }

    private static func isClassicLinearProgressionDayB(_ template: WorkoutTemplate) -> Bool {
        let exerciseIDs = Set(template.exercises.map(\.exerciseID))
        let requiredExerciseIDs: Set<UUID> = [CatalogSeed.backSquat, CatalogSeed.overheadPress, CatalogSeed.deadlift]
        return requiredExerciseIDs.isSubset(of: exerciseIDs)
    }

    private static func isAlternatingDayA(_ template: TemplateSummary) -> Bool {
        isStartingStrengthStyleDayA(template) || isClassicLinearProgressionDayA(template)
    }

    private static func isAlternatingDayB(_ template: TemplateSummary) -> Bool {
        isStartingStrengthStyleDayB(template) || isClassicLinearProgressionDayB(template)
    }

    private static func isStartingStrengthStyleDayA(_ template: TemplateSummary) -> Bool {
        let exerciseIDs = Set(template.exerciseIDs)
        let requiredExerciseIDs: Set<UUID> = [CatalogSeed.backSquat, CatalogSeed.benchPress, CatalogSeed.deadlift]
        return requiredExerciseIDs.isSubset(of: exerciseIDs)
    }

    private static func isStartingStrengthStyleDayB(_ template: TemplateSummary) -> Bool {
        let exerciseIDs = Set(template.exerciseIDs)
        let requiredExerciseIDs: Set<UUID> = [CatalogSeed.backSquat, CatalogSeed.overheadPress, CatalogSeed.powerClean]
        return requiredExerciseIDs.isSubset(of: exerciseIDs)
    }

    private static func isClassicLinearProgressionDayA(_ template: TemplateSummary) -> Bool {
        let exerciseIDs = Set(template.exerciseIDs)
        let requiredExerciseIDs: Set<UUID> = [CatalogSeed.backSquat, CatalogSeed.benchPress, CatalogSeed.barbellRow]
        return requiredExerciseIDs.isSubset(of: exerciseIDs)
    }

    private static func isClassicLinearProgressionDayB(_ template: TemplateSummary) -> Bool {
        let exerciseIDs = Set(template.exerciseIDs)
        let requiredExerciseIDs: Set<UUID> = [CatalogSeed.backSquat, CatalogSeed.overheadPress, CatalogSeed.deadlift]
        return requiredExerciseIDs.isSubset(of: exerciseIDs)
    }
}
