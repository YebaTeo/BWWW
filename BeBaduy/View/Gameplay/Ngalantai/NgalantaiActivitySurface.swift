import SwiftUI
struct NgalantaiActivitySurface: View {
    let model: NgalantaiViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ActivityPhoto(asset: model.step == .drying || model.step == .complete ? "drying_rice_after" : "drying_rice_before")
                if [.balancing, .balanceInstructions, .balanceDemo].contains(model.step) {
                    if model.step == .balancing {
                        Capsule()
                            .fill(AppTheme.cream.opacity(0.42))
                            .frame(width: geometry.size.width * 0.82, height: 1)
                            .allowsHitTesting(false)
                            .accessibilityHidden(true)
                    }
                    DibuatBalanceArtwork(balance: model.balance, reduceMotion: reduceMotion)
                        .frame(width: geometry.size.width * 0.73,
                               height: min(geometry.size.height * 0.54, geometry.size.width * 0.38))
                }
                if model.step == .balanceInstructions || model.step == .awaitingLandscape {
                    Color.black.opacity(0.42).allowsHitTesting(false)
                }
            }.clipped()
        }
    }
}
