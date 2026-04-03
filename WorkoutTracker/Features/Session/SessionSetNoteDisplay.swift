import Foundation

/// Filters auto-generated set notes so the session UI only surfaces coaching cues (e.g. AMRAP), not scaffolding labels.
enum SessionSetNoteDisplay {
    /// Shared prefix line under the exercise title when every set agrees; omit week / warmup scaffolding only.
    static func shouldShowHoistedExerciseCaption(_ prefix: String) -> Bool {
        let trimmed = prefix.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        return !isStructuralScaffolding(trimmed)
    }

    /// Yellow caption for a single set row (`noteLine` from the parent when notes were split for hoisting).
    static func rowCaption(noteLine: String?, fullNote: String?) -> String? {
        let resolved: String?
        if let noteLine {
            let trimmed = noteLine.trimmingCharacters(in: .whitespacesAndNewlines)
            resolved = trimmed.isEmpty ? nil : trimmed
        } else if let raw = fullNote?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty {
            resolved = coachingCue(from: raw)
        } else {
            resolved = nil
        }

        guard let text = resolved?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            return nil
        }
        guard !isStructuralScaffolding(text) else {
            return nil
        }
        return text
    }

    private static func coachingCue(from fullNote: String) -> String {
        if let range = fullNote.range(of: " • ") {
            let suffix = String(fullNote[range.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !suffix.isEmpty {
                return suffix
            }
        }
        return fullNote
    }

    private static func isStructuralScaffolding(_ trimmed: String) -> Bool {
        if trimmed.caseInsensitiveCompare(WarmupDefaults.note) == .orderedSame {
            return true
        }
        if trimmed.caseInsensitiveCompare("Deload") == .orderedSame {
            return true
        }
        return trimmed.range(of: #"^Week\s+\d+$"#, options: [.regularExpression, .caseInsensitive]) != nil
    }
}
