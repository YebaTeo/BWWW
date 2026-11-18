import XCTest
@testable import BeBaduy

@MainActor final class NarawasTests: XCTestCase {
    func testSceneCannotCompleteWithoutPreparation() {
        let vm = NarawasViewModel(); vm.start()
        vm.burn(); vm.finishBurn(); vm.collect(-1)
        XCTAssertNil(vm.session.outcome)
        XCTAssertTrue(vm.collected.isEmpty)
        vm.suspend(); XCTAssertTrue(vm.scene.suspended)
    }

    func testReplayKeepsPreviouslySavedCredit() {
        var progress = JourneyProgress(); progress.complete(.narawas, outcome: .observed)
        let vm = NarawasViewModel(); vm.restore(progress.record(for: .narawas).outcome)
        vm.start(); XCTAssertNil(vm.session.outcome)
        XCTAssertTrue(progress.record(for: .narawas).explanationAvailable)
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

        let vm = NarawasViewModel()
        vm.start()
        await vm.scene.prepareAssets()
        XCTAssertEqual(vm.stage, .clearing)

        vm.collect(3)
        XCTAssertTrue(vm.collected.isEmpty)
        for index in 0..<NarawasViewModel.treeCount {
            for tap in 1..<NarawasViewModel.tapsPerTree {
                vm.collect(index)
                XCTAssertEqual(vm.treeTapCounts[index], tap)
                XCTAssertFalse(vm.collected.contains(index))
            }
            vm.collect(index)
            XCTAssertEqual(vm.treeTapCounts[index], NarawasViewModel.tapsPerTree)
            XCTAssertTrue(vm.collected.contains(index))
        }
        XCTAssertEqual(vm.collected.count, NarawasViewModel.treeCount)
        XCTAssertEqual(vm.stage, .prepared)

        vm.setVisible(true)
        vm.burn()
        XCTAssertEqual(vm.stage, .burning)
        vm.finishBurn()
        XCTAssertNil(vm.session.outcome)
        for index in 1..<NarawasViewModel.treeCount { vm.burn(startingAt: index) }
        vm.finishBurn()
        XCTAssertEqual(vm.stage, .complete)
        XCTAssertEqual(vm.session.outcome, .performed)
    }
}
