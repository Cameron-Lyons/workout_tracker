import Observation
import SwiftUI
import UIKit

enum AppColors {
    static let canvasTop = Color(red: 0.12, green: 0.12, blue: 0.14)
    static let canvasMid = Color(red: 0.06, green: 0.06, blue: 0.07)
    static let canvasBottom = Color(red: 0.03, green: 0.03, blue: 0.04)
    static let chrome = Color(red: 0.08, green: 0.08, blue: 0.10)
    static let surfaceStrong = Color(red: 0.15, green: 0.15, blue: 0.18)
    static let surface = Color(red: 0.09, green: 0.09, blue: 0.11)
    static let surfaceSoft = Color(red: 0.06, green: 0.06, blue: 0.08)
    static let stroke = Color.white.opacity(0.12)
    static let strokeStrong = Color.white.opacity(0.34)
    static let textPrimary = Color(red: 0.97, green: 0.97, blue: 0.95)
    static let textSecondary = Color(red: 0.74, green: 0.74, blue: 0.70)
    static let accent = Color(red: 0.70, green: 0.82, blue: 0.98)
    static let accentAlt = Color(red: 0.86, green: 0.92, blue: 1.00)
    static let accentPlans = Color(red: 0.58, green: 0.90, blue: 0.78)
    static let accentProgress = Color(red: 0.98, green: 0.82, blue: 0.47)
    static let success = Color(red: 0.72, green: 0.95, blue: 0.64)
    static let warning = Color(red: 1.00, green: 0.73, blue: 0.40)
    static let danger = Color(red: 0.98, green: 0.52, blue: 0.54)
    static let input = Color.black.opacity(0.34)
    static let glassTint = Color.white.opacity(0.06)
}

enum AppCardMetrics {
    static let compactPadding: CGFloat = 16
    static let compactCornerRadius: CGFloat = 10
    static let featurePadding: CGFloat = 18
    static let featureCornerRadius: CGFloat = 12
    static let panelCornerRadius: CGFloat = 12
    static let insetPadding: CGFloat = 12
    static let insetCornerRadius: CGFloat = 10
    static let chipCornerRadius: CGFloat = 6
    static let heroIconSize: CGFloat = 56
    static let emptyStateIconSize: CGFloat = 56
}

enum AppToneStyle: Equatable {
    case base
    case today
    case plans
    case progress
    case success
    case warning
    case danger

    var accent: Color {
        switch self {
        case .base, .today:
            AppColors.accent
        case .plans:
            AppColors.accentPlans
        case .progress:
            AppColors.accentProgress
        case .success:
            AppColors.success
        case .warning:
            AppColors.warning
        case .danger:
            AppColors.danger
        }
    }

    var accentSecondary: Color {
        switch self {
        case .base, .today:
            AppColors.accentAlt
        case .plans:
            AppColors.accentPlans.opacity(0.82)
        case .progress:
            AppColors.accentProgress.opacity(0.84)
        case .success:
            AppColors.success.opacity(0.84)
        case .warning:
            AppColors.warning.opacity(0.84)
        case .danger:
            AppColors.danger.opacity(0.84)
        }
    }

    var softFill: Color {
        accent.opacity(0.12)
    }

    var softBorder: Color {
        accent.opacity(0.64)
    }

    var glassTint: Color {
        accent.opacity(0.18)
    }
}

@MainActor
enum AppAppearance {
    private static var didConfigure = false

