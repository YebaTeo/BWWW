import XCTest

@MainActor final class HomeUITests: XCTestCase {
    func testPreviewDoesNotUnlockJourneyAndHomeNavigationWorks() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-progress"]
        app.launch()
        XCTAssertTrue(app.buttons["home.stage.0"].waitForExistence(timeout: 15))
        for (index, title) in ["NUKUH", "NGASEUK", "NGORED", "DIBUAT"].enumerated() {
            app.buttons["home.stage.\(index)"].tap()
            XCTAssertEqual(app.staticTexts["home.stage.title"].label, title)
        }
        XCTAssertEqual(app.staticTexts["home.progress"].label, "0 dari 11 tahap telah dijelajahi")
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Harvest-home"; screenshot.lifetime = .keepAlways; add(screenshot)
        app.buttons["home.journey"].tap()
        XCTAssertTrue(app.buttons["phase_narawas"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["phase_nyacar"].isEnabled)
        app.buttons["phase_narawas"].tap()
        XCTAssertTrue(app.navigationBars["Narawas"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["resume"].waitForExistence(timeout: 5))
        app.buttons["resume"].tap()
        XCTAssertTrue(app.navigationBars["Narawas"].waitForExistence(timeout: 5))
    }

    func testSingleSwipeAdvancesOnePreview() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-progress"]
        app.launch()
        XCTAssertTrue(app.buttons["home.stage.0"].waitForExistence(timeout: 15))
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.40))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.24))
        start.press(forDuration: 0.05, thenDragTo: end)
        XCTAssertEqual(app.staticTexts["home.stage.title"].label, "NGASEUK")
        end.press(forDuration: 0.05, thenDragTo: start)
        XCTAssertEqual(app.staticTexts["home.stage.title"].label, "NUKUH")
    }
}
