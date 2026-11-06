import XCTest
@MainActor final class HomeUITests: XCTestCase {
    func testSwipeUnfinishedChapterOpensActivityAndMenuHasFiveChapters() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-progress"]
        app.launch()
        XCTAssertTrue(app.buttons["intro.continue"].waitForExistence(timeout: 10))
        app.buttons["intro.continue"].tap(); app.buttons["intro.continue"].tap()
        XCTAssertTrue(app.buttons["start"].waitForExistence(timeout: 5))
        app.swipeUp()
        XCTAssertTrue(app.staticTexts["nukuh.sceneReady"].waitForExistence(timeout: 30))
        XCTAssertFalse(app.buttons["continue"].exists)
        app.buttons["lesson.back"].tap()
        app.buttons["home.journey"].tap()
        XCTAssertTrue(app.buttons["phase_ngahuru"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["phase_ngaseuk"].isEnabled)
        XCTAssertFalse(app.buttons["phase_narawas"].exists)
    }
}
