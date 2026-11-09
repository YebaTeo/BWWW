// SceneKitCropView.swift
// BeBaduy – Kanekes traditional rice-farming ceremony visualiser
//
// 5-stage cinematic scene driven by a single progress: CGFloat (0 → 1)
//   Stage 1  NUKUH   p 0.000 – 0.333  Dense wild forest
//   Transition 1→2   p 0.100 – 0.333  Trees fall & burn
//   Stage 2  NGASEUK p 0.333 – 0.666  Cleared, plain soil
//   Stage 3  NGORED  p 0.666 – 0.750  Dibble holes and seeds
//   Stage 4  DIBUAT  p 0.666 – 0.750  Golden panicles / harvest
//   Stage 5  LEUIT   p 0.750 – 1.000  Bamboo rack rises; harvested rice hangs

import SceneKit
import SwiftUI

// MARK: - Public SwiftUI wrapper

struct SceneKitCropView: UIViewRepresentable {
    let progress: CGFloat
    let isActive: Bool
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeCoordinator() -> HomeSceneRenderer { HomeSceneRenderer() }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero, options: [
            SCNView.Option.preferredRenderingAPI.rawValue: SCNRenderingAPI.metal.rawValue
        ])
        context.coordinator.install(in: view)
        context.coordinator.setActive(isActive && scenePhase == .active, in: view, reduceMotion: reduceMotion)
        context.coordinator.update(progress: progress)
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        context.coordinator.setActive(isActive && scenePhase == .active, in: view, reduceMotion: reduceMotion)
        context.coordinator.update(progress: progress)
    }

    static func dismantleUIView(_ view: SCNView, coordinator: HomeSceneRenderer) {
        coordinator.stopUpdates()
        view.isPlaying = false
    }

}
