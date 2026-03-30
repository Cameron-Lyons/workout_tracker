import SwiftUI

private struct ProgressSectionSpacingModifier: ViewModifier {
    let topPadding: CGFloat
    let bottomPadding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(.top, topPadding)
            .padding(.bottom, bottomPadding)
    }
}

extension View {
    func progressSectionSpacing(topPadding: CGFloat = 4, bottomPadding: CGFloat = 2) -> some View {
        modifier(ProgressSectionSpacingModifier(topPadding: topPadding, bottomPadding: bottomPadding))
    }
}

struct ProgressSpotlightCard<Content: View>: View {
    let tone: AppToneStyle
    let content: Content

    init(tone: AppToneStyle, @ViewBuilder content: () -> Content) {
        self.tone = tone
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .progressSectionSpacing(topPadding: 4, bottomPadding: 2)
    }
}

struct ProgressLegendPill: View {
    let title: String
    let systemImage: String
    let tone: AppToneStyle

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.caption2.weight(.black))
            Text(title.uppercased())
                .font(.caption2.weight(.black))
                .tracking(0.8)
        }
        .foregroundStyle(tone.accent)
    }
}
