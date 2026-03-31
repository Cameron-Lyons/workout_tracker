import SwiftUI

struct TemplateEditorContext: Identifiable {
    let id: UUID
    var planID: UUID
    var template: WorkoutTemplate?

    init(planID: UUID, template: WorkoutTemplate?) {
        id = template?.id ?? UUID()
        self.planID = planID
        self.template = template
    }
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
                tone: .plans,
                trailingStyle: .plain
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
        Button(action: onAdd) {
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

                Image(systemName: "plus")
                    .font(.title3.weight(.black))
                    .frame(width: 28, height: 28)
                    .foregroundStyle(AppToneStyle.plans.accent)
                    .padding(.top, 2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add \(pack.displayName)")
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
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if plansStore.planSummaries.isEmpty {
                            AvailableProgramsSectionView(
                                presetPacks: availablePrograms,
                                onSelectPack: { pack in
                                    selectedPresetPack = pack
                                }
                            )
                        }

                        AppSectionHeader(
                            title: "Your Programs",
                            systemImage: "list.bullet.rectangle",
                            trailing: "\(plansStore.planCount)",
                            tone: .plans,
                            trailingStyle: .plain
                        )

                        if plansStore.planSummaries.isEmpty {
                            AppEmptyStateCard(
                                systemImage: "list.bullet.rectangle",
                                title: "No programs yet",
                                message: "Create a custom program or add one of the available programs above.",
                                tone: .plans
                            )
                        } else {
                            ForEach(plansStore.planSummaries) { plan in
                                PlanCardView(
                                    plan: plan,
                                    activeDraft: activeDraft,
                                    editingPlan: $editingPlan,
                                    editingTemplateContext: $editingTemplateContext,
                                    pendingStartRequest: $pendingStartRequest
                                )
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Programs")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            editingPlan = appStore.makePlan(name: "")
                        } label: {
                            Label("New Program", systemImage: "square.and.pencil")
                        }

                        Divider()

                        ForEach(availablePrograms, id: \.rawValue) { pack in
                            Button {
                                selectedPresetPack = pack
                            } label: {
                                Label("Add \(pack.displayName)", systemImage: pack.systemImage)
                            }
                        }
                    } label: {
                        Image(systemName: "plus")
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
                    Task { @MainActor in
                        await appStore.preparePlanInteractionDataIfNeeded()
                        appStore.replaceActiveSessionAndStart(
                            planID: request.planID,
                            templateID: request.templateID
                        )
                    }
                }
            )
        }
    }
}
