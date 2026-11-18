import SwiftUI
import UIKit

/// Captures a field swipe in the same coordinate space as the projected weeds.
struct KoredDragHandle: UIViewRepresentable {
    let onSwipe: (CGPoint, CGPoint) -> Void

    func makeCoordinator() -> Coordinator { Coordinator(onSwipe: onSwipe) }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.pan(_:)))
        pan.maximumNumberOfTouches = 1
        view.addGestureRecognizer(pan)
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        context.coordinator.onSwipe = onSwipe
    }

    @MainActor final class Coordinator: NSObject {
        var onSwipe: (CGPoint, CGPoint) -> Void

        init(onSwipe: @escaping (CGPoint, CGPoint) -> Void) {
            self.onSwipe = onSwipe
        }

        @objc func pan(_ gesture: UIPanGestureRecognizer) {
            guard gesture.state == .ended else { return }
            let end = gesture.location(in: gesture.view)
            let delta = gesture.translation(in: gesture.view)
            guard hypot(delta.x, delta.y) >= 18 else { return }
            onSwipe(CGPoint(x: end.x - delta.x, y: end.y - delta.y), end)
        }
    }
}
