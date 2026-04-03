import SwiftUI

struct TemplateEditorExercisesSectionView: View {
    @Binding var draftExercises: [TemplateDraftExercise]
    let weightUnit: WeightUnit
    let scrollProxy: ScrollViewProxy
    @Binding var showingExercisePickerForBlockID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                AppSectionHeader(
                    title: "Exercises",
                    systemImage: "dumbbell",
                    subtitle: "Keep the default prescription simple, then expand an exercise for more control.",
                    trailing: draftExercises.isEmpty ? nil : "\(draftExercises.count)",
                    tone: .today
                )

                Button {
                    addDraftExercise()
                } label: {
                    Label("Add Exercise", systemImage: "plus")
                }
                .accessibilityIdentifier("plans.template.addExerciseButton")
                .appPrimaryActionButton(tone: .today, controlSize: .regular)
            }

            if draftExercises.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    AppStatePill(title: "Start Here", systemImage: "sparkles", tone: .today)

                    Text("Add at least one exercise.")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppColors.textPrimary)

                    Text(
                        "Each exercise holds the main prescription up front, with progression details hidden until you need them."
                    )
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .appInsetContentCard(
                    fill: AppToneStyle.today.softFill.opacity(0.55),
                    border: AppToneStyle.today.softBorder
                )
            } else {
                LazyVStack(spacing: 12) {
                    ForEach($draftExercises) { $draft in
                        TemplateDraftExerciseEditorView(
                            draft: $draft,
                            weightUnit: weightUnit,
                            onPickExercise: { rowID in
                                showingExercisePickerForBlockID = rowID
                            },
                            onDelete: { rowID in
                                deleteDraftExercise(rowID)
                            }
                        )
                        .id($draft.wrappedValue.id)
                    }
                }
            }
        }
        .appSectionFrame(tone: .today, topPadding: 16, bottomPadding: 8)
    }

    private func addDraftExercise() {
        let newDraft = TemplateDraftExercise()
        draftExercises.append(newDraft)

        Task { @MainActor in
            await Task.yield()
            withAnimation(.easeInOut(duration: 0.2)) {
                scrollProxy.scrollTo(newDraft.id, anchor: .bottom)
            }
        }
    }

    private func deleteDraftExercise(_ rowID: UUID) {
        draftExercises.removeAll(where: { $0.id == rowID })
    }
}
