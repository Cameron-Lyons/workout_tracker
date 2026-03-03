import SwiftUI

private struct EditableExercise: Identifiable {
    var id: UUID
    var name: String
    var trainingMaxText: String
}

struct RoutineEditorView: View {
    private enum Layout {
        static let listAnimation = Animation.spring(response: 0.40, dampingFraction: 0.84)
        static let sectionSpacing: CGFloat = 14
        static let sectionTitleSpacing: CGFloat = 8
        static let sectionTitleTracking: CGFloat = 0.6
        static let cardPadding: CGFloat = 14
        static let contentVerticalPadding: CGFloat = 14
        static let fieldSpacing: CGFloat = 10
        static let exerciseRowSpacing: CGFloat = 10
        static let exerciseRowPadding: CGFloat = 12
        static let cardCornerRadius: CGFloat = 14
        static let controlOpacity = 0.82
    }

    @EnvironmentObject private var store: WorkoutStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage(WeightUnit.preferenceKey) private var weightUnitRawValue = WeightUnit.pounds.rawValue

    let routineID: UUID

    @State private var routineName = ""
    @State private var exercises: [EditableExercise] = []
    @State private var pendingExerciseName = ""
    @State private var previousWeightUnit: WeightUnit = .pounds

    @State private var showInvalidAlert = false

    private var routine: Routine? {
        store.routine(withID: routineID)
    }

