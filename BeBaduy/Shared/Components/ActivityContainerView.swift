import SwiftUI
struct ActivityContainerView<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        VStack(alignment: .leading, spacing: 14) { content }
            .padding(16).background(.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 20))
    }
}
