import SwiftUI

private enum TodayViewMetrics {
    static let quickStartCardWidth: CGFloat = 238
    static let spotlightCornerRadius: CGFloat = 22
}

private struct SessionStartRequest: Identifiable {
    let planID: UUID
    let templateID: UUID
    let templateName: String

    var id: String {
        "\(planID.uuidString)-\(templateID.uuidString)"
    }
}

struct TodayView: View {
    @Environment(AppStore.self) private var appStore
    @Environment(PlansStore.self) private var plansStore
    @Environment(SessionStore.self) private var sessionStore
    @Environment(SettingsStore.self) private var settingsStore
    @Environment(TodayStore.self) private var todayStore
    @Environment(ProgressStore.self) private var progressStore

    @State private var pendingStartRequest: SessionStartRequest?

    private var activeDraft: SessionDraft? {
        sessionStore.activeDraft
    }

    private var weightUnit: WeightUnit {
        settingsStore.weightUnit
    }

    private func startOrConfirmSession(planID: UUID, templateID: UUID, templateName: String) {
        if activeDraft?.planID == planID, activeDraft?.templateID == templateID {
            appStore.resumeActiveSession()
            return
        }

        guard activeDraft != nil else {
            appStore.startSession(planID: planID, templateID: templateID)
            return
        }

        pendingStartRequest = SessionStartRequest(
            planID: planID,
            templateID: templateID,
            templateName: templateName
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    LazyVStack(spacing: 18) {
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
                                message: "Finish onboarding or create a template in Plans to get a pinned next workout.",
                                tone: .today
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
            .confirmationDialog(
                "Replace current session?",
                isPresented: Binding(
                    get: { pendingStartRequest != nil },
                    set: { isPresented in
                        if !isPresented {
                            pendingStartRequest = nil
                        }
                    }
                ),
                titleVisibility: .visible
            ) {
                if let pendingStartRequest {
                    Button("Resume Current Session") {
                        appStore.resumeActiveSession()
                        self.pendingStartRequest = nil
                    }

                    Button("Replace and Start \(pendingStartRequest.templateName)", role: .destructive) {
                        appStore.replaceActiveSessionAndStart(
                            planID: pendingStartRequest.planID,
                            templateID: pendingStartRequest.templateID
                        )
                        self.pendingStartRequest = nil
                    }
                }

                Button("Cancel", role: .cancel) {
                    pendingStartRequest = nil
                }
            } message: {
                if let activeDraft, let pendingStartRequest {
                    Text(
                        "\(activeDraft.templateNameSnapshot) is still autosaved. Replacing it will discard that session and start \(pendingStartRequest.templateName) instead."
                    )
                }
            }
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
                ),
            ],
            tone: .today
        )
    }

    private func resumeCard(_ draft: SessionDraft) -> some View {
        let completedSetCount = draft.blocks.reduce(0) { partialResult, block in
            partialResult + block.sets.filter(\.log.isCompleted).count
        }

        return TodaySpotlightCard(tone: .today) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        AppStatePill(title: "Autosaved", systemImage: "bolt.fill", tone: .warning)

                        Text(draft.templateNameSnapshot)
                            .font(.system(.title2, design: .rounded).weight(.bold))
                            .foregroundStyle(AppColors.textPrimary)

                        Text("Last updated \(draft.lastUpdatedAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    Spacer(minLength: 12)

                    VStack(alignment: .trailing, spacing: 8) {
                        MetricBadge(
                            label: "Blocks",
                            value: "\(draft.blocks.count)",
                            systemImage: "square.grid.2x2",
                            tone: .today
                        )
                        MetricBadge(
                            label: "Logged",
                            value: "\(completedSetCount)",
                            systemImage: "checklist",
                            tone: .success
                        )
                    }
                }

                Text("Jump back into the logger with every set, note, and timer exactly where you left it.")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)

                Button {
                    appStore.resumeActiveSession()
                } label: {
                    Label("Resume Session", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 16))
                .tint(AppToneStyle.today.accent)
                .controlSize(.large)
                .accessibilityIdentifier("today.resumeSessionButton")
            }
        }
    }

    private func pinnedTemplateCard(_ reference: TemplateReference) -> some View {
        let usesStartingStrengthRotation = TemplateReferenceSelection.isStartingStrengthPlan(
            plansStore.plan(for: reference.planID)
        )

        return TodaySpotlightCard(tone: .plans) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        AppStatePill(title: "Pinned Next", systemImage: "pin.fill", tone: .plans)

                        Text(reference.templateName)
                            .font(.system(.title2, design: .rounded).weight(.bold))
                            .foregroundStyle(AppColors.textPrimary)

                        Text(reference.planName)
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    Spacer(minLength: 12)

                    Image(systemName: "figure.run")
                        .font(.system(size: 30, weight: .semibold))
                        .foregroundStyle(AppToneStyle.plans.accent)
                        .padding(12)
                        .appInsetCard(cornerRadius: 16, fill: AppToneStyle.plans.softFill, border: AppToneStyle.plans.softBorder)
                }

                if usesStartingStrengthRotation {
                    Text("A/B rotation keeps this aligned with the last Starting Strength session you finished.")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                } else if reference.scheduledWeekdays.isEmpty {
                    Text("No weekday pin yet. Keep this as your default whenever you want a fast start.")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                } else {
                    HStack(spacing: 8) {
                        ForEach(reference.scheduledWeekdays) { weekday in
                            Text(weekday.shortLabel)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppToneStyle.plans.accent)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .appInsetCard(
                                    cornerRadius: 999,
                                    fill: AppToneStyle.plans.softFill.opacity(0.8),
                                    border: AppToneStyle.plans.softBorder
                                )
                        }
                    }
                }

                Text("Start straight from Today and drop into the workout logger immediately.")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)

                Button {
                    startOrConfirmSession(
                        planID: reference.planID,
                        templateID: reference.templateID,
                        templateName: reference.templateName
                    )
                } label: {
                    Label("Start Workout", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 16))
                .tint(AppToneStyle.today.accent)
                .controlSize(.large)
                .accessibilityIdentifier("today.pinnedStartButton")
            }
        }
    }

    private var quickStartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppSectionHeader(
                title: "Quick Start",
                systemImage: "bolt",
                subtitle: "Templates you launched recently stay close.",
                trailing: todayStore.quickStartTemplates.isEmpty ? nil : "\(todayStore.quickStartTemplates.count)",
                tone: .today
            )

            if todayStore.quickStartTemplates.isEmpty {
                Text("Templates you launch recently will show up here.")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .appSectionSurface()
            } else {
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 12) {
                        ForEach(todayStore.quickStartTemplates) { reference in
                            Button {
                                startOrConfirmSession(
                                    planID: reference.planID,
                                    templateID: reference.templateID,
                                    templateName: reference.templateName
                                )
                            } label: {
                                TodayQuickStartTile(reference: reference)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("today.quickStart.\(reference.templateID.uuidString)")
                        }
                    }
                    .padding(.vertical, 2)
                }
                .scrollIndicators(.hidden)
            }
        }
    }

    private var recentPRSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppSectionHeader(
                title: "Recent PRs",
                systemImage: "rosette",
                subtitle: "Your latest high points stay visible after every session.",
                trailing: todayStore.recentPersonalRecords.isEmpty ? nil : "\(todayStore.recentPersonalRecords.count)",
                tone: .success
            )

            if todayStore.recentPersonalRecords.isEmpty {
                Text("Finish sessions and the latest PRs will appear here.")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(AppCardMetrics.compactPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .appSurface(cornerRadius: AppCardMetrics.compactCornerRadius, shadow: false)
            } else {
                ForEach(todayStore.recentPersonalRecords) { record in
                    PersonalRecordSummaryCardView(record: record, weightUnit: weightUnit, tone: .success)
                }
            }
        }
    }

    private var recentSessionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppSectionHeader(
                title: "Recent Sessions",
                systemImage: "clock.arrow.circlepath",
                subtitle: "Keep momentum by reliving the last few workouts at a glance.",
                trailing: todayStore.recentSessions.isEmpty ? nil : "\(todayStore.recentSessions.count)",
                tone: .progress
            )

            if todayStore.recentSessions.isEmpty {
                Text("Your finished workouts will show up here.")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                    .padding(AppCardMetrics.compactPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .appSurface(cornerRadius: AppCardMetrics.compactCornerRadius, shadow: false)
            } else {
                ForEach(todayStore.recentSessions) { session in
                    CompletedSessionSummaryCardView(session: session, detailSuffix: " logged", tone: .progress)
                }
            }
        }
    }
}

