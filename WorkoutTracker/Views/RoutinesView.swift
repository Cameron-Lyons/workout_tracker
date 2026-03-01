import SwiftUI

struct RoutinesView: View {
    private enum Constants {
        static let scrollFadeOpacity = 0.82
        static let scrollScale = 0.985
        static let rowInsetTop: CGFloat = 7
        static let rowInsetLeadingTrailing: CGFloat = 14
        static let rowInsetBottom: CGFloat = 7
        static let rowDotSize: CGFloat = 11
        static let rowDotShadowOpacity = 0.65
        static let rowDotShadowRadius: CGFloat = 6
        static let rowDotTopPadding: CGFloat = 8
        static let rowOuterPadding: CGFloat = 14
        static let rowCornerRadius: CGFloat = 16
        static let rowTitleSize: CGFloat = 22
        static let rowProgramTagSpacing: CGFloat = 8
        static let rowProgramTagVerticalPadding: CGFloat = 4
        static let rowProgramTagTracking: CGFloat = 0.8
        static let rowProgramTagFillOpacity = 0.12
        static let rowProgramTagStrokeOpacity = 0.45
        static let rowChevronOpacity = 0.8
        static let rowDotGradientEndRadius: CGFloat = 8
        static let rowDotGradientStartRadius: CGFloat = 1
        static let rowDotGradientEndOpacity = 0.4
        static let rowTextLineLimit = 2
    }

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
                            .opacity(phase.isIdentity ? 1 : Constants.scrollFadeOpacity)
                            .scaleEffect(phase.isIdentity ? 1 : Constants.scrollScale)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(
                        EdgeInsets(
                            top: Constants.rowInsetTop,
                            leading: Constants.rowInsetLeadingTrailing,
                            bottom: Constants.rowInsetBottom,
                            trailing: Constants.rowInsetLeadingTrailing
                        )
                    )
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
        AppEmptyStateCard(
            systemImage: "list.bullet.rectangle",
            title: "Build your first routine",
            message: "Create a custom plan or start from a proven strength template."
        )
    }

    private func routineRow(_ routine: Routine) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(
                            colors: [
                                AppColors.accent,
                                AppColors.accent.opacity(Constants.rowDotGradientEndOpacity)
                            ]
                        ),
                        center: .center,
                        startRadius: Constants.rowDotGradientStartRadius,
                        endRadius: Constants.rowDotGradientEndRadius
                    )
                )
                .frame(width: Constants.rowDotSize, height: Constants.rowDotSize)
                .shadow(
                    color: AppColors.accent.opacity(Constants.rowDotShadowOpacity),
                    radius: Constants.rowDotShadowRadius,
                    x: 0,
                    y: 0
                )
                .padding(.top, Constants.rowDotTopPadding)

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(routine.name)
                        .font(.system(size: Constants.rowTitleSize, weight: .black, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppColors.textSecondary.opacity(Constants.rowChevronOpacity))
                }

                if let program = routine.program {
                    Text(program.kind.displayName.uppercased())
                        .font(.caption2.weight(.heavy))
                        .tracking(Constants.rowProgramTagTracking)
                        .foregroundStyle(AppColors.accent)
                        .padding(.horizontal, Constants.rowProgramTagSpacing)
                        .padding(.vertical, Constants.rowProgramTagVerticalPadding)
                        .background(AppColors.accent.opacity(Constants.rowProgramTagFillOpacity), in: Capsule())
                        .overlay(
                            Capsule()
                                .stroke(AppColors.accent.opacity(Constants.rowProgramTagStrokeOpacity), lineWidth: 1)
                        )
                }

                Text(routine.exercises.map(\.name).joined(separator: " • "))
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(Constants.rowTextLineLimit)
            }
        }
        .padding(Constants.rowOuterPadding)
        .appSurface(cornerRadius: Constants.rowCornerRadius, shadow: false)
    }
}