    static func configureIfNeeded() {
        guard !didConfigure else { return }
        didConfigure = true

        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithTransparentBackground()
        tabBarAppearance.backgroundColor = .clear
        tabBarAppearance.shadowColor = .clear
        tabBarAppearance.stackedLayoutAppearance.normal.iconColor = UIColor(AppColors.textSecondary)
        tabBarAppearance.stackedLayoutAppearance.normal.titleTextAttributes = [
            .foregroundColor: UIColor(AppColors.textSecondary)
        ]
        tabBarAppearance.stackedLayoutAppearance.selected.iconColor = UIColor(AppColors.accent)
        tabBarAppearance.stackedLayoutAppearance.selected.titleTextAttributes = [
            .foregroundColor: UIColor(AppColors.accent)
        ]
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithTransparentBackground()
        navAppearance.backgroundColor = .clear
        navAppearance.shadowColor = .clear
        navAppearance.titleTextAttributes = [
            .foregroundColor: UIColor(AppColors.textPrimary),
            .font: UIFont.systemFont(ofSize: 17, weight: .bold),
        ]
        navAppearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor(AppColors.textPrimary),
            .font: UIFont.systemFont(ofSize: 32, weight: .black),
        ]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
    }
}

struct AppBackground: View {
    var body: some View {
        ZStack {
            AppColors.canvasBottom

            VStack(spacing: 0) {
                Rectangle()
                    .fill(AppColors.canvasTop)
                    .frame(height: 172)
                Spacer(minLength: 0)
            }

            VStack(spacing: 0) {
                Rectangle()
                    .fill(AppColors.strokeStrong.opacity(0.7))
                    .frame(height: 1)
                Spacer(minLength: 0)
            }

            HStack(spacing: 0) {
                Rectangle()
                    .fill(AppColors.surfaceStrong.opacity(0.7))
                    .frame(width: 8)
                Spacer(minLength: 0)
            }

            Rectangle()
                .stroke(AppColors.strokeStrong.opacity(0.22), lineWidth: 1)
                .frame(width: 172, height: 172)
                .rotationEffect(.degrees(12))
                .offset(x: 120, y: 260)

            Rectangle()
                .stroke(AppColors.stroke.opacity(0.46), lineWidth: 1)
                .frame(width: 96, height: 96)
                .offset(x: -140, y: -248)
        }
        .ignoresSafeArea()
    }
}

private struct AppSurfaceModifier: ViewModifier {
    let cornerRadius: CGFloat
    let shadowOpacity: Double
    let tone: AppToneStyle?

    func body(content: Content) -> some View {
        content
            .background {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(AppColors.surface)
                    .overlay {
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .fill(AppColors.surfaceStrong.opacity(0.38))
                            .padding(1)
                    }
            }
            .overlay {
                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .stroke(AppColors.strokeStrong, lineWidth: 1)

                    if let tone {
                        Rectangle()
                            .fill(tone.accent)
                            .frame(width: 88, height: 4)
                            .padding(1)
                            .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
                    }
                }
            }
            .shadow(color: .black.opacity(shadowOpacity), radius: 8, x: 0, y: 3)
    }
}

private struct AppInputFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppColors.input)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(AppColors.strokeStrong.opacity(0.88), lineWidth: 1)
            )
            .glassEffect(.regular.tint(AppColors.glassTint).interactive(), in: .rect(cornerRadius: 10))
    }
}

private struct AppInsetCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    let fillOpacity: Double
    let borderOpacity: Double
    let fill: Color?
    let border: Color?

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(fill ?? AppColors.surfaceStrong.opacity(fillOpacity))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(border ?? AppColors.strokeStrong.opacity(borderOpacity), lineWidth: 1)
            )
    }
}

private struct AppRevealModifier: ViewModifier {
    let delay: Double
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 6)
            .onAppear {
                guard !isVisible else { return }
                withAnimation(.spring(response: 0.36, dampingFraction: 0.9).delay(delay)) {
                    isVisible = true
                }
            }
    }
}

struct AppHeroMetric: Identifiable {
    let id: String
    let label: String
    let value: String
    let systemImage: String
}

struct AppHeroCard: View {
    let eyebrow: String?
    let title: String
    let subtitle: String
    let systemImage: String
    let metrics: [AppHeroMetric]
    var tone: AppToneStyle = .base

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    if let eyebrow, !eyebrow.isEmpty {
                        Text(eyebrow.uppercased())
                            .font(.caption.weight(.black))
                            .tracking(1.1)
                            .foregroundStyle(tone.accent)
                    }

