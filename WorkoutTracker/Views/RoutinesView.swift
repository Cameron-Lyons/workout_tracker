import SwiftUI

struct TodayView: View {
    @Environment(AppStore.self) private var appStore
    @Environment(PlansStore.self) private var plansStore
    @Environment(SessionStore.self) private var sessionStore
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(TodayStore.self) private var todayStore
    @Environment(ProgressStore.self) private var progressStore

    private var activeDraft: SessionDraft? {
        sessionStore.activeDraft
    }

    private var weightUnit: WeightUnit {
        settingsStore.weightUnit
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    LazyVStack(spacing: 16) {
                        heroCard
                            .appReveal(delay: 0.01)

                        if let activeDraft {
                            resumeCard(activeDraft)
                                .appReveal(delay: 0.03)
                        } else if let pinnedTemplate = todayStore.pinnedTemplate {
                            pinnedTemplateCard(pinnedTemplate)
                                .appReveal(delay: 0.03)
                        } else {
                            AppEmptyStateCard(
                                systemImage: "sparkles.rectangle.stack",
                                title: "Start from a plan",
                                message: "Finish onboarding or create a template in Plans to get a pinned next workout."
                            )
                            .appReveal(delay: 0.03)
                        }

                        quickStartSection
                            .appReveal(delay: 0.05)

                        recentPRSection
                            .appReveal(delay: 0.07)

                        recentSessionsSection
                            .appReveal(delay: 0.09)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Today")
            .toolbarBackground(AppColors.chrome, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
    }

    private var heroCard: some View {
        let sessionsLast30 = progressStore.overview.sessionsLast30Days
        let recentPRCount = todayStore.recentPersonalRecords.count
        let activeStatus = activeDraft == nil ? "Ready" : "In Progress"

        return AppHeroCard(
            eyebrow: "Session-First Logger",
            title: activeDraft?.templateNameSnapshot ?? "Ready to train",
            subtitle: activeDraft == nil
                ? "Start from a pinned template, relaunch a recent session, or jump into Plans to build something custom."
                : "Your active session is autosaved after every change. Resume exactly where you left it.",
            systemImage: "figure.strengthtraining.traditional",
            metrics: [
                AppHeroMetric(
                    id: "status",
                    label: "Status",
                    value: activeStatus,
                    systemImage: "play.circle"
                ),
                AppHeroMetric(
                    id: "plans",
                    label: "Templates",
                    value: "\(plansStore.templateReferenceCount)",
                    systemImage: "rectangle.stack"
                ),
                AppHeroMetric(
                    id: "sessions",
                    label: "Last 30d",
                    value: "\(sessionsLast30)",
                    systemImage: "calendar"
                ),
                AppHeroMetric(
                    id: "records",
                    label: "Recent PRs",
                    value: "\(recentPRCount)",
                    systemImage: "rosette"
                )
            ]
        )
    }

    private func resumeCard(_ draft: SessionDraft) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Active Session")
                        .font(.caption.weight(.semibold))
                        .tracking(0.6)
                        .foregroundStyle(AppColors.textSecondary)

                    Text(draft.templateNameSnapshot)
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(AppColors.textPrimary)

                    Text("Last updated \(draft.lastUpdatedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer()

                MetricBadge(
                    label: "Blocks",
                    value: "\(draft.blocks.count)",
                    systemImage: "square.grid.2x2"
                )
            }

            Button {
                appStore.resumeActiveSession()
            } label: {
                Label("Resume Session", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColors.accent)
            .accessibilityIdentifier("today.resumeSessionButton")
        }
        .appFeatureSurface()
    }

    private func pinnedTemplateCard(_ reference: TemplateReference) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Pinned Next Workout")
                .font(.caption.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(AppColors.textSecondary)

            Text(reference.templateName)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundStyle(AppColors.textPrimary)

            Text(reference.planName)
                .font(.subheadline)
                .foregroundStyle(AppColors.textSecondary)

            HStack(spacing: 8) {
                ForEach(reference.scheduledWeekdays) { weekday in
                        Text(weekday.shortLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppColors.accent)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .appInsetCard(
                                cornerRadius: AppCardMetrics.chipCornerRadius,
                                fillOpacity: 0.8,
                                borderOpacity: 0.65
                            )
                }
            }

            Button {
                appStore.startSession(planID: reference.planID, templateID: reference.templateID)
            } label: {
                Label("Start \(reference.templateName)", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(AppColors.accent)
            .accessibilityIdentifier("today.pinnedStartButton")
        }
        .appFeatureSurface()
    }

    private var quickStartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Quick Start", systemImage: "bolt")

            if todayStore.quickStartTemplates.isEmpty {
                Text("Templates you start most often will show up here.")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .appSectionSurface()
            } else {
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)],
                    spacing: 12
                ) {
                    ForEach(todayStore.quickStartTemplates) { reference in
                        Button {
                            appStore.startSession(planID: reference.planID, templateID: reference.templateID)
                        } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                Text(reference.templateName)
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(AppColors.textPrimary)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                Text(reference.planName)
                                    .font(.caption)
                                    .foregroundStyle(AppColors.textSecondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                if let lastStartedAt = reference.lastStartedAt {
                                    Text("Last started \(lastStartedAt.formatted(date: .abbreviated, time: .omitted))")
                                        .font(.caption2)
                                        .foregroundStyle(AppColors.textSecondary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .appSectionSurface()
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("today.quickStart.\(reference.templateID.uuidString)")
                    }
                }
            }
        }
    }

