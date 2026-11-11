import SwiftUI
struct NgalantaiActivitySurface: View {
    let model: NgalantaiViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if [.balancing, .balanceInstructions, .balanceDemo].contains(model.step) {
                    MipitBalanceArtwork(balance: model.balance, reduceMotion: reduceMotion)
                        .frame(width: geometry.size.width * 0.73,
                               height: min(geometry.size.height * 0.38, geometry.size.width * 0.38))
                        .position(x: geometry.size.width / 2, y: geometry.size.height * 0.34)
                }
                if model.step == .balanceInstructions || model.step == .awaitingLandscape {
                    Color.black.opacity(0.42).allowsHitTesting(false)
                }
            }.clipped()
        }
    }
}
