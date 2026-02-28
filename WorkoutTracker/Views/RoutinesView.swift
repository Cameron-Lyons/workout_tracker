import SwiftUI

struct RoutinesView: View {
    @EnvironmentObject private var store: WorkoutStore
    @State private var showingAddRoutine = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                Group {
                    if store.routines.isEmpty {
                        emptyState
                    } else {
                        routinesList
                    }
                }
            }
            .navigationTitle("Routines")
            .toolbarBackground(AppColors.chrome, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
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

                        Divider()

                        Menu("Popular Online Packs", systemImage: "globe") {
                            ForEach(PopularRoutinePack.allCases) { pack in
                                Button(pack.displayName, systemImage: pack.systemImage) {
                                    store.addPopularRoutinePack(pack)
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .tint(AppColors.accent)
            .sheet(isPresented: $showingAddRoutine) {
                AddRoutineSheet { name, exercises in
                    store.addRoutine(name: name, exerciseNames: exercises)
                }
            }
        }
    }

    private var routinesList: some View {
        List {
            Section {
                ForEach(store.routines) { routine in
                    NavigationLink {
                        RoutineEditorView(routineID: routine.id)
                    } label: {
                        routineRow(routine)
                    }
                    .scrollTransition(axis: .vertical) { content, phase in
                        content
                            .opacity(phase.isIdentity ? 1 : 0.82)
                            .scaleEffect(phase.isIdentity ? 1 : 0.985)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 7, leading: 14, bottom: 7, trailing: 14))
                }
                .onDelete(perform: store.deleteRoutines)
                .onMove(perform: store.moveRoutines)
            } footer: {
                Text("Use Edit to reorder or remove routines.")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "list.bullet.rectangle")
                .font(.system(size: 40, weight: .semibold))
                .foregroundStyle(AppColors.accent)

            Text("Build Your First Routine")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)

            Text("Create a custom plan or start from a proven strength template.")
                .font(.subheadline)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .appSurface()
        .padding(.horizontal, 20)
    }

    private func routineRow(_ routine: Routine) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(colors: [AppColors.accent, AppColors.accent.opacity(0.4)]),
                        center: .center,
                        startRadius: 1,
                        endRadius: 8
                    )
                )
                .frame(width: 11, height: 11)
                .shadow(color: AppColors.accent.opacity(0.65), radius: 6, x: 0, y: 0)
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(routine.name)
                        .font(.system(size: 22, weight: .black, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppColors.textSecondary.opacity(0.8))
                }

                if let program = routine.program {
                    Text(program.kind.displayName.uppercased())
                        .font(.caption2.weight(.heavy))
                        .tracking(0.8)
                        .foregroundStyle(AppColors.accent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppColors.accent.opacity(0.12), in: Capsule())
                        .overlay(
                            Capsule()
                                .stroke(AppColors.accent.opacity(0.45), lineWidth: 1)
                        )
                }

                Text(routine.exercises.map(\.name).joined(separator: " • "))
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(2)
            }
        }
        .padding(14)
        .appSurface(cornerRadius: 16, shadow: false)
    }
}
