import Foundation

enum PersonalRecordSelection {
    static func mergedNewestFirst(
        _ newRecords: [PersonalRecord],
        existingRecords: [PersonalRecord],
        limit: Int? = nil
    ) -> [PersonalRecord] {
        let mergedRecords = Array(newRecords.reversed()) + existingRecords
        var seenRecordIDs: Set<UUID> = []
        let deduplicated = mergedRecords.filter { record in
            seenRecordIDs.insert(record.id).inserted
        }

        if let limit {
            return Array(deduplicated.prefix(limit))
        }

        return deduplicated
    }
}

enum ExerciseAnalyticsSelection {
    static func selectedExerciseID(
        _ currentSelection: UUID?,
        summaries: [ExerciseAnalyticsSummary]
    ) -> UUID? {
        guard !summaries.isEmpty else {
            return nil
        }

        if let currentSelection,
            summaries.contains(where: { $0.exerciseID == currentSelection })
        {
            return currentSelection
        }

        return summaries.first?.exerciseID
    }
}