private struct TodaySpotlightCard<Content: View>: View {
    let tone: AppToneStyle
    let content: Content

    init(tone: AppToneStyle, @ViewBuilder content: () -> Content) {
        self.tone = tone
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: TodayViewMetrics.spotlightCornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    AppColors.chrome.opacity(0.94),
                                    tone.softFill.opacity(0.95),
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    RoundedRectangle(cornerRadius: TodayViewMetrics.spotlightCornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .opacity(0.2)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: TodayViewMetrics.spotlightCornerRadius, style: .continuous)
                    .stroke(tone.softBorder, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.18), radius: 16, x: 0, y: 10)
    }
}

private struct TodayQuickStartTile: View {
    let reference: TemplateReference

    private var visibleWeekdays: [Weekday] {
        Array(reference.scheduledWeekdays.prefix(4))
    }

    var body: some View {
        TodaySpotlightCard(tone: .plans) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top) {
                    AppStatePill(title: "Quick Start", systemImage: "bolt.fill", tone: .today)

                    Spacer()

                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(AppToneStyle.today.accent)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(reference.templateName)
                        .font(.system(.title3, design: .rounded).weight(.bold))
                        .foregroundStyle(AppColors.textPrimary)
                        .lineLimit(2)

                    Text(reference.planName)
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                if visibleWeekdays.isEmpty {
                    Text("Ready any day")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppToneStyle.plans.accent)
                } else {
                    HStack(spacing: 6) {
                        ForEach(visibleWeekdays) { weekday in
                            Text(weekday.shortLabel)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(AppToneStyle.plans.accent)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .appInsetCard(
                                    cornerRadius: 999,
                                    fill: AppToneStyle.plans.softFill.opacity(0.78),
                                    border: AppToneStyle.plans.softBorder
                                )
                        }
                    }
                }

