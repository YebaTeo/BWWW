import XCTest

@MainActor final class StoryPilotUITests: XCTestCase {
    private var app: XCUIApplication!
    private func launch(large: Bool = false, reduceMotion: Bool = false) {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--story-pilot"]
        if reduceMotion { app.launchArguments.append("--story-reduce-motion") }
        if large {
            app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL", "--dark-appearance"]
        }
        app.launch()
    }
    private func reveal(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        for _ in 0..<24 {
            if element.exists && element.isHittable && element.frame.minY > 80 && element.frame.maxY < app.frame.maxY - 20 { return }
            if element.exists && element.frame.minY < 80 { app.swipeDown(velocity: .slow) } else { app.swipeUp(velocity: .slow) }
        }
        screenshot("Story-failure")
        print(app.debugDescription)
        XCTFail("Cannot reveal \(element)", file: file, line: line)
    }
    private func tap(_ id: String) { let button = app.buttons[id]; reveal(button); button.tap() }
    private func screenshot(_ name: String) {
        Thread.sleep(forTimeInterval: 0.6) // Capture the settled seed placement, not a transition frame.
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    func testFullPageSequence() {
        launch()
        let intro = app.staticTexts["Ngaseuk"]
        XCTAssertTrue(intro.isHittable)
        app.swipeUp(velocity: .fast)
        let target = app.buttons["story.target.0"]
        XCTAssertTrue(target.isHittable)
        XCTAssertFalse(intro.isHittable)
        target.tap()
        app.buttons["story.target.1"].tap()
        app.buttons["story.target.2"].tap()
        XCTAssertTrue(target.isHittable) // Success must not auto-advance.
        app.swipeUp(velocity: .fast)
        XCTAssertTrue(app.staticTexts["Benih sudah ditanam"].isHittable)
        XCTAssertFalse(target.isHittable)
        app.swipeUp(velocity: .fast)
        XCTAssertTrue(app.staticTexts["Ngored"].isHittable)
        app.swipeDown(velocity: .fast)
        XCTAssertTrue(app.staticTexts["Benih sudah ditanam"].isHittable)
        screenshot("Story-fullscreen-explanation")
    }
    func testGateTouchBackwardReplayAndStableOffset() {
        launch(); screenshot("Story-introduction")
        XCTAssertFalse(app.buttons["start"].exists)
        XCTAssertFalse(app.buttons["continue"].exists)
        app.swipeUp(velocity: .fast); app.swipeUp(velocity: .fast)
        XCTAssertFalse(app.staticTexts["Benih sudah ditanam"].exists)
        XCTAssertFalse(app.staticTexts["Ngored"].exists)
        let target = app.buttons["story.target.0"]
        reveal(target)
        target.tap(); target.tap()
        XCTAssertTrue(app.staticTexts["1 dari 3 lubang berisi benih"].exists)
        XCTAssertFalse(app.staticTexts["Ngored"].exists)
        tap("story.target.1")
        let last = app.buttons["story.target.2"]
        reveal(last); let before = last.frame; last.tap()
        XCTAssertTrue(app.staticTexts["3 dari 3 lubang berisi benih"].exists)
        XCTAssertEqual(last.frame.minY, before.minY, accuracy: 3)
        screenshot("Story-activity-completed")
        let result = app.staticTexts["Benih sudah ditanam"]
        reveal(result); screenshot("Story-result")
        let next = app.staticTexts["Ngored"]
        reveal(next); screenshot("Story-Ngored")
        tap("story.replay")
        XCTAssertTrue(app.staticTexts["0 dari 3 lubang berisi benih"].exists)
        reveal(result); reveal(next) // Replay never removes unlocked sections.
        for _ in 0..<5 { app.swipeDown(velocity: .fast) }
        reveal(app.staticTexts["Ngaseuk"])
        XCTAssertTrue(app.staticTexts["Tahap 5 dari 11"].exists)
    }
    func testDemonstrationCancelledOffscreenAndOnBackground() {
        launch(); tap("story.demonstrate")
        for _ in 0..<3 { app.swipeDown(velocity: .fast) }
        // Waiting longer than the demonstration must not unlock content after cancellation.
        let unlocked = app.staticTexts["Benih sudah ditanam"]
        XCTAssertFalse(unlocked.waitForExistence(timeout: 3))
        tap("story.demonstrate")
        XCUIDevice.shared.press(.home)
        app.activate()
        XCTAssertFalse(unlocked.waitForExistence(timeout: 3))
        tap("story.demonstrate")
        XCTAssertTrue(app.staticTexts["Demonstrasi selesai. Jelajahi penjelasan di bawah."].waitForExistence(timeout: 6))
        reveal(unlocked); screenshot("Story-demonstration-result")
    }
    func testLargestTextDarkTouchAndAccessibility() throws {
        launch(large: true)
        screenshot("Story-large-text-introduction")
        for target in 0..<3 { tap("story.target.\(target)") }
        reveal(app.staticTexts["Benih sudah ditanam"])
        screenshot("Story-large-text-result")
        reveal(app.staticTexts["Ngored"])
        screenshot("Story-large-text-Ngored")
        try app.performAccessibilityAudit(for: [.dynamicType, .textClipped, .hitRegion]) { issue in
            print("STORY AUDIT: \(issue.compactDescription); \(issue.detailedDescription); element=\(String(describing: issue.element))")
            return false
        }
    }
    func testReduceMotionEnvironmentAndAccessibleNames() throws {
        launch(reduceMotion: true)
        for target in 0..<3 { tap("story.target.\(target)") }
        XCTAssertEqual(app.buttons["story.target.2"].value as? String, "Sudah berisi benih")
        reveal(app.staticTexts["Benih sudah ditanam"])
        screenshot("Story-reduce-motion-result")
        try app.performAccessibilityAudit(for: [.sufficientElementDescription, .trait])
        reveal(app.staticTexts["Ngored"])
    }

}
