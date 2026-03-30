import SwiftUI

struct FlowAccentCard<Content: View>: View {
    let tone: AppToneStyle
    let content: Content

    init(tone: AppToneStyle, @ViewBuilder content: () -> Content) {
        self.tone = tone
        self.content = content()
    }

    var body: some View {
        content
            .padding(18)
            .appSectionFrame(tone: tone, topPadding: 14, bottomPadding: 6)
    }
}
