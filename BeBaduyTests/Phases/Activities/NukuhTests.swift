import XCTest
import RealityKit
@testable import BeBaduy

@MainActor final class NukuhTests: XCTestCase {
    func testSceneCannotCompleteWithoutPreparation() {
        let vm = NukuhViewModel(); vm.start()
        vm.burn(); vm.scene.finishBurn(); vm.collect(-1)
        XCTAssertNil(vm.session.outcome)
        XCTAssertTrue(vm.collected.isEmpty)
        vm.suspend(); XCTAssertTrue(vm.scene.suspended)
    }
    func testReplayKeepsPreviouslySavedCredit() {
        var progress = JourneyProgress(); progress.complete(.nukuh, outcome: .observed)
        let vm = NukuhViewModel(); vm.restore(progress.record(for: .nukuh).outcome)
        vm.start(); XCTAssertNil(vm.session.outcome)
        XCTAssertTrue(progress.record(for: .nukuh).explanationAvailable)
    }
    func testSphereUVsAndPanorama() throws {
        let mesh = MeshResource.generateSphere(radius: 1.0)
        for model in mesh.contents.models {
            for part in model.parts {
                let positions = Array(part.positions)
                if let uvsBuffer = part.textureCoordinates {
                    let uvs = Array(uvsBuffer)
                    var maxYIndex = 0
                    var minYIndex = 0
                    for (i, p) in positions.enumerated() {
                        if p.y > positions[maxYIndex].y { maxYIndex = i }
                        if p.y < positions[minYIndex].y { minYIndex = i }
                    }
                    print("TEST_SPHERE_NORTH_POLE: pos=\(positions[maxYIndex]) uv=\(uvs[maxYIndex])")
                    print("TEST_SPHERE_SOUTH_POLE: pos=\(positions[minYIndex]) uv=\(uvs[minYIndex])")
                }
            }
        }

        guard let environment = UIImage(named: "HumaEnvironment"),
              let envCG = environment.cgImage else {
            XCTFail("Missing HumaEnvironment")
            return
        }
        print("ENV_CG_DIMENSIONS: \(envCG.width)x\(envCG.height)")

        let pano = NgahumaMaterials.build360Panorama(from: envCG)
        XCTAssertNotNil(pano)
        XCTAssertEqual(pano?.width, 2048)
        XCTAssertEqual(pano?.height, 1024)

        let soil = NgahumaMaterials.extractSeamlessSoil(from: envCG, targetSize: 512)
        XCTAssertNotNil(soil)
        XCTAssertEqual(soil?.width, 512)
        XCTAssertEqual(soil?.height, 512)
    }
}