                    Text(title)
                        .font(.system(size: 29, weight: .black))
                        .foregroundStyle(AppColors.textPrimary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(subtitle)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .layoutPriority(1)

                Spacer(minLength: 12)

                ZStack {
                    Rectangle()
                        .fill(tone.softFill.opacity(0.82))

                    Rectangle()
                        .stroke(tone.softBorder, lineWidth: 1)

                    Image(systemName: systemImage)
                        .font(.system(size: 23, weight: .black))
                        .foregroundStyle(tone.accent)
                }
                .frame(width: AppCardMetrics.heroIconSize, height: AppCardMetrics.heroIconSize)
            }

            if !metrics.isEmpty {
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(AppColors.strokeStrong.opacity(0.7))
                        .frame(height: 1)

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(minimum: 110), spacing: 0),
                            GridItem(.flexible(minimum: 110), spacing: 0),
                        ],
                        alignment: .leading,
                        spacing: 0
                    ) {
                        ForEach(Array(metrics.enumerated()), id: \.element.id) { index, metric in
                            AppHeroMetricCell(metric: metric, tone: tone)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 12)
                                .overlay(alignment: .top) {
                                    if index >= 2 {
                                        Rectangle()
                                            .fill(AppColors.stroke.opacity(0.82))
                                            .frame(height: 1)
                                    }
                                }
                                .overlay(alignment: .leading) {
                                    if index.isMultiple(of: 2) == false {
                                        Rectangle()
                                            .fill(AppColors.stroke.opacity(0.82))
                                            .frame(width: 1)
                                    }
                                }
                        }
                    }
                }
            }
        }
        .appFeatureSurface(tone: tone)
    }
}

private struct AppHeroMetricCell: View {
    let metric: AppHeroMetric
    let tone: AppToneStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Image(systemName: metric.systemImage)
                    .font(.caption.weight(.black))
                    .foregroundStyle(tone.accent)

                Text(metric.label.uppercased())
                    .font(.caption2.weight(.black))
                    .tracking(0.8)
                    .foregroundStyle(AppColors.textSecondary)
            }

            Text(metric.value)
                .font(.system(size: 22, weight: .black))
                .monospacedDigit()
                .foregroundStyle(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AppEmptyStateCard: View {
    let systemImage: String
    let title: String
    let message: String
    var tone: AppToneStyle = .base

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 16) {
                ZStack {
                    Rectangle()
                        .fill(tone.softFill.opacity(0.82))

                    Rectangle()
                        .stroke(tone.softBorder, lineWidth: 1)

                    Image(systemName: systemImage)
                        .font(.system(size: 28, weight: .black))
                        .foregroundStyle(tone.accent)
                }
                .frame(width: AppCardMetrics.emptyStateIconSize, height: AppCardMetrics.emptyStateIconSize)

                VStack(alignment: .leading, spacing: 8) {
                    Text(title)
                        .font(.system(size: 28, weight: .black))
                        .foregroundStyle(AppColors.textPrimary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(message)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .layoutPriority(1)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appFeatureSurface(tone: tone)
    }
}

struct AppStatePill: View {
    let title: String
    let systemImage: String
    var tone: AppToneStyle = .base

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption2.weight(.black))
            Text(title.uppercased())
                .font(.caption2.weight(.black))
                .tracking(0.8)
        }
        .foregroundStyle(tone.accent)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .appInsetCard(cornerRadius: 6, fill: tone.softFill.opacity(0.65), border: tone.softBorder)
    }
}

struct AppSectionHeader: View {
    let title: String
    let systemImage: String
    var subtitle: String?
    var trailing: String?
    var tone: AppToneStyle = .base

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Label {
                    Text(title.uppercased())
                } icon: {
                    Image(systemName: systemImage)
                        .foregroundStyle(tone.accent)
                }
                .font(.caption.weight(.black))
                .tracking(1)
                .foregroundStyle(AppColors.textPrimary)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 12)

            if let trailing, !trailing.isEmpty {
                Text(trailing)
                    .font(.caption.weight(.black))
                    .monospacedDigit()
                    .foregroundStyle(AppColors.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .appInsetCard(cornerRadius: 6, fill: tone.softFill.opacity(0.65), border: tone.softBorder)
            }
        }
    }
}

