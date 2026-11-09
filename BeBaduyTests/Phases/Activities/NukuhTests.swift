import XCTest
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

    func testThreeSpatialLayersAndInteractiveFlow() async throws {
        let materials = try await NgahumaMaterials.load()
        XCTAssertEqual(materials.skyTexture.cgImage?.width, 2048)
        XCTAssertEqual(materials.skyTexture.cgImage?.height, 1024)
        XCTAssertEqual(materials.mountainTexture.cgImage?.width, 2048)
        XCTAssertEqual(materials.mountainTexture.cgImage?.height, 512)
        XCTAssertEqual(materials.horizonGrassTexture.cgImage?.width, 2048)
        XCTAssertEqual(materials.horizonGrassTexture.cgImage?.height, 256)
        XCTAssertEqual(materials.soilTexture.cgImage?.width, 1024)
        XCTAssertEqual(materials.soilTexture.cgImage?.height, 1024)

        let vm = NukuhViewModel()
        vm.start()
        await vm.scene.prepareAssets()
        XCTAssertEqual(vm.scene.stage, .clearing)

        for index in 0..<6 {
            vm.collect(index)
        }
        XCTAssertEqual(vm.collected.count, 6)
        XCTAssertEqual(vm.scene.stage, .prepared)

        vm.burn()
        XCTAssertEqual(vm.scene.stage, .burning)
        vm.scene.finishBurn()
        XCTAssertEqual(vm.scene.stage, .complete)
        XCTAssertEqual(vm.session.outcome, .performed)
    }
}
