import SwiftUI
import UIKit

/// A dedicated touch surface for the moving tool, independent of the sheet's pan gesture.
struct KoredDragHandle: UIViewRepresentable {
    var move: (CGSize) -> Void
    var end: () -> Void
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isAccessibilityElement = true
        view.accessibilityIdentifier = "field.kored"
        view.accessibilityLabel = "Kored. Geser gagangnya ke gulma, lalu sapukan ke bawah tiga kali."
        let pan = UIPanGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.pan(_:)))
        pan.delegate = context.coordinator
        view.addGestureRecognizer(pan)
        return view
    }
    func updateUIView(_ view: UIView, context: Context) {
        context.coordinator.parent = self
    }
    @MainActor final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool { true }
        var parent: KoredDragHandle
        init(_ parent: KoredDragHandle) { self.parent = parent }
        @objc func pan(_ gesture: UIPanGestureRecognizer) {
            switch gesture.state {
            case .began, .changed:
                let translation = gesture.translation(in: gesture.view?.window)
                parent.move(CGSize(width: translation.x, height: translation.y))
            case .ended:
                let translation = gesture.translation(in: gesture.view?.window)
                parent.move(CGSize(width: translation.x, height: translation.y))
                parent.end()
            case .cancelled, .failed: parent.end()
            default: break
            }
        }
    }
}
