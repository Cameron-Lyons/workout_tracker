import SwiftUI

@MainActor
struct ActiveSessionNotesCardView: View, Equatable {
    let notes: String
    let onUpdateNotes: (String) -> Void
    @State private var draftNotesText: String
    @State private var commitTask: Task<Void, Never>?
    @FocusState private var isFocused: Bool

    init(notes: String, onUpdateNotes: @escaping (String) -> Void) {
        self.notes = notes
        self.onUpdateNotes = onUpdateNotes
        _draftNotesText = State(initialValue: notes)
    }

    nonisolated static func == (lhs: ActiveSessionNotesCardView, rhs: ActiveSessionNotesCardView) -> Bool {
        lhs.notes == rhs.notes
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            AppSectionHeader(
                title: "Session Notes",
                systemImage: "note.text",
                subtitle: "Capture anything you want to remember before you finish.",
                tone: .plans
            )

            TextField(
                "How did the session feel?",
                text: $draftNotesText,
                axis: .vertical
            )
            .foregroundStyle(AppColors.textPrimary)
            .lineLimit(2...4)
            .focused($isFocused)
            .modifier(SessionUnderlineFieldModifier())
            .onChange(of: notes) { _, newValue in
                guard !isFocused else {
                    return
                }

                draftNotesText = newValue
            }
            .onChange(of: draftNotesText) { _, newValue in
                guard isFocused else {
                    return
                }

                scheduleCommit(for: newValue)
            }
            .onChange(of: isFocused) { previousValue, newValue in
                guard previousValue, !newValue else {
                    return
                }

                commitImmediately()
            }
            .onDisappear {
                commitImmediately()
            }

            SessionSectionDivider()
        }
    }

    private func scheduleCommit(for text: String) {
        commitTask?.cancel()
        commitTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: SessionInputCommitDefaults.debounceNanoseconds)
            guard !Task.isCancelled else {
                return
            }

            commit(text)
        }
    }

    private func commitImmediately() {
        commitTask?.cancel()
        commitTask = nil
        commit(draftNotesText)
    }

    private func commit(_ text: String) {
        guard text != notes else {
            return
        }

        onUpdateNotes(text)
    }
}
