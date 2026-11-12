import SwiftUI
import UIKit

struct MipitActivitySurface: View {
    let model: MipitViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var activeCut: Int?


    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if [.harvesting, .harvestSuccess].contains(model.step) {
                    harvestTargets(in: geometry.size)
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

    private func harvestTargets(in size: CGSize) -> some View {
        let plantWidth = min(120, size.width * 0.28)
        let plantHeight = min(200, size.height * 0.26)
        return ForEach(0..<MipitViewModel.harvestCount, id: \.self) { index in
            let done = model.harvested.contains(index)
            ZStack {
                Color.clear
                if activeCut == index {
                    Image("mipit_etem").resizable().scaledToFit()
                        .frame(width: 62, height: 60)
                        .offset(x: 16, y: 32)
                        .transition(.opacity)
                        .accessibilityHidden(true)
                }
            }
            .frame(width: plantWidth, height: plantHeight)
            .contentShape(Rectangle())
            .gesture(MagnifyGesture().onEnded { value in
                guard !done, value.magnification < 0.78 else { return }
                model.harvest(index)
            })
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Padi \(index + 1)")
            .accessibilityValue(done ? "Sudah dipanen" : "Siap dipanen")
            .accessibilityHint("Cubit dengan dua jari untuk memanen")
            .accessibilityIdentifier("field.harvest.\(index)")
            .accessibilityAction(named: "Panen padi") {
                if !done { model.harvest(index) }
            }
            .animation(.easeInOut(duration: reduceMotion ? 0.12 : 0.55), value: done)
            .position(x: size.width * (0.22 + CGFloat(index) * 0.28),
                      y: size.height * 0.40)
        }
    }
}
