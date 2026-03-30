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
        AppColors.canvasBottom
            .ignoresSafeArea()
    }
}