    private var recentPRSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Recent PRs", systemImage: "rosette")

            if todayStore.recentPersonalRecords.isEmpty {
                Text("Finish sessions and the latest PRs will appear here.")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(AppCardMetrics.compactPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .appSurface(cornerRadius: AppCardMetrics.compactCornerRadius, shadow: false)
            } else {
                ForEach(todayStore.recentPersonalRecords) { record in
                    PersonalRecordSummaryCardView(record: record, weightUnit: weightUnit)
                }
            }
        }
    }

    private var recentSessionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionLabel("Recent Sessions", systemImage: "clock.arrow.circlepath")

            if todayStore.recentSessions.isEmpty {
                Text("Your finished workouts will show up here.")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(AppCardMetrics.compactPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .appSurface(cornerRadius: AppCardMetrics.compactCornerRadius, shadow: false)
            } else {
                ForEach(todayStore.recentSessions) { session in
                    CompletedSessionSummaryCardView(session: session, detailSuffix: " logged")
                }
            }
        }
    }

    private func sectionLabel(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.headline.weight(.semibold))
            .foregroundStyle(AppColors.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TemplateEditorContext: Identifiable {
    var id: UUID {
        template?.id ?? UUID()
    }

    var planID: UUID
    var template: WorkoutTemplate?
}

struct PlansView: View {
    @Environment(AppStore.self) private var appStore
    @Environment(PlansStore.self) private var plansStore

    @State private var editingPlan: Plan?
    @State private var editingTemplateContext: TemplateEditorContext?
    @State private var selectedPresetPack: PresetPack?

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    LazyVStack(spacing: 16) {
                        plansHero
                            .appReveal(delay: 0.01)

                        if plansStore.plans.isEmpty {
                            AppEmptyStateCard(
                                systemImage: "list.bullet.rectangle",
                                title: "No plans yet",
                                message: "Create a custom plan or install one of the preset packs."
                            )
                            .appReveal(delay: 0.03)
                        } else {
                            ForEach(plansStore.plans) { plan in
                                planCard(plan)
                                    .appReveal(delay: 0.03)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 14)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Plans")
            .toolbarBackground(AppColors.chrome, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
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
        }
    }

    private var plansHero: some View {
        AppHeroCard(
            eyebrow: "Plan Builder",
            title: "\(plansStore.plans.count) plans",
            subtitle: "Templates define your future sessions. Schedule them loosely, pin the important ones, and start from Today whenever you want.",
            systemImage: "list.bullet.rectangle",
            metrics: [
                AppHeroMetric(
                    id: "plans",
                    label: "Plans",
                    value: "\(plansStore.plans.count)",
                    systemImage: "list.bullet"
                ),
                AppHeroMetric(
                    id: "templates",
                    label: "Templates",
                    value: "\(plansStore.templateReferenceCount)",
                    systemImage: "rectangle.stack"
                ),
                AppHeroMetric(
                    id: "catalog",
                    label: "Exercises",
                    value: "\(plansStore.catalog.count)",
                    systemImage: "dumbbell"
                ),
                AppHeroMetric(
                    id: "profiles",
                    label: "Profiles",
                    value: "\(plansStore.profiles.count)",
                    systemImage: "slider.horizontal.3"
                )
            ]
        )
    }

    private func planCard(_ plan: Plan) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(plan.name)
                        .font(.system(.title3, design: .rounded).weight(.bold))
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
                .buttonStyle(.bordered)
                .tint(AppColors.accent)
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
                    .appInsetContentCard(borderOpacity: 0.65)
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(plan.templates) { template in
                        templateCard(plan: plan, template: template)
                    }
                }
            }
        }
        .appFeatureSurface()
    }

    private func templateCard(plan: Plan, template: WorkoutTemplate) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Text(template.name)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(AppColors.textPrimary)

                        if plan.pinnedTemplateID == template.id {
                                Text("PINNED")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(AppColors.accent)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 4)
                                    .appInsetCard(
                                        cornerRadius: AppCardMetrics.chipCornerRadius,
                                        fillOpacity: 0.86,
                                        borderOpacity: 0.8
                                    )
                        }
                    }

                    if !template.note.isEmpty {
                        Text(template.note)
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }

                Spacer()
            }

            if !template.scheduledWeekdays.isEmpty {
                HStack(spacing: 8) {
                    ForEach(template.scheduledWeekdays) { weekday in
                        Text(weekday.shortLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppColors.accent)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 5)
                            .appInsetCard(
                                cornerRadius: AppCardMetrics.chipCornerRadius,
                                fillOpacity: 0.82,
                                borderOpacity: 0.75
                            )
                    }
                }
            }

            LazyVStack(spacing: 10) {
                ForEach(template.blocks) { block in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(block.exerciseNameSnapshot)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(AppColors.textPrimary)

                            Text("\(block.targets.count) sets • \(block.targets.first?.repRange.displayLabel ?? "-") reps")
                                .font(.caption)
                                .foregroundStyle(AppColors.textSecondary)

                            if let supersetGroup = block.supersetGroup, !supersetGroup.isEmpty {
                                Text("Superset \(supersetGroup)")
                                    .font(.caption2)
                                    .foregroundStyle(AppColors.accent)
                            }
                        }

                        Spacer()

                        MetricBadge(
                            label: "Rule",
                            value: block.progressionRule.kind.displayLabel,
                            systemImage: "arrow.up.right"
                        )
                    }
                    .appInsetContentCard(fillOpacity: 0.78)
                }
            }

            HStack(spacing: 10) {
                Button {
                    appStore.startSession(planID: plan.id, templateID: template.id)
                } label: {
                    Label("Start", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppColors.accent)
                .accessibilityIdentifier("plans.startTemplate.\(template.id.uuidString)")

                Button {
                    editingTemplateContext = TemplateEditorContext(planID: plan.id, template: template)
                } label: {
                    Label("Edit", systemImage: "square.and.pencil")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(AppColors.accent)

                Button(role: .destructive) {
                    appStore.deleteTemplate(planID: plan.id, templateID: template.id)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)
            }
        }
        .appEditorInsetCard()
    }
}
