import XCTest
@MainActor final class HomeUITests: XCTestCase {
    func testSwipeUnfinishedChapterOpensActivityAndMenuHasSixChapters() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-progress"]
        app.launch()
        XCTAssertTrue(app.buttons["intro.continue"].waitForExistence(timeout: 10))
        app.buttons["intro.continue"].tap(); app.buttons["intro.continue"].tap()
        XCTAssertTrue(app.buttons["resume"].waitForExistence(timeout: 5))
        let scene = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4))
        scene.press(forDuration: 0.05, thenDragTo: scene.withOffset(CGVector(dx: 0, dy: -140)))
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

        XCTAssertTrue(app.buttons["home.stage.0"].waitForExistence(timeout: 15))
        for (index, title) in ["NUKUH", "NGASEUK", "NGORED", "MIPIT", "NGALANTAI", "LEUIT"].enumerated() {
            app.buttons["home.stage.\(index)"].tap()
            waitForPreviewTitle(title, in: app)
            if index == 3 {
                XCTAssertTrue(app.buttons["home.preview.finish"].isHittable)
                XCTAssertTrue(app.buttons["resume"].isHittable)
                app.buttons["home.preview.finish"].tap()
                XCTAssertFalse(app.buttons["home.preview.finish"].exists)
            }
        }
        XCTAssertTrue(app.buttons["resume"].isHittable)
        XCTAssertTrue(app.buttons["home.menu"].isHittable)
        app.buttons["resume"].tap()
        XCTAssertTrue(app.staticTexts["nukuh.sceneReady"].waitForExistence(timeout: 30))
        app.buttons["lesson.back"].tap()
        app.buttons["home.stage.5"].tap()
        let preview = XCTAttachment(screenshot: app.screenshot())
        preview.name = "Leuit-hanging-rice"
        preview.lifetime = .keepAlways
        add(preview)
        XCTAssertEqual(app.staticTexts["home.progress"].label, "0 dari 6 tahap telah dijelajahi")
        app.buttons["home.preview.next"].tap()
        waitForPreviewTitle("NUKUH", in: app)
        app.buttons["resume"].tap()
        XCTAssertTrue(app.staticTexts["nukuh.sceneReady"].waitForExistence(timeout: 30))
    }

    func testSelectedUnlockedChapterOpensInsteadOfSavedChapter() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-progress", "--uitest-ngored"]
        app.launch()
        app.buttons["home.stage.1"].tap()
        XCTAssertTrue(app.buttons["resume"].isHittable)
        app.buttons["resume"].tap()
        XCTAssertTrue(app.scrollViews["lesson.explanation.page"].waitForExistence(timeout: 5))
    }

    private func waitForPreviewTitle(_ title: String, in app: XCUIApplication,
                                     file: StaticString = #filePath, line: UInt = #line) {
        let expectedTitle = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", title),
            object: app.staticTexts["home.stage.title"]
        )
        XCTAssertEqual(XCTWaiter.wait(for: [expectedTitle], timeout: 35), .completed,
                       "Preview did not reach \(title)", file: file, line: line)
    }

}
