import SwiftUI

private enum TodayViewMetrics {
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

private func handleSessionStart(
    activeDraft: SessionDraft?,
    pendingStartRequest: Binding<SessionStartRequest?>,
    planID: UUID,
    templateID: UUID,
    templateName: String,
    onResumeCurrent: () -> Void,
    onStartNew: (_ planID: UUID, _ templateID: UUID) -> Void
) {
    if activeDraft?.planID == planID, activeDraft?.templateID == templateID {
        onResumeCurrent()
        return
    }

    guard activeDraft != nil else {
        onStartNew(planID, templateID)
        return
    }

    pendingStartRequest.wrappedValue = SessionStartRequest(
        planID: planID,
        templateID: templateID,
        templateName: templateName
    )
}

private func setTargetRepSummary(for targets: [SetTarget]) -> String {
    let labels = targets.reduce(into: [String]()) { partialResult, target in
        let label = target.repRange.displayLabel
        if partialResult.last != label {
            partialResult.append(label)
        }
    }

    return labels.isEmpty ? "-" : labels.joined(separator: "/")
}

private func weekdaySummary(_ weekdays: [Weekday], emptyLabel: String) -> String {
    guard !weekdays.isEmpty else {
        return emptyLabel
    }

    return weekdays.map { $0.shortLabel.uppercased() }.joined(separator: " • ")
}

private struct SessionStartConfirmationDialogModifier: ViewModifier {
    @Binding var pendingStartRequest: SessionStartRequest?
    let activeDraft: SessionDraft?
    let onResumeCurrent: () -> Void
    let onReplace: (_ request: SessionStartRequest) -> Void

    func body(content: Content) -> some View {
        content.confirmationDialog(
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
                    onResumeCurrent()
                    self.pendingStartRequest = nil
                }

                Button("Replace and Start \(pendingStartRequest.templateName)", role: .destructive) {
                    onReplace(pendingStartRequest)
                    self.pendingStartRequest = nil
                }
            }

            Button("Cancel", role: .cancel) {
                pendingStartRequest = nil
            }
        } message: {
            if let activeDraft, let pendingStartRequest {
                Text(
                    "\(activeDraft.templateNameSnapshot) is still autosaved. "
                        + "Replacing it will discard that session and start "
                        + "\(pendingStartRequest.templateName) instead."
                )
            }
        }
    }
}

