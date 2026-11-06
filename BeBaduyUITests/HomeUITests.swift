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

    func testPoCPadiPreviewKeepsLearningProgressAndResumes() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-progress"]
        app.launch()
        app.buttons["intro.continue"].tap()
        app.buttons["intro.continue"].tap()
        app.buttons["lesson.back"].tap()

        XCTAssertTrue(app.buttons["home.stage.0"].waitForExistence(timeout: 15))
        for (index, title) in ["NUKUH", "NGASEUK", "NGORED", "DIBUAT", "LEUIT"].enumerated() {
            app.buttons["home.stage.\(index)"].tap()
            waitForPreviewTitle(title, in: app)
        }
        let preview = XCTAttachment(screenshot: app.screenshot())
        preview.name = "Leuit-hanging-rice"
        preview.lifetime = .keepAlways
        add(preview)
        XCTAssertEqual(app.staticTexts["home.progress"].label, "0 dari 5 tahap telah dijelajahi")
        app.buttons["home.preview.next"].tap()
        waitForPreviewTitle("NUKUH", in: app)
        app.buttons["resume"].tap()
        XCTAssertTrue(app.buttons["start"].waitForExistence(timeout: 5))
    }

    private func waitForPreviewTitle(_ title: String, in app: XCUIApplication,
                                     file: StaticString = #filePath, line: UInt = #line) {
        // The title follows the scene's progress, including the 30-second
        // Ngored–Dibuat transition. Wait for its label instead of a fixed delay.
        let expectedTitle = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", title),
            object: app.staticTexts["home.stage.title"]
        )
        XCTAssertEqual(XCTWaiter.wait(for: [expectedTitle], timeout: 35), .completed,
                       "Preview did not reach \(title)", file: file, line: line)
    }

}
