import SwiftUI
import Observation

@Observable @MainActor final class ActivitySheetState {
    static let compact = PresentationDetent.height(110)
    var detent: PresentationDetent = .medium
    var largeText = false
    private(set) var contentRevision = 0
    var compactDetent: PresentationDetent { largeText ? .height(160) : Self.compact }
    var collapsed: Bool { detent == Self.compact || detent == .height(160) }
    func expand() { detent = largeText ? .large : .medium; contentRevision += 1 }
    func collapse() { detent = compactDetent }
}

/// Full-bleed artwork; interactive targets are layered above it by each phase.
struct ActivityPhoto: View {
    let asset: String
    var body: some View {
        GeometryReader { geometry in
            Image(asset).resizable().scaledToFill()
                .frame(width: geometry.size.width, height: geometry.size.height).clipped()
        }.accessibilityHidden(true)
    }
}

struct FieldTarget: View {
    let title: String
    let symbol: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.system(size: 18, weight: .semibold))
                .padding(14).frame(minWidth: 56, minHeight: 56)
                .foregroundStyle(.white)
                .background(.black.opacity(0.72), in: Capsule())
        }.buttonStyle(.plain)
    }
}