private extension View {
    func sessionStartConfirmationDialog(
        pendingStartRequest: Binding<SessionStartRequest?>,
        activeDraft: SessionDraft?,
        onResumeCurrent: @escaping () -> Void,
        onReplace: @escaping (_ request: SessionStartRequest) -> Void
    ) -> some View {
        modifier(
            SessionStartConfirmationDialogModifier(
                pendingStartRequest: pendingStartRequest,
                activeDraft: activeDraft,
                onResumeCurrent: onResumeCurrent,
                onReplace: onReplace
            )
        )
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
        let progress = sessionStore.activeDraftProgress

        return TodaySpotlightCard(tone: .today) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        AppStatePill(title: "Autosaved", systemImage: "bolt.fill", tone: .warning)

                        Text(draft.templateNameSnapshot)
                            .font(.system(size: 28, weight: .black))
                            .foregroundStyle(AppColors.textPrimary)

                        Text("Last updated \(draft.lastUpdatedAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    Spacer(minLength: 12)

                    VStack(alignment: .trailing, spacing: 8) {
                        MetricBadge(
                            label: "Blocks",
                            value: "\(progress.blockCount)",
                            systemImage: "square.grid.2x2",
                            tone: .today
                        )
                        MetricBadge(
                            label: "Logged",
                            value: "\(progress.completedSetCount)",
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
                .appPrimaryActionButton(tone: .today)
                .accessibilityIdentifier("today.resumeSessionButton")
            }
        }
    }

    private func pinnedTemplateCard(_ reference: TemplateReference) -> some View {
        let usesAlternatingRotation = TemplateReferenceSelection.isAlternatingPlan(
            plansStore.planSummary(for: reference.planID)
        )

        return TodaySpotlightCard(tone: .plans) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        AppStatePill(title: "Pinned Next", systemImage: "pin.fill", tone: .plans)

                        Text(reference.templateName)
                            .font(.system(size: 28, weight: .black))
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

                if usesAlternatingRotation {
                    Text("A/B rotation keeps this aligned with the last alternating workout you finished.")
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
                    handleSessionStart(
                        activeDraft: activeDraft,
                        pendingStartRequest: $pendingStartRequest,
                        planID: reference.planID,
                        templateID: reference.templateID,
                        templateName: reference.templateName,
                        onResumeCurrent: {
                            appStore.resumeActiveSession()
                        },
                        onStartNew: { planID, templateID in
                            appStore.startSession(planID: planID, templateID: templateID)
                        }
                    )
                } label: {
                    Label("Start Workout", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
                .appPrimaryActionButton(tone: .today)
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
                AppInlineMessage(
                    systemImage: "bolt.fill",
                    title: "No quick starts yet",
                    message: "Templates you launch recently will show up here.",
                    tone: .today
                )
                .appSectionFrame(tone: .today)
            } else {
                TodayGroupedPanel(tone: .today) {
                    VStack(spacing: 0) {
                        ForEach(Array(todayStore.quickStartTemplates.enumerated()), id: \.element.id) { index, reference in
                            Button {
                                handleSessionStart(
                                    activeDraft: activeDraft,
                                    pendingStartRequest: $pendingStartRequest,
                                    planID: reference.planID,
                                    templateID: reference.templateID,
                                    templateName: reference.templateName,
                                    onResumeCurrent: {
                                        appStore.resumeActiveSession()
                                    },
                                    onStartNew: { planID, templateID in
                                        appStore.startSession(planID: planID, templateID: templateID)
                                    }
                                )
                            } label: {
                                TodayQuickStartRow(reference: reference)
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("today.quickStart.\(reference.templateID.uuidString)")

                            if index < todayStore.quickStartTemplates.count - 1 {
                                SectionSurfaceDivider()
                            }
                        }
                    }
                }
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
                AppInlineMessage(
                    systemImage: "rosette",
                    title: "No PRs yet",
                    message: "Finish sessions and the latest PRs will appear here.",
                    tone: .success
                )
                .appSectionFrame(tone: .success)
            } else {
                TodayGroupedPanel(tone: .success) {
                    VStack(spacing: 0) {
                        ForEach(Array(todayStore.recentPersonalRecords.enumerated()), id: \.element.id) { index, record in
                            TodayPersonalRecordRow(record: record, weightUnit: weightUnit, tone: .success)

                            if index < todayStore.recentPersonalRecords.count - 1 {
                                SectionSurfaceDivider()
                            }
                        }
                    }
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
                AppInlineMessage(
                    systemImage: "clock.arrow.circlepath",
                    title: "No sessions logged yet",
                    message: "Your finished workouts will show up here.",
                    tone: .progress
                )
                .appSectionFrame(tone: .progress)
            } else {
                TodayGroupedPanel(tone: .progress) {
                    VStack(spacing: 0) {
                        ForEach(Array(todayStore.recentSessions.enumerated()), id: \.element.id) { index, session in
                            TodayCompletedSessionRow(session: session, tone: .progress)

                            if index < todayStore.recentSessions.count - 1 {
                                SectionSurfaceDivider()
                            }
                        }
                    }
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
            .appSurface(cornerRadius: TodayViewMetrics.spotlightCornerRadius, tone: tone)
    }
}

private struct TodayGroupedPanel<Content: View>: View {
    let tone: AppToneStyle
    let content: Content

    init(tone: AppToneStyle, @ViewBuilder content: () -> Content) {
        self.tone = tone
        self.content = content()
    }

    var body: some View {
        content
            .appSectionFrame(tone: tone, topPadding: 12, bottomPadding: 4)
    }
}

private struct SectionSurfaceDivider: View {
    var body: some View {
        Rectangle()
            .fill(AppColors.stroke.opacity(0.78))
            .frame(height: 1)
    }
}

private struct TodayQuickStartRow: View {
    let reference: TemplateReference

    private var scheduleLabel: String {
        weekdaySummary(reference.scheduledWeekdays, emptyLabel: "READY ANY DAY")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "bolt.fill")
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(AppToneStyle.today.accent)
                .frame(width: 40, height: 40)
                .appInsetCard(
                    cornerRadius: 8,
                    fill: AppToneStyle.today.softFill.opacity(0.78),
                    border: AppToneStyle.today.softBorder
                )

            VStack(alignment: .leading, spacing: 6) {
                Text("QUICK START")
                    .font(.caption2.weight(.black))
                    .tracking(0.8)
                    .foregroundStyle(AppToneStyle.today.accent)

                Text(reference.templateName)
                    .font(.system(size: 21, weight: .black))
                    .foregroundStyle(AppColors.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text(reference.planName)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text(scheduleLabel)
                    .font(.caption.weight(.black))
                    .tracking(0.7)
                    .foregroundStyle(AppColors.textPrimary.opacity(0.88))

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
            .layoutPriority(1)

            Spacer(minLength: 12)

            Image(systemName: "arrow.right")
                .font(.caption.weight(.black))
                .foregroundStyle(AppToneStyle.today.accent)
                .padding(.top, 4)
        }
        .padding(.vertical, 14)
    }
}

private struct TodayPersonalRecordRow: View {
    let record: PersonalRecord
    let weightUnit: WeightUnit
    let tone: AppToneStyle

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("PR")
                    .font(.caption2.weight(.black))
                    .tracking(0.8)
                    .foregroundStyle(tone.accent)

                Text(record.displayName)
                    .font(.system(size: 19, weight: .black))
                    .foregroundStyle(AppColors.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text("\(WeightFormatter.displayString(record.weight, unit: weightUnit)) \(weightUnit.symbol) x \(record.reps)")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppColors.textSecondary)
            }

            Spacer(minLength: 12)

            VStack(alignment: .trailing, spacing: 6) {
                Text(record.achievedAt.formatted(date: .abbreviated, time: .omitted).uppercased())
                    .font(.caption2.weight(.black))
                    .tracking(0.7)
                    .foregroundStyle(AppColors.textSecondary)

                Text("E1RM \(WeightFormatter.displayString(record.estimatedOneRepMax, unit: weightUnit))")
                    .font(.caption.weight(.black))
                    .monospacedDigit()
                    .foregroundStyle(tone.accent)
            }
        }
        .padding(.vertical, 12)
    }
}

private struct TodayCompletedSessionRow: View {
    let session: CompletedSession
    let tone: AppToneStyle

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text("LOGGED")
                    .font(.caption2.weight(.black))
                    .tracking(0.8)
                    .foregroundStyle(tone.accent)

                Text(session.templateNameSnapshot)
                    .font(.system(size: 19, weight: .black))
                    .foregroundStyle(AppColors.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text("\(session.blocks.count) exercise block\(session.blocks.count == 1 ? "" : "s")")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppColors.textSecondary)
            }

            Spacer(minLength: 12)

            Text(session.completedAt.formatted(date: .abbreviated, time: .shortened).uppercased())
                .font(.caption.weight(.black))
                .monospacedDigit()
                .foregroundStyle(AppColors.textSecondary)
        }
        .padding(.vertical, 12)
    }
}

private struct TemplateEditorContext: Identifiable {
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

    private var plansHero: some View {
        AppHeroCard(
            eyebrow: "Plan Builder",
            title: "\(plansStore.planCount) plans",
            subtitle:
                "Templates define your future sessions. Schedule them loosely, pin your Today favorite, and start whenever you want.",
            systemImage: "list.bullet.rectangle",
            metrics: [
                AppHeroMetric(
                    id: "plans",
                    label: "Plans",
                    value: "\(plansStore.planCount)",
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
                    value: "\(plansStore.profileCount)",
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
                        templateCard(plan: plan, template: template)

                        if index < plan.templates.count - 1 {
                            SectionSurfaceDivider()
                        }
                    }
                }
            }
        }
        .appSectionFrame(tone: .plans, topPadding: 16, bottomPadding: 8)
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
