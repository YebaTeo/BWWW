import XCTest
@testable import BeBaduy

@MainActor final class LeuitDiscoveryTests: XCTestCase {
    func testEveryChoiceNeedsASeparateRevealAndFinishesOnce() {
        for index in 0..<7 {
            let model = LeuitDiscoveryViewModel(cardCount: 7)
            model.choose(-1)
            model.choose(7)
            XCTAssertNil(model.selected)
            model.choose(index)
            model.choose((index + 1) % 7)
            model.reveal()
            XCTAssertEqual(model.selected, index)
            XCTAssertEqual(model.step, .movingForward)
            XCTAssertFalse(model.finish())

            model.finishMoving(visit: model.visit)
            XCTAssertEqual(model.step, .awaitingReveal)
            model.reveal()
            XCTAssertEqual(model.step, .revealing)
            XCTAssertFalse(model.finish())

            model.finishRevealing(visit: model.visit)
            XCTAssertTrue(model.finish())
            XCTAssertFalse(model.finish())
        }
    }

    func testAnimationCompletionsFromPriorVisitsAreIgnored() {
        let model = LeuitDiscoveryViewModel(cardCount: 7)
        let priorVisit = model.visit
        model.choose(0)
        model.reset()
        XCTAssertNil(model.selected)
        XCTAssertEqual(model.step, .choosing)

        model.choose(6)
        model.finishMoving(visit: priorVisit)
        XCTAssertEqual(model.step, .movingForward)
        model.finishMoving(visit: model.visit)
        model.reveal()
        model.finishRevealing(visit: priorVisit)
        XCTAssertEqual(model.step, .revealing)
    }
}
