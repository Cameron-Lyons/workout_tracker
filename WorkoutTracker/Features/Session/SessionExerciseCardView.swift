import SwiftUI

@MainActor
struct SessionExerciseCardView: View, Equatable {
    let sessionExercise: SessionExercise
    let displaySettings: ActiveSessionDisplaySettings
    let actions: ActiveSessionActions
    let showsDetailedChrome: Bool

    init(
        sessionExercise: SessionExercise,
        displaySettings: ActiveSessionDisplaySettings,
        actions: ActiveSessionActions,
        showsDetailedChrome: Bool
    ) {
        self.sessionExercise = sessionExercise
        self.displaySettings = displaySettings
        self.actions = actions
        self.showsDetailedChrome = showsDetailedChrome
    }

    nonisolated static func == (lhs: SessionExerciseCardView, rhs: SessionExerciseCardView) -> Bool {
        lhs.sessionExercise == rhs.sessionExercise
            && lhs.displaySettings == rhs.displaySettings
            && lhs.showsDetailedChrome == rhs.showsDetailedChrome
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(sessionExercise.exerciseNameSnapshot)
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(AppColors.textPrimary)

                    Text(compactExerciseSummary)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer()

                Text("\(completedSetCount)/\(sessionExercise.sets.count) done")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(completedSetCount == sessionExercise.sets.count ? AppToneStyle.success.accent : AppColors.textSecondary)
            }

            if showsDetailedChrome,
                let hoisted = hoistedSharedWaveNote,
                SessionSetNoteDisplay.shouldShowHoistedExerciseCaption(hoisted)
            {
                Text(hoisted)
                    .font(.caption)
                    .foregroundStyle(AppToneStyle.progress.accent)
            }

            if !sessionExercise.sets.isEmpty {
                HStack(alignment: .top, spacing: 18) {
                    Text("LOAD")
                        .font(.caption2.weight(.semibold))
                        .tracking(0.5)
                        .foregroundStyle(AppColors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("REPS")
                        .font(.caption2.weight(.semibold))
                        .tracking(0.5)
                        .foregroundStyle(AppColors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.bottom, 8)
                .accessibilityElement(children: .ignore)
            }

            VStack(spacing: 0) {
                ForEach(Array(sessionExercise.sets.enumerated()), id: \.element.id) { index, row in
                    let previousKind = index > 0 ? sessionExercise.sets[index - 1].target.setKind : nil
                    let showSetKindHeading = previousKind.map { $0 != row.target.setKind } ?? true
                    SessionSetRowView(
                        blockID: sessionExercise.id,
                        row: row,
                        weightUnit: displaySettings.weightUnit,
                        actions: actions,
                        showsDetailedChrome: showsDetailedChrome,
                        showsMetricColumnTitles: false,
                        noteLine: Self.noteLineParameter(for: row, hoistedPrefix: hoistedSharedWaveNote),
                        showSetKindHeading: showSetKindHeading
                    )
                    .equatable()

                    if index < sessionExercise.sets.count - 1 {
                        Rectangle()
                            .fill(AppColors.stroke.opacity(0.78))
                            .frame(height: 1)
                    }
                }
            }

            HStack(spacing: 18) {
                Button {
                    actions.addSet(sessionExercise.id)
                } label: {
                    Label("Add Set", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppToneStyle.today.accent)

                Button {
                    actions.copyLastSet(sessionExercise.id)
                } label: {
                    Label("Copy Last", systemImage: "doc.on.doc")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppToneStyle.plans.accent)

                Spacer(minLength: 0)
            }

            SessionSectionDivider()
        }
    }

    private var hoistedSharedWaveNote: String? {
        Self.hoistedSharedNotePrefix(for: sessionExercise)
    }

    private var completedSetCount: Int {
        sessionExercise.sets.reduce(0) { partialResult, row in
            partialResult + (row.log.isCompleted ? 1 : 0)
        }
    }

    private var compactExerciseSummary: String {
        var parts = ["\(sessionExercise.sets.count) sets", "\(sessionExercise.restSeconds)s rest", sessionExercise.progressionRule.kind.displayLabel]
        if let supersetGroup = sessionExercise.supersetGroup, !supersetGroup.isEmpty {
            parts.insert("Superset \(supersetGroup)", at: 2)
        }
        return parts.joined(separator: " • ")
    }

    private static func hoistedSharedNotePrefix(for sessionExercise: SessionExercise) -> String? {
        let trimmedNotes = sessionExercise.sets.compactMap { row -> String? in
            guard let raw = row.target.note?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
                return nil
            }
            return raw
        }
        guard !trimmedNotes.isEmpty else {
            return nil
        }

        let prefixes = trimmedNotes.map { note in
            if let range = note.range(of: " • ") {
                return String(note[..<range.lowerBound])
            }
            return note
        }
        guard let first = prefixes.first, prefixes.allSatisfy({ $0 == first }) else {
            return nil
        }
        return first
    }

    private static func noteLineParameter(for row: SessionSetRow, hoistedPrefix: String?) -> String? {
        guard let prefix = hoistedPrefix else {
            return nil
        }
        guard let raw = row.target.note?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return ""
        }
        if raw == prefix {
            return ""
        }
        let delimiter = " • "
        if raw.hasPrefix(prefix + delimiter) {
            let suffix = String(raw.dropFirst((prefix + delimiter).count)).trimmingCharacters(in: .whitespacesAndNewlines)
            return suffix.isEmpty ? "" : suffix
        }
        return nil
    }
}
