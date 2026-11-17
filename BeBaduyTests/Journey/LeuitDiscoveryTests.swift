import XCTest
@testable import BeBaduy

@MainActor final class LeuitDiscoveryTests: XCTestCase {
    func testEveryChoiceNeedsASeparateRevealAndFinishesOnce() {
        for topic in LeuitDiscoveryViewModel.Topic.allCases {
            let model = LeuitDiscoveryViewModel()
            model.choose(topic)
            model.choose(topic == .birth ? .death : .birth)
            model.reveal()
            XCTAssertEqual(model.selected, topic)
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
        let model = LeuitDiscoveryViewModel()
        let priorVisit = model.visit
        model.choose(.birth)
        model.reset()
        XCTAssertNil(model.selected)
        XCTAssertEqual(model.step, .choosing)

        model.choose(.death)
        model.finishMoving(visit: priorVisit)
        XCTAssertEqual(model.step, .movingForward)
        model.finishMoving(visit: model.visit)
        model.reveal()
        model.finishRevealing(visit: priorVisit)
        XCTAssertEqual(model.step, .revealing)
    }
}
