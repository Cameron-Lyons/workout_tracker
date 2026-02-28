import SwiftUI

private struct EditableExercise: Identifiable {
    var id: UUID
    var name: String
    var trainingMaxText: String
}

struct RoutineEditorView: View {
    @EnvironmentObject private var store: WorkoutStore
    @Environment(\.dismiss) private var dismiss

    let routineID: UUID

    @State private var routineName = ""
    @State private var exercises: [EditableExercise] = []
    @State private var pendingExerciseName = ""

    @State private var showInvalidAlert = false

    private var routine: Routine? {
        store.routines.first(where: { $0.id == routineID })
    }

    var body: some View {
        ZStack {
            AppBackground()
            Form {
                if let routine, let program = routine.program {
                    Section("Program") {
                        Text(program.kind.displayName)
                            .foregroundStyle(AppColors.textPrimary)

                        if let context = WorkoutProgramEngine.contextLabel(for: routine) {
                            Text(context)
                                .font(.caption)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                    }
                    .listRowBackground(AppColors.surface)
                }

                Section("Routine") {
                    TextField("Name", text: $routineName)
                        .textInputAutocapitalization(.words)
                        .foregroundStyle(AppColors.textPrimary)
                }
                .listRowBackground(AppColors.surface)

                Section {
                    HStack {
                        TextField("Add exercise", text: $pendingExerciseName)
                            .textInputAutocapitalization(.words)
                            .foregroundStyle(AppColors.textPrimary)

                        Button("Add") {
                            addExercise()
                        }
                        .disabled(pendingExerciseName.nonEmptyTrimmed == nil)
                        .tint(AppColors.accent)
                    }
                } header: {
                    Text("Exercises")
                } footer: {
                    Text("Set TM/Working Weight for auto-calculated sets.")
                }
                .listRowBackground(AppColors.surface)

                if exercises.isEmpty {
                    Text("Add at least one exercise")
                        .foregroundStyle(AppColors.textSecondary)
                        .listRowBackground(AppColors.surface)
                } else {
                    Section {
                        ForEach($exercises) { $exercise in
                            VStack(alignment: .leading, spacing: 8) {
                                TextField("Exercise", text: $exercise.name)
                                    .textInputAutocapitalization(.words)
                                    .foregroundStyle(AppColors.textPrimary)

                                TextField("TM / Working Weight (lbs)", text: $exercise.trainingMaxText)
                                    .keyboardType(.decimalPad)
                                    .foregroundStyle(AppColors.textPrimary)
                            }
                            .padding(.vertical, 2)
                        }
                        .onDelete(perform: deleteExercise)
                        .onMove(perform: moveExercise)
                    }
                    .listRowBackground(AppColors.surface)
                }
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Edit Routine")
        .toolbarBackground(AppColors.chrome, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .onAppear(perform: loadRoutine)
        .alert("Could Not Save", isPresented: $showInvalidAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Routine name and at least one exercise are required.")
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                EditButton()
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Save") {
                    saveRoutine()
                }
            }
        }
        .tint(AppColors.accent)
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

        exercises.append(
            EditableExercise(
                id: UUID(),
                name: trimmed,
                trainingMaxText: ""
            )
        )
        pendingExerciseName = ""
    }

    private func deleteExercise(at offsets: IndexSet) {
        exercises.remove(atOffsets: offsets)
    }

    private func moveExercise(from source: IndexSet, to destination: Int) {
        exercises.move(fromOffsets: source, toOffset: destination)
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
        let sanitized = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")

        guard !sanitized.isEmpty else { return nil }
        return Double(sanitized)
    }

    private func formatTrainingMax(_ trainingMax: Double?) -> String {
        guard let trainingMax else {
            return ""
        }
        return WeightFormatter.displayString(trainingMax)
    }
}
