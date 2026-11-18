import SwiftUI
import UIKit

struct MipitActivitySurface: View {
    let model: MipitViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var activeCut: Int?
    @GestureState private var isPinching = false
    @State private var harvestedThisPinch = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if [.harvesting, .harvestSuccess].contains(model.step) {
                    harvestTargets(in: geometry.size)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .contentShape(Rectangle())
            .gesture(
                MagnifyGesture(minimumScaleDelta: 0.02)
                    .updating($isPinching) { _, active, _ in active = true }
                    .onChanged { handlePinch($0, in: geometry.size) }
                    .onEnded { handlePinch($0, in: geometry.size) }
            )
            .clipped()
        }
        .allowsHitTesting(!model.isDemonstrating)
        .onChange(of: isPinching) { _, active in
            if !active { harvestedThisPinch = false }
        }
        .task(id: model.lastHarvest) {
            activeCut = model.lastHarvest
            guard activeCut != nil else { return }
            do { try await Task.sleep(for: .milliseconds(420)) } catch { return }
            activeCut = nil
        }
    }

    private func harvestTargets(in size: CGSize) -> some View {
        let plantWidth = min(130, size.width * 0.33)
        let plantHeight = min(260, size.height * 0.34)

        return ForEach(0..<MipitViewModel.harvestCount, id: \.self) { index in
            let done = model.harvested.contains(index)
            let center = plantCenter(index, in: size)

            ZStack {
                Color.clear
                if activeCut == index {
                    Image("mipit_etem")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 62, height: 60)
                        .offset(x: 16, y: 32)
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                        .accessibilityHidden(true)
                }
            }
            .frame(width: plantWidth, height: plantHeight)
            .contentShape(Rectangle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Padi \(index + 1)")
            .accessibilityValue(done ? "Sudah dipanen" : "Siap dipanen")
            .accessibilityHint("Cubit dengan dua jari untuk memanen")
            .accessibilityIdentifier("field.harvest.\(index)")
            .accessibilityAction(named: "Panen padi") {
                if !done { triggerHarvest(index) }
            }
            .animation(.easeInOut(duration: reduceMotion ? 0.12 : 0.55), value: done)
            .position(center)
        }
    }

    private func plantCenter(_ index: Int, in size: CGSize) -> CGPoint {
        CGPoint(x: size.width * (0.22 + CGFloat(index) * 0.28), y: size.height * 0.40)
    }

    private func handlePinch(_ value: MagnifyGesture.Value, in size: CGSize) {
        guard !harvestedThisPinch, value.magnification <= 0.94, model.step == .harvesting else { return }

        let start = value.startLocation
        guard abs(start.y - size.height * 0.40) <= min(170, size.height * 0.23),
              let index = (0..<MipitViewModel.harvestCount).min(by: {
                  abs(plantCenter($0, in: size).x - start.x) < abs(plantCenter($1, in: size).x - start.x)
              }),
              abs(plantCenter(index, in: size).x - start.x) <= size.width * 0.24,
              !model.harvested.contains(index) else { return }

        harvestedThisPinch = true
        triggerHarvest(index)
    }

    private func triggerHarvest(_ index: Int) {
        guard !model.harvested.contains(index) else { return }
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.prepare()
        generator.impactOccurred()
        model.harvest(index)
    }
}
