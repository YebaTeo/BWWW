import XCTest
@testable import BeBaduy

@MainActor final class NukuhTests: XCTestCase {
    func testSceneCannotCompleteWithoutPreparation() {
        let vm = NukuhViewModel(); vm.start()
        vm.burn(); vm.finishBurn(); vm.collect(-1)
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
        XCTAssertEqual(vm.stage, .clearing)

        for index in 0..<3 {
            vm.collect(index)
            vm.collect(index)
        }
        vm.collect(4)
        XCTAssertEqual(vm.collected.count, 3)
        XCTAssertEqual(vm.stage, .clearing)
        vm.collect(3)
        XCTAssertEqual(vm.collected.count, 4)
        XCTAssertEqual(vm.stage, .prepared)

        vm.setVisible(true)
        vm.burn()
        vm.burn(startingAt: 0)
        vm.burn(startingAt: 4)
        XCTAssertEqual(vm.ignited, [0])
        XCTAssertEqual(vm.stage, .burning)
        vm.finishBurn()
        XCTAssertNil(vm.session.outcome)
        for index in 1..<4 { vm.burn(startingAt: index) }
        vm.finishBurn()
        XCTAssertEqual(vm.stage, .complete)
        XCTAssertEqual(vm.session.outcome, .performed)
        let event = vm.session.event
        vm.finishBurn()
        XCTAssertEqual(vm.session.event, event)
    }
}
