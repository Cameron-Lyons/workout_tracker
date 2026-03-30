import SwiftUI

private struct AppSurfaceModifier: ViewModifier {
    let cornerRadius: CGFloat
    let shadowOpacity: Double
    let tone: AppToneStyle?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(AppColors.stroke.opacity(0.18))
                        .frame(height: 1)

                    Rectangle()
                        .fill((tone?.accent ?? AppColors.strokeStrong).opacity(0.55))
                        .frame(width: 40, height: 2)
                }
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(AppColors.stroke.opacity(0.4))
                    .frame(height: 1)
            }
    }
}

private struct AppInputFieldModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(AppColors.input.opacity(0.28))
            }
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(AppColors.strokeStrong.opacity(0.62), lineWidth: 1)
            )
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
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(border ?? AppColors.strokeStrong.opacity(borderOpacity), lineWidth: 1)
            )
    }
}

private struct AppSectionFrameModifier: ViewModifier {
    let tone: AppToneStyle?
    let topPadding: CGFloat
    let bottomPadding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(.top, topPadding)
            .padding(.bottom, bottomPadding)
            .overlay(alignment: .top) {
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(AppColors.stroke.opacity(0.18))
                        .frame(height: 1)

                    Rectangle()
                        .fill((tone?.accent ?? AppColors.strokeStrong).opacity(0.55))
                        .frame(width: 40, height: 2)
                }
            }
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(AppColors.stroke.opacity(0.4))
                    .frame(height: 1)
            }
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

    func appSectionFrame(
        tone: AppToneStyle? = nil,
        topPadding: CGFloat = 14,
        bottomPadding: CGFloat = 6
    ) -> some View {
        modifier(AppSectionFrameModifier(tone: tone, topPadding: topPadding, bottomPadding: bottomPadding))
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
