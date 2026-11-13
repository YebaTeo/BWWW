import SwiftUI

struct NgaleuitkeunPareActivitySurface: View {
    let model: NgaleuitkeunPareViewModel
    @Environment(ActivityCardState.self) private var card
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        GeometryReader { geometry in
            Color.clear
                .contentShape(Rectangle())
                .gesture(DragGesture(minimumDistance: 5)
                    .onChanged { value in
                        guard !model.isLadderPlaced else { return }
                        model.moveLadder(
                            x: Float(value.translation.width / max(1, geometry.size.width)),
                            y: Float(value.translation.height / max(1, geometry.size.height))
                        )
                    }
                    .onEnded { value in
                        guard !model.isLadderPlaced else { return }
                        let x = value.location.x / max(1, geometry.size.width)
                        let y = value.location.y / max(1, geometry.size.height)
                        if (0.27...0.73).contains(x) && (0.18...0.64).contains(y) {
                            model.placeLadder()
                        } else {
                            model.moveLadder(x: 0, y: 0)
                        }
                    })
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Tangga bambu menuju pintu leuit")
                .accessibilityHint("Seret tangga ke pintu leuit.")
                .accessibilityAction { model.placeLadder() }
                .accessibilityIdentifier("field.ladder")
                .overlay(alignment: .top) {
                    if !model.isLadderPlaced {
                        Text("Seret tangga bambu ke pintu leuit.")
                            .font(.headline)
                            .multilineTextAlignment(.center)
                            .padding(12)
                            .background(.black.opacity(0.7), in: RoundedRectangle(cornerRadius: 14))
                            .padding(.top, 76)
                            .allowsHitTesting(false)
                    }
                }
        }
        .onChange(of: model.isLadderPlaced) { _, placed in
            if placed { card.dismiss() }
        }
        .task(id: model.isLadderPlaced && scenePhase == .active) {
            guard model.isLadderPlaced, scenePhase == .active, model.session.isActive else { return }
            model.setClimbProgress(0)
            model.setEntering(false)
            do {
                if !reduceMotion {
                    for rung in 1...6 {
                        model.setClimbProgress(Float(rung) / 6)
                        try await Task.sleep(for: .milliseconds(250))
                    }
                } else {
                    model.setClimbProgress(1)
                }
                model.setEntering(true)
                try await Task.sleep(for: .milliseconds(850))
                guard !Task.isCancelled else { return }
                model.finish()
            } catch { return }
        }
    }
}