struct MetricBadge: View {
    let label: String
    let value: String
    let systemImage: String
    var tone: AppToneStyle = .base

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.caption2.weight(.black))
                    .foregroundStyle(tone.accent)

                Text(label.uppercased())
                    .font(.caption2.weight(.black))
                    .tracking(0.7)
                    .foregroundStyle(AppColors.textSecondary)
            }

            Text(value)
                .font(.caption.weight(.black))
                .monospacedDigit()
                .foregroundStyle(AppColors.textPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .appInsetCard(cornerRadius: 8, borderOpacity: 0.8, fill: AppColors.surfaceStrong.opacity(0.9), border: tone.softBorder)
    }
}

struct RootAppView: View {
    @Environment(AppStore.self) private var appStore
    @State private var loggerPresentationSignpost: PerformanceSignpost.Interval?

    init() {
        AppAppearance.configureIfNeeded()
    }

    var body: some View {
        @Bindable var appStore = appStore

        Group {
            if appStore.shouldShowOnboarding {
                OnboardingView()
            } else if appStore.settingsStore.isCompletingOnboarding {
                OnboardingSetupView()
            } else {
                RootTabView()
                    .environment(appStore)
                    .environment(appStore.settingsStore)
                    .environment(appStore.plansStore)
                    .environment(appStore.sessionStore)
                    .environment(appStore.todayStore)
                    .environment(appStore.progressStore)
            }
        }
        .fullScreenCover(
            isPresented: Binding(
                get: { appStore.sessionStore.isPresentingSession },
                set: { isPresented in
                    if !isPresented {
                        appStore.sessionStore.dismissSessionPresentation()
                    }
                }
            )
        ) {
            ActiveSessionView(onDisplayed: endLoggerPresentationSignpost)
                .environment(appStore)
                .environment(appStore.settingsStore)
                .environment(appStore.plansStore)
                .environment(appStore.sessionStore)
        }
        .onChange(of: appStore.sessionStore.isPresentingSession, initial: false) { _, isPresenting in
            if isPresenting {
                loggerPresentationSignpost = PerformanceSignpost.begin("Logger Presentation")
            } else {
                endLoggerPresentationSignpost()
            }
        }
        .sheet(
            item: Binding(
                get: { appStore.sessionStore.lastFinishedSummary },
                set: { appStore.sessionStore.lastFinishedSummary = $0 }
            )
        ) { summary in
            SessionFinishSummaryView(summary: summary)
                .environment(appStore.settingsStore)
        }
        .alert(
            item: Binding(
                get: { appStore.persistenceStartupIssue },
                set: { issue in
                    if issue == nil {
                        appStore.dismissPersistenceStartupIssue()
                    }
                }
            )
        ) { issue in
            Alert(
                title: Text(issue.title),
                message: Text(issue.message),
                dismissButton: .default(Text("OK")) {
                    appStore.dismissPersistenceStartupIssue()
                }
            )
        }
    }

    private func endLoggerPresentationSignpost() {
        guard let loggerPresentationSignpost else {
            return
        }

        PerformanceSignpost.end(loggerPresentationSignpost)
        self.loggerPresentationSignpost = nil
    }
}

private struct OnboardingSetupView: View {
    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 18) {
                ProgressView()
                    .controlSize(.large)
                    .tint(AppToneStyle.today.accent)

                VStack(spacing: 8) {
                    Text("Setting Up Your Plans")
                        .font(.system(size: 28, weight: .black))
                        .foregroundStyle(AppColors.textPrimary)

                    Text("Bringing your preset pack into the app so Today is ready when it appears.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .padding(28)
            .frame(maxWidth: 340)
            .appFeatureSurface(tone: .today)
        }
    }
}

