import SwiftUI

struct RoutinesView: View {
    private enum Constants {
        static let listAnimation = Animation.spring(response: 0.42, dampingFraction: 0.86)
        static let scrollFadeOpacity = 0.82
        static let scrollScale = 0.985
        static let standardHorizontalInset: CGFloat = 14
        static let sectionInset: CGFloat = 8
        static let rowInsetTop: CGFloat = 7
        static let rowInsetLeadingTrailing: CGFloat = 14
        static let rowInsetBottom: CGFloat = 7
        static let rowDotSize: CGFloat = 11
        static let rowDotShadowOpacity = 0.65
        static let rowDotShadowRadius: CGFloat = 6
        static let rowDotTopPadding: CGFloat = 8
        static let rowOuterPadding: CGFloat = 16
        static let rowCornerRadius: CGFloat = 16
        static let rowTitleSize: CGFloat = 21
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
        static let rowSpacing: CGFloat = 12
        static let rowMetaSpacing: CGFloat = 8
        static let rowMetaHorizontalPadding: CGFloat = 9
        static let rowMetaVerticalPadding: CGFloat = 6
        static let emptyStateSpacing: CGFloat = 14
    }

    @EnvironmentObject private var store: WorkoutStore
    @State private var showingAddRoutine = false
    @State private var exerciseSummaryByRoutineID: [UUID: String] = [:]

    private var totalExerciseCount: Int {
        store.routines.reduce(0) { $0 + $1.exercises.count }
    }

    private var templateRoutineCount: Int {
        store.routines.filter { $0.program != nil }.count
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                Group {
                    if store.routines.isEmpty {
                        emptyState
                            .appReveal(delay: 0.03)
                    } else {
                        routinesList
                            .appReveal(delay: 0.03)
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
                    .accessibilityIdentifier("routines.addMenuButton")
                }
            }
            .tint(AppColors.accent)
            .sheet(isPresented: $showingAddRoutine) {
                AddRoutineSheet { name, exercises in
                    store.addRoutine(name: name, exerciseNames: exercises)
                }
            }
            .onAppear {
                rebuildExerciseSummaryCache()
            }
            .onChange(of: store.routines) { _, _ in
                rebuildExerciseSummaryCache()
            }
        }
    }

    private var routinesList: some View {
        List {
            Section {
                AppHeroCard(
                    eyebrow: "Training Library",
                    title: "\(store.routines.count) routines ready",
                    subtitle: "Mix custom plans with progression templates and jump into logging faster.",
                    systemImage: "list.bullet.clipboard",
                    metrics: [
                        AppHeroMetric(
                            id: "routines",
                            label: "Routines",
                            value: "\(store.routines.count)",
                            systemImage: "list.bullet"
                        ),
                        AppHeroMetric(
                            id: "exercises",
                            label: "Exercises",
                            value: "\(totalExerciseCount)",
                            systemImage: "dumbbell"
                        ),
                        AppHeroMetric(
                            id: "templates",
                            label: "Templates",
                            value: "\(templateRoutineCount)",
                            systemImage: "sparkles"
                        ),
                        AppHeroMetric(
                            id: "custom",
                            label: "Custom",
                            value: "\(max(0, store.routines.count - templateRoutineCount))",
                            systemImage: "square.and.pencil"
                        )
                    ]
                )
                .appReveal(delay: 0.01)
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(
                    EdgeInsets(
                        top: Constants.sectionInset,
                        leading: Constants.standardHorizontalInset,
                        bottom: Constants.sectionInset,
                        trailing: Constants.standardHorizontalInset
                    )
                )
            }

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
            } header: {
                Text("Saved routines")
            } footer: {
                Text("Use Edit to reorder or remove routines.")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollIndicators(.hidden)
        .animation(Constants.listAnimation, value: store.routines)
    }

    private var emptyState: some View {
        VStack(spacing: Constants.emptyStateSpacing) {
            AppEmptyStateCard(
                systemImage: "list.bullet.rectangle",
                title: "Build your first routine",
                message: "Create a custom plan or start from a proven strength template."
            )

            Button {
                showingAddRoutine = true
            } label: {
                Label("Create Routine", systemImage: "plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColors.accent)
            .controlSize(.large)
            .padding(.horizontal, 20)
        }
    }

    private func routineRow(_ routine: Routine) -> some View {
        HStack(alignment: .top, spacing: Constants.rowSpacing) {
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
                        .font(.system(size: Constants.rowTitleSize, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColors.textSecondary.opacity(Constants.rowChevronOpacity))
                }

                if let program = routine.program {
                    Text(program.kind.displayName.uppercased())
                        .font(.caption2.weight(.semibold))
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

                Text(exerciseSummaryByRoutineID[routine.id] ?? routine.exercises.map(\.name).joined(separator: " • "))
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                    .lineLimit(Constants.rowTextLineLimit)

                HStack(spacing: Constants.rowMetaSpacing) {
                    rowMetadataChip(
                        label: "\(routine.exercises.count) exercise\(routine.exercises.count == 1 ? "" : "s")",
                        systemImage: "figure.strengthtraining.traditional"
                    )

                    rowMetadataChip(
                        label: routine.program == nil ? "Custom" : "Template",
                        systemImage: routine.program == nil ? "square.and.pencil" : "sparkles"
                    )
                }
            }
        }
        .padding(Constants.rowOuterPadding)
        .appSurface(cornerRadius: Constants.rowCornerRadius, shadow: false)
    }

    private func rowMetadataChip(label: String, systemImage: String) -> some View {
        Label(label, systemImage: systemImage)
            .font(.caption2.weight(.medium))
            .foregroundStyle(AppColors.textSecondary)
            .padding(.horizontal, Constants.rowMetaHorizontalPadding)
            .padding(.vertical, Constants.rowMetaVerticalPadding)
            .appInsetCard(cornerRadius: 9, fillOpacity: 0.78, borderOpacity: 0.68)
    }

    private func rebuildExerciseSummaryCache() {
        var summaries: [UUID: String] = [:]
        summaries.reserveCapacity(store.routines.count)

        for routine in store.routines {
            summaries[routine.id] = routine.exercises.map(\.name).joined(separator: " • ")
        }

        exerciseSummaryByRoutineID = summaries
    }
}
