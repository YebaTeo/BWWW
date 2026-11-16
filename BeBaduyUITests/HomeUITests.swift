import XCTest
@MainActor final class HomeUITests: XCTestCase {
    func testJourneyMenuShowsSceneCardsAndLocksNextStage() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-progress"]
        app.launch()
        finishOnboarding(in: app)
        XCTAssertTrue(app.buttons["resume"].waitForExistence(timeout: 5))
        app.buttons["home.journey"].tap()
        XCTAssertTrue(app.staticTexts["Perjalanan Ngahuma"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["journey.prologue"].exists)
        XCTAssertTrue(app.buttons["phase_ngahuru"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["phase_ngaseuk"].isEnabled)
        XCTAssertFalse(app.buttons["phase_narawas"].exists)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.name = "Journey scene cards"
        screenshot.lifetime = .keepAlways
        add(screenshot)
        app.buttons["home.journey.close"].tap()
        XCTAssertTrue(app.buttons["resume"].waitForExistence(timeout: 5))
    }

    func testPoCPadiPreviewKeepsLearningProgressAndResumes() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-progress"]
        app.launch()
        finishOnboarding(in: app)

        XCTAssertTrue(app.buttons["home.stage.0"].waitForExistence(timeout: 15))
        for (index, title) in ["NARAWAS", "NGASEUK", "NGORED", "MIPIT", "NGALANTAI", "NGALEUITKEUN"].enumerated() {
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
        XCTAssertTrue(app.staticTexts["narawas.sceneReady"].waitForExistence(timeout: 30))
        app.buttons["lesson.back"].tap()
        app.buttons["home.stage.5"].tap()
        XCTAssertTrue(app.buttons["home.preview.finish"].waitForNonExistence(timeout: 8))
        let preview = XCTAttachment(screenshot: app.screenshot())
        preview.name = "Leuit-granary"
        preview.lifetime = .keepAlways
        add(preview)
        XCTAssertEqual(app.staticTexts["home.progress"].label, "0 dari 6 tahap telah dijelajahi")
        app.buttons["home.preview.next"].tap()
        waitForPreviewTitle("NARAWAS", in: app)
        app.buttons["resume"].tap()
        XCTAssertTrue(app.staticTexts["narawas.sceneReady"].waitForExistence(timeout: 30))
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

    func testOnboardingReturnsOnNextLaunch() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-progress"]
        app.launch()

        finishOnboarding(in: app)
        XCTAssertTrue(app.buttons["resume"].waitForExistence(timeout: 15))

        app.terminate()
        app.launchArguments = ["--uitesting"]
        app.launch()
        XCTAssertTrue(app.scrollViews["intro.story"].waitForExistence(timeout: 15))
        finishOnboarding(in: app)
        XCTAssertTrue(app.buttons["resume"].waitForExistence(timeout: 15))
    }

    private func finishOnboarding(in app: XCUIApplication) {
        let story = app.scrollViews["intro.story"]
        XCTAssertTrue(app.staticTexts["Selamat Datang!"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["intro.continue"].isHittable)
        story.swipeUp()
        let pikukuh = app.staticTexts["Pikukuh"]
        XCTAssertTrue(pikukuh.waitForExistence(timeout: 5))
        let pikukuhIsHittable = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isHittable == true"), object: pikukuh
        )
        XCTAssertEqual(XCTWaiter.wait(for: [pikukuhIsHittable], timeout: 5), .completed)
        XCTAssertFalse(app.buttons["intro.continue"].isHittable)
        story.swipeUp()
        XCTAssertTrue(app.buttons["intro.continue"].waitForExistence(timeout: 5))
        app.buttons["intro.continue"].tap()
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
