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
    static let accent = Color("AccentColor")
    static let accentAlt = Color(red: 0.55, green: 0.64, blue: 0.89)
    static let input = Color(red: 0.03, green: 0.05, blue: 0.10)
}

@MainActor
enum AppAppearance {
    private enum Metrics {
        static let tabBarShadowOpacity = 0.38
        static let largeTitleFontSize: CGFloat = 33
    }

    private static var didConfigure = false

    static func configureIfNeeded() {
        guard !didConfigure else { return }
        didConfigure = true

        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor(AppColors.chrome)
        tabBarAppearance.shadowColor = UIColor(AppColors.stroke.opacity(Metrics.tabBarShadowOpacity))
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
            .font: UIFont.systemFont(ofSize: Metrics.largeTitleFontSize, weight: .bold)
        ]

        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
    }
}

struct AppBackground: View {
    private enum Layout {
        static let accentStartRadius: CGFloat = 40
        static let accentEndRadius: CGFloat = 420
        static let accentBlurRadius: CGFloat = 24
        static let accentOpacity = 0.20

        static let accentAltStartRadius: CGFloat = 20
        static let accentAltEndRadius: CGFloat = 380
        static let accentAltBlurRadius: CGFloat = 30
        static let accentAltOpacity = 0.12

        static let topGlowOpacity = 0.06
        static let topGlowSize: CGFloat = 300
        static let topGlowBlurRadius: CGFloat = 70
        static let topGlowOffsetX: CGFloat = 90
        static let topGlowOffsetY: CGFloat = -110

        static let bottomGlowOpacity = 0.04
        static let bottomGlowSize: CGFloat = 300
        static let bottomGlowBlurRadius: CGFloat = 85
        static let bottomGlowOffsetX: CGFloat = -100
        static let bottomGlowOffsetY: CGFloat = 120

        static let darkOverlayOpacity = 0.16
    }

    var body: some View {
        LinearGradient(
            colors: [AppColors.canvasTop, AppColors.canvasMid, AppColors.canvasBottom],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay {
            RadialGradient(
                gradient: Gradient(colors: [
                    AppColors.accent.opacity(Layout.accentOpacity),
                    .clear
                ]),
                center: .topTrailing,
                startRadius: Layout.accentStartRadius,
                endRadius: Layout.accentEndRadius
            )
            .blur(radius: Layout.accentBlurRadius)
        }
        .overlay {
            RadialGradient(
                gradient: Gradient(colors: [
                    AppColors.accentAlt.opacity(Layout.accentAltOpacity),
                    .clear
                ]),
                center: .bottomLeading,
                startRadius: Layout.accentAltStartRadius,
                endRadius: Layout.accentAltEndRadius
            )
            .blur(radius: Layout.accentAltBlurRadius)
        }
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(.white.opacity(Layout.topGlowOpacity))
                .frame(width: Layout.topGlowSize, height: Layout.topGlowSize)
                .blur(radius: Layout.topGlowBlurRadius)
                .offset(x: Layout.topGlowOffsetX, y: Layout.topGlowOffsetY)
        }
        .overlay(alignment: .bottomLeading) {
            Circle()
                .fill(.white.opacity(Layout.bottomGlowOpacity))
                .frame(width: Layout.bottomGlowSize, height: Layout.bottomGlowSize)
                .blur(radius: Layout.bottomGlowBlurRadius)
                .offset(x: Layout.bottomGlowOffsetX, y: Layout.bottomGlowOffsetY)
        }
        .overlay {
            Rectangle()
                .fill(.black.opacity(Layout.darkOverlayOpacity))
        }
        .ignoresSafeArea()
    }
}

private struct AppSurfaceModifier: ViewModifier {
    private enum Style {
        static let materialOpacity = 0.62
        static let highlightOpacity = 0.06
        static let accentHighlightOpacity = 0.04
        static let edgeHighlightOpacity = 0.14
        static let innerStrokeWidth: CGFloat = 0.8
        static let highlightStrokeWidth: CGFloat = 0.6
        static let shadowRadius: CGFloat = 14
        static let shadowYOffset: CGFloat = 8
    }

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
                        .opacity(Style.materialOpacity)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(Style.highlightOpacity),
                                    .clear,
                                    AppColors.accentAlt.opacity(Style.accentHighlightOpacity)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppColors.stroke, lineWidth: Style.innerStrokeWidth)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(Style.edgeHighlightOpacity), .clear, .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: Style.highlightStrokeWidth
                    )
            )
            .shadow(
                color: .black.opacity(shadowOpacity),
                radius: shadowOpacity > 0 ? Style.shadowRadius : 0,
                x: 0,
                y: Style.shadowYOffset
            )
    }
}

private struct AppInputFieldModifier: ViewModifier {
    private enum Layout {
        static let horizontalPadding: CGFloat = 12
        static let verticalPadding: CGFloat = 10
        static let cornerRadius: CGFloat = 10
        static let fillOpacity = 0.88
        static let borderOpacity = 0.58
        static let borderWidth: CGFloat = 1
    }

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.vertical, Layout.verticalPadding)
            .background(
                RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous)
                    .fill(AppColors.input)
                    .opacity(Layout.fillOpacity)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Layout.cornerRadius, style: .continuous)
                    .stroke(
                        AppColors.stroke.opacity(Layout.borderOpacity),
                        lineWidth: Layout.borderWidth
                    )
            )
    }
}

private struct AppInsetCardModifier: ViewModifier {
    private enum Style {
        static let borderWidth: CGFloat = 1
    }

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
                    .stroke(
                        AppColors.stroke.opacity(borderOpacity),
                        lineWidth: Style.borderWidth
                    )
            )
    }
}

