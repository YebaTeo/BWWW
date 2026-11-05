import XCTest
@testable import BeBaduy

private actor DemonstrationSteps {
    private var pending: [CheckedContinuation<Void, Never>] = []
    var count: Int { pending.count }
    func wait() async { await withCheckedContinuation { pending.append($0) } }
    func step() { if !pending.isEmpty { pending.removeFirst().resume() } }
}

final class StoryPilotTests: XCTestCase {
    @MainActor private func pilot() -> StoryJourneyViewModel {
        StoryJourneyViewModel(journey: JourneyViewModel(store: StoryPreviewStore()), motion: FakeMotion())
    }
    @MainActor func testScrollingIsReadingOnlyAndLockedContentIsAbsent() {
        let vm = pilot()
        let viewport = CGRect(x: 0, y: 0, width: 375, height: 600)
        vm.updateVisibility(frames: [.ngaseukIntroduction: CGRect(x: 0, y: -600, width: 375, height: 600),
                                     .ngaseukActivity: viewport], viewport: viewport)
        XCTAssertEqual(vm.readingSection, .ngaseukActivity)
        XCTAssertTrue(vm.activityVisible)
        XCTAssertEqual(vm.ngaseuk.session.stage, .introduction)
        XCTAssertFalse(vm.ngaseuk.motionActive)
        XCTAssertEqual(vm.sections, [.ngaseukIntroduction, .ngaseukActivity])
        XCTAssertFalse(vm.unlocked)
        XCTAssertFalse(vm.journey.progress.record(for: .ngaseuk).explanationAvailable)
        vm.updateVisibility(frames: [.ngaseukActivity: CGRect(x: 0, y: -590, width: 375, height: 600)], viewport: viewport)
        XCTAssertFalse(vm.activityVisible)
    }
    @MainActor func testDirectTouchCountsOnceAndReplayNeverRelocks() {
        let vm = pilot(); vm.setActivityVisible(true)
        vm.plant(8); XCTAssertEqual(vm.ngaseuk.session.stage, .introduction)
        vm.plant(0); vm.plant(0); XCTAssertEqual(vm.ngaseuk.holes, [0])
        XCTAssertFalse(vm.unlocked)
        vm.plant(1); vm.plant(2)
        XCTAssertTrue(vm.unlocked); XCTAssertEqual(vm.sections, StorySectionID.allCases)
        XCTAssertTrue(vm.journey.progress.record(for: .ngaseuk).performed)
        let progress = vm.journey.progress
        vm.replay(); XCTAssertTrue(vm.ngaseuk.holes.isEmpty)
        XCTAssertEqual(vm.sections, StorySectionID.allCases)
        XCTAssertEqual(vm.journey.progress, progress)
        vm.setActivityVisible(false); vm.plant(0); XCTAssertTrue(vm.ngaseuk.holes.isEmpty)
    }
    @MainActor func testMotionUsesSamePlantingRuleAndVisibilityStopsIt() {
        let motion = FakeMotion()
        let vm = StoryJourneyViewModel(journey: JourneyViewModel(store: StoryPreviewStore()), motion: motion)
        vm.setActivityVisible(true); vm.plant(0); vm.startMotion()
        XCTAssertTrue(vm.ngaseuk.motionActive)
        motion.handler?(.init(time: 0, verticalAcceleration: 0))
        motion.handler?(.init(time: 1, verticalAcceleration: -0.5))
        XCTAssertEqual(vm.ngaseuk.holes, [0, 1])
        vm.setActivityVisible(false); XCTAssertFalse(vm.ngaseuk.motionActive); XCTAssertNil(motion.handler)
        vm.setActivityVisible(true); XCTAssertFalse(vm.ngaseuk.motionActive)
        vm.startMotion(); vm.suspend(); XCTAssertFalse(vm.ngaseuk.motionActive)
        vm.plant(2); XCTAssertTrue(vm.unlocked)
    }
    @MainActor func testPreviewStoreIsIsolatedAndPreservesSchema() {
        let one = pilot(); let two = pilot()
        one.setActivityVisible(true); for target in 0..<3 { one.plant(target) }
        XCTAssertTrue(one.unlocked); XCTAssertFalse(two.unlocked)
        XCTAssertEqual(one.journey.progress.version, 1)
        XCTAssertTrue(one.journey.progress.isValid)
        XCTAssertEqual(two.journey.progress.currentPhase, .ngaseuk)
    }
    @MainActor func testDemonstrationAwardsOnlyAfterThreeStepsAndCancellationCannotFinish() async {
        let vm = pilot(); vm.setActivityVisible(true)
        let steps = DemonstrationSteps()
        vm.ngaseuk.beginStoryDemonstration { await steps.wait() }
        XCTAssertTrue(vm.ngaseuk.isDemonstrating); XCTAssertFalse(vm.unlocked)
        for index in 0..<3 {
            await waitForPending(steps)
            XCTAssertEqual(vm.ngaseuk.storyHoles.count, index)
            await steps.step()
            for _ in 0..<20 { await Task.yield() }
            if index < 2 { XCTAssertFalse(vm.ngaseuk.session.showsDescription) }
        }
        XCTAssertFalse(vm.ngaseuk.session.showsDescription)
        await waitForPending(steps); await steps.step()
        for _ in 0..<20 { await Task.yield() }
        vm.acceptOutcome()
        XCTAssertEqual(vm.ngaseuk.session.outcome, .observed)
        XCTAssertTrue(vm.unlocked); XCTAssertFalse(vm.journey.progress.record(for: .ngaseuk).performed)
        vm.replay()
        vm.ngaseuk.beginStoryDemonstration { await steps.wait() }
        await waitForPending(steps)
        vm.setActivityVisible(false)
        await steps.step()
        for _ in 0..<20 { await Task.yield() }
        XCTAssertFalse(vm.ngaseuk.isDemonstrating); XCTAssertNil(vm.ngaseuk.session.outcome)
        XCTAssertTrue(vm.ngaseuk.storyHoles.isEmpty)
        XCTAssertTrue(vm.unlocked) // Historical completion survives a cancelled replay.
    }
    @MainActor func testInputModeChangeAndInactivityCancelDemonstration() async {
        let vm = pilot(); vm.setActivityVisible(true)
        let steps = DemonstrationSteps()
        vm.ngaseuk.beginStoryDemonstration { await steps.wait() }
        await waitForPending(steps); vm.startMotion()
        await steps.step(); for _ in 0..<20 { await Task.yield() }
        XCTAssertFalse(vm.ngaseuk.isDemonstrating); XCTAssertNil(vm.ngaseuk.session.outcome)
        vm.ngaseuk.beginStoryDemonstration { await steps.wait() }
        await waitForPending(steps); vm.suspend()
        await steps.step(); for _ in 0..<20 { await Task.yield() }
        XCTAssertFalse(vm.ngaseuk.isDemonstrating); XCTAssertFalse(vm.ngaseuk.motionActive)
        XCTAssertFalse(vm.unlocked)
    }
    @MainActor private func waitForPending(_ steps: DemonstrationSteps) async {
        for _ in 0..<1000 {
            if await steps.count > 0 { return }
            await Task.yield()
        }
        XCTFail("Demonstration did not reach its next step")
    }
}
