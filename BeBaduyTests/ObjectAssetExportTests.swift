import XCTest
import SceneKit
import ModelIO
@testable import BeBaduy

@MainActor final class ObjectAssetExportTests: XCTestCase {
    func testExportObjects() async throws {
        let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ObjectExports")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        var report: [String] = []

        func visibleBounds(of root: SCNNode) -> (min: SCNVector3, max: SCNVector3) {
            var minV = SCNVector3(Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude, Float.greatestFiniteMagnitude)
            var maxV = SCNVector3(-Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude, -Float.greatestFiniteMagnitude)
            var found = false
            root.enumerateChildNodes { node, _ in
                guard !node.isHidden, let geo = node.geometry, !geo.elements.isEmpty else { return }
                let box = node.boundingBox
                let localSpan = max(box.max.x - box.min.x, max(box.max.y - box.min.y, box.max.z - box.min.z))
                guard localSpan.isFinite, localSpan > 0.00001 else { return }
                if localSpan > 15.0 && root.childNodes.count > 1 { return }
                for x in [box.min.x, box.max.x] {
                    for y in [box.min.y, box.max.y] {
                        for z in [box.min.z, box.max.z] {
                            let pt = node.convertPosition(SCNVector3(x, y, z), to: root)
                            guard pt.x.isFinite, pt.y.isFinite, pt.z.isFinite else { continue }
                            found = true
                            minV.x = min(minV.x, pt.x); maxV.x = max(maxV.x, pt.x)
                            minV.y = min(minV.y, pt.y); maxV.y = max(maxV.y, pt.y)
                            minV.z = min(minV.z, pt.z); maxV.z = max(maxV.z, pt.z)
                        }
                    }
                }
            }
            if !found { return (SCNVector3(-0.2, -0.2, -0.2), SCNVector3(0.2, 0.2, 0.2)) }
            return (minV, maxV)
        }

        func stripDeadLeaves(_ node: SCNNode) {
            for child in node.childNodes {
                stripDeadLeaves(child)
            }
            if let geo = node.geometry, geo.elements.isEmpty {
                node.geometry = nil
            }
            if node.geometry == nil && node.childNodes.isEmpty {
                node.removeFromParentNode()
            }
        }

        func renderAndExport(
            _ name: String,
            _ original: SCNNode,
            writeUSDZ: Bool = true,
            fallbackUSDZ: URL? = nil,
            cameraOffset: SIMD3<Float> = SIMD3(0.6, 0.35, 2.3),
            scaleFactor: Float = 0.72,
            fixedCenter: SCNVector3? = nil,
            fixedSpan: Float? = nil
        ) throws {
            let scene = SCNScene()
            let object = original.clone()
            object.position = SCNVector3Zero
            object.isHidden = false
            object.opacity = 1
            object.enumerateChildNodes { node, _ in
                node.removeAllActions()
                node.removeAllParticleSystems()
                node.physicsBody = nil
                if node.camera != nil || node.light != nil || node.name == "Camera" || node.name == "env_light" || (node.name?.hasPrefix("Light") ?? false) {
                    node.removeFromParentNode()
                    return
                }
                if node.name?.lowercased().contains("shadow") == true {
                    node.removeFromParentNode()
                    return
                }
                if let geo = node.geometry {
                    node.geometry = geo.copy() as? SCNGeometry
                    node.geometry?.materials = geo.materials.map {
                        let m = $0.copy() as! SCNMaterial
                        m.shaderModifiers = nil
                        return m
                    }
                }
            }
            stripDeadLeaves(object)
            scene.rootNode.addChildNode(object)

            let bounds = visibleBounds(of: object)
            let computedCenter = SCNVector3(
                (bounds.min.x + bounds.max.x) * 0.5,
                (bounds.min.y + bounds.max.y) * 0.5,
                (bounds.min.z + bounds.max.z) * 0.5
            )
            let computedSpan = max(bounds.max.x - bounds.min.x, max(bounds.max.y - bounds.min.y, bounds.max.z - bounds.min.z))
            let center = fixedCenter ?? computedCenter
            let span = fixedSpan ?? computedSpan

            let camera = SCNNode()
            camera.camera = SCNCamera()
            camera.camera!.usesOrthographicProjection = true
            camera.camera!.orthographicScale = Double(max(span * scaleFactor, 0.04))
            camera.camera!.zNear = 0.001
            camera.camera!.zFar = Double(max(span * 30, 100))
            camera.position = SCNVector3(
                center.x + span * cameraOffset.x,
                center.y + span * cameraOffset.y,
                center.z + span * cameraOffset.z
            )
            camera.look(at: center)
            scene.rootNode.addChildNode(camera)

            let key = SCNNode()
            key.light = SCNLight()
            key.light!.type = .directional
            key.light!.color = UIColor(red: 1.0, green: 0.96, blue: 0.88, alpha: 1)
            key.light!.intensity = 1100
            key.position = SCNVector3(span * 1.5, span * 2.5, span * 2.5)
            key.look(at: center)
            scene.rootNode.addChildNode(key)

            let rim = SCNNode()
            rim.light = SCNLight()
            rim.light!.type = .directional
            rim.light!.color = UIColor(red: 1.0, green: 0.92, blue: 0.80, alpha: 1)
            rim.light!.intensity = 420
            rim.position = SCNVector3(-span * 1.8, span * 1.2, -span * 1.2)
            rim.look(at: center)
            scene.rootNode.addChildNode(rim)

            let ambient = SCNNode()
            ambient.light = SCNLight()
            ambient.light!.type = .ambient
            ambient.light!.intensity = 520
            scene.rootNode.addChildNode(ambient)

            if let env = UIImage(named: "HumaEnvironment") {
                scene.lightingEnvironment.contents = env
                scene.lightingEnvironment.intensity = 0.8
            }
            scene.background.contents = UIColor.clear

            let renderer = SCNRenderer(device: nil, options: nil)
            renderer.scene = scene
            renderer.pointOfView = camera
            let preview = renderer.snapshot(atTime: 0, with: CGSize(width: 1024, height: 1024), antialiasingMode: .multisampling4X)
            try XCTUnwrap(preview.pngData()).write(to: folder.appendingPathComponent(name + ".png"))

            // Export USDZ from a scene without helper camera/lights.
            camera.removeFromParentNode()
            key.removeFromParentNode()
            rim.removeFromParentNode()
            ambient.removeFromParentNode()

            let outUSDZ = folder.appendingPathComponent(name + ".usdz")
            if FileManager.default.fileExists(atPath: outUSDZ.path) {
                try? FileManager.default.removeItem(at: outUSDZ)
            }
            if writeUSDZ {
                let written = scene.write(to: outUSDZ, options: nil, delegate: nil, progressHandler: nil)
                report.append("\(name): USDZ=\(written)")
                if !written, let fallbackUSDZ {
                    try FileManager.default.copyItem(at: fallbackUSDZ, to: outUSDZ)
                }
            } else if let fallbackUSDZ {
                try FileManager.default.copyItem(at: fallbackUSDZ, to: outUSDZ)
                report.append("\(name): USDZ=copied")
            }
        }

        // 1. Seeded dibble hole & crisp overhead planting hole
        let seededHole = HomeSceneRenderer.makePlantingHoleNode(homePreview: false)
        let seedOffsets: [(x: Float, z: Float)] = [(-0.004, 0.001), (0.004, -0.001), (0.001, 0.004), (0.001, -0.004)]
        for offset in seedOffsets {
            let s = HomeSceneRenderer.makePlantingSeedNode()
            s.position = SCNVector3(offset.x, -0.002, offset.z)
            seededHole.addChildNode(s)
        }
        try renderAndExport("dibble_hole_seeded", seededHole, cameraOffset: SIMD3(0.0, 1.4, 1.4), scaleFactor: 0.68)
        try renderAndExport("planting_hole", HomeSceneRenderer.makePlantingHoleNode(homePreview: false), cameraOffset: SIMD3(0.0, 1.4, 1.4), scaleFactor: 0.68)

        // 2. Ngored 7-blade weed clump
        let ngahuma = NgahumaScene()
        let ngView = SCNView(frame: CGRect(x: 0, y: 0, width: 256, height: 256))
        ngahuma.attach(ngView)
        await ngahuma.prepareAssets()
        if let weed = ngView.scene?.rootNode.childNode(withName: "ngoredWeed_0", recursively: true) {
            try renderAndExport("ngored_weed", weed, cameraOffset: SIMD3(0.55, 0.45, 2.1), scaleFactor: 0.75)
        }
        ngahuma.stop()

        // 3. Full assembled & textured Leuit granary preview
        let granary = HomeSceneRenderer.makeMenuGranaryPreview()
        let lumbungURL = Bundle.main.url(forResource: "lumbung", withExtension: "usdz")
            ?? Bundle.main.url(forResource: "lumbung", withExtension: "usdz", subdirectory: "Shared/Rendering/Huma/Resources")
        try renderAndExport(
            "leuit_granary",
            granary,
            writeUSDZ: false,
            fallbackUSDZ: lumbungURL,
            cameraOffset: SIMD3(0, 0.55, 2.5),
            scaleFactor: 0.85,
            fixedCenter: SCNVector3(0, 0.22, 0),
            fixedSpan: 0.65
        )

        try report.joined(separator: "\n").write(to: folder.appendingPathComponent("export-log.txt"), atomically: true, encoding: .utf8)
    }
}
