import SwiftUI

struct TemplateEditorContext: Identifiable {
    var id: UUID {
        template?.id ?? UUID()
    }

    var planID: UUID
    var template: WorkoutTemplate?
}

private struct PlansLibraryLoadingCard: View {
    var body: some View {
        VStack(spacing: 14) {
            ProgressView()
                .progressViewStyle(.circular)
                .tint(AppColors.accentPlans)
                .scaleEffect(1.08)

            Text("Loading plans...")
                .font(.headline.weight(.bold))
                .foregroundStyle(AppColors.textPrimary)

            Text("The full plan library is hydrating in the background so launch stays fast.")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(AppColors.textSecondary)
        }
        .padding(.vertical, 22)
        .padding(.horizontal, 24)
        .appSurface(cornerRadius: AppCardMetrics.featureCornerRadius, shadow: false, tone: .plans)
        .padding(.horizontal, 24)
    }
}

struct PlansView: View {
    @Environment(AppStore.self) private var appStore
    @Environment(PlansStore.self) private var plansStore
    @Environment(SessionStore.self) private var sessionStore

    @State private var editingPlan: Plan?
    @State private var editingTemplateContext: TemplateEditorContext?
    @State private var selectedPresetPack: PresetPack?
    @State private var pendingStartRequest: SessionStartRequest?

    private var activeDraft: SessionDraft? {
        sessionStore.activeDraft
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                if plansStore.hasLoadedPlanLibrary == false {
                    PlansLibraryLoadingCard()
                } else {
                    ScrollView {
                        LazyVStack(spacing: 16) {
                            PlansHeroCardView()
                                .appReveal(delay: 0.01)

                            if plansStore.plans.isEmpty {
                                AppEmptyStateCard(
                                    systemImage: "list.bullet.rectangle",
                                    title: "No plans yet",
                                    message: "Create a custom plan or install one of the preset packs.",
                                    tone: .plans
                                )
                                .appReveal(delay: 0.03)
                            } else {
                                ForEach(plansStore.plans) { plan in
                                    PlanCardView(
                                        plan: plan,
                                        activeDraft: activeDraft,
                                        editingPlan: $editingPlan,
                                        editingTemplateContext: $editingTemplateContext,
                                        pendingStartRequest: $pendingStartRequest
                                    )
                                    .appReveal(delay: 0.03)
                                }
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .navigationTitle("Plans")
            .task {
                await appStore.loadPlanLibraryIfNeeded(priority: .userInitiated)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        ForEach(PresetPack.allCases) { pack in
                            Button(pack.displayName, systemImage: pack.systemImage) {
                                selectedPresetPack = pack
                            }
                        }
                    } label: {
                        Label("Preset", systemImage: "sparkles")
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editingPlan = appStore.makePlan(name: "")
                    } label: {
                        Label("Plan", systemImage: "plus")
                    }
                    .accessibilityIdentifier("plans.addPlanButton")
                }
            }
            .sheet(item: $editingPlan) { plan in
                PlanEditorSheet(existingPlan: plan.name.isEmpty ? nil : plan) { savedPlan in
                    appStore.savePlan(savedPlan)
                }
            }
            .sheet(item: $editingTemplateContext) { context in
                TemplateEditorSheet(
                    existingTemplate: context.template
                ) { template, profiles in
                    appStore.saveProfiles(profiles)
                    appStore.saveTemplate(planID: context.planID, template: template)
                }
            }
            .confirmationDialog(
                "Install preset pack",
                isPresented: Binding(
                    get: { selectedPresetPack != nil },
                    set: { isPresented in
                        if !isPresented {
                            selectedPresetPack = nil
                        }
                    }
                ),
                titleVisibility: .visible
            ) {
                if let selectedPresetPack {
                    Button("Add \(selectedPresetPack.displayName)") {
                        appStore.plansStore.addPresetPack(selectedPresetPack, settings: appStore.settingsStore)
                        appStore.refreshTodayStore()
                    }
                }

                Button("Cancel", role: .cancel) {
                    selectedPresetPack = nil
                }
            } message: {
                Text(selectedPresetPack?.description ?? "")
            }
            .sessionStartConfirmationDialog(
                pendingStartRequest: $pendingStartRequest,
                activeDraft: activeDraft,
                onResumeCurrent: {
                    appStore.resumeActiveSession()
                },
                onReplace: { request in
                    appStore.replaceActiveSessionAndStart(
                        planID: request.planID,
                        templateID: request.templateID
                    )
                }
            )
        }
    }
}
