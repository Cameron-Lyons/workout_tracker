import SwiftUI

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
            .appSectionFrame(tone: tone, topPadding: 14, bottomPadding: 6)
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
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .appInsetCard(cornerRadius: 6, fill: tone.softFill.opacity(0.76), border: tone.softBorder)
    }
}
