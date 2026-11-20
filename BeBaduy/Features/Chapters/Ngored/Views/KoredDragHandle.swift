import SwiftUI
import UIKit

/// Captures a field swipe in the same coordinate space as the projected weeds.
struct KoredDragHandle: UIViewRepresentable {
    let onSwipe: (CGPoint, CGPoint) -> Bool

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
        private var stroke = KoredStrokeTracker()
        var onSwipe: (CGPoint, CGPoint) -> Bool

        init(onSwipe: @escaping (CGPoint, CGPoint) -> Bool) {
            self.onSwipe = onSwipe
        }

        @objc func pan(_ gesture: UIPanGestureRecognizer) {
            let point = gesture.location(in: gesture.view)
            switch gesture.state {
            case .began:
                let delta = gesture.translation(in: gesture.view)
                stroke.begin(at: CGPoint(x: point.x - delta.x, y: point.y - delta.y))
                fallthrough
            case .changed, .ended:
                stroke.move(to: point, hitTest: onSwipe)
            default:
                break
            }
        }
    }
}
