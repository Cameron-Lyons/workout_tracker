import SwiftUI

struct OnboardingView: View {
    @Environment(AppStore.self) private var appStore

    private let presetPacks = PresetPack.allCases

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                LazyVStack(spacing: 18) {
                    VStack(alignment: .leading, spacing: 12) {
                        AppSectionHeader(
                            title: "Choose A Path",
                            systemImage: "point.3.filled.connected.trianglepath.dotted",
                            subtitle: "Pick a preset or start blank. The structure can be edited later.",
                            trailing: "\(presetPacks.count + 1)",
                            tone: .plans
                        )

                        OnboardingOptionsPanel(
                            presetPacks: presetPacks,
                            onSelectPack: beginPresetOnboarding,
                            onStartBlank: {
                                appStore.completeOnboarding(with: nil)
                            }
                        )
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 18)
            }
            .scrollIndicators(.hidden)
        }
    }

    private func beginPresetOnboarding(_ pack: PresetPack) {
        guard appStore.settingsStore.isCompletingOnboarding == false else {
            return
        }

        appStore.settingsStore.isCompletingOnboarding = true
        appStore.settingsStore.hasCompletedOnboarding = true

        Task { @MainActor in
            await Task.yield()
            appStore.completeOnboarding(with: pack)
            appStore.settingsStore.isCompletingOnboarding = false
        }
    }
}

private struct OnboardingOptionsPanel: View {
    let presetPacks: [PresetPack]
    let onSelectPack: (PresetPack) -> Void
    let onStartBlank: () -> Void

    var body: some View {
        FlowAccentCard(tone: .plans) {
            VStack(spacing: 0) {
                ForEach(Array(presetPacks.enumerated()), id: \.element.id) { index, pack in
                    Button {
                        onSelectPack(pack)
                    } label: {
                        OnboardingPresetRow(pack: pack)
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("onboarding.preset.\(pack.rawValue)")

                    if index < presetPacks.count - 1 {
                        Rectangle()
                            .fill(AppColors.stroke.opacity(0.78))
                            .frame(height: 1)
                    }
                }

                Rectangle()
                    .fill(AppColors.strokeStrong.opacity(0.88))
                    .frame(height: 1)
                    .padding(.vertical, 4)

                Button {
                    onStartBlank()
                } label: {
                    OnboardingBlankRow()
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("onboarding.startBlank")
            }
        }
    }
}

private struct OnboardingPresetRow: View {
    let pack: PresetPack

    var body: some View {
        let tone = pack.onboardingTone

        HStack(alignment: .top, spacing: 14) {
            Image(systemName: pack.systemImage)
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(tone.accent)
                .frame(width: 40, height: 40)
                .appInsetCard(
                    cornerRadius: 8,
                    fill: tone.softFill.opacity(0.72),
                    border: tone.softBorder
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(pack.onboardingLabel.uppercased())
                    .font(.caption2.weight(.black))
                    .tracking(0.8)
                    .foregroundStyle(tone.accent)

                Text(pack.displayName)
                    .font(.system(size: 21, weight: .black))
                    .foregroundStyle(AppColors.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text(pack.description)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text(pack.onboardingHighlights.map { $0.uppercased() }.joined(separator: " • "))
                    .font(.caption.weight(.black))
                    .tracking(0.7)
                    .foregroundStyle(AppColors.textPrimary.opacity(0.88))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)

            Spacer(minLength: 12)

            Image(systemName: "arrow.right")
                .font(.caption.weight(.black))
                .foregroundStyle(tone.accent)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
    }
}

private struct OnboardingBlankRow: View {
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: "square.and.pencil")
                .font(.system(size: 18, weight: .black))
                .foregroundStyle(AppToneStyle.today.accent)
                .frame(width: 40, height: 40)
                .appInsetCard(
                    cornerRadius: 8,
                    fill: AppToneStyle.today.softFill.opacity(0.72),
                    border: AppToneStyle.today.softBorder
                )

            VStack(alignment: .leading, spacing: 6) {
                Text("BUILD YOUR OWN")
                    .font(.caption2.weight(.black))
                    .tracking(0.8)
                    .foregroundStyle(AppToneStyle.today.accent)

                Text("Start Blank")
                    .font(.system(size: 21, weight: .black))
                    .foregroundStyle(AppColors.textPrimary)

                Text("Begin with an empty setup and add plans, templates, and exercises as you go.")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text("NO PRESETS • FULL CONTROL")
                    .font(.caption.weight(.black))
                    .tracking(0.7)
                    .foregroundStyle(AppColors.textPrimary.opacity(0.88))
            }
            .layoutPriority(1)

            Spacer(minLength: 12)

            Image(systemName: "arrow.right")
                .font(.caption.weight(.black))
                .foregroundStyle(AppToneStyle.today.accent)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 14)
    }
}


private extension PresetPack {
    var onboardingTone: AppToneStyle {
        switch self {
        case .generalGym:
            .today
        case .phul:
            .success
        case .startingStrength:
            .warning
        case .strongLiftsFiveByFive:
            .warning
        case .greyskullLP:
            .plans
        case .fiveThreeOne:
            .progress
        case .boringButBig:
            .success
        case .madcowFiveByFive:
            .progress
        case .gzclp:
            .plans
        }
    }

    var onboardingLabel: String {
        switch self {
        case .generalGym:
            "Most Flexible"
        case .phul:
            "4-Day Split"
        case .startingStrength:
            "Simple Strength"
        case .strongLiftsFiveByFive:
            "Novice 5x5"
        case .greyskullLP:
            "AMRAP Linear"
        case .fiveThreeOne:
            "Cycle Based"
        case .boringButBig:
            "Volume Focus"
        case .madcowFiveByFive:
            "Intermediate"
        case .gzclp:
            "Tiered Progression"
        }
    }

    var onboardingHighlights: [String] {
        switch self {
        case .generalGym:
            ["Upper/Lower", "Balanced", "Flexible"]
        case .phul:
            ["Power", "Hypertrophy", "Upper/Lower"]
        case .startingStrength:
            ["A/B Days", "Barbell", "Linear"]
        case .strongLiftsFiveByFive:
            ["A/B Days", "5x5", "Barbell"]
        case .greyskullLP:
            ["A/B Days", "AMRAP", "Linear"]
        case .fiveThreeOne:
            ["4 Main Lifts", "Wave", "Cycles"]
        case .boringButBig:
            ["5/3/1", "5x10", "Supplemental"]
        case .madcowFiveByFive:
            ["3 Days", "Ramp Sets", "Weekly"]
        case .gzclp:
            ["T1/T2/T3", "4 Days", "Powerbuilding"]
        }
    }
}
