import SwiftUI
import UIKit

struct DibuatActivitySurface: View {
    let model: DibuatViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var activeCut: Int?
    private let targets = [CGPoint(x: 0.24, y: 0.43), CGPoint(x: 0.47, y: 0.55), CGPoint(x: 0.73, y: 0.53)]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ActivityPhoto(asset: asset)
                if model.step == .harvesting || model.step == .harvestSuccess {
                    harvestTargets(in: geometry.size)
                }
                if [.balancing, .balanceInstructions, .balanceDemo].contains(model.step) {
                    DibuatBalanceArtwork(balance: model.balance, reduceMotion: reduceMotion)
                        .frame(width: geometry.size.width * 0.73,
                               height: min(geometry.size.height * 0.54, geometry.size.width * 0.38))
                }
                if model.step == .balanceInstructions || model.step == .awaitingLandscape {
                    Color.black.opacity(0.42).allowsHitTesting(false)
                }
            }.clipped()
        }
        .allowsHitTesting(!model.isDemonstrating)
        .task(id: model.lastHarvest) {
            activeCut = model.lastHarvest
            guard activeCut != nil else { return }
            do { try await Task.sleep(for: .milliseconds(420)) } catch { return }
            activeCut = nil
        }
    }

    private var asset: String {
        switch model.step {
        case .harvesting: "dibuat_before"
        case .harvestSuccess, .awaitingLandscape: "dibuat_after"
        case .balanceInstructions, .balancing, .balanceDemo, .awaitingPortrait: "drying_rice_before"
        case .drying, .complete: "drying_rice_after"
        }
    }

    private func harvestTargets(in size: CGSize) -> some View {
        let photo = UIImage(named: "dibuat_before")?.size ?? CGSize(width: 2, height: 3)
        let scale = max(size.width / photo.width, size.height / photo.height)
        let width = photo.width * scale
        let height = photo.height * scale
        return ForEach(targets.indices, id: \.self) { index in
            let target = targets[index]
            let done = model.harvested.contains(index)
            ZStack {
                if !done {
                    Button { model.harvest(index) } label: {
                        Circle().strokeBorder(.white.opacity(0.85), style: StrokeStyle(lineWidth: 2, dash: [4, 4]))
                            .frame(width: 42, height: 42)
                            .frame(width: 64, height: 64)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .simultaneousGesture(MagnifyGesture().onEnded { value in
                        if value.magnification < 0.85 { model.harvest(index) }
                    })
                    .accessibilityLabel("Panen malai \(index + 1)")
                    .accessibilityIdentifier("field.harvest.\(index)")
                } else if activeCut == index {
                    Image("dibuat_etem").resizable().scaledToFit()
                        .frame(width: 58, height: 54)
                        .transition(reduceMotion ? .opacity : .offset(x: 26, y: -24).combined(with: .opacity))
                        .accessibilityHidden(true)
                }
            }
            .animation(.easeOut(duration: reduceMotion ? 0.12 : 0.3), value: activeCut)
            .position(x: (size.width - width) / 2 + width * target.x,
                      y: (size.height - height) / 2 + height * target.y)
        }
    }
}
