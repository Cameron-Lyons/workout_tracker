import SwiftUI
import UIKit

enum AppColors {
    static let canvasTop = Color(red: 0.05, green: 0.07, blue: 0.12)
    static let canvasMid = Color(red: 0.03, green: 0.05, blue: 0.10)
    static let canvasBottom = Color(red: 0.01, green: 0.02, blue: 0.05)
    static let chrome = Color(red: 0.04, green: 0.06, blue: 0.10)
    static let surfaceStrong = Color(red: 0.14, green: 0.16, blue: 0.22).opacity(0.84)
    static let surface = Color(red: 0.10, green: 0.13, blue: 0.20).opacity(0.74)
    static let surfaceSoft = Color(red: 0.07, green: 0.10, blue: 0.16).opacity(0.66)
    static let stroke = Color(red: 0.57, green: 0.64, blue: 0.77).opacity(0.46)
    static let textPrimary = Color(red: 0.96, green: 0.97, blue: 0.99)
    static let textSecondary = Color(red: 0.76, green: 0.81, blue: 0.90)
    static let accent = Color(red: 0.93, green: 0.73, blue: 0.29)
    static let accentAlt = Color(red: 0.33, green: 0.81, blue: 0.76)
    static let input = Color(red: 0.03, green: 0.05, blue: 0.10)
}

enum AppAppearance {
    private static var didConfigure = false

    static func configureIfNeeded() {
        guard !didConfigure else { return }
        didConfigure = true

        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = UIColor(AppColors.chrome)
        tabBarAppearance.shadowColor = UIColor(AppColors.stroke.opacity(0.45))
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
            .foregroundColor: UIColor(AppColors.textPrimary)
        ]
        navAppearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor(AppColors.textPrimary),
            .font: UIFont.systemFont(ofSize: 35, weight: .black)
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
                gradient: Gradient(colors: [
                    AppColors.accent.opacity(0.22),
                    .clear
                ]),
                center: .topTrailing,
                startRadius: 40,
                endRadius: 420
            )
            .blur(radius: 24)
        }
        .overlay {
            RadialGradient(
                gradient: Gradient(colors: [
                    AppColors.accentAlt.opacity(0.20),
                    .clear
                ]),
                center: .bottomLeading,
                startRadius: 20,
                endRadius: 380
            )
            .blur(radius: 30)
        }
        .overlay(alignment: .topTrailing) {
            Circle()
                .fill(.white.opacity(0.06))
                .frame(width: 300, height: 300)
                .blur(radius: 70)
                .offset(x: 90, y: -110)
        }
        .overlay(alignment: .bottomLeading) {
            Circle()
                .fill(.white.opacity(0.04))
                .frame(width: 300, height: 300)
                .blur(radius: 85)
                .offset(x: -100, y: 120)
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
                        .opacity(0.72)
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.white.opacity(0.11), .clear, AppColors.accentAlt.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppColors.stroke, lineWidth: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.22), .clear, .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.9
                    )
            )
            .shadow(color: .black.opacity(shadowOpacity), radius: shadowOpacity > 0 ? 18 : 0, x: 0, y: 12)
    }
}

private struct AppInputFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppColors.input)
                    .opacity(0.88)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(AppColors.stroke.opacity(0.7), lineWidth: 1)
            )
    }
}

extension View {
    func appSurface(cornerRadius: CGFloat = 14, shadow: Bool = true) -> some View {
        modifier(AppSurfaceModifier(cornerRadius: cornerRadius, shadowOpacity: shadow ? 0.32 : 0))
    }

    func appInputField() -> some View {
        modifier(AppInputFieldModifier())
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