struct RootTabView: View {
    private enum Tab: String, Hashable {
        case today
        case plans
        case progress

        static var launchSelection: Tab? {
            let arguments = ProcessInfo.processInfo.arguments
            guard let flagIndex = arguments.firstIndex(of: "-codex-initial-tab"),
                arguments.indices.contains(flagIndex + 1)
            else {
                return nil
            }

            return Tab(rawValue: arguments[flagIndex + 1].lowercased())
        }
    }

    @State private var selectedTab: Tab
    @State private var progressSelectionSignpost: PerformanceSignpost.Interval?

    init() {
        _selectedTab = State(initialValue: Tab.launchSelection ?? .today)
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView()
                .tag(Tab.today)
                .tabItem {
                    Label("Today", systemImage: "sun.max")
                }

            PlansView()
                .tag(Tab.plans)
                .tabItem {
                    Label("Plans", systemImage: "list.bullet.rectangle")
                }

            ProgressDashboardView(onDisplayed: endProgressSelectionSignpost)
                .tag(Tab.progress)
                .tabItem {
                    Label("Progress", systemImage: "chart.line.uptrend.xyaxis")
                }
        }
        .tint(AppColors.accent)
        .onChange(of: selectedTab) { _, newValue in
            if newValue == .progress {
                progressSelectionSignpost = PerformanceSignpost.begin("Progress Tab Selection")
            } else {
                endProgressSelectionSignpost()
            }
        }
    }

    private func endProgressSelectionSignpost() {
        guard let progressSelectionSignpost else {
            return
        }

        PerformanceSignpost.end(progressSelectionSignpost)
        self.progressSelectionSignpost = nil
    }
}

struct SessionFinishSummaryView: View {
    let summary: SessionFinishSummary
    @Environment(\.dismiss) private var dismiss
    @Environment(SettingsStore.self) private var settingsStore

    private var weightUnit: WeightUnit {
        settingsStore.weightUnit
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    LazyVStack(spacing: 16) {
                        SessionFinishHeroCardView(summary: summary, weightUnit: weightUnit)

                        if summary.personalRecords.isEmpty {
                            AppEmptyStateCard(
                                systemImage: "bolt.badge.clock",
                                title: "Session locked in",
                                message: "No new PRs this time, but the log is saved and progression rules were advanced.",
                                tone: .success
                            )
                        } else {
                            SessionFinishRecordsSectionView(
                                records: summary.personalRecords,
                                weightUnit: weightUnit
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 16)
                }
            }
            .navigationTitle("Summary")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct SessionFinishHeroCardView: View, Equatable {
    let summary: SessionFinishSummary
    let weightUnit: WeightUnit

    nonisolated static func == (lhs: SessionFinishHeroCardView, rhs: SessionFinishHeroCardView) -> Bool {
        lhs.summary == rhs.summary && lhs.weightUnit == rhs.weightUnit
    }

    var body: some View {
        AppHeroCard(
            eyebrow: "Workout Complete",
            title: summary.templateName,
            subtitle: "Session saved and analytics refreshed.",
            systemImage: "checkmark.seal.fill",
            metrics: [
                AppHeroMetric(
                    id: "sets",
                    label: "Completed Sets",
                    value: "\(summary.completedSetCount)",
                    systemImage: "checklist"
                ),
                AppHeroMetric(
                    id: "volume",
                    label: "Volume",
                    value: WeightFormatter.displayString(summary.totalVolume, unit: weightUnit),
                    systemImage: "scalemass"
                ),
                AppHeroMetric(
                    id: "records",
                    label: "New PRs",
                    value: "\(summary.personalRecords.count)",
                    systemImage: "rosette"
                ),
                AppHeroMetric(
                    id: "time",
                    label: "Finished",
                    value: summary.completedAt.formatted(date: .omitted, time: .shortened),
                    systemImage: "clock"
                ),
            ],
            tone: .success
        )
    }
}

private struct SessionFinishRecordsSectionView: View, Equatable {
    let records: [PersonalRecord]
    let weightUnit: WeightUnit

    nonisolated static func == (lhs: SessionFinishRecordsSectionView, rhs: SessionFinishRecordsSectionView) -> Bool {
        lhs.records == rhs.records && lhs.weightUnit == rhs.weightUnit
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppSectionHeader(
                title: "New Personal Records",
                systemImage: "rosette",
                subtitle: "\(records.count) milestone\(records.count == 1 ? "" : "s") captured in this session.",
                trailing: "\(records.count)",
                tone: .success
            )

            LazyVStack(spacing: 12) {
                ForEach(records) { record in
                    SessionFinishRecordCardView(record: record, weightUnit: weightUnit)
                        .equatable()
                }
            }
        }
    }
}

private struct SessionFinishRecordCardView: View, Equatable {
    let record: PersonalRecord
    let weightUnit: WeightUnit

