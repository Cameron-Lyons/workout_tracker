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
                    Image(systemName: "plus")
                        .font(.title3.weight(.black))
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .foregroundStyle(AppToneStyle.plans.accent)
                .accessibilityLabel("Add Template")
                .accessibilityIdentifier("plans.addTemplateButton.\(plan.id.uuidString)")

                Menu {
                    Button("Edit Program", systemImage: "square.and.pencil") {
                        editingPlan = plan
                    }
                    Button("Delete Program", systemImage: "trash", role: .destructive) {
                        appStore.deletePlan(plan.id)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(AppColors.textSecondary)
                }
            }

            if plan.templates.isEmpty {
                Text("This program has no templates yet.")
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

    private var isPinned: Bool {
        plan.pinnedTemplateID == template.id
    }

    private var detailLine: String {
        var parts: [String] = []

        if !template.note.isEmpty {
            parts.append(template.note)
        }

        let scheduleSummary = weekdaySummary(template.scheduledWeekdays, emptyLabel: "")
        if !scheduleSummary.isEmpty {
            parts.append(scheduleSummary)
        }

        parts.append("\(template.blocks.count) exercise\(template.blocks.count == 1 ? "" : "s")")
        return parts.joined(separator: " • ")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(template.name)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(AppColors.textPrimary)

                    if isPinned {
                        AppStatePill(title: "Pinned", systemImage: "pin.fill", tone: .plans, style: .plain)
                    }
                }

                Text(detailLine)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            HStack(spacing: 8) {
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
                }
                .appPrimaryActionButton(tone: .today, controlSize: .small)
                .accessibilityIdentifier("plans.startTemplate.\(template.id.uuidString)")

                Menu {
                    Button(
                        isPinned ? "Pinned to Today" : "Pin to Today",
                        systemImage: isPinned ? "pin.fill" : "pin"
                    ) {
                        appStore.pinTemplate(planID: plan.id, templateID: template.id)
                    }

                    Button("Edit Template", systemImage: "square.and.pencil") {
                        editingTemplateContext = TemplateEditorContext(planID: plan.id, template: template)
                    }

                    Button("Delete Template", systemImage: "trash", role: .destructive) {
                        appStore.deleteTemplate(planID: plan.id, templateID: template.id)
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(AppColors.textSecondary)
                }
                .accessibilityIdentifier("plans.pinTemplate.\(template.id.uuidString)")
            }
        }
        .padding(.vertical, 14)
    }
}
