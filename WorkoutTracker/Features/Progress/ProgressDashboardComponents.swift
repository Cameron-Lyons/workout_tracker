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
