import SwiftUI

struct RoutinesView: View {
    @EnvironmentObject private var store: WorkoutStore
    @State private var showingAddRoutine = false

    var body: some View {
        NavigationStack {
            Group {
                if store.routines.isEmpty {
                    ContentUnavailableView(
                        "No Routines",
                        systemImage: "list.bullet.rectangle",
                        description: Text("Add a routine to start logging workouts.")
                    )
                } else {
                    List {
                        ForEach(store.routines) { routine in
                            NavigationLink {
                                RoutineEditorView(routineID: routine.id)
                            } label: {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(routine.name)
                                        .font(.headline)

                                    if let program = routine.program {
                                        Text(program.kind.displayName)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    Text(routine.exercises.map(\.name).joined(separator: " • "))
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                        .onDelete(perform: store.deleteRoutines)
                        .onMove(perform: store.moveRoutines)
                    }
                }
            }
            .navigationTitle("Routines")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Custom Routine", systemImage: "square.and.pencil") {
                            showingAddRoutine = true
                        }

                        Divider()

                        Button("Starting Strength", systemImage: "figure.strengthtraining.traditional") {
                            store.addProgramTemplate(.startingStrength)
                        }
                        Button("5/3/1", systemImage: "number") {
                            store.addProgramTemplate(.fiveThreeOne)
                        }
                        Button("Boring But Big", systemImage: "scalemass") {
                            store.addProgramTemplate(.boringButBig)
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddRoutine) {
                AddRoutineSheet { name, exercises in
                    store.addRoutine(name: name, exerciseNames: exercises)
                }
            }
        }
    }
}
