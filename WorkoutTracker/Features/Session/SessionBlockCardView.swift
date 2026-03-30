import SwiftUI

@MainActor
struct SessionBlockCardView: View, Equatable {
    let block: SessionBlock
    let displaySettings: ActiveSessionDisplaySettings
    let actions: ActiveSessionActions
    let showsDetailedChrome: Bool
    @State private var blockNoteText: String
    @State private var blockNoteCommitTask: Task<Void, Never>?
    @FocusState private var isBlockNoteFocused: Bool

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
        _blockNoteText = State(initialValue: block.blockNote)
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

            TextField(
                "Block note",
                text: $blockNoteText,
                axis: .vertical
            )
            .foregroundStyle(AppColors.textPrimary)
            .lineLimit(2...3)
            .focused($isBlockNoteFocused)
            .modifier(SessionUnderlineFieldModifier())
            .onChange(of: block) { _, newValue in
                guard !isBlockNoteFocused else {
                    return
                }

                blockNoteText = newValue.blockNote
            }
            .onChange(of: blockNoteText) { _, newValue in
                guard isBlockNoteFocused else {
                    return
                }

                scheduleBlockNoteCommit(for: newValue)
            }
            .onChange(of: isBlockNoteFocused) { previousValue, newValue in
                guard previousValue, !newValue else {
                    return
                }

                commitBlockNoteImmediately()
            }
            .onDisappear {
                commitBlockNoteImmediately()
            }

            VStack(spacing: 0) {
                ForEach(Array(block.sets.enumerated()), id: \.element.id) { index, row in
                    SessionSetRowView(
                        blockID: block.id,
                        row: row,
                        weightUnit: displaySettings.weightUnit,
                        weightStep: displaySettings.weightStep(for: block),
                        actions: actions,
                        showsDetailedChrome: showsDetailedChrome
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

    private func scheduleBlockNoteCommit(for note: String) {
        blockNoteCommitTask?.cancel()
        blockNoteCommitTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: SessionInputCommitDefaults.debounceNanoseconds)
            guard !Task.isCancelled else {
                return
            }

            commitBlockNote(note)
        }
    }

    private func commitBlockNoteImmediately() {
        blockNoteCommitTask?.cancel()
        blockNoteCommitTask = nil
        commitBlockNote(blockNoteText)
    }

    private func commitBlockNote(_ note: String) {
        guard note != block.blockNote else {
            return
        }

        actions.updateBlockNotes(block.id, note)
    }
}
