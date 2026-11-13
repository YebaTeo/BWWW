import SwiftUI

private struct ActivityCardStyle: ViewModifier {
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 18)
        content
            .foregroundStyle(.white)
            .background(Color(red: 0.36, green: 0.29, blue: 0.23).opacity(0.88), in: shape)
            .overlay(shape.strokeBorder(Color(red: 0.77, green: 0.65, blue: 0.48), lineWidth: 0.75)
                .allowsHitTesting(false))
    }
}

extension View {
    func activityCardStyle() -> some View { modifier(ActivityCardStyle()) }
}

/// Content-sized card shared by all chapters. Only overflowing content scrolls.
struct ActivityCardPanel<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ViewThatFits(in: .vertical) {
            contents.fixedSize(horizontal: false, vertical: true)
            ScrollView {
                contents
            }
            .accessibilityIdentifier("activity.card.scroll")
        }
        .frame(maxWidth: 400)
        .activityCardStyle()
    }

    private var contents: some View {
        VStack(spacing: 16) { content }
            .font(.subheadline)
            .multilineTextAlignment(.center)
            .controlSize(.large)
            .padding(24)
            .frame(maxWidth: .infinity)
    }
}
