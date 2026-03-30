import SwiftUI

struct TemplateEditorBlocksSectionView: View {
    @Binding var blocks: [TemplateDraftBlock]
    let weightUnit: WeightUnit
    let scrollProxy: ScrollViewProxy
    @Binding var showingExercisePickerForBlockID: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                AppSectionHeader(
                    title: "Exercise Blocks",
                    systemImage: "dumbbell",
                    subtitle: "Keep the default prescription simple, then expand a block for more control.",
                    trailing: blocks.isEmpty ? nil : "\(blocks.count)",
                    tone: .today
                )

                Button {
                    addBlock()
                } label: {
                    Label("Add Block", systemImage: "plus")
                }
                .appPrimaryActionButton(tone: .today, controlSize: .regular)
                .accessibilityIdentifier("plans.template.addBlockButton")
            }

            if blocks.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    AppStatePill(title: "Start Here", systemImage: "sparkles", tone: .today)

                    Text("Add at least one exercise block.")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppColors.textPrimary)

                    Text(
                        "Each block holds the main prescription up front, with progression details hidden until you need them."
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
                    ForEach($blocks) { $block in
                        TemplateDraftBlockEditorView(
                            block: $block,
                            weightUnit: weightUnit,
                            onPickExercise: { blockID in
                                showingExercisePickerForBlockID = blockID
                            },
                            onDelete: { blockID in
                                deleteBlock(blockID)
                            }
                        )
                        .id($block.wrappedValue.id)
                    }
                }
            }
        }
        .appSectionFrame(tone: .today, topPadding: 16, bottomPadding: 8)
    }

    private func addBlock() {
        let newBlock = TemplateDraftBlock()
        blocks.append(newBlock)

        Task { @MainActor in
            await Task.yield()
            withAnimation(.easeInOut(duration: 0.2)) {
                scrollProxy.scrollTo(newBlock.id, anchor: .bottom)
            }
        }
    }

    private func deleteBlock(_ blockID: UUID) {
        blocks.removeAll(where: { $0.id == blockID })
    }
}