    private var weightUnit: WeightUnit {
        WeightUnit(rawValue: weightUnitRawValue) ?? .pounds
    }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: Layout.sectionSpacing) {
                    programSection
                    routineSection
                    exerciseSetupSection
                    exercisesSection
                }
                .padding(.horizontal)
                .padding(.vertical, Layout.contentVerticalPadding)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Edit Routine")
        .toolbarBackground(AppColors.chrome, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear {
            previousWeightUnit = weightUnit
            loadRoutine()
        }
        .onChange(of: weightUnitRawValue) { _, _ in
            handleWeightUnitChange()
        }
        .alert("Could Not Save", isPresented: $showInvalidAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Routine name and at least one exercise are required.")
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    saveRoutine()
                }
            }
        }
        .tint(AppColors.accent)
    }

    @ViewBuilder
    private var programSection: some View {
        if let routine, let program = routine.program {
            VStack(alignment: .leading, spacing: Layout.sectionTitleSpacing) {
                Text("Program Template")
                    .font(.caption.weight(.semibold))
                    .tracking(Layout.sectionTitleTracking)
                    .textCase(.uppercase)
                    .foregroundStyle(AppColors.textSecondary)

                Text(program.kind.displayName)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)

                if let context = WorkoutProgramEngine.contextLabel(for: routine) {
                    Text(context)
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .padding(Layout.cardPadding)
            .appSurface(cornerRadius: Layout.cardCornerRadius, shadow: false)
            .appReveal(delay: 0.02)
        }
    }

    private var routineSection: some View {
        AppFormSectionCard(
            title: "Routine",
            cardPadding: Layout.cardPadding,
            cornerRadius: Layout.cardCornerRadius,
            revealDelay: 0.05
        ) {
            TextField("Routine name", text: $routineName)
                .textInputAutocapitalization(.words)
                .foregroundStyle(AppColors.textPrimary)
                .appInputField()
        }
    }

    private var exerciseSetupSection: some View {
        AppFormSectionCard(
            title: "Exercises",
            cardPadding: Layout.cardPadding,
            cornerRadius: Layout.cardCornerRadius,
            revealDelay: 0.08
        ) {
            ExerciseNameInputRow(exerciseName: $pendingExerciseName, addAction: addExercise)

            Text("Set a training max (TM) or working weight to auto-calculate sets.")
                .font(.caption2)
                .foregroundStyle(AppColors.textSecondary)
        }
    }

    private var exercisesSection: some View {
        ExerciseEditingList(
            isEmpty: exercises.isEmpty,
            rowSpacing: Layout.exerciseRowSpacing,
            emptyTopPadding: 0,
            listTopPadding: 0,
            animation: Layout.listAnimation,
            animationValue: exercises.count
        ) {
            ForEach(Array(exercises.indices), id: \.self) { index in
                editableExerciseRow(at: index)
            }
        }
        .padding(Layout.cardPadding)
        .appSurface(cornerRadius: Layout.cardCornerRadius, shadow: false)
        .appReveal(delay: 0.11)
    }

    private func loadRoutine() {
        guard let routine else {
            return
        }

        routineName = routine.name
        exercises = routine.exercises.map {
            EditableExercise(
                id: $0.id,
                name: $0.name,
                trainingMaxText: formatTrainingMax($0.trainingMax)
            )
        }
    }

    private func addExercise() {
        guard let trimmed = pendingExerciseName.nonEmptyTrimmed else { return }

        withAnimation(Layout.listAnimation) {
            exercises.append(
                EditableExercise(
                    id: UUID(),
                    name: trimmed,
                    trainingMaxText: ""
                )
            )
        }
        pendingExerciseName = ""
    }

    private func saveRoutine() {
        let trimmedName = routineName.nonEmptyTrimmed ?? ""
        let cleanedExercises = exercises.compactMap { exercise -> Exercise? in
            guard let trimmedExerciseName = exercise.name.nonEmptyTrimmed else { return nil }

            return Exercise(
                id: exercise.id,
                name: trimmedExerciseName,
                trainingMax: parseTrainingMax(exercise.trainingMaxText)
            )
        }

        guard !trimmedName.isEmpty, !cleanedExercises.isEmpty else {
            showInvalidAlert = true
            return
        }

        guard routine != nil else {
            dismiss()
            return
        }

        store.updateRoutine(id: routineID, name: trimmedName, exercises: cleanedExercises)
        dismiss()
    }

    private func parseTrainingMax(_ text: String) -> Double? {
        guard let displayValue = WeightInputParser.parseDisplayValue(text) else {
            return nil
        }
        return weightUnit.storedPounds(fromDisplayValue: displayValue)
    }

    private func formatTrainingMax(_ trainingMax: Double?) -> String {
        guard let trainingMax else {
            return ""
        }
        return WeightFormatter.displayString(trainingMax, unit: weightUnit)
    }

    private func editableExerciseRow(at index: Int) -> some View {
        VStack(alignment: .leading, spacing: Layout.fieldSpacing) {
            HStack(spacing: 10) {
                Text("Exercise \(index + 1)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColors.textSecondary)

                Spacer()

                ExerciseRowControls(
                    isFirst: index == 0,
                    isLast: index == exercises.count - 1,
                    controlOpacity: Layout.controlOpacity,
                    onMoveUp: {
                        ExerciseEditingMutations.move(
                            in: &exercises,
                            from: index,
                            to: index - 1,
                            animation: Layout.listAnimation
                        )
                    },
                    onMoveDown: {
                        ExerciseEditingMutations.move(
                            in: &exercises,
                            from: index,
                            to: index + 1,
                            animation: Layout.listAnimation
                        )
                    },
                    onDelete: {
                        ExerciseEditingMutations.delete(
                            from: &exercises,
                            at: index,
                            animation: Layout.listAnimation
                        )
                    }
                )
            }

            TextField("Exercise", text: exerciseTextBinding(at: index, keyPath: \.name))
                .textInputAutocapitalization(.words)
                .foregroundStyle(AppColors.textPrimary)
                .appInputField()

            TextField(
                "Training max (TM) / working weight (\(weightUnit.symbol))",
                text: exerciseTextBinding(at: index, keyPath: \.trainingMaxText)
            )
            .keyboardType(.decimalPad)
            .foregroundStyle(AppColors.textPrimary)
            .appInputField()
        }
        .padding(Layout.exerciseRowPadding)
        .appInsetCard()
    }

    private func exerciseTextBinding(at index: Int, keyPath: WritableKeyPath<EditableExercise, String>) -> Binding<String> {
        Binding(
            get: {
                guard exercises.indices.contains(index) else { return "" }
                return exercises[index][keyPath: keyPath]
            },
            set: { updatedValue in
                guard exercises.indices.contains(index) else { return }
                exercises[index][keyPath: keyPath] = updatedValue
            }
        )
    }

    private func handleWeightUnitChange() {
        let newUnit = weightUnit
        let oldUnit = previousWeightUnit
        previousWeightUnit = newUnit

        guard newUnit != oldUnit else {
            return
        }

        exercises = exercises.map { exercise in
            guard let convertedWeight = newUnit.convertedDisplayString(from: oldUnit, text: exercise.trainingMaxText) else {
                return exercise
            }

            var updated = exercise
            updated.trainingMaxText = convertedWeight
            return updated
        }
    }
}
