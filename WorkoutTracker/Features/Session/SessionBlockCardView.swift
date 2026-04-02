import SwiftUI

@MainActor
struct SessionBlockCardView: View, Equatable {
    let block: SessionBlock
    let displaySettings: ActiveSessionDisplaySettings
    let actions: ActiveSessionActions
    let showsDetailedChrome: Bool

    init(
        block: SessionBlock,
        displaySettings: ActiveSessionDisplaySettings,
        actions: ActiveSessionActions,
        showsDetailedChrome: Bool
    ) {
        self.block = block
        self.displaySettings = displaySettings
        self.actions = actions
        self.showsDetailedChrome = showsDetailedChrome
    }

    nonisolated static func == (lhs: SessionBlockCardView, rhs: SessionBlockCardView) -> Bool {
        lhs.block == rhs.block
            && lhs.displaySettings == rhs.displaySettings
            && lhs.showsDetailedChrome == rhs.showsDetailedChrome
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(block.exerciseNameSnapshot)
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(AppColors.textPrimary)

                    Text(compactBlockSummary)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer()

                Text("\(completedSetCount)/\(block.sets.count) done")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(completedSetCount == block.sets.count ? AppToneStyle.success.accent : AppColors.textSecondary)
            }

            if showsDetailedChrome, let hoisted = hoistedSharedWaveNote {
                Text(hoisted)
                    .font(.caption)
                    .foregroundStyle(AppToneStyle.progress.accent)
            }

            if !block.sets.isEmpty {
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
                ForEach(Array(block.sets.enumerated()), id: \.element.id) { index, row in
                    SessionSetRowView(
                        blockID: block.id,
                        row: row,
                        weightUnit: displaySettings.weightUnit,
                        actions: actions,
                        showsDetailedChrome: showsDetailedChrome,
                        showsMetricColumnTitles: false,
                        noteLine: Self.noteLineParameter(for: row, hoistedPrefix: hoistedSharedWaveNote)
                    )
                    .equatable()

                    if index < block.sets.count - 1 {
                        Rectangle()
                            .fill(AppColors.stroke.opacity(0.78))
                            .frame(height: 1)
                    }
                }
            }

            HStack(spacing: 18) {
                Button {
                    actions.addSet(block.id)
                } label: {
                    Label("Add Set", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppToneStyle.today.accent)

                Button {
                    actions.copyLastSet(block.id)
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
        Self.hoistedSharedNotePrefix(for: block)
    }

    private var completedSetCount: Int {
        block.sets.reduce(0) { partialResult, row in
            partialResult + (row.log.isCompleted ? 1 : 0)
        }
    }

    private var compactBlockSummary: String {
        var parts = ["\(block.sets.count) sets", "\(block.restSeconds)s rest", block.progressionRule.kind.displayLabel]
        if let supersetGroup = block.supersetGroup, !supersetGroup.isEmpty {
            parts.insert("Superset \(supersetGroup)", at: 2)
        }
        return parts.joined(separator: " • ")
    }

    /// When every non-empty set note shares the same prefix (text before ` • `, or the whole note), return it once at the block level.
    private static func hoistedSharedNotePrefix(for block: SessionBlock) -> String? {
        let trimmedNotes = block.sets.compactMap { row -> String? in
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

    /// `nil` = show `row.target.note` as before. Non-nil empty string = hide row note. Non-nil text = show that line only.
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
