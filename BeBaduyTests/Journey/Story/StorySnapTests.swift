import XCTest
@testable import BeBaduy

final class StorySnapTests: XCTestCase {
    func testFastFlickCannotSkipExplanationInEitherDirection() {
        XCTAssertEqual(offset(1800, from: 600), 1200)
        XCTAssertEqual(offset(0, from: 1800), 1200)
        XCTAssertEqual(offset(1800, from: 0), 600)
    }
    func testBoundsAndCancelledSwipe() {
        XCTAssertEqual(offset(-900, from: 0), 0)
        XCTAssertEqual(offset(4000, from: 1800), 1800)
        XCTAssertEqual(offset(650, from: 600), 600)
        XCTAssertEqual(StorySnapBehavior.singlePageOffset(proposed: 1800, start: 600,
            height: 600, contentHeight: 1200), 600)
    }
    private func offset(_ proposed: CGFloat, from start: CGFloat) -> CGFloat {
        StorySnapBehavior.singlePageOffset(proposed: proposed, start: start,
            height: 600, contentHeight: 2400)
    }
}
