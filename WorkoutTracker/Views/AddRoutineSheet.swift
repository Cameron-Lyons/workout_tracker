import SwiftUI

private struct DraftExercise: Identifiable, Equatable {
    var id = UUID()
    var name: String
}

struct AddRoutineSheet: View {
    private enum Layout {
        static let listAnimation = Animation.spring(response: 0.40, dampingFraction: 0.84)
        static let sectionSpacing: CGFloat = 14
        static let sectionTitleSpacing: CGFloat = 8
        static let sectionTitleTracking: CGFloat = 0.6
        static let cardPadding: CGFloat = 14
        static let exerciseRowSpacing: CGFloat = 8
        static let exerciseControlSpacing: CGFloat = 10
        static let exerciseRowPadding: CGFloat = 10
        static let emptyStateTopPadding: CGFloat = 4
        static let exerciseListTopPadding: CGFloat = 2
        static let contentVerticalPadding: CGFloat = 14
        static let cornerRadius: CGFloat = 14
        static let moveButtonOpacity = 0.82
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
                        VStack(alignment: .leading, spacing: Layout.sectionTitleSpacing) {
                            Text("Routine")
                                .font(.caption.weight(.semibold))
                                .tracking(Layout.sectionTitleTracking)
                                .textCase(.uppercase)
                                .foregroundStyle(AppColors.textSecondary)

                            TextField("Routine name", text: $routineName)
                                .textInputAutocapitalization(.words)
                                .foregroundStyle(AppColors.textPrimary)
                                .appInputField()
                        }
                        .padding(Layout.cardPadding)
                        .appSurface(cornerRadius: Layout.cornerRadius, shadow: false)
                        .appReveal(delay: 0.02)

                        VStack(alignment: .leading, spacing: Layout.sectionTitleSpacing) {
                            Text("Exercises")
                                .font(.caption.weight(.semibold))
                                .tracking(Layout.sectionTitleTracking)
                                .textCase(.uppercase)
                                .foregroundStyle(AppColors.textSecondary)

                            ExerciseNameInputRow(exerciseName: $pendingExercise, addAction: addExercise)

                            if exercises.isEmpty {
                                Text("Add at least one exercise")
                                    .font(.subheadline)
                                    .foregroundStyle(AppColors.textSecondary)
                                    .padding(.top, Layout.emptyStateTopPadding)
                            } else {
                                VStack(spacing: Layout.exerciseRowSpacing) {
                                    ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
                                        HStack(spacing: Layout.exerciseControlSpacing) {
                                            Text(exercise.name)
                                                .font(.body.weight(.medium))
                                                .foregroundStyle(AppColors.textPrimary)
                                                .frame(maxWidth: .infinity, alignment: .leading)

                                            Button {
                                                moveExercise(from: index, to: index - 1)
                                            } label: {
                                                Image(systemName: "arrow.up")
                                            }
                                            .buttonStyle(.plain)
                                            .foregroundStyle(AppColors.textSecondary.opacity(Layout.moveButtonOpacity))
                                            .disabled(index == 0)

                                            Button {
                                                moveExercise(from: index, to: index + 1)
                                            } label: {
                                                Image(systemName: "arrow.down")
                                            }
                                            .buttonStyle(.plain)
                                            .foregroundStyle(AppColors.textSecondary.opacity(Layout.moveButtonOpacity))
                                            .disabled(index == exercises.count - 1)

                                            Button(role: .destructive) {
                                                deleteExercise(at: index)
                                            } label: {
                                                Image(systemName: "trash")
                                            }
                                            .buttonStyle(.plain)
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
                        .padding(Layout.cardPadding)
                        .appSurface(cornerRadius: Layout.cornerRadius, shadow: false)
                        .appReveal(delay: 0.08)
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
                        onSave(routineName.nonEmptyTrimmed ?? routineName, exercises.map(\.name))
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
        guard exercises.indices.contains(index) else { return }
        _ = withAnimation(Layout.listAnimation) {
            exercises.remove(at: index)
        }
    }

    private func moveExercise(from sourceIndex: Int, to destinationIndex: Int) {
        guard exercises.indices.contains(sourceIndex), exercises.indices.contains(destinationIndex) else {
            return
        }
        withAnimation(Layout.listAnimation) {
            exercises.swapAt(sourceIndex, destinationIndex)
        }
    }
}
