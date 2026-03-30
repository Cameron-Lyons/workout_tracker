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

enum KanagawaPalette {
    static let sumiInk0 = Color(hex: 0x16161D)
    static let sumiInk1 = Color(hex: 0x181820)
    static let sumiInk2 = Color(hex: 0x1A1A22)
    static let sumiInk3 = Color(hex: 0x1F1F28)
    static let sumiInk4 = Color(hex: 0x2A2A37)
    static let sumiInk5 = Color(hex: 0x363646)
    static let sumiInk6 = Color(hex: 0x54546D)
    static let waveBlue1 = Color(hex: 0x223249)
    static let oldWhite = Color(hex: 0xC8C093)
    static let fujiWhite = Color(hex: 0xDCD7BA)
    static let fujiGray = Color(hex: 0x727169)
    static let crystalBlue = Color(hex: 0x7E9CD8)
    static let lightBlue = Color(hex: 0xA3D4D5)
    static let waveAqua2 = Color(hex: 0x7AA89F)
    static let springGreen = Color(hex: 0x98BB6C)
    static let carpYellow = Color(hex: 0xE6C384)
    static let surimiOrange = Color(hex: 0xFFA066)
    static let waveRed = Color(hex: 0xE46876)
}

enum AppColors {
    static let canvasTop = KanagawaPalette.sumiInk3
    static let canvasMid = KanagawaPalette.sumiInk1
    static let canvasBottom = KanagawaPalette.sumiInk0
    static let chrome = KanagawaPalette.sumiInk2
    static let surfaceStrong = KanagawaPalette.sumiInk5
    static let surface = KanagawaPalette.sumiInk4
    static let surfaceSoft = KanagawaPalette.sumiInk2
    static let stroke = KanagawaPalette.sumiInk6
    static let strokeStrong = KanagawaPalette.fujiGray
    static let textPrimary = KanagawaPalette.fujiWhite
    static let textSecondary = KanagawaPalette.oldWhite
    static let accent = KanagawaPalette.crystalBlue
    static let accentAlt = KanagawaPalette.lightBlue
    static let accentPlans = KanagawaPalette.waveAqua2
    static let accentProgress = KanagawaPalette.carpYellow
    static let success = KanagawaPalette.springGreen
    static let warning = KanagawaPalette.surimiOrange
    static let danger = KanagawaPalette.waveRed
    static let input = KanagawaPalette.sumiInk0
    static let glassTint = KanagawaPalette.waveBlue1
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
