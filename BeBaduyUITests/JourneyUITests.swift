import XCTest
@MainActor final class JourneyUITests: XCTestCase {
    var app: XCUIApplication!
    func prepare(_ extra: [String] = []) {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-progress"] + extra
        app.launch()
    }
    func tap(_ id: String, file: StaticString = #filePath, line: UInt = #line) {
        let button = app.buttons[id].firstMatch
        _ = button.waitForExistence(timeout: 5)
        for _ in 0..<12 {
            if button.exists && button.isHittable { button.tap(); return }
            if button.exists && button.frame.minY < 100 { app.swipeDown() } else { app.swipeUp() }
        }
        XCTFail("Button unavailable: \(id)", file: file, line: line)
    }
    func intro() { tap("intro.continue"); tap("intro.continue") }
    func start() {
        tap("start")
        if app.buttons["lesson.begin"].waitForExistence(timeout: 1) { tap("lesson.begin") }
    }
    func next() { tap("lesson.result.continue"); tap("continue") }
    func capture(_ name: String) {
        let item = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        item.name = name; item.lifetime = .keepAlways; add(item)
    }
    func completeNukuh() {
        start()
        XCTAssertTrue(app.staticTexts["nukuh.sceneReady"].waitForExistence(timeout: 30))
        for index in 0..<6 { tap("nukuh.cut.\(index)") }
        XCTAssertFalse(app.buttons["continue"].exists)
        tap("nukuh.burn.continue"); tap("nukuh.finishBurn")
    }
    func testFullFiveChapterTouchJourneyAndReplay() {
        prepare(); intro(); completeNukuh(); next()
        start(); tap("ngaseuk.instructions.continue")
        for index in 0..<3 { tap("dig_\(index)") }
        XCTAssertFalse(app.buttons["lesson.result.continue"].exists)
        tap("ngaseuk.seeds.continue")
        for index in 0..<3 { tap("seed_\(index)") }
        next(); start()
        for index in 0..<8 { tap("weed_\(index)") }
        tap("ngored.rain.continue"); capture("Ngored-rain"); tap("ngored.finishRain")
        next(); start()
        for index in 0..<4 { tap("harvest_\(index)") }
        tap("dibuat.balance.continue"); tap("dibuat.balance.center")
        tap("dibuat.drying.continue"); next(); start()
        for index in 0..<3 { tap("bundle_\(index)"); tap("space_\(index)") }
        XCTAssertFalse(app.buttons["lesson.result.continue"].exists)
        tap("leuit.inspect"); capture("Leuit-interior"); tap("leuit.interior.continue"); next()
        XCTAssertTrue(app.staticTexts["journey.completed"].waitForExistence(timeout: 5))
        tap("home")
        XCTAssertEqual(app.staticTexts["home.progress"].label, "5 dari 5 tahap telah dijelajahi")
        app.terminate(); app.launchArguments = ["--uitesting"]; app.launch()
        tap("resume"); tap("lesson.explanation"); tap("replay")
        XCTAssertTrue(app.buttons["lesson.skip"].exists)
        tap("lesson.back")
        XCTAssertEqual(app.staticTexts["home.progress"].label, "5 dari 5 tahap telah dijelajahi")
    }
    func testNukuhDemoAndReplay() {
        prepare(); intro(); start()
        XCTAssertTrue(app.staticTexts["nukuh.sceneReady"].waitForExistence(timeout: 30))
        tap("demonstrate")
        XCTAssertTrue(app.buttons["lesson.result.continue"].waitForExistence(timeout: 40))
        capture("Nukuh-observed"); tap("replay")
        for index in 0..<6 { tap("nukuh.cut.\(index)") }
        tap("nukuh.burn.continue"); tap("nukuh.finishBurn"); next()
        XCTAssertTrue(app.staticTexts["NGASEUK"].exists)
    }
    func testLargeTextButtonFlow() {
        prepare(["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        intro(); capture("Nukuh-large-text"); completeNukuh(); next()
        XCTAssertTrue(app.staticTexts["NGASEUK"].waitForExistence(timeout: 5))
    }
    func testLargeTextDarkLayoutAndAccessibility() throws {
        prepare(["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL", "--dark-appearance"])
        capture("Intro-large-text-dark")
        try app.performAccessibilityAudit(for: [.contrast, .dynamicType, .textClipped, .hitRegion])
        intro(); capture("Nukuh-large-text-dark")
        try app.performAccessibilityAudit(for: [.contrast, .dynamicType, .textClipped, .hitRegion])
    }
}
