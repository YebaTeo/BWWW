import SwiftUI

private struct ActivityCardStyle: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.dynamicTypeSize) private var typeSize

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 20)
        content
            .foregroundStyle(AppTheme.cream)
            .background {
                if reduceTransparency || contrast == .increased || typeSize.isAccessibilitySize {
                    shape.fill(Color(red: 0.19, green: 0.13, blue: 0.09))
                } else {
                    shape.fill(.regularMaterial)
                        .overlay(shape.fill(Color.black.opacity(0.30)))
                }
            }
            .overlay(shape.strokeBorder(AppTheme.cream.opacity(0.3)).allowsHitTesting(false))
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
        VStack(spacing: 8) { content }
            .multilineTextAlignment(.center)
            .controlSize(.large)
            .padding(16)
            .frame(maxWidth: .infinity)
    }
}
