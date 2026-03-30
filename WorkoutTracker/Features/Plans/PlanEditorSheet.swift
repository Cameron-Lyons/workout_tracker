import SwiftUI

struct PlanEditorSheet: View {
    @Environment(\.dismiss) private var dismiss

    let existingPlan: Plan?
    let onSave: (Plan) -> Void

    @State private var name = ""

    private var planTitle: String {
        name.nonEmptyTrimmed ?? existingPlan?.name ?? "Name your program"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    LazyVStack(spacing: 18) {
                        AppHeroCard(
                            eyebrow: existingPlan == nil ? "New Program" : "Edit Program",
                            title: planTitle,
                            subtitle: "Programs keep related templates together so Today stays fast and organized.",
                            systemImage: "list.bullet.rectangle",
                            metrics: [
                                AppHeroMetric(
                                    id: "templates",
                                    label: "Templates",
                                    value: "\(existingPlan?.templates.count ?? 0)",
                                    systemImage: "rectangle.stack"
                                ),
                                AppHeroMetric(
                                    id: "pin",
                                    label: "Pinned",
                                    value: existingPlan?.pinnedTemplateID == nil ? "None" : "Set",
                                    systemImage: "pin"
                                ),
                            ],
                            tone: .plans
                        )

                        VStack(alignment: .leading, spacing: 12) {
                            AppSectionHeader(
                                title: "Program Identity",
                                systemImage: "textformat",
                                subtitle: "Choose a short name you will recognize from Today and Programs.",
                                tone: .plans
                            )

                            TextField("Program name", text: $name)
                                .textInputAutocapitalization(.words)
                                .foregroundStyle(AppColors.textPrimary)
                                .appInputField()

                            Text("Examples: Upper / Lower, Garage Gym, Travel Split.")
                                .font(.caption)
                                .foregroundStyle(AppColors.textSecondary)
                        }
                        .appSectionFrame(tone: .plans)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle(existingPlan == nil ? "New Program" : "Edit Program")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        let trimmedName = name.nonEmptyTrimmed ?? ""
                        guard !trimmedName.isEmpty else {
                            return
                        }

                        onSave(
                            Plan(
                                id: existingPlan?.id ?? UUID(),
                                name: trimmedName,
                                createdAt: existingPlan?.createdAt ?? .now,
                                pinnedTemplateID: existingPlan?.pinnedTemplateID,
                                templates: existingPlan?.templates ?? []
                            )
                        )
                        dismiss()
                    }
                    .disabled(name.nonEmptyTrimmed == nil)
                }
            }
            .onAppear {
                name = existingPlan?.name ?? ""
            }
        }
    }
}
