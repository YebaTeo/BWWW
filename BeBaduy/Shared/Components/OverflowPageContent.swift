import SwiftUI

private struct PageContentHeightKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// A single accessible content tree: only oversized content gets its own scroll area.
struct OverflowPageContent<Content: View>: View {
    let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    @State private var contentHeight: CGFloat = 0
    var body: some View {
        GeometryReader { bounds in
            let overflows = contentHeight > bounds.size.height + 1
            VStack(spacing: 8) {
                ScrollView {
                    content
                        .fixedSize(horizontal: false, vertical: true)
                        .background {
                            GeometryReader { measured in
                                Color.clear.preference(key: PageContentHeightKey.self,
                                                       value: measured.size.height)
                            }
                        }
                        .frame(maxWidth: .infinity, minHeight: overflows ? 0 : bounds.size.height,
                               alignment: .center)
                }
                .scrollDisabled(!overflows)
                if overflows {
                    Text("Geser halaman")
                        .font(.footnote).multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .contentShape(Rectangle())
                        .accessibilityHint("Geser ke atas untuk halaman berikutnya, ke bawah untuk kembali")
                }
            }
            .onPreferenceChange(PageContentHeightKey.self) { contentHeight = $0 }
        }
    }
}
