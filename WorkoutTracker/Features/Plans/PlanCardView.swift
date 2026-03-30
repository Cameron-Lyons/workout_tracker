import SwiftUI

struct PlanCardView: View {
    @Environment(AppStore.self) private var appStore

    let plan: Plan
    let activeDraft: SessionDraft?
    @Binding var editingPlan: Plan?
    @Binding var editingTemplateContext: TemplateEditorContext?
    @Binding var pendingStartRequest: SessionStartRequest?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(plan.name)
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(AppColors.textPrimary)

                    Text("\(plan.templates.count) template\(plan.templates.count == 1 ? "" : "s")")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer()

                Button {
                    editingTemplateContext = TemplateEditorContext(planID: plan.id, template: nil)
                } label: {
                    Label("Add Template", systemImage: "plus")
                }
                .appSecondaryActionButton(tone: .plans)
                .accessibilityIdentifier("plans.addTemplateButton.\(plan.id.uuidString)")

                Menu {
                    Button("Edit Plan", systemImage: "square.and.pencil") {
                        editingPlan = plan
                    }
                    Button("Delete Plan", systemImage: "trash", role: .destructive) {
                        appStore.deletePlan(plan.id)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(AppColors.textSecondary)
                }
            }

            if plan.templates.isEmpty {
                Text("This plan has no templates yet.")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(plan.templates.enumerated()), id: \.element.id) { index, template in
                        TemplateCardView(
                            plan: plan,
                            template: template,
                            activeDraft: activeDraft,
                            editingTemplateContext: $editingTemplateContext,
                            pendingStartRequest: $pendingStartRequest
                        )

                        if index < plan.templates.count - 1 {
                            SectionSurfaceDivider()
                        }
                    }
                }
            }
        }
        .appSectionFrame(tone: .plans, topPadding: 16, bottomPadding: 8)
    }
}

private struct TemplateCardView: View {
    @Environment(AppStore.self) private var appStore

    let plan: Plan
    let template: WorkoutTemplate
    let activeDraft: SessionDraft?
    @Binding var editingTemplateContext: TemplateEditorContext?
    @Binding var pendingStartRequest: SessionStartRequest?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(template.name)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppColors.textPrimary)

                        if plan.pinnedTemplateID == template.id {
                            Text("PINNED")
                                .font(.caption2.weight(.black))
                                .tracking(0.8)
                                .foregroundStyle(AppToneStyle.plans.accent)
                        }
                    }

                    if !template.note.isEmpty {
                        Text(template.note)
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    Text(weekdaySummary(template.scheduledWeekdays, emptyLabel: "ANY DAY"))
                        .font(.caption.weight(.black))
                        .tracking(0.7)
                        .foregroundStyle(AppColors.textPrimary.opacity(0.88))
                }

                Spacer()

                Button {
                    appStore.pinTemplate(planID: plan.id, templateID: template.id)
                } label: {
                    Image(systemName: plan.pinnedTemplateID == template.id ? "pin.fill" : "pin")
                        .font(.subheadline.weight(.semibold))
                }
                .appSecondaryActionButton(tone: .plans, controlSize: .small)
                .accessibilityLabel(plan.pinnedTemplateID == template.id ? "Pinned to Today" : "Pin to Today")
                .accessibilityIdentifier("plans.pinTemplate.\(template.id.uuidString)")
            }

            VStack(spacing: 0) {
                ForEach(Array(template.blocks.enumerated()), id: \.element.id) { index, block in
                    TemplateBlockSummaryRow(block: block)

                    if index < template.blocks.count - 1 {
                        SectionSurfaceDivider()
                    }
                }
            }

            HStack(spacing: 10) {
                Button {
                    handleSessionStart(
                        activeDraft: activeDraft,
                        pendingStartRequest: $pendingStartRequest,
                        planID: plan.id,
                        templateID: template.id,
                        templateName: template.name,
                        onResumeCurrent: {
                            appStore.resumeActiveSession()
                        },
                        onStartNew: { planID, templateID in
                            appStore.startSession(planID: planID, templateID: templateID)
                        }
                    )
                } label: {
                    Label("Start", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .appPrimaryActionButton(tone: .today, controlSize: .regular)
                .accessibilityIdentifier("plans.startTemplate.\(template.id.uuidString)")

                Button {
                    editingTemplateContext = TemplateEditorContext(planID: plan.id, template: template)
                } label: {
                    Label("Edit", systemImage: "square.and.pencil")
                        .frame(maxWidth: .infinity)
                }
                .appSecondaryActionButton(tone: .plans, controlSize: .regular)

                Button(role: .destructive) {
                    appStore.deleteTemplate(planID: plan.id, templateID: template.id)
                } label: {
                    Image(systemName: "trash")
                }
                .appSecondaryActionButton(tone: .danger, controlSize: .regular)
            }
        }
        .padding(.vertical, 14)
    }
}

private struct TemplateBlockSummaryRow: View {
    let block: ExerciseBlock

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(block.exerciseNameSnapshot)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text("\(block.targets.count) sets • \(setTargetRepSummary(for: block.targets)) reps")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)

                if let supersetGroup = block.supersetGroup, !supersetGroup.isEmpty {
                    Text("SUPERSET \(supersetGroup)")
                        .font(.caption2.weight(.black))
                        .tracking(0.7)
                        .foregroundStyle(AppToneStyle.plans.accent)
                }
            }

            Spacer(minLength: 12)

            Text(block.progressionRule.kind.displayLabel.uppercased())
                .font(.caption2.weight(.black))
                .tracking(0.7)
                .foregroundStyle(AppToneStyle.progress.accent)
        }
        .padding(.vertical, 10)
    }
}
