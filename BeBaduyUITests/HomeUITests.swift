import XCTest
@MainActor final class HomeUITests: XCTestCase {
    func testJourneyMenuShowsSceneCardsAndLocksNextStage() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-progress"]
        app.launch()
        finishOnboarding(in: app)
        XCTAssertTrue(app.buttons["resume"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["home.journey"].value as? String, "1 dari 6 biji")
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

    func testHomeBlocksForwardSwipesBeforeCompletingNarawas() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-progress"]
        app.launch()
        finishOnboarding(in: app)
        waitForPreviewTitle("NARAWAS", in: app)
        app.swipeUp()
        app.swipeUp()
        waitForPreviewTitle("NARAWAS", in: app)
        XCTAssertFalse(app.buttons["home.stage.next"].exists)
        let startLabel = app.staticTexts["Ikut Narawas"]
        XCTAssertTrue(startLabel.exists)
        startLabel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(app.staticTexts["narawas.sceneReady"].waitForExistence(timeout: 30))
    }

    func testHomeBrowsesUnlockedStagesAndStopsAtUnfinishedNgored() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-progress", "--uitest-ngored"]
        app.launch()
        waitForPreviewTitle("NGORED", in: app)
        XCTAssertEqual(app.buttons["home.journey"].value as? String, "3 dari 6 biji")
        XCTAssertFalse(app.buttons["home.stage.next"].exists)
        app.swipeDown()
        waitForPreviewTitle("NGASEUK", in: app)
        XCTAssertEqual(app.buttons["home.journey"].value as? String, "2 dari 6 biji")
        app.buttons["home.stage.next"].tap()
        waitForPreviewTitle("NGORED", in: app)
        XCTAssertEqual(app.buttons["home.journey"].value as? String, "3 dari 6 biji")
        app.swipeUp()
        waitForPreviewTitle("NGORED", in: app)
        XCTAssertFalse(app.buttons["home.stage.next"].exists)
        app.buttons["resume"].tap()
        XCTAssertTrue(app.buttons["lesson.equipment.reveal"].waitForExistence(timeout: 15))
    }

    func testJourneyMenuShowsSixGrainsAtLastPhase() {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-progress", "--uitest-explanations", "--preview-stage=5"]
        app.launch()
        waitForPreviewTitle("NGALEUITKEUN", in: app)
        let menu = app.buttons["home.journey"]
        XCTAssertEqual(menu.value as? String, "6 dari 6 biji")
        menu.tap()
        XCTAssertTrue(app.staticTexts["Perjalanan Ngahuma"].waitForExistence(timeout: 10))
    }

    func testEquipmentCardsOpenAndFlipRepeatedly() {
        for (phase, title) in [("ngaseuk", "Aseuk"), ("ngored", "Kored"), ("mipit", "Etem")] {
            let app = XCUIApplication()
            app.launchArguments = ["--uitesting", "--reset-progress", "--uitest-\(phase)"]
            if phase == "mipit" {
                app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
            }
            app.launch()
            let resume = app.buttons["resume"]
            XCTAssertTrue(resume.waitForExistence(timeout: 30))
            resume.tap()
            let reveal = app.buttons["lesson.equipment.reveal"]
            let begin = app.buttons["lesson.begin"]
            XCTAssertTrue(reveal.waitForExistence(timeout: 30))
            captureEquipment("\(title)-closed", in: app)
            XCTAssertFalse(begin.exists)
            reveal.tap()
            XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 5))
            captureEquipment("\(title)-open", in: app)
            XCTAssertTrue(begin.exists)
            app.staticTexts[title].tap()
            XCTAssertTrue(reveal.waitForExistence(timeout: 5))
            XCTAssertFalse(begin.exists)
            reveal.tap()
            XCTAssertTrue(begin.waitForExistence(timeout: 5))
            for _ in 0..<3 where !begin.isHittable { app.swipeUp() }
            begin.tap()
            XCTAssertTrue(app.buttons["lesson.back"].waitForExistence(timeout: 10))
            XCTAssertFalse(reveal.exists)
            app.terminate()
            app.launchArguments.removeAll { $0 == "--reset-progress" }
            app.launchArguments.insert("--uitest-explanations", at: 0)
            app.launch()
            XCTAssertTrue(resume.waitForExistence(timeout: 30))
            resume.tap()
            XCTAssertTrue(reveal.waitForExistence(timeout: 15))
            XCTAssertFalse(begin.exists)
            app.terminate()
        }
    }

    private func captureEquipment(_ name: String, in app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
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
