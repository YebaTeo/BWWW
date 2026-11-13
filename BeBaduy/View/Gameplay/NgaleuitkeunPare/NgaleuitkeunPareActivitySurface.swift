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
                        let nearDoor = (0.32...0.68).contains(x) && (0.22...0.50).contains(y)
                        let nearFootMarker = (0.22...0.55).contains(x) && (0.52...0.75).contains(y)
                        if nearDoor || nearFootMarker {
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
            model.setDoorOpening(0)
            model.setEnteringProgress(0)
            do {
                if !reduceMotion {
                    for frame in 0...25 {
                        let t = Float(frame) / 25
                        model.setDoorOpening(t * t * (3 - 2 * t))
                        try await Task.sleep(for: .milliseconds(16))
                    }
                    for frame in 0...90 {
                        let t = Float(frame) / 90
                        model.setClimbProgress(t * t * (3 - 2 * t))
                        try await Task.sleep(for: .milliseconds(16))
                    }
                    for frame in 0...70 {
                        let t = Float(frame) / 70
                        model.setEnteringProgress(t * t * (3 - 2 * t))
                        try await Task.sleep(for: .milliseconds(16))
                    }
                } else {
                    model.setDoorOpening(1)
                    model.setClimbProgress(1)
                    model.setEnteringProgress(1)
                }
                try await Task.sleep(for: .milliseconds(350))
                guard !Task.isCancelled else { return }
                model.finish()
            } catch { return }
        }
    }
}
