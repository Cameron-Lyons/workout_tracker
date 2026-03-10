import Observation
import SwiftUI
import UIKit

enum AppColors {
    static let canvasTop = Color(red: 0.05, green: 0.07, blue: 0.12)
    static let canvasMid = Color(red: 0.03, green: 0.05, blue: 0.10)
    static let canvasBottom = Color(red: 0.01, green: 0.02, blue: 0.05)
    static let chrome = Color(red: 0.04, green: 0.06, blue: 0.10)
    static let surfaceStrong = Color(red: 0.14, green: 0.16, blue: 0.22).opacity(0.78)
    static let surface = Color(red: 0.10, green: 0.13, blue: 0.20).opacity(0.70)
    static let surfaceSoft = Color(red: 0.07, green: 0.10, blue: 0.16).opacity(0.62)
    static let stroke = Color(red: 0.57, green: 0.64, blue: 0.77).opacity(0.36)
    static let textPrimary = Color(red: 0.96, green: 0.97, blue: 0.99)
    static let textSecondary = Color(red: 0.76, green: 0.81, blue: 0.90)
    static let accent = Color(red: 0.48, green: 0.60, blue: 0.95)
    static let accentAlt = Color(red: 0.55, green: 0.64, blue: 0.89)
    static let input = Color(red: 0.03, green: 0.05, blue: 0.10)
}

enum AppCardMetrics {
    static let compactPadding: CGFloat = 14
    static let compactCornerRadius: CGFloat = 14
}

@MainActor
enum AppAppearance {
    private static var didConfigure = false

    static func configureIfNeeded() {
        guard !didConfigure else { return }
        didConfigure = true

        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor(AppColors.chrome)
        tabBarAppearance.shadowColor = UIColor(AppColors.stroke)
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
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = UIColor(AppColors.chrome)
        navAppearance.shadowColor = .clear
        navAppearance.titleTextAttributes = [
            .foregroundColor: UIColor(AppColors.textPrimary),
            .font: UIFont.systemFont(ofSize: 17, weight: .semibold)
        ]
        navAppearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor(AppColors.textPrimary),
            .font: UIFont.systemFont(ofSize: 33, weight: .bold)
        ]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
    }
}

struct AppBackground: View {
    var body: some View {
        LinearGradient(
            colors: [AppColors.canvasTop, AppColors.canvasMid, AppColors.canvasBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            RadialGradient(
                colors: [AppColors.accent.opacity(0.22), .clear],
                center: .topTrailing,
                startRadius: 40,
                endRadius: 420
            )
            .blur(radius: 24)
        }
        .overlay {
            RadialGradient(
                colors: [AppColors.accentAlt.opacity(0.16), .clear],
                center: .bottomLeading,
                startRadius: 20,
                endRadius: 360
            )
            .blur(radius: 30)
        }
        .overlay {
            Rectangle()
                .fill(.black.opacity(0.18))
        }
        .ignoresSafeArea()
    }
}

private struct AppSurfaceModifier: ViewModifier {
    let cornerRadius: CGFloat
    let shadowOpacity: Double

    func body(content: Content) -> some View {
        content
            .background {
                ZStack {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [AppColors.surfaceStrong, AppColors.surface, AppColors.surfaceSoft],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial)
                        .opacity(0.62)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppColors.stroke, lineWidth: 0.8)
            )
            .shadow(color: .black.opacity(shadowOpacity), radius: 14, x: 0, y: 8)
    }
}

private struct AppInputFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppColors.input.opacity(0.88))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(AppColors.stroke.opacity(0.6), lineWidth: 1)
            )
    }
}

private struct AppInsetCardModifier: ViewModifier {
    let cornerRadius: CGFloat
    let fillOpacity: Double
    let borderOpacity: Double

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(AppColors.input.opacity(fillOpacity))
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppColors.stroke.opacity(borderOpacity), lineWidth: 1)
            )
    }
}

private struct AppRevealModifier: ViewModifier {
    let delay: Double
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : 10)
            .onAppear {
                guard !isVisible else { return }
                withAnimation(.spring(response: 0.46, dampingFraction: 0.86).delay(delay)) {
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

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    AppColors.accent.opacity(0.30),
                                    AppColors.accentAlt.opacity(0.20)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    Image(systemName: systemImage)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppColors.accent)
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 5) {
                    if let eyebrow, !eyebrow.isEmpty {
                        Text(eyebrow.uppercased())
                            .font(.caption2.weight(.semibold))
                            .tracking(0.6)
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    Text(title)
                        .font(.system(size: 25, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }

            if !metrics.isEmpty {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(minimum: 110), spacing: 10),
                        GridItem(.flexible(minimum: 110), spacing: 10)
                    ],
                    alignment: .leading,
                    spacing: 10
                ) {
                    ForEach(metrics) { metric in
                        VStack(alignment: .leading, spacing: 4) {
                            Label(metric.label, systemImage: metric.systemImage)
                                .font(.caption2.weight(.medium))
                                .foregroundStyle(AppColors.textSecondary)

                            Text(metric.value)
                                .font(.system(size: 17, weight: .semibold, design: .rounded))
                                .foregroundStyle(AppColors.textPrimary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 9)
                        .appInsetCard(cornerRadius: 11, fillOpacity: 0.78, borderOpacity: 0.65)
                    }
                }
            }
        }
        .padding(16)
        .appSurface(cornerRadius: 18, shadow: false)
    }
}

struct AppEmptyStateCard: View {
    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                AppColors.accent.opacity(0.28),
                                AppColors.accent.opacity(0.10)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Image(systemName: systemImage)
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundStyle(AppColors.accent)
            }
            .frame(width: 68, height: 68)

            Text(title)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .appSurface()
        .padding(.horizontal, 20)
    }
}

