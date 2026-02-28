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
        Form {
            if let routine, let program = routine.program {
                Section("Program") {
                    Text(program.kind.displayName)

                    if let context = WorkoutProgramEngine.contextLabel(for: routine) {
                        Text(context)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Routine") {
                TextField("Name", text: $routineName)
                    .textInputAutocapitalization(.words)
            }

            Section {
                HStack {
                    TextField("Add exercise", text: $pendingExerciseName)
                        .textInputAutocapitalization(.words)

                    Button("Add") {
                        addExercise()
                    }
                    .disabled(pendingExerciseName.nonEmptyTrimmed == nil)
                }
            } header: {
                Text("Exercises")
            } footer: {
                Text("Set TM/Working Weight for auto-calculated sets.")
            }

            if exercises.isEmpty {
                Text("Add at least one exercise")
                    .foregroundStyle(.secondary)
            } else {
                Section {
                    ForEach($exercises) { $exercise in
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("Exercise", text: $exercise.name)
                                .textInputAutocapitalization(.words)

                            TextField("TM / Working Weight (lbs)", text: $exercise.trainingMaxText)
                                .keyboardType(.decimalPad)
                        }
                        .padding(.vertical, 2)
                    }
                    .onDelete(perform: deleteExercise)
                    .onMove(perform: moveExercise)
                }
            }
        }
        .navigationTitle("Edit Routine")
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
