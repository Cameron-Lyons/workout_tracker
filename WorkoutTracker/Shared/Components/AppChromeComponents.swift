import SwiftUI

struct AppHeroMetric: Identifiable {
    let id: String
    let label: String
    let value: String
    let systemImage: String
}

enum AppRowStyle: Equatable {
    case surface
    case plain
}

enum AppChromeStyle: Equatable {
    case boxed
    case plain
}

struct AppHeroCard: View {
    let eyebrow: String?
    let title: String
    let subtitle: String
    let systemImage: String
    let metrics: [AppHeroMetric]
    var tone: AppToneStyle = .base
    var style: AppChromeStyle = .boxed

    var body: some View {
        Group {
            if style == .boxed {
                content
                    .appFeatureSurface(tone: tone)
            } else {
                content
                    .padding(.vertical, 4)
            }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 10) {
                if let eyebrow, !eyebrow.isEmpty {
                    Text(eyebrow.uppercased())
                        .font(.caption.weight(.black))
                        .tracking(1.1)
                        .foregroundStyle(tone.accent)
                }

                Spacer(minLength: 0)

                Image(systemName: systemImage)
                    .font(.headline.weight(.black))
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

            if !metrics.isEmpty {
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(minimum: 110), spacing: 12),
                        GridItem(.flexible(minimum: 110), spacing: 12),
                    ],
                    alignment: .leading,
                    spacing: 12
                ) {
                    ForEach(metrics) { metric in
                        AppHeroMetricCell(metric: metric, tone: tone)
                    }
                }
            }
        }
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

                Text(metric.label)
                    .font(.caption2.weight(.semibold))
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
    var style: AppChromeStyle = .boxed

    var body: some View {
        Group {
            if style == .boxed {
                content
                    .padding(.vertical, 18)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .appFeatureSurface(tone: tone)
            } else {
                content
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 16) {
            Image(systemName: systemImage)
                .font(.title2.weight(.black))
                .foregroundStyle(tone.accent)

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 24, weight: .black))
                    .foregroundStyle(AppColors.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Text(message)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct AppInlineMessage: View {
    let systemImage: String
    let title: String
    let message: String
    var tone: AppToneStyle = .base
    var style: AppChromeStyle = .boxed

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            icon

            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.headline.weight(.black))
                    .foregroundStyle(AppColors.textPrimary)

                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .layoutPriority(1)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var icon: some View {
        let content = Image(systemName: systemImage)
                .font(.system(size: 16, weight: .black))
                .foregroundStyle(tone.accent)
                .frame(width: 36, height: 36)

        if style == .boxed {
            content
                .appInsetCard(
                    cornerRadius: 8,
                    fill: tone.softFill.opacity(0.72),
                    border: tone.softBorder
                )
        } else {
            content
        }
    }
}

struct AppStatePill: View {
    let title: String
    let systemImage: String
    var tone: AppToneStyle = .base
    var style: AppChromeStyle = .boxed

    var body: some View {
        Group {
            if style == .boxed {
                content
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .appInsetCard(cornerRadius: 6, fill: tone.softFill.opacity(0.65), border: tone.softBorder)
            } else {
                content
            }
        }
    }

    private var content: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption2.weight(.semibold))
            Text(title)
                .font(.caption2.weight(.semibold))
        }
        .foregroundStyle(tone.accent)
    }
}

struct AppDisclosureIndicator: View {
    var tone: AppToneStyle? = nil

    var body: some View {
        Image(systemName: "chevron.right")
            .font(.caption.weight(.bold))
            .foregroundStyle((tone?.accent ?? AppColors.textSecondary).opacity(0.9))
            .padding(.top, 2)
    }
}

struct AppSectionHeader: View {
    let title: String
    let systemImage: String
    var subtitle: String?
    var trailing: String?
    var tone: AppToneStyle = .base
    var trailingStyle: AppChromeStyle = .boxed

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Label {
                    Text(title)
                } icon: {
                    Image(systemName: systemImage)
                        .foregroundStyle(tone.accent)
                }
                .font(.headline.weight(.semibold))
                .foregroundStyle(AppColors.textPrimary)

                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(AppColors.textSecondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 12)

            if let trailing, !trailing.isEmpty {
                if trailingStyle == .boxed {
                    Text(trailing)
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(AppColors.textPrimary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 7)
                        .appInsetCard(cornerRadius: 6, fill: tone.softFill.opacity(0.65), border: tone.softBorder)
                } else {
                    Text(trailing)
                        .font(.caption.weight(.semibold))
                        .monospacedDigit()
                        .foregroundStyle(tone.accent)
                }
            }
        }
    }
}

struct MetricBadge: View {
    let label: String
    let value: String
    let systemImage: String
    var tone: AppToneStyle = .base
    var style: AppChromeStyle = .boxed

    var body: some View {
        Group {
            if style == .boxed {
                content
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .appInsetCard(
                        cornerRadius: 8,
                        borderOpacity: 0.8,
                        fill: AppColors.surfaceStrong.opacity(0.9),
                        border: tone.softBorder
                    )
            } else {
                content
                    .padding(.vertical, 2)
            }
        }
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(tone.accent)

                Text(label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(AppColors.textSecondary)
            }

            Text(value)
                .font(.caption.weight(.black))
                .monospacedDigit()
                .foregroundStyle(AppColors.textPrimary)
        }
    }
}
