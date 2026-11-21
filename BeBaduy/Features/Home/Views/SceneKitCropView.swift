// SceneKitCropView.swift
// BeBaduy – Kanekes traditional rice-farming ceremony visualiser
//
// 5-stage cinematic scene driven by a single progress: CGFloat (0 → 1)
//   Stage 1  NARAWAS   p 0.000 – 0.333  Dense wild forest
//   Transition 1→2   p 0.100 – 0.333  Trees fall & burn
//   Stage 2  NGASEUK p 0.333 – 0.666  Cleared, plain soil
//   Stage 3  NGORED  p 0.666 – 0.750  Dibble holes and seeds
//   Stage 4  MIPIT  p 0.666 – 0.750  Golden panicles / harvest
//   Stage 5  LEUIT   p 0.750 – 1.000  Bamboo rack rises; harvested rice hangs

import SceneKit
import SwiftUI

// MARK: - Public SwiftUI wrapper

struct LeuitActivitySceneState: Equatable {
    var ladderPlaced: Bool
    var dragX: Float
    var dragY: Float
    var climbProgress: Float
    var doorOpening: Float
    var enteringProgress: Float
}

struct SceneKitCropView: UIViewRepresentable {
    let progress: CGFloat
    let isActive: Bool
    var showsRice = true
    var showsMipitHarvestTargets = true
    var showsTreeFallEffects = true
    var mipitHarvested: Set<Int> = []
    var showsRackPosts = true
    var rackBalance = 0.0
    var animateWhileInactive = false
    var rackTransitionTimeConstant = 0.16
    var rackScale: Float = 0.92
    var leuitActivity: LeuitActivitySceneState? = nil
    var onSettledFrame: (() -> Void)? = nil
    var onFirstFrame: (() -> Void)? = nil
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeCoordinator() -> HomeSceneRenderer { HomeSceneRenderer() }

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero, options: [
            SCNView.Option.preferredRenderingAPI.rawValue: SCNRenderingAPI.metal.rawValue
        ])
        #if DEBUG
        print("SceneKitCropView uses Metal: \(view.renderingAPI == .metal)")
        #endif
        context.coordinator.install(in: view)
        if let onFirstFrame { context.coordinator.notifyAfterFirstFrame(in: view, action: onFirstFrame) }
        context.coordinator.showsRice = showsRice
        context.coordinator.showsMipitHarvestTargets = showsMipitHarvestTargets
        context.coordinator.showsTreeFallEffects = showsTreeFallEffects
        context.coordinator.mipitHarvested = mipitHarvested
        context.coordinator.showsRackPosts = showsRackPosts
        context.coordinator.rackBalance = rackBalance
        context.coordinator.rackTransitionTimeConstant = rackTransitionTimeConstant
        context.coordinator.rackScale = rackScale
        context.coordinator.leuitActivity = leuitActivity
        context.coordinator.setActive(shouldRender, in: view, reduceMotion: reduceMotion)
        context.coordinator.update(progress: progress)
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {
        let renderer = context.coordinator
        if renderer.showsTreeFallEffects != showsTreeFallEffects {
            renderer.showsTreeFallEffects = showsTreeFallEffects
        }
        if renderer.showsRice != showsRice { renderer.showsRice = showsRice }
        if renderer.showsMipitHarvestTargets != showsMipitHarvestTargets {
            renderer.showsMipitHarvestTargets = showsMipitHarvestTargets
        }
        if renderer.mipitHarvested != mipitHarvested { renderer.mipitHarvested = mipitHarvested }
        if renderer.showsRackPosts != showsRackPosts { renderer.showsRackPosts = showsRackPosts }
        if renderer.rackBalance != rackBalance { renderer.rackBalance = rackBalance }
        if renderer.rackTransitionTimeConstant != rackTransitionTimeConstant {
            renderer.rackTransitionTimeConstant = rackTransitionTimeConstant
        }
        if renderer.rackScale != rackScale { renderer.rackScale = rackScale }
        if renderer.leuitActivity != leuitActivity { renderer.leuitActivity = leuitActivity }
        renderer.setActive(shouldRender, in: view, reduceMotion: reduceMotion)
        renderer.update(progress: progress)
        if let onSettledFrame {
            renderer.afterSettling = { [weak renderer, weak view] in
                guard let renderer, let view else { return }
                renderer.notifyAfterFirstFrame(in: view, action: onSettledFrame)
            }
        } else {
            renderer.afterSettling = nil
        }
    }

    static func dismantleUIView(_ view: SCNView, coordinator: HomeSceneRenderer) {
        coordinator.stopUpdates()
        view.isPlaying = false
    }

    private var shouldRender: Bool {
        (isActive && scenePhase == .active) || (animateWhileInactive && scenePhase == .inactive)
    }

}
