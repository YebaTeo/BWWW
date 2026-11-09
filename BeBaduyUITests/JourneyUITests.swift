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
            let scroll = app.scrollViews["activity.sheet.scroll"]
            let insideSheet = scroll.exists && scroll.buttons[id].exists
            let centerVisible = !insideSheet || (button.frame.midY >= scroll.frame.minY + 8 && button.frame.midY <= scroll.frame.maxY - 8)
            if button.exists && button.isHittable && centerVisible { button.tap(); return }
            if app.buttons["activity.sheet.expand"].exists && !id.hasPrefix("field.") {
                app.buttons["activity.sheet.expand"].tap()
            } else if app.scrollViews["activity.sheet.scroll"].exists {
                let scroll = app.scrollViews["activity.sheet.scroll"]
                let down = button.exists && button.frame.minY < scroll.frame.minY
                let origin = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: down ? 0.35 : 0.7))
                let end = scroll.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: down ? 0.7 : 0.35))
                origin.press(forDuration: 0.05, thenDragTo: end, withVelocity: .slow, thenHoldForDuration: 0.15)
            } else if button.exists && button.frame.minY < 100 { app.swipeDown() } else { app.swipeUp() }
        }
        capture("Unavailable-" + id)
        let detail = XCTAttachment(string: app.debugDescription); detail.lifetime = .keepAlways; add(detail)
        XCTFail("Button unavailable: \(id)", file: file, line: line)
    }
    func intro() { tap("intro.continue"); tap("intro.continue") }
    func start() {
        tap("start")
        if app.buttons["lesson.begin"].waitForExistence(timeout: 1) { tap("lesson.begin") }
    }
    func next() {
        tap("lesson.result.continue")
        XCTAssertTrue(app.scrollViews["lesson.explanation.page"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["activity.sheet.collapse"].waitForNonExistence(timeout: 5))
        XCTAssertFalse(app.buttons["activity.sheet.expand"].exists)
        tap("continue")
    }
    func capture(_ name: String) {
        let item = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        item.name = name; item.lifetime = .keepAlways; add(item)
    }
    func completeNukuh(captureScene: Bool = false) {
        start()
        XCTAssertTrue(app.staticTexts["nukuh.sceneReady"].waitForExistence(timeout: 30))
        if captureScene {
            tap("activity.sheet.collapse"); capture("Nukuh-fullscreen"); tap("activity.sheet.expand")
        }
        for index in 0..<6 { tap("nukuh.cut.\(index)") }
        XCTAssertFalse(app.buttons["continue"].exists)
        for index in 0..<6 { tap("nukuh.ignite.\(index)") }; tap("nukuh.finishBurn")
    }
    func testFullFiveChapterTouchJourneyAndReplay() {
        prepare(); intro(); completeNukuh(); next()
        start(); tap("ngaseuk.instructions.continue")
        for index in 0..<3 { tap("dig_\(index)") }
        XCTAssertFalse(app.buttons["lesson.result.continue"].exists)
        tap("ngaseuk.seeds.continue")
        for index in 0..<3 { tap("seed_\(index)") }
        next(); start()
        for index in 0..<8 { for _ in 0..<3 { tap("weed_\(index)") } }
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
    func testFullScreenFieldInteractionWithCollapsedSheet() {
        prepare(); intro(); completeNukuh(captureScene: true); next(); start()
        tap("ngaseuk.instructions.continue")
        tap("activity.sheet.collapse")
        capture("Ngaseuk-fullscreen")
        for index in 0..<3 { tap("field.hole.\(index)") }
        XCTAssertTrue(app.buttons["ngaseuk.seeds.continue"].waitForExistence(timeout: 5))
        tap("ngaseuk.seeds.continue"); tap("activity.sheet.collapse")
        let source = app.descendants(matching: .any)["field.seed"].firstMatch
        let target = app.buttons["field.hole.0"]
        XCTAssertTrue(source.waitForExistence(timeout: 5))
        source.press(forDuration: 0.6, thenDragTo: target)
        pourIntoHole(1); pourIntoHole(2)
        XCTAssertTrue(app.buttons["lesson.result.continue"].waitForExistence(timeout: 5))
        next(); start(); tap("activity.sheet.collapse")
        for index in 0..<8 { for _ in 0..<3 { tap("weed_\(index)") } }
        tap("ngored.rain.continue"); tap("activity.sheet.collapse"); capture("Rain-fullscreen")
        tap("activity.sheet.expand"); tap("ngored.finishRain"); next(); start()
        tap("activity.sheet.collapse")
        for index in 0..<4 { tap("field.harvest.\(index)") }
        tap("dibuat.balance.continue"); tap("dibuat.balance.center"); tap("dibuat.drying.continue")
        next(); start(); tap("activity.sheet.collapse")
        for index in 0..<3 {
            tap("field.bundle.\(index)"); tap("field.leuit.\(index)")
        }
        tap("leuit.inspect"); tap("activity.sheet.collapse"); capture("Leuit-fullscreen")
        tap("activity.sheet.expand"); tap("leuit.interior.continue"); next()
        XCTAssertTrue(app.staticTexts["journey.completed"].waitForExistence(timeout: 5))
    }
    func pourIntoHole(_ index: Int) {
        tap("field.hole.\(index)")
        XCTAssertTrue(app.buttons["ngaseuk.peek.pour"].waitForExistence(timeout: 5))
        capture("Ngaseuk-peek-\(index)")
        tap("ngaseuk.peek.pour")
        if index == 2 {
            XCTAssertTrue(app.buttons["lesson.result.continue"].waitForExistence(timeout: 5))
        } else {
            XCTAssertTrue(app.staticTexts["Benih sudah masuk"].waitForExistence(timeout: 5))
            tap("ngaseuk.peek.back")
        }
    }

    func testNgaseukAseukPressAndPlant() {
        prepare(); intro(); completeNukuh(); next(); start()
        tap("ngaseuk.instructions.continue")
        XCTAssertTrue(app.buttons["activity.sheet.expand"].waitForExistence(timeout: 5))
        capture("Ngaseuk-aseuk-ready")
        for index in 0..<3 {
            let hole = app.buttons["field.hole.\(index)"]
            let ready = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: hole)
            XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
            hole.tap()
            let dug = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", "Sudah dibuat"), object: hole)
            XCTAssertEqual(XCTWaiter.wait(for: [dug], timeout: 5), .completed)
        }
        XCTAssertTrue(app.buttons["ngaseuk.seeds.continue"].waitForExistence(timeout: 5))
        capture("Ngaseuk-three-soil-holes")
        tap("ngaseuk.seeds.continue")
        XCTAssertTrue(app.buttons["activity.sheet.expand"].waitForExistence(timeout: 5))
        let seed = app.descendants(matching: .any)["field.seed"].firstMatch
        seed.press(forDuration: 0.6, thenDragTo: app.buttons["field.hole.0"])
        pourIntoHole(1); pourIntoHole(2)
        next()
        XCTAssertTrue(app.staticTexts["NGORED"].waitForExistence(timeout: 5))
        checkKoredActivity()
    }

    func testKoredDraggingAndThreeStrokes() {
        prepare(["--uitest-ngored"]); tap("resume")
        checkKoredActivity()
    }

    private func checkKoredActivity() {
        start(); tap("ngored.field.begin")
        XCTAssertTrue(app.buttons["activity.sheet.expand"].waitForExistence(timeout: 5))
        capture("Ngored-kored-field")
        tap("field.rice")
        XCTAssertTrue(app.staticTexts["ngored.rice.feedback"].exists)
        XCTAssertTrue(app.buttons["activity.sheet.expand"].exists, "Sheet expanded after rice")
        let weed = app.descendants(matching: .any)["field.weed.0"].firstMatch
        weed.tap()
        XCTAssertTrue(app.buttons["activity.sheet.expand"].exists, "Sheet expanded after weed")
        XCTAssertEqual(weed.value as? String, "0 dari 3 sapuan")
        let tool = app.descendants(matching: .any)["field.kored"].firstMatch
        XCTAssertTrue(tool.waitForExistence(timeout: 5))
        for stroke in 1...3 {
            let previousY = tool.frame.midY
            let origin = tool.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            origin.press(forDuration: 0.05, thenDragTo: origin.withOffset(CGVector(dx: 0, dy: 36)), withVelocity: .slow, thenHoldForDuration: 0.1)
            XCTAssertGreaterThan(tool.frame.midY, previousY + 20)
            let expected = stroke == 3 ? "Bersih" : "\(stroke) dari 3 sapuan"
            let applied = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", expected), object: weed)
            XCTAssertEqual(XCTWaiter.wait(for: [applied], timeout: 5), .completed)
            if stroke < 3 {
                let lifted = tool.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                lifted.press(forDuration: 0.05, thenDragTo: lifted.withOffset(CGVector(dx: 0, dy: -36)), withVelocity: .slow, thenHoldForDuration: 0.1)
                XCTAssertEqual(weed.value as? String, expected)
            }
        }
        capture("Ngored-three-kored-strokes")
        for index in 1..<8 { for _ in 0..<3 { tap("weed_\(index)") } }
        XCTAssertTrue(app.buttons["ngored.rain.continue"].waitForExistence(timeout: 5))
        tap("ngored.rain.continue")
        tap("activity.sheet.collapse"); capture("Ngored-time-passing-rain")
        tap("activity.sheet.expand"); tap("ngored.finishRain"); next()
        XCTAssertTrue(app.staticTexts["DIBUAT"].waitForExistence(timeout: 5))
    }

    func testNukuhStartsFireByTappingClearedLand() {
        prepare(); intro(); start()
        XCTAssertTrue(app.staticTexts["nukuh.sceneReady"].waitForExistence(timeout: 30))
        for index in 0..<6 { tap("nukuh.cut.\(index)") }
        XCTAssertTrue(app.buttons["activity.sheet.expand"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["nukuh.fire.hint"].exists)
        // Sky taps must not start a fire; only cleared ground receives ignition.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.3)).tap()
        XCTAssertTrue(app.staticTexts["nukuh.fire.hint"].exists)
        capture("Nukuh-ready-for-ground-tap")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.72)).tap()
        XCTAssertTrue(app.staticTexts["nukuh.fire.hint"].exists)
        // Repeating the same ground tap must not light a second patch.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.72)).tap()
        capture("Nukuh-ground-ignition")
        tap("activity.sheet.expand")
        XCTAssertEqual(app.staticTexts["nukuh.fire.progress"].label, "1 / 6 lahan dinyalakan")
        XCTAssertFalse(app.buttons["nukuh.finishBurn"].exists)
        XCTAssertFalse(app.buttons["lesson.result.continue"].exists)
        for index in 1..<6 { tap("nukuh.ignite.\(index)") }
        tap("nukuh.finishBurn")
        next()
        XCTAssertTrue(app.staticTexts["NGASEUK"].waitForExistence(timeout: 5))
    }

    func testNukuhDemoAndReplay() {
        prepare(); intro(); start()
        XCTAssertTrue(app.staticTexts["nukuh.sceneReady"].waitForExistence(timeout: 30))
        tap("demonstrate")
        XCTAssertTrue(app.buttons["lesson.result.continue"].waitForExistence(timeout: 40))
        capture("Nukuh-observed"); tap("replay")
        for index in 0..<6 { tap("nukuh.cut.\(index)") }
        for index in 0..<6 { tap("nukuh.ignite.\(index)") }; tap("nukuh.finishBurn"); next()
        XCTAssertTrue(app.staticTexts["NGASEUK"].exists)
    }
    func testLargeTextButtonFlow() {
        prepare(["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        intro(); capture("Nukuh-large-text"); completeNukuh(); next()
        XCTAssertTrue(app.staticTexts["NGASEUK"].waitForExistence(timeout: 5))
    }
    func testActivitySheetLargeTextAccessibility() throws {
        prepare(["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        intro(); start()
        XCTAssertTrue(app.staticTexts["nukuh.sceneReady"].waitForExistence(timeout: 30))
        capture("Activity-sheet-large-text")
        try app.performAccessibilityAudit(for: [.contrast, .dynamicType, .textClipped, .hitRegion])
        tap("activity.sheet.collapse"); capture("Activity-sheet-collapsed-large-text")
        tap("activity.sheet.expand")
        XCTAssertTrue(app.scrollViews["activity.sheet.scroll"].exists)
    }
    func testLargeTextDarkLayoutAndAccessibility() throws {
        prepare(["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL", "--dark-appearance"])
        capture("Intro-large-text-dark")
        try app.performAccessibilityAudit(for: [.contrast, .dynamicType, .textClipped, .hitRegion])
        intro(); capture("Nukuh-large-text-dark")
        try app.performAccessibilityAudit(for: [.contrast, .dynamicType, .textClipped, .hitRegion])
    }
}
