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

struct ExerciseEditingRowControls<Element>: View {
    @Binding var items: [Element]
    let index: Int
    let controlOpacity: Double
    let animation: Animation

    var body: some View {
        ExerciseRowControls(
            isFirst: index == 0,
            isLast: index == items.count - 1,
            controlOpacity: controlOpacity,
            onMoveUp: {
                ExerciseEditingMutations.move(
                    in: $items,
                    from: index,
                    to: index - 1,
                    animation: animation
                )
            },
            onMoveDown: {
                ExerciseEditingMutations.move(
                    in: $items,
                    from: index,
                    to: index + 1,
                    animation: animation
                )
            },
            onDelete: {
                ExerciseEditingMutations.delete(
                    from: $items,
                    at: index,
                    animation: animation
                )
            }
        )
    }
}

struct ExerciseEditingList<Rows: View>: View {
    let isEmpty: Bool
    let rowSpacing: CGFloat
    let emptyTopPadding: CGFloat
    let listTopPadding: CGFloat
    let animation: Animation
    let animationValue: Int
    @ViewBuilder var rows: () -> Rows

    var body: some View {
        if isEmpty {
            Text("Add at least one exercise")
                .font(.subheadline)
                .foregroundStyle(AppColors.textSecondary)
                .padding(.top, emptyTopPadding)
        } else {
            VStack(spacing: rowSpacing) {
                rows()
            }
            .padding(.top, listTopPadding)
            .animation(animation, value: animationValue)

            Text("Use arrows to reorder exercises.")
                .font(.caption2)
                .foregroundStyle(AppColors.textSecondary)
        }
    }
}

enum ExerciseEditingMutations {
    static func delete<Element>(
        from items: Binding<[Element]>,
        at index: Int,
        animation: Animation
    ) {
        var updatedItems = items.wrappedValue
        _ = withAnimation(animation) {
            updatedItems.removeIfPresent(at: index)
        }
        items.wrappedValue = updatedItems
    }

    static func move<Element>(
        in items: Binding<[Element]>,
        from sourceIndex: Int,
        to destinationIndex: Int,
        animation: Animation
    ) {
        var updatedItems = items.wrappedValue
        withAnimation(animation) {
            _ = updatedItems.swapIfPresent(from: sourceIndex, to: destinationIndex)
        }
        items.wrappedValue = updatedItems
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
                                .accessibilityIdentifier("addRoutine.routineNameField")
                        }

                        AppFormSectionCard(
                            title: "Exercises",
                            cardPadding: Layout.cardPadding,
                            cornerRadius: Layout.cornerRadius,
                            revealDelay: 0.08
                        ) {
                            ExerciseNameInputRow(
                                exerciseName: $pendingExercise,
                                textFieldAccessibilityIdentifier: "addRoutine.exerciseNameField",
                                addButtonAccessibilityIdentifier: "addRoutine.addExerciseButton",
                                addAction: addExercise
                            )
                            ExerciseEditingList(
                                isEmpty: exercises.isEmpty,
                                rowSpacing: Layout.exerciseRowSpacing,
                                emptyTopPadding: Layout.emptyStateTopPadding,
                                listTopPadding: Layout.exerciseListTopPadding,
                                animation: Layout.listAnimation,
                                animationValue: exercises.count
                            ) {
                                ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
                                    HStack(spacing: 10) {
                                        Text(exercise.name)
                                            .font(.body.weight(.medium))
                                            .foregroundStyle(AppColors.textPrimary)
                                            .frame(maxWidth: .infinity, alignment: .leading)

                                        ExerciseEditingRowControls(
                                            items: $exercises,
                                            index: index,
                                            controlOpacity: Layout.controlOpacity,
                                            animation: Layout.listAnimation
                                        )
                                    }
                                    .padding(Layout.exerciseRowPadding)
                                    .appInsetCard()
                                    .transition(.move(edge: .bottom).combined(with: .opacity))
                                }
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
                    .accessibilityIdentifier("addRoutine.cancelButton")
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
                    .accessibilityIdentifier("addRoutine.saveButton")
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
}