    nonisolated static func == (lhs: SessionFinishRecordCardView, rhs: SessionFinishRecordCardView) -> Bool {
        lhs.record == rhs.record && lhs.weightUnit == rhs.weightUnit
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(record.displayName)
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(AppColors.textPrimary)

                    Text(
                        "\(WeightFormatter.displayString(record.weight, unit: weightUnit)) \(weightUnit.symbol) x \(record.reps)"
                    )
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppColors.textSecondary)
                }

                Spacer()

                AppStatePill(title: "PR", systemImage: "rosette", tone: .success)
            }

            Text(
                "Estimated 1RM \(WeightFormatter.displayString(record.estimatedOneRepMax, unit: weightUnit)) \(weightUnit.symbol)"
            )
            .font(.caption.weight(.black))
            .foregroundStyle(AppColors.success)
        }
        .padding(AppCardMetrics.compactPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appSurface(cornerRadius: AppCardMetrics.compactCornerRadius, shadow: false, tone: .success)
    }
}

struct PersonalRecordSummaryCardView: View, Equatable {
    let record: PersonalRecord
    let weightUnit: WeightUnit
    let tone: AppToneStyle

    init(record: PersonalRecord, weightUnit: WeightUnit, tone: AppToneStyle = .success) {
        self.record = record
        self.weightUnit = weightUnit
        self.tone = tone
    }

    nonisolated static func == (lhs: PersonalRecordSummaryCardView, rhs: PersonalRecordSummaryCardView) -> Bool {
        lhs.record == rhs.record && lhs.weightUnit == rhs.weightUnit && lhs.tone == rhs.tone
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(record.displayName)
                    .font(.system(size: 20, weight: .black))
                    .foregroundStyle(AppColors.textPrimary)

                Text(
                    "\(WeightFormatter.displayString(record.weight, unit: weightUnit)) \(weightUnit.symbol) x \(record.reps)"
                )
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppColors.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 8) {
                AppStatePill(title: "Record", systemImage: "rosette.fill", tone: tone)

                Text(record.achievedAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption.weight(.black))
                    .monospacedDigit()
                    .foregroundStyle(tone.accent)
            }
        }
        .padding(AppCardMetrics.compactPadding)
        .appSurface(cornerRadius: AppCardMetrics.compactCornerRadius, shadow: false, tone: tone)
    }
}

struct CompletedSessionSummaryCardView: View, Equatable {
    let session: CompletedSession
    let detailSuffix: String
    let tone: AppToneStyle

    init(session: CompletedSession, detailSuffix: String = "", tone: AppToneStyle = .base) {
        self.session = session
        self.detailSuffix = detailSuffix
        self.tone = tone
    }

    nonisolated static func == (lhs: CompletedSessionSummaryCardView, rhs: CompletedSessionSummaryCardView) -> Bool {
        lhs.session == rhs.session && lhs.detailSuffix == rhs.detailSuffix && lhs.tone == rhs.tone
    }

