import XCTest
@testable import BeBaduy

@MainActor final class LessonFlowTests: XCTestCase {
    func testFirstVisitCannotSkipAndRequiresResultAcknowledgement() {
        let flow = LessonFlowViewModel()
        flow.restore(completed: false)
        flow.explain()
        XCTAssertEqual(flow.screen, .introduction)
        flow.explore(hasEquipment: true)
        XCTAssertEqual(flow.screen, .equipment)
        flow.beginActivity()
        flow.explain()
        XCTAssertEqual(flow.screen, .activity)
        flow.completed()
        XCTAssertEqual(flow.screen, .result)
        flow.explain()
        XCTAssertEqual(flow.screen, .explanation)
    }
    func testReplayAndRestoredCompletionAllowSkippingWithoutNewAward() {
        let flow = LessonFlowViewModel()
        flow.restore(completed: true)
        flow.explore(hasEquipment: false)
        flow.explain()
        XCTAssertEqual(flow.screen, .explanation)
        flow.replay()
        XCTAssertEqual(flow.screen, .activity)
        XCTAssertTrue(flow.canSkip)
    }
}
