import SwiftUI
import UIKit

@MainActor
final class HarvestOrientationDelegate: NSObject, UIApplicationDelegate {
    static weak var landscapeScene: UIWindowScene?

    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        if let scene = window?.windowScene, scene === Self.landscapeScene {
            return .allButUpsideDown
        }
        return .portrait
    }
}

/// Observes the interface orientation of the window actually presenting Mipit.
struct HarvestOrientation: UIViewControllerRepresentable {
    let allowsLandscape: Bool
    let returnToPortrait: Bool
    let onChange: (Int) -> Void

    func makeUIViewController(context: Context) -> Controller { Controller() }

    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.configuration = self
        controller.scheduleUpdate()
    }

    static func dismantleUIViewController(_ controller: Controller, coordinator: ()) {
        controller.configuration = nil
        controller.restorePortrait()
    }

    final class Controller: UIViewController {
        var configuration: HarvestOrientation?
        private weak var scene: UIWindowScene?
        private var allowed = false
        private var requestedPortrait = false
        private var updateQueued = false

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            scheduleUpdate()
        }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            scheduleUpdate()
        }

        override func viewWillTransition(to size: CGSize, with coordinator: any UIViewControllerTransitionCoordinator) {
            super.viewWillTransition(to: size, with: coordinator)
            coordinator.animate(alongsideTransition: nil) { [weak self] _ in
                self?.scheduleUpdate()
            }
        }

        func scheduleUpdate() {
            guard !updateQueued else { return }
            updateQueued = true
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.updateQueued = false
                self.updateOrientation()
            }
        }

        private func updateOrientation() {
            guard let configuration, let scene = view.window?.windowScene else { return }
            self.scene = scene
            let leavingLandscape = allowed && !configuration.allowsLandscape
            if allowed != configuration.allowsLandscape {
                allowed = configuration.allowsLandscape
                HarvestOrientationDelegate.landscapeScene = allowed ? scene : nil
                view.window?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            }
            if (configuration.returnToPortrait || leavingLandscape) && !requestedPortrait {
                requestedPortrait = true
                requestPortrait(in: scene)
            } else if !configuration.returnToPortrait {
                requestedPortrait = false
            }
            let orientation = scene.effectiveGeometry.interfaceOrientation
            configuration.onChange(orientation == .landscapeLeft ? 1 : orientation == .landscapeRight ? -1 : 0)
        }

        func restorePortrait() {
            guard let scene, scene === HarvestOrientationDelegate.landscapeScene || allowed else { return }
            allowed = false
            HarvestOrientationDelegate.landscapeScene = nil
            requestPortrait(in: scene)
        }

        private func requestPortrait(in scene: UIWindowScene) {
            (view.window ?? scene.keyWindow)?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
            scene.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
        }
    }
}
