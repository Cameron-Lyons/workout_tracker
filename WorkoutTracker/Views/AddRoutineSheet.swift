import SwiftUI

private struct DraftExercise: Identifiable, Equatable {
    var id = UUID()
    var name: String
}

struct AppFormSectionCard<Content: View>: View {
    private let sectionTitleSpacing: CGFloat = 8
    private let sectionTitleTracking: CGFloat = 0.6

    let title: String
    let cardPadding: CGFloat
    let cornerRadius: CGFloat
    let revealDelay: Double
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: sectionTitleSpacing) {
            Text(title)
                .font(.caption.weight(.semibold))
                .tracking(sectionTitleTracking)
                .textCase(.uppercase)
                .foregroundStyle(AppColors.textSecondary)

            content()
        }
        .padding(cardPadding)
        .appSurface(cornerRadius: cornerRadius, shadow: false)
        .appReveal(delay: revealDelay)
    }
}

struct ExerciseRowControls: View {
    private enum Layout {
        static let spacing: CGFloat = 10
    }

    let isFirst: Bool
    let isLast: Bool
    let controlOpacity: Double
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: Layout.spacing) {
            Button {
                onMoveUp()
            } label: {
                Image(systemName: "arrow.up")
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppColors.textSecondary.opacity(controlOpacity))
            .disabled(isFirst)

            Button {
                onMoveDown()
            } label: {
                Image(systemName: "arrow.down")
            }
            .buttonStyle(.plain)
            .foregroundStyle(AppColors.textSecondary.opacity(controlOpacity))
            .disabled(isLast)

            Button(role: .destructive) {
                onDelete()
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.plain)
        }
    }
}

extension Array {
    @discardableResult
    mutating func removeIfPresent(at index: Int) -> Bool {
        guard indices.contains(index) else {
            return false
        }

        remove(at: index)
        return true
    }

    @discardableResult
    mutating func swapIfPresent(from sourceIndex: Int, to destinationIndex: Int) -> Bool {
        guard indices.contains(sourceIndex), indices.contains(destinationIndex) else {
            return false
        }

        swapAt(sourceIndex, destinationIndex)
        return true
    }
}

struct AddRoutineSheet: View {
    private enum Layout {
        static let listAnimation = Animation.spring(response: 0.40, dampingFraction: 0.84)
        static let sectionSpacing: CGFloat = 14
        static let cardPadding: CGFloat = 14
        static let exerciseRowSpacing: CGFloat = 8
        static let exerciseRowPadding: CGFloat = 10
        static let emptyStateTopPadding: CGFloat = 4
        static let exerciseListTopPadding: CGFloat = 2
        static let contentVerticalPadding: CGFloat = 14
        static let cornerRadius: CGFloat = 14
        static let controlOpacity = 0.82
    }

    @Environment(\.dismiss) private var dismiss

    @State private var routineName = ""
    @State private var pendingExercise = ""
    @State private var exercises: [DraftExercise] = []

    let onSave: (String, [String]) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: Layout.sectionSpacing) {
                        AppFormSectionCard(
                            title: "Routine",
                            cardPadding: Layout.cardPadding,
                            cornerRadius: Layout.cornerRadius,
                            revealDelay: 0.02
                        ) {
                            TextField("Routine name", text: $routineName)
                                .textInputAutocapitalization(.words)
                                .foregroundStyle(AppColors.textPrimary)
                                .appInputField()
                        }

                        AppFormSectionCard(
                            title: "Exercises",
                            cardPadding: Layout.cardPadding,
                            cornerRadius: Layout.cornerRadius,
                            revealDelay: 0.08
                        ) {
                            ExerciseNameInputRow(exerciseName: $pendingExercise, addAction: addExercise)

                            if exercises.isEmpty {
                                Text("Add at least one exercise")
                                    .font(.subheadline)
                                    .foregroundStyle(AppColors.textSecondary)
                                    .padding(.top, Layout.emptyStateTopPadding)
                            } else {
                                VStack(spacing: Layout.exerciseRowSpacing) {
                                    ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
                                        HStack(spacing: 10) {
                                            Text(exercise.name)
                                                .font(.body.weight(.medium))
                                                .foregroundStyle(AppColors.textPrimary)
                                                .frame(maxWidth: .infinity, alignment: .leading)

                                            ExerciseRowControls(
                                                isFirst: index == 0,
                                                isLast: index == exercises.count - 1,
                                                controlOpacity: Layout.controlOpacity,
                                                onMoveUp: { moveExercise(from: index, to: index - 1) },
                                                onMoveDown: { moveExercise(from: index, to: index + 1) },
                                                onDelete: { deleteExercise(at: index) }
                                            )
                                        }
                                        .padding(Layout.exerciseRowPadding)
                                        .appInsetCard()
                                        .transition(.move(edge: .bottom).combined(with: .opacity))
                                    }
                                }
                                .padding(.top, Layout.exerciseListTopPadding)
                                .animation(Layout.listAnimation, value: exercises)

                                Text("Use arrows to reorder exercises.")
                                    .font(.caption2)
                                    .foregroundStyle(AppColors.textSecondary)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, Layout.contentVerticalPadding)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("New Routine")
            .toolbarBackground(AppColors.chrome, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        guard let trimmedRoutineName = routineName.nonEmptyTrimmed else {
                            return
                        }
                        onSave(trimmedRoutineName, exercises.map(\.name))
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            .tint(AppColors.accent)
        }
    }

    private var canSave: Bool {
        routineName.nonEmptyTrimmed != nil && !exercises.isEmpty
    }

    private func addExercise() {
        guard let trimmed = pendingExercise.nonEmptyTrimmed else { return }
        withAnimation(Layout.listAnimation) {
            exercises.append(DraftExercise(name: trimmed))
        }
        pendingExercise = ""
    }

    private func deleteExercise(at index: Int) {
        _ = withAnimation(Layout.listAnimation) {
            exercises.removeIfPresent(at: index)
        }
    }

    private func moveExercise(from sourceIndex: Int, to destinationIndex: Int) {
        withAnimation(Layout.listAnimation) {
            _ = exercises.swapIfPresent(from: sourceIndex, to: destinationIndex)
        }
    }
}