                if let lastStartedAt = reference.lastStartedAt {
                    Text("Last started \(lastStartedAt.formatted(date: .abbreviated, time: .omitted))")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                } else {
                    Text("Fresh template ready to launch")
                        .font(.caption)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .frame(width: TodayViewMetrics.quickStartCardWidth, alignment: .leading)
            .frame(minHeight: 196, alignment: .leading)
        }
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
    @Environment(SessionStore.self) private var sessionStore

    @State private var editingPlan: Plan?
    @State private var editingTemplateContext: TemplateEditorContext?
    @State private var selectedPresetPack: PresetPack?
    @State private var pendingStartRequest: SessionStartRequest?

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
                                message: "Create a custom plan or install one of the preset packs.",
                                tone: .plans
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
            .confirmationDialog(
                "Replace current session?",
                isPresented: Binding(
                    get: { pendingStartRequest != nil },
                    set: { isPresented in
                        if !isPresented {
                            pendingStartRequest = nil
                        }
                    }
                ),
                titleVisibility: .visible
            ) {
                if let pendingStartRequest {
                    Button("Resume Current Session") {
                        appStore.resumeActiveSession()
                        self.pendingStartRequest = nil
                    }

                    Button("Replace and Start \(pendingStartRequest.templateName)", role: .destructive) {
                        appStore.replaceActiveSessionAndStart(
                            planID: pendingStartRequest.planID,
                            templateID: pendingStartRequest.templateID
                        )
                        self.pendingStartRequest = nil
                    }
                }

                Button("Cancel", role: .cancel) {
                    pendingStartRequest = nil
                }
            } message: {
                if let activeDraft = sessionStore.activeDraft, let pendingStartRequest {
                    Text(
                        "\(activeDraft.templateNameSnapshot) is still autosaved. Replacing it will discard that session and start \(pendingStartRequest.templateName) instead."
                    )
                }
            }
        }
    }

    private func startOrConfirmSession(planID: UUID, templateID: UUID, templateName: String) {
        if sessionStore.activeDraft?.planID == planID, sessionStore.activeDraft?.templateID == templateID {
            appStore.resumeActiveSession()
            return
        }

        guard sessionStore.activeDraft != nil else {
            appStore.startSession(planID: planID, templateID: templateID)
            return
        }

        pendingStartRequest = SessionStartRequest(
            planID: planID,
            templateID: templateID,
            templateName: templateName
        )
    }

    private var plansHero: some View {
        AppHeroCard(
            eyebrow: "Plan Builder",
            title: "\(plansStore.plans.count) plans",
            subtitle:
                "Templates define your future sessions. Schedule them loosely, pin your Today favorite, and start whenever you want.",
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
                ),
            ],
            tone: .plans
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
                .buttonBorderShape(.roundedRectangle(radius: 14))
                .tint(AppToneStyle.plans.accent)
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
                                .foregroundStyle(AppToneStyle.plans.accent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 4)
                                .appInsetCard(
                                    cornerRadius: AppCardMetrics.chipCornerRadius,
                                    fillOpacity: 0.86,
                                    borderOpacity: 0.8,
                                    border: AppToneStyle.plans.softBorder
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

                Button {
                    appStore.pinTemplate(planID: plan.id, templateID: template.id)
                } label: {
                    Image(systemName: plan.pinnedTemplateID == template.id ? "pin.fill" : "pin")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: 12))
                .tint(plan.pinnedTemplateID == template.id ? AppToneStyle.plans.accent : AppColors.textSecondary)
                .accessibilityLabel(plan.pinnedTemplateID == template.id ? "Pinned to Today" : "Pin to Today")
                .accessibilityIdentifier("plans.pinTemplate.\(template.id.uuidString)")
            }

            if !template.scheduledWeekdays.isEmpty {
                HStack(spacing: 8) {
                    ForEach(template.scheduledWeekdays) { weekday in
                        Text(weekday.shortLabel)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppToneStyle.plans.accent)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 5)
                            .appInsetCard(
                                cornerRadius: AppCardMetrics.chipCornerRadius,
                                fillOpacity: 0.82,
                                borderOpacity: 0.75,
                                border: AppToneStyle.plans.softBorder
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

                            Text("\(block.targets.count) sets • \(repSummary(for: block.targets)) reps")
                                .font(.caption)
                                .foregroundStyle(AppColors.textSecondary)

                            if let supersetGroup = block.supersetGroup, !supersetGroup.isEmpty {
                                Text("Superset \(supersetGroup)")
                                    .font(.caption2)
                                    .foregroundStyle(AppToneStyle.plans.accent)
                            }
                        }

                        Spacer()

                        MetricBadge(
                            label: "Rule",
                            value: block.progressionRule.kind.displayLabel,
                            systemImage: "arrow.up.right",
                            tone: .progress
                        )
                    }
                    .appInsetContentCard(fillOpacity: 0.78)
                }
            }

            HStack(spacing: 10) {
                Button {
                    startOrConfirmSession(
                        planID: plan.id,
                        templateID: template.id,
                        templateName: template.name
                    )
                } label: {
                    Label("Start", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.roundedRectangle(radius: 14))
                .tint(AppToneStyle.today.accent)
                .accessibilityIdentifier("plans.startTemplate.\(template.id.uuidString)")

                Button {
                    editingTemplateContext = TemplateEditorContext(planID: plan.id, template: template)
                } label: {
                    Label("Edit", systemImage: "square.and.pencil")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.roundedRectangle(radius: 14))
                .tint(AppToneStyle.plans.accent)

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

    private func repSummary(for targets: [SetTarget]) -> String {
        let labels = targets.reduce(into: [String]()) { partialResult, target in
            let label = target.repRange.displayLabel
            if partialResult.last != label {
                partialResult.append(label)
            }
        }

        return labels.isEmpty ? "-" : labels.joined(separator: "/")
    }
}
