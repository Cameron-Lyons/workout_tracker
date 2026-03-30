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

            Text("Loading programs...")
                .font(.headline.weight(.bold))
                .foregroundStyle(AppColors.textPrimary)

            Text("The full program library is hydrating in the background so launch stays fast.")
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

private struct AvailableProgramsSectionView: View {
    let presetPacks: [PresetPack]
    let onSelectPack: (PresetPack) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            AppSectionHeader(
                title: "Available Programs",
                systemImage: "square.grid.2x2",
                subtitle: "Install one of the starter programs directly from here.",
                trailing: "\(presetPacks.count)",
                tone: .plans
            )

            VStack(spacing: 0) {
                ForEach(Array(presetPacks.enumerated()), id: \.element.id) { index, pack in
                    AvailableProgramRow(pack: pack) {
                        onSelectPack(pack)
                    }

                    if index < presetPacks.count - 1 {
                        SectionSurfaceDivider()
                    }
                }
            }
            .appSectionFrame(tone: .plans, topPadding: 8, bottomPadding: 8)
        }
    }
}

private struct AvailableProgramRow: View {
    let pack: PresetPack
    let onAdd: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: pack.systemImage)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(AppToneStyle.plans.accent)
                .frame(width: 42, height: 42)
                .appInsetCard(
                    cornerRadius: 10,
                    fill: AppToneStyle.plans.softFill.opacity(0.72),
                    border: AppToneStyle.plans.softBorder
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(pack.displayName)
                    .font(.headline.weight(.black))
                    .foregroundStyle(AppColors.textPrimary)

                Text(pack.description)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)

            Spacer(minLength: 12)

            Button {
                onAdd()
            } label: {
                Label("Add", systemImage: "plus")
            }
            .appSecondaryActionButton(tone: .plans, controlSize: .small)
            .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
        .accessibilityIdentifier("programs.preset.\(pack.rawValue)")
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

    private let availablePrograms = PresetPack.allCases

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
                                AvailableProgramsSectionView(
                                    presetPacks: availablePrograms,
                                    onSelectPack: { pack in
                                        selectedPresetPack = pack
                                    }
                                )
                                .appReveal(delay: 0.03)
                            }

                            AppSectionHeader(
                                title: "Your Programs",
                                systemImage: "list.bullet.rectangle",
                                subtitle: "Build custom programs and manage the ones you add.",
                                trailing: "\(plansStore.planCount)",
                                tone: .plans
                            )
                            .appReveal(delay: plansStore.plans.isEmpty ? 0.05 : 0.03)

                            if plansStore.plans.isEmpty {
                                AppEmptyStateCard(
                                    systemImage: "list.bullet.rectangle",
                                    title: "No programs yet",
                                    message: "Create a custom program or add one of the available programs above.",
                                    tone: .plans
                                )
                                .appReveal(delay: 0.07)
                            } else {
                                ForEach(plansStore.plans) { plan in
                                    PlanCardView(
                                        plan: plan,
                                        activeDraft: activeDraft,
                                        editingPlan: $editingPlan,
                                        editingTemplateContext: $editingTemplateContext,
                                        pendingStartRequest: $pendingStartRequest
                                    )
                                    .appReveal(delay: 0.07)
                                }

                                AvailableProgramsSectionView(
                                    presetPacks: availablePrograms,
                                    onSelectPack: { pack in
                                        selectedPresetPack = pack
                                    }
                                )
                                .appReveal(delay: 0.09)
                            }
                        }
                        .padding(.horizontal, 14)
                        .padding(.vertical, 14)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .navigationTitle("Programs")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                await appStore.loadPlanLibraryIfNeeded(priority: .userInitiated)
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        editingPlan = appStore.makePlan(name: "")
                    } label: {
                        Label("Program", systemImage: "plus")
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
                "Add program",
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