struct MetricBadge: View {
    let label: String
    let value: String
    let systemImage: String

    var body: some View {
        Label {
            Text("\(label): \(value)")
        } icon: {
            Image(systemName: systemImage)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(AppColors.textSecondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .appInsetCard(cornerRadius: 10, fillOpacity: 0.75, borderOpacity: 0.6)
    }
}

struct RootAppView: View {
    @Environment(AppStore.self) private var appStore

    init() {
        AppAppearance.configureIfNeeded()
    }

    var body: some View {
        @Bindable var appStore = appStore

        Group {
            if appStore.shouldShowOnboarding {
                OnboardingView()
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
        .preferredColorScheme(.dark)
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
            ActiveSessionView()
                .environment(appStore)
                .environment(appStore.settingsStore)
                .environment(appStore.plansStore)
                .environment(appStore.sessionStore)
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
    }
}

struct RootTabView: View {
    var body: some View {
        TabView {
            TodayView()
                .tabItem {
                    Label("Today", systemImage: "sun.max")
                }

            PlansView()
                .tabItem {
                    Label("Plans", systemImage: "list.bullet.rectangle")
                }

            ProgressDashboardView()
                .tabItem {
                    Label("Progress", systemImage: "chart.line.uptrend.xyaxis")
                }
        }
        .tint(AppColors.accent)
        .toolbarBackground(AppColors.chrome, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
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
                                message: "No new PRs this time, but the log is saved and progression rules were advanced."
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
            .toolbarBackground(AppColors.chrome, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
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
                )
            ]
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
            Text("New Personal Records")
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)

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
        VStack(alignment: .leading, spacing: 6) {
            Text(record.displayName)
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)

            Text(
                "\(WeightFormatter.displayString(record.weight, unit: weightUnit)) \(weightUnit.symbol) x \(record.reps)"
            )
            .font(.subheadline)
            .foregroundStyle(AppColors.textSecondary)

            Text(
                "Estimated 1RM \(WeightFormatter.displayString(record.estimatedOneRepMax, unit: weightUnit)) \(weightUnit.symbol)"
            )
            .font(.caption)
            .foregroundStyle(AppColors.accent)
        }
        .padding(AppCardMetrics.compactPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appSurface(cornerRadius: AppCardMetrics.compactCornerRadius, shadow: false)
    }
}

struct PersonalRecordSummaryCardView: View, Equatable {
    let record: PersonalRecord
    let weightUnit: WeightUnit

    nonisolated static func == (lhs: PersonalRecordSummaryCardView, rhs: PersonalRecordSummaryCardView) -> Bool {
        lhs.record == rhs.record && lhs.weightUnit == rhs.weightUnit
    }

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 6) {
                Text(record.displayName)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)

                Text(
                    "\(WeightFormatter.displayString(record.weight, unit: weightUnit)) \(weightUnit.symbol) x \(record.reps)"
                )
                .font(.subheadline)
                .foregroundStyle(AppColors.textSecondary)
            }

            Spacer()

            Text(record.achievedAt.formatted(date: .abbreviated, time: .omitted))
                .font(.caption)
                .foregroundStyle(AppColors.accent)
        }
        .padding(AppCardMetrics.compactPadding)
        .appSurface(cornerRadius: AppCardMetrics.compactCornerRadius, shadow: false)
    }
}

struct CompletedSessionSummaryCardView: View, Equatable {
    let session: CompletedSession
    let detailSuffix: String

    init(session: CompletedSession, detailSuffix: String = "") {
        self.session = session
        self.detailSuffix = detailSuffix
    }

    nonisolated static func == (lhs: CompletedSessionSummaryCardView, rhs: CompletedSessionSummaryCardView) -> Bool {
        lhs.session == rhs.session && lhs.detailSuffix == rhs.detailSuffix
    }

    private var detailText: String {
        "\(session.blocks.count) exercise block\(session.blocks.count == 1 ? "" : "s")\(detailSuffix)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(session.templateNameSnapshot)
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)

            Text(session.completedAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .foregroundStyle(AppColors.textSecondary)

            Text(detailText)
                .font(.caption)
                .foregroundStyle(AppColors.accent)
        }
        .padding(AppCardMetrics.compactPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .appSurface(cornerRadius: AppCardMetrics.compactCornerRadius, shadow: false)
    }
}

extension View {
    func appSurface(cornerRadius: CGFloat = AppCardMetrics.compactCornerRadius, shadow: Bool = true) -> some View {
        modifier(AppSurfaceModifier(cornerRadius: cornerRadius, shadowOpacity: shadow ? 0.24 : 0))
    }

    func appSectionSurface() -> some View {
        padding(AppCardMetrics.compactPadding)
            .appSurface(cornerRadius: AppCardMetrics.compactCornerRadius, shadow: false)
    }

    func appInputField() -> some View {
        modifier(AppInputFieldModifier())
    }

    func appInsetCard(
        cornerRadius: CGFloat = 10,
        fillOpacity: Double = 0.85,
        borderOpacity: Double = 0.55
    ) -> some View {
        modifier(
            AppInsetCardModifier(
                cornerRadius: cornerRadius,
                fillOpacity: fillOpacity,
                borderOpacity: borderOpacity
            )
        )
    }

    func appEditorInsetCard(fillOpacity: Double = 0.82, borderOpacity: Double = 0.7) -> some View {
        padding(AppCardMetrics.compactPadding)
            .appInsetCard(
                cornerRadius: AppCardMetrics.compactCornerRadius,
                fillOpacity: fillOpacity,
                borderOpacity: borderOpacity
            )
    }

    func appReveal(delay: Double = 0) -> some View {
        modifier(AppRevealModifier(delay: delay))
    }
}
