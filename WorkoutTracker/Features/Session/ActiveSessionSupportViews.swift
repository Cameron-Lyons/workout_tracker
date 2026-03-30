import SwiftUI

struct SessionUnderlineFieldModifier: ViewModifier {
    var lineColor: Color = AppColors.strokeStrong.opacity(0.72)

    func body(content: Content) -> some View {
        content
            .padding(.bottom, 10)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(lineColor)
                    .frame(height: 1)
            }
    }
}

struct SessionSectionDivider: View {
    var body: some View {
        Rectangle()
            .fill(AppColors.stroke.opacity(0.78))
            .frame(height: 1)
    }
}

enum SessionInputCommitDefaults {
    static let debounceNanoseconds: UInt64 = 180_000_000
}

struct RestTimerTickView<Content: View>: View {
    let endDate: Date?
    let content: (Date) -> Content

    init(endDate: Date?, @ViewBuilder content: @escaping (Date) -> Content) {
        self.endDate = endDate
        self.content = content
    }

    var body: some View {
        Group {
            if endDate == nil {
                content(.now)
            } else {
                TimelineView(.periodic(from: .now, by: 1)) { context in
                    content(context.date)
                }
            }
        }
    }
}
