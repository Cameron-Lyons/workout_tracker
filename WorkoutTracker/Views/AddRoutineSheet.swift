import SwiftUI

struct AddRoutineSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var routineName = ""
    @State private var pendingExercise = ""
    @State private var exercises: [String] = []

    let onSave: (String, [String]) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                Form {
                    Section("Routine") {
                        TextField("Routine name", text: $routineName)
                            .textInputAutocapitalization(.words)
                            .foregroundStyle(AppColors.textPrimary)
                    }
                    .listRowBackground(AppColors.surface)

                    Section("Exercises") {
                        ExerciseNameInputRow(exerciseName: $pendingExercise, addAction: addExercise)

                        if exercises.isEmpty {
                            Text("Add at least one exercise")
                                .foregroundStyle(AppColors.textSecondary)
                        } else {
                            ForEach(exercises, id: \.self) { exercise in
                                Text(exercise)
                                    .foregroundStyle(AppColors.textPrimary)
                            }
                            .onDelete(perform: deleteExercise)
                        }
                    }
                    .listRowBackground(AppColors.surface)
                }
                .scrollContentBackground(.hidden)
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
                        onSave(routineName, exercises)
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
        exercises.append(trimmed)
        pendingExercise = ""
    }

    private func deleteExercise(at offsets: IndexSet) {
        exercises.remove(atOffsets: offsets)
    }
}