    private var detailText: String {
        "\(session.blocks.count) exercise block\(session.blocks.count == 1 ? "" : "s")\(detailSuffix)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(session.templateNameSnapshot)
                        .font(.system(size: 20, weight: .black))
                        .foregroundStyle(AppColors.textPrimary)

                    Text(session.completedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption.weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(AppColors.textSecondary)
                }

                Spacer()

                AppStatePill(title: "Logged", systemImage: "checkmark.circle.fill", tone: tone)
            }

            Text(detailText)
                .font(.caption.weight(.black))
                .foregroundStyle(tone.accent)
        }
        .padding(AppCardMetrics.compactPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appSurface(cornerRadius: AppCardMetrics.compactCornerRadius, shadow: false, tone: tone)
    }
}

extension View {
    func appSurface(
        cornerRadius: CGFloat = AppCardMetrics.compactCornerRadius,
        shadow: Bool = false,
        tone: AppToneStyle? = nil
    ) -> some View {
        modifier(AppSurfaceModifier(cornerRadius: cornerRadius, shadowOpacity: shadow ? 0.18 : 0, tone: tone))
    }

    func appSurfaceCard(
        padding: CGFloat = AppCardMetrics.compactPadding,
        cornerRadius: CGFloat = AppCardMetrics.compactCornerRadius,
        shadow: Bool = false,
        tone: AppToneStyle? = nil
    ) -> some View {
        self.padding(padding)
            .appSurface(cornerRadius: cornerRadius, shadow: shadow, tone: tone)
    }

    func appSectionSurface(tone: AppToneStyle? = nil) -> some View {
        appSurfaceCard(tone: tone)
    }

    func appFeatureSurface(tone: AppToneStyle? = nil) -> some View {
        appSurfaceCard(
            padding: AppCardMetrics.featurePadding,
            cornerRadius: AppCardMetrics.featureCornerRadius,
            tone: tone
        )
    }

    func appInputField() -> some View {
        modifier(AppInputFieldModifier())
    }

    func appInsetCard(
        cornerRadius: CGFloat = 10,
        fillOpacity: Double = 0.85,
        borderOpacity: Double = 0.55,
        fill: Color? = nil,
        border: Color? = nil
    ) -> some View {
        modifier(
            AppInsetCardModifier(
                cornerRadius: cornerRadius,
                fillOpacity: fillOpacity,
                borderOpacity: borderOpacity,
                fill: fill,
                border: border
            )
        )
    }

    func appInsetContentCard(
        padding: CGFloat = AppCardMetrics.insetPadding,
        cornerRadius: CGFloat = AppCardMetrics.insetCornerRadius,
        fillOpacity: Double = 0.8,
        borderOpacity: Double = 0.68,
        fill: Color? = nil,
        border: Color? = nil
    ) -> some View {
        self.padding(padding)
            .appInsetCard(
                cornerRadius: cornerRadius,
                fillOpacity: fillOpacity,
                borderOpacity: borderOpacity,
                fill: fill,
                border: border
            )
    }

    func appEditorInsetCard(fillOpacity: Double = 0.82, borderOpacity: Double = 0.7) -> some View {
        appInsetContentCard(
            padding: AppCardMetrics.compactPadding,
            cornerRadius: AppCardMetrics.compactCornerRadius,
            fillOpacity: fillOpacity,
            borderOpacity: borderOpacity
        )
    }

    func appReveal(delay: Double = 0) -> some View {
        modifier(AppRevealModifier(delay: delay))
    }

    func appPrimaryActionButton(tone: AppToneStyle, controlSize: ControlSize = .large) -> some View {
        self
            .buttonStyle(.glassProminent)
            .buttonBorderShape(.roundedRectangle(radius: controlSize == .large ? 12 : 10))
            .controlSize(controlSize)
            .tint(tone.accent)
    }

    func appSecondaryActionButton(tone: AppToneStyle, controlSize: ControlSize = .regular) -> some View {
        self
            .buttonStyle(.glass(.regular.tint(tone.glassTint).interactive()))
            .buttonBorderShape(.roundedRectangle(radius: controlSize == .large ? 12 : 10))
            .controlSize(controlSize)
            .tint(tone.accent)
    }
}
