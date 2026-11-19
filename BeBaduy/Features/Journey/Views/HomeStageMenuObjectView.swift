import SceneKit
import SwiftUI

/// Small, static previews assembled from the same assets and SceneKit builders as Home.
struct HomeStageMenuObjectView: View {
    let phase: PhaseID

    var body: some View {
        Group {
            switch phase {
            case .narawas:
                Image("HumaTreeNatural")
                    .resizable()
                    .scaledToFit()
            case .ngaseuk:
                AseukTool(pitch: 0.18, yaw: 0.65, roll: -0.42)
            case .ngored, .mipit, .ngalantai, .ngaleuitkeunPare:
                HomeStageSceneIcon(phase: phase)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct HomeStageSceneIcon: UIViewRepresentable {
    let phase: PhaseID

    func makeUIView(context: Context) -> SCNView {
        let view = SCNView(frame: .zero, options: [
            SCNView.Option.preferredRenderingAPI.rawValue: SCNRenderingAPI.metal.rawValue
        ])
        view.backgroundColor = .clear
        view.isOpaque = false
        view.scene = HomeStageMenuScenes.scene(for: phase)
        view.autoenablesDefaultLighting = false
        view.antialiasingMode = .multisampling2X
        view.rendersContinuously = false
        view.isPlaying = false
        view.allowsCameraControl = false
        return view
    }

    func updateUIView(_ view: SCNView, context: Context) {}
}

@MainActor
private enum HomeStageMenuScenes {
    private static var cache: [PhaseID: SCNScene] = [:]

    static func scene(for phase: PhaseID) -> SCNScene {
        if let cached = cache[phase] { return cached }
        let scene = SCNScene()
        scene.background.contents = UIColor.clear
        let object = makeObject(for: phase)
        let holder = SCNNode()
        holder.addChildNode(object)
        scene.rootNode.addChildNode(holder)

        if phase == .ngaleuitkeunPare {
            // The USDZ contains very long hidden helper meshes. Home positions
            // the building directly instead of fitting those mesh bounds.
            holder.scale = SCNVector3(1.35, 1.35, 1.35)
            holder.position = SCNVector3(0, -0.18, 0)
        } else {
            let (minimum, maximum) = bounds(of: object, relativeTo: scene.rootNode)
            let span = max(maximum.x - minimum.x, maximum.y - minimum.y, maximum.z - minimum.z)
            if span.isFinite && span > 0.0001 {
                let scale: Float = 0.92 / span
                holder.scale = SCNVector3(scale, scale, scale)
                holder.position = SCNVector3(
                    -(minimum.x + maximum.x) * 0.5 * scale,
                    -(minimum.y + maximum.y) * 0.5 * scale,
                    -(minimum.z + maximum.z) * 0.5 * scale
                )
            }
        }

        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.orthographicScale = switch phase {
        case .ngored, .mipit: 0.32
        case .ngalantai: 0.48
        case .ngaleuitkeunPare: 0.40
        default: 0.65
        }
        let cameraNode = SCNNode()
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 0.55, 2.5)
        cameraNode.look(at: SCNVector3Zero)
        scene.rootNode.addChildNode(cameraNode)

        let ambient = SCNLight()
        ambient.type = .ambient
        ambient.color = UIColor(white: 0.75, alpha: 1)
        let ambientNode = SCNNode()
        ambientNode.light = ambient
        scene.rootNode.addChildNode(ambientNode)

        let key = SCNLight()
        key.type = .directional
        key.intensity = 1_200
        let keyNode = SCNNode()
        keyNode.light = key
        keyNode.position = SCNVector3(-1, 2, 2)
        keyNode.look(at: SCNVector3Zero)
        scene.rootNode.addChildNode(keyNode)

        cache[phase] = scene
        return scene
    }

    private static func makeObject(for phase: PhaseID) -> SCNNode {
        switch phase {
        case .ngored, .mipit:
            let plant = HomeSceneRenderer.makeNgoredTransitionRicePlant()
            plant.scale = SCNVector3(3.0, 1, 3.0)
            plant.enumerateChildNodes { node, _ in
                if let morpher = node.morpher, !morpher.targets.isEmpty {
                    node.geometry = morpher.targets[0]
                    node.morpher = nil
                }
            }
            if phase == .ngored {
                plant.childNode(withName: "homeRicePanicles", recursively: false)?.removeFromParentNode()
            }
            let cluster = SCNNode()
            for offset: Float in [-0.11, 0, 0.11] {
                let stem = plant.clone()
                stem.position.x = offset
                stem.eulerAngles.y = offset * 2
                cluster.addChildNode(stem)
            }
            return cluster
        case .ngalantai:
            let sheaf = HomeSceneRenderer.makeNgalantaiHarvestedSheaf()
            sheaf.eulerAngles.z = -.pi / 7
            return sheaf
        case .ngaleuitkeunPare:
            return HomeSceneRenderer.makeMenuGranaryPreview()
        case .narawas, .ngaseuk:
            return SCNNode()
        }
    }

    private static func bounds(of root: SCNNode, relativeTo parent: SCNNode) -> (SCNVector3, SCNVector3) {
        var minimum = SCNVector3(Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude)
        var maximum = SCNVector3(-Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude)
        root.enumerateChildNodes { node, _ in
            guard node.geometry != nil else { return }
            let box = node.boundingBox
            for x in [box.min.x, box.max.x] {
                for y in [box.min.y, box.max.y] {
                    for z in [box.min.z, box.max.z] {
                        let point = node.convertPosition(SCNVector3(x, y, z), to: parent)
                        minimum.x = min(minimum.x, point.x)
                        minimum.y = min(minimum.y, point.y)
                        minimum.z = min(minimum.z, point.z)
                        maximum.x = max(maximum.x, point.x)
                        maximum.y = max(maximum.y, point.y)
                        maximum.z = max(maximum.z, point.z)
                    }
                }
            }
        }
        return (minimum, maximum)
    }
}
