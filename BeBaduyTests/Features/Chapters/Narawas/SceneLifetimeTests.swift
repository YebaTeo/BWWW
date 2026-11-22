import XCTest
import SceneKit
@testable import BeBaduy

final class SceneLifetimeTests: XCTestCase {
    @MainActor func testNgoredPreparesFieldBeforeActivityAndReusesRiceNodes() async throws {
        let model = NgoredViewModel()
        let ready = await model.scene.prepareNgoredField()
        XCTAssertTrue(ready)
        XCTAssertFalse(model.session.isActive)
        let field = try XCTUnwrap(model.scene.takePreparedFieldView())
        let rice = try XCTUnwrap(field.scene?.rootNode.childNode(withName: "ngoredRice_0", recursively: true))
        model.start()
        model.scene.attach(field, prepared: true)
        defer { model.scene.stop() }
        XCTAssertTrue(field.scene?.rootNode.childNode(withName: "ngoredRice_0", recursively: true) === rice)
    }

    @MainActor func testNgoredRegrowthUsesOriginalPlotsAndOnlyRiceGlows() async throws {
        let renderer = NgahumaScene()
        let view = SCNView()
        renderer.attach(view)
        defer { renderer.stop() }
        await renderer.prepareAssets()
        renderer.showNgoredField()
        renderer.revealNgoredRegrowth()
        let root = try XCTUnwrap(view.scene?.rootNode)
        func node(_ name: String) throws -> SCNNode {
            try XCTUnwrap(root.childNode(withName: name, recursively: true))
        }
        for (offset, original) in [0, 1, 3].enumerated() {
            let weed = try node("ngoredWeed_\(4 + offset)")
            XCTAssertEqual(weed.simdWorldPosition, try node("ngoredWeed_\(original)").simdWorldPosition)
            XCTAssertNil(weed.childNode(withName: "ngoredRiceGlow", recursively: true))
        }
        for index in 0..<3 {
            let rice = try node("ngoredRice_\(index)")
            let glow = try XCTUnwrap(rice.childNode(withName: "ngoredRiceGlow", recursively: true))
            XCTAssertEqual(glow.geometry?.firstMaterial?.blendMode, .add)
        }
    }

    @MainActor func testNgoredSunArcIsVisibleAndLightsTheFieldFromTheDisk() async throws {
        let renderer = NgahumaScene()
        let view = SCNView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        renderer.attach(view)
        defer { renderer.stop() }
        await renderer.prepareAssets()
        renderer.showNgoredField()
        let root = try XCTUnwrap(view.scene?.rootNode)
        let camera = try XCTUnwrap(root.childNode(withName: "narawasARCamera", recursively: true))
        view.pointOfView = camera
        let sun = try XCTUnwrap(root.childNode(withName: "spatialSunLightSource", recursively: true))
        let light = try XCTUnwrap(sun.childNodes.first { $0.light?.type == .directional })
        XCTAssertTrue(light.light?.castsShadow == true)
        XCTAssertEqual(light.light?.shadowMode, .deferred)

        renderer.setNgoredGrowth(0.5)
        let field = XCTAttachment(image: view.snapshot())
        field.name = "Ngored daylight"
        field.lifetime = .keepAlways
        add(field)

        renderer.animateNgoredDayNight(cycles: 1, duration: 4, growthFrom: 0, growthTo: 1) {}
        for delta in [0.0, 1.0, 0.99] {
            renderer.advanceNgoredDayNight(by: delta)
            let point = view.projectPoint(sun.worldPosition)
            XCTAssertGreaterThan(point.z, 0)
            XCTAssertLessThan(point.z, 1)
            XCTAssertTrue(view.bounds.insetBy(dx: 20, dy: 50).contains(CGPoint(x: CGFloat(point.x), y: CGFloat(point.y))))
            let towardField = simd_normalize(SIMD3<Float>(0, 0.038, 0) - sun.simdWorldPosition)
            XCTAssertGreaterThan(simd_dot(light.simdWorldFront, towardField), 0.999)
        }
    }

    @MainActor func testClosingDuringNgoredGrowthReleasesRenderer() async {
        for _ in 0..<3 {
            var renderer: NgahumaScene? = NgahumaScene()
            weak var releasedRenderer = renderer
            var view: SCNView? = SCNView()
            renderer!.attach(view!)
            await renderer!.prepareAssets()
            XCTAssertNil(renderer!.assetError)
            renderer!.showNgoredField()
            renderer!.growNgoredRice()
            renderer!.stop()
            view = nil
            renderer = nil
            XCTAssertNil(releasedRenderer)
        }
    }
}
