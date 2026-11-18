import SwiftUI

struct MenuView: View {
    let journey: JourneyViewModel
    let onPrologue: () -> Void
    let open: (PhaseID) -> Void
    let onScroll: (CGFloat, CGFloat) -> Void
    @State private var isUserScrolling = false

    var body: some View {
        ScrollView {
            JourneyView(journey: journey, onPrologue: onPrologue, open: open)
                .padding(.vertical, 24)
                .frame(maxWidth: 540)
                .frame(maxWidth: .infinity)
        }
        .scrollIndicators(.hidden)
        .onScrollGeometryChange(for: Int.self) { geometry in
            Int((geometry.contentOffset.y + geometry.contentInsets.top) / 12)
        } action: { oldOffset, newOffset in
            guard isUserScrolling else { return }
            onScroll(CGFloat(oldOffset * 12), CGFloat(newOffset * 12))
        }
        .onScrollPhaseChange { _, newPhase in
            isUserScrolling = newPhase == .interacting
        }
        .background { MenuBackground(progress: journey.progress) }
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
    }
}
