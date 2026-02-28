import SwiftUI

struct AddRoutineSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var routineName = ""
    @State private var pendingExercise = ""
    @State private var exercises: [String] = []

    let onSave: (String, [String]) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("Routine") {
                    TextField("Name", text: $routineName)
                        .textInputAutocapitalization(.words)
                }

                Section("Exercises") {
                    HStack {
                        TextField("Add exercise", text: $pendingExercise)
                            .textInputAutocapitalization(.words)

                        Button("Add") {
                            addExercise()
                        }
                        .disabled(pendingExercise.nonEmptyTrimmed == nil)
                    }

                    if exercises.isEmpty {
                        Text("Add at least one exercise")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(exercises, id: \.self) { exercise in
                            Text(exercise)
                        }
                        .onDelete(perform: deleteExercise)
                    }
                }
            }
            .navigationTitle("New Routine")
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
