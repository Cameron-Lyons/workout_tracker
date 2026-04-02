import SwiftUI
import UIKit

private extension Color {
    init(hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

private enum TokyoNightPalette {
    static let bgDark = Color(hex: 0x16161E)
    static let bg = Color(hex: 0x1A1B26)
    static let bgHighlight = Color(hex: 0x292E42)
    static let terminalBlack = Color(hex: 0x414868)
    static let comment = Color(hex: 0x565F89)
    static let fgDark = Color(hex: 0xA9B1D6)
    static let fg = Color(hex: 0xC0CAF5)
    static let blue0 = Color(hex: 0x3D59A1)
    static let blue = Color(hex: 0x7AA2F7)
    static let cyan = Color(hex: 0x7DCFFF)
    static let green1 = Color(hex: 0x73DACA)
    static let green = Color(hex: 0x9ECE6A)
    static let yellow = Color(hex: 0xE0AF68)
    static let orange = Color(hex: 0xFF9E64)
    static let red = Color(hex: 0xF7768E)
}

enum AppColors {
    static let canvasTop = TokyoNightPalette.bgHighlight
    static let canvasMid = TokyoNightPalette.bg
    static let canvasBottom = TokyoNightPalette.bgDark
    static let chrome = TokyoNightPalette.bg
    static let surfaceStrong = TokyoNightPalette.terminalBlack
    static let surface = TokyoNightPalette.bgHighlight
    static let surfaceSoft = TokyoNightPalette.bg
    static let stroke = TokyoNightPalette.comment
    static let strokeStrong = TokyoNightPalette.fgDark
    static let textPrimary = TokyoNightPalette.fg
    static let textSecondary = TokyoNightPalette.fgDark
    static let accent = TokyoNightPalette.blue
    static let accentAlt = TokyoNightPalette.cyan
    static let accentPlans = TokyoNightPalette.green1
    static let accentProgress = TokyoNightPalette.yellow
    static let success = TokyoNightPalette.green
    static let warning = TokyoNightPalette.orange
    static let danger = TokyoNightPalette.red
    static let input = TokyoNightPalette.bgDark
    static let glassTint = TokyoNightPalette.blue0
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
