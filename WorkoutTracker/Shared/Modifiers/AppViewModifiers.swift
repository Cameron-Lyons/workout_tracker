import SwiftUI

private struct AppSurfaceModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
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
    }
}

private struct AppInsetCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
    }
}

private struct AppSectionFrameModifier: ViewModifier {
    let topPadding: CGFloat
    let bottomPadding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(.top, topPadding)
            .padding(.bottom, bottomPadding)
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
        cornerRadius _: CGFloat = AppCardMetrics.compactCornerRadius,
        shadow _: Bool = false,
        tone _: AppToneStyle? = nil
    ) -> some View {
        modifier(AppSurfaceModifier())
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
        tone _: AppToneStyle? = nil,
        topPadding: CGFloat = 14,
        bottomPadding: CGFloat = 6
    ) -> some View {
        modifier(AppSectionFrameModifier(topPadding: topPadding, bottomPadding: bottomPadding))
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
        cornerRadius _: CGFloat = 10,
        fillOpacity _: Double = 0.85,
        borderOpacity _: Double = 0.55,
        fill _: Color? = nil,
        border _: Color? = nil
    ) -> some View {
        modifier(AppInsetCardModifier())
    }

    func appInsetContentCard(
        padding: CGFloat = AppCardMetrics.insetPadding,
        cornerRadius _: CGFloat = AppCardMetrics.insetCornerRadius,
        fillOpacity: Double = 0.8,
        borderOpacity: Double = 0.68,
        fill: Color? = nil,
        border: Color? = nil
    ) -> some View {
        self.padding(padding)
            .appInsetCard(
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