private struct AppRevealModifier: ViewModifier {
    private enum Motion {
        static let initialOffsetY: CGFloat = 10
        static let animation = Animation.spring(response: 0.46, dampingFraction: 0.86)
    }

    let delay: Double
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .offset(y: isVisible ? 0 : Motion.initialOffsetY)
            .onAppear {
                guard !isVisible else { return }
                withAnimation(Motion.animation.delay(delay)) {
                    isVisible = true
                }
            }
    }
}

struct AppEmptyStateCard: View {
    private enum Layout {
        static let spacing: CGFloat = 12
        static let iconSize: CGFloat = 36
        static let iconContainerSize: CGFloat = 68
        static let titleSize: CGFloat = 28
        static let outerPadding: CGFloat = 24
        static let horizontalPadding: CGFloat = 20
    }

    let systemImage: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: Layout.spacing) {
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
                    .font(.system(size: Layout.iconSize, weight: .semibold))
                    .foregroundStyle(AppColors.accent)
            }
            .frame(width: Layout.iconContainerSize, height: Layout.iconContainerSize)

            Text(title)
                .font(.system(size: Layout.titleSize, weight: .bold, design: .rounded))
                .foregroundStyle(AppColors.textPrimary)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(Layout.outerPadding)
        .appSurface()
        .padding(.horizontal, Layout.horizontalPadding)
    }
}

struct AppHeroMetric: Identifiable {
    let id: String
    let label: String
    let value: String
    let systemImage: String
}

struct AppHeroCard: View {
    private enum Layout {
        static let cardSpacing: CGFloat = 14
        static let iconSize: CGFloat = 18
        static let iconContainerSize: CGFloat = 42
        static let eyebrowTracking: CGFloat = 0.6
        static let titleSize: CGFloat = 25
        static let subtitleLineSpacing: CGFloat = 3
        static let metricsSpacing: CGFloat = 10
        static let metricLabelTracking: CGFloat = 0.4
        static let metricValueSize: CGFloat = 17
        static let horizontalPadding: CGFloat = 16
        static let verticalPadding: CGFloat = 16
        static let cornerRadius: CGFloat = 18
    }

    let eyebrow: String?
    let title: String
    let subtitle: String
    let systemImage: String
    let metrics: [AppHeroMetric]

    private var metricColumns: [GridItem] {
        [
            GridItem(.flexible(minimum: 110), spacing: Layout.metricsSpacing),
            GridItem(.flexible(minimum: 110), spacing: Layout.metricsSpacing)
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.cardSpacing) {
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
                        .font(.system(size: Layout.iconSize, weight: .semibold))
                        .foregroundStyle(AppColors.accent)
                }
                .frame(width: Layout.iconContainerSize, height: Layout.iconContainerSize)

                VStack(alignment: .leading, spacing: 5) {
                    if let eyebrow, !eyebrow.isEmpty {
                        Text(eyebrow.uppercased())
                            .font(.caption2.weight(.semibold))
                            .tracking(Layout.eyebrowTracking)
                            .foregroundStyle(AppColors.textSecondary)
                    }

                    Text(title)
                        .font(.system(size: Layout.titleSize, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.textPrimary)

                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineSpacing(Layout.subtitleLineSpacing)
                }
            }

            if !metrics.isEmpty {
                LazyVGrid(columns: metricColumns, alignment: .leading, spacing: Layout.metricsSpacing) {
                    ForEach(metrics) { metric in
                        VStack(alignment: .leading, spacing: 4) {
                            Label(metric.label, systemImage: metric.systemImage)
                                .font(.caption2.weight(.medium))
                                .tracking(Layout.metricLabelTracking)
                                .foregroundStyle(AppColors.textSecondary)

                            Text(metric.value)
                                .font(
                                    .system(
                                        size: Layout.metricValueSize,
                                        weight: .semibold,
                                        design: .rounded
                                    )
                                )
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
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.vertical, Layout.verticalPadding)
        .appSurface(cornerRadius: Layout.cornerRadius, shadow: false)
    }
}

struct ExerciseNameInputRow: View {
    @Binding var exerciseName: String
    var placeholder: String = "Add exercise name"
    let addAction: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            TextField(placeholder, text: $exerciseName)
                .textInputAutocapitalization(.words)
                .foregroundStyle(AppColors.textPrimary)
                .appInputField()

            Button {
                addAction()
            } label: {
                Label("Add", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .disabled(exerciseName.nonEmptyTrimmed == nil)
            .tint(AppColors.accent)
        }
    }
}

extension View {
    func appSurface(cornerRadius: CGFloat = 14, shadow: Bool = true) -> some View {
        modifier(AppSurfaceModifier(cornerRadius: cornerRadius, shadowOpacity: shadow ? 0.24 : 0))
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

    func appReveal(delay: Double = 0) -> some View {
        modifier(AppRevealModifier(delay: delay))
    }
}

struct RootTabView: View {
    init() {
        AppAppearance.configureIfNeeded()
    }

    var body: some View {
        TabView {
            RoutinesView()
                .tabItem {
                    Label("Routines", systemImage: "list.bullet.clipboard")
                }

            WorkoutLoggerView()
                .tabItem {
                    Label("Log", systemImage: "figure.strengthtraining.traditional")
                }

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
        }
        .tint(AppColors.accent)
        .toolbarBackground(AppColors.chrome, for: .tabBar)
        .toolbarBackground(.visible, for: .tabBar)
        .preferredColorScheme(.dark)
    }
}
