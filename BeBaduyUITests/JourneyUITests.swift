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
        if id.hasPrefix("nukuh.cut.") || id.hasPrefix("nukuh.ignite.") ||
            id.hasPrefix("dig_") || id.hasPrefix("seed_") || id.hasPrefix("weed_") ||
            id.hasPrefix("bundle_") || id.hasPrefix("space_") {
            for entry in ["activity.card.start", "nukuh.fire.begin", "ngored.field.begin", "activity.help"] {
                if !button.exists && app.buttons[entry].exists { tap(entry) }
            }
        }
        _ = button.waitForExistence(timeout: 5)
        for _ in 0..<12 {
            let scroll = app.scrollViews["activity.card.scroll"].exists
                ? app.scrollViews["activity.card.scroll"] : app.scrollViews["home.content.scroll"]
            let insideCard = scroll.exists && scroll.buttons[id].exists
            let centerVisible = !insideCard || (button.frame.midY >= scroll.frame.minY + 8 && button.frame.midY <= scroll.frame.maxY - 8)
            if button.exists && button.isHittable && centerVisible { button.tap(); return }
            if scroll.exists {
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
        if app.buttons["resume"].exists { tap("resume") }
        if app.buttons["lesson.begin"].waitForExistence(timeout: 1) { tap("lesson.begin") }
        if app.buttons["mipit.card.start"].exists { tap("mipit.card.start") }
    }
    func next() {
        tap("lesson.result.continue")
        XCTAssertTrue(app.scrollViews["lesson.explanation.page"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["lesson.explanation.card"].exists)
        capture("Explanation-glass-card")
        XCTAssertTrue(app.buttons["activity.card.close"].waitForNonExistence(timeout: 5))
        XCTAssertFalse(app.buttons["activity.help"].exists)
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
            tap("activity.card.start"); capture("Nukuh-fullscreen")
        }
        for index in 0..<4 { tap("nukuh.cut.\(index)") }
        XCTAssertFalse(app.buttons["continue"].exists)
        for index in 0..<4 { tap("nukuh.ignite.\(index)") }; tap("nukuh.finishBurn")
    }
    func testSixGlassExplanations() {
        verifyGlassExplanations(largeText: false)
    }

    func testSixGlassExplanationsLargeText() {
        verifyGlassExplanations(largeText: true)
    }

    private func verifyGlassExplanations(largeText: Bool) {
        var arguments = ["--uitest-explanations"]
        if largeText {
            arguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        prepare(arguments)
        for index in 0..<6 {
            XCTAssertTrue(app.buttons["resume"].waitForExistence(timeout: 15))
            tap("resume")
            XCTAssertTrue(app.scrollViews["lesson.explanation.page"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.otherElements["lesson.explanation.card"].exists)
            if index > 0 { XCTAssertTrue(app.staticTexts["Yang kita pelajari"].exists) }
            XCTAssertTrue(app.buttons["replay"].isHittable)
            capture("Glass-explanation-\(index)-large-\(largeText)")
            if largeText {
                let scroll = app.scrollViews["lesson.explanation.content.scroll"]
                XCTAssertTrue(scroll.exists)
                scroll.swipeUp()
            }
            tap("continue")
            if index < 5 {
                XCTAssertTrue(app.buttons["resume"].waitForExistence(timeout: 5))
            } else {
                XCTAssertTrue(app.staticTexts["journey.completed"].waitForExistence(timeout: 5))
            }
        }
    }

    func testFullSixChapterTouchJourneyAndReplay() {
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
        completeMipit(); next(); start()
        for index in 0..<3 { tap("bundle_\(index)"); tap("space_\(index)") }
        XCTAssertFalse(app.buttons["lesson.result.continue"].exists)
        tap("leuit.inspect"); capture("Leuit-interior"); tap("leuit.interior.continue"); next()
        XCTAssertTrue(app.staticTexts["journey.completed"].waitForExistence(timeout: 5))
        tap("home")
        XCTAssertEqual(app.staticTexts["home.progress"].label, "6 dari 6 tahap telah dijelajahi")
        app.terminate(); app.launchArguments = ["--uitesting"]; app.launch()
        tap("resume"); tap("replay")
        XCTAssertTrue(app.buttons["lesson.skip"].exists)
        tap("lesson.back")
        XCTAssertEqual(app.staticTexts["home.progress"].label, "6 dari 6 tahap telah dijelajahi")
    }
    func testFullScreenFieldInteractionWithoutCard() {
        prepare(); intro(); completeNukuh(captureScene: true); next(); start()
        tap("ngaseuk.instructions.continue")
        capture("Ngaseuk-fullscreen")
        for index in 0..<3 { tap("field.hole.\(index)") }
        XCTAssertTrue(app.buttons["ngaseuk.seeds.continue"].waitForExistence(timeout: 5))
        tap("ngaseuk.seeds.continue")
        let source = app.descendants(matching: .any)["field.seed"].firstMatch
        let target = app.buttons["field.hole.0"]
        XCTAssertTrue(source.waitForExistence(timeout: 5))
        source.press(forDuration: 0.6, thenDragTo: target)
        pourIntoHole(1); pourIntoHole(2)
        XCTAssertTrue(app.buttons["lesson.result.continue"].waitForExistence(timeout: 5))
        next(); start()
        for index in 0..<8 { for _ in 0..<3 { tap("weed_\(index)") } }
        tap("ngored.rain.continue"); capture("Rain-fullscreen")
        tap("ngored.finishRain"); next(); start()
        completeMipit()
        next(); start()
        tap("activity.card.start")
        for index in 0..<3 {
            tap("field.bundle.\(index)"); tap("field.leuit.\(index)")
        }
        tap("leuit.inspect"); capture("Leuit-fullscreen")
        tap("leuit.interior.continue"); next()
        XCTAssertTrue(app.staticTexts["journey.completed"].waitForExistence(timeout: 5))
    }
    func testMipitLandscapeAndDemonstration() {
        defer { XCUIDevice.shared.orientation = .portrait }
        prepare(["--uitest-mipit"]); tap("resume"); start()
        capture("Mipit-three-plants")
        for index in 0..<3 {
            let plant = app.otherElements["field.harvest.\(index)"].firstMatch
            XCTAssertTrue(plant.waitForExistence(timeout: 5))
            plant.tap()
            XCTAssertEqual(plant.value as? String, "Siap dipanen")
            plant.pinch(withScale: 0.5, velocity: -1)
            XCTAssertEqual(plant.value as? String, "Sudah dipanen")
        }
        tap("dibuat.rotate"); next(); start()
        XCTAssertFalse(app.buttons["dibuat.balance.continue"].exists)
        XCUIDevice.shared.orientation = .landscapeRight
        tap("dibuat.balance.continue")
        XCUIDevice.shared.orientation = .landscapeLeft
        tap("dibuat.balance.continue")
        capture("Ngalantai-landscape-controls")
        tap("lesson.back")
        XCTAssertTrue(app.buttons["resume"].waitForExistence(timeout: 10))

        XCUIDevice.shared.orientation = .portrait
        tap("resume"); start()
        tap("demonstrate")
        tap("dibuat.drying.continue")
        tap("lesson.result.continue")
        XCTAssertTrue(app.scrollViews["lesson.explanation.page"].waitForExistence(timeout: 5))
        tap("replay")
        XCTAssertTrue(app.staticTexts["Putar ponsel ke posisi mendatar."].waitForExistence(timeout: 5))
        XCUIDevice.shared.orientation = .portrait
        XCUIDevice.shared.orientation = .landscapeLeft
        tap("dibuat.balance.continue")
        if app.buttons["dibuat.balance.touch"].exists { tap("dibuat.balance.touch") }
        tap("dibuat.balance.center")
        tap("dibuat.drying.continue")
        next()
        XCTAssertTrue(app.staticTexts["home.stage.title"].waitForExistence(timeout: 5))
    }

    func completeMipit() {
        defer { XCUIDevice.shared.orientation = .portrait }
        for index in 0..<3 {
            let plant = app.otherElements["field.harvest.\(index)"].firstMatch
            XCTAssertTrue(plant.waitForExistence(timeout: 5))
            plant.tap()
            XCTAssertEqual(plant.value as? String, "Siap dipanen")
            plant.pinch(withScale: 0.5, velocity: -1)
            XCTAssertEqual(plant.value as? String, "Sudah dipanen")
        }
        tap("dibuat.rotate"); next(); start()
        XCUIDevice.shared.orientation = .landscapeLeft
        tap("dibuat.balance.continue")
        if app.buttons["dibuat.balance.touch"].exists { tap("dibuat.balance.touch") }
        tap("dibuat.balance.center")
        // Let the uninterrupted hold finish and the app request portrait itself.
        tap("dibuat.drying.continue")
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
        XCTAssertTrue(app.buttons["activity.help"].waitForExistence(timeout: 5))
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
        XCTAssertTrue(app.buttons["activity.help"].waitForExistence(timeout: 5))
        let seed = app.descendants(matching: .any)["field.seed"].firstMatch
        seed.press(forDuration: 0.6, thenDragTo: app.buttons["field.hole.0"])
        pourIntoHole(1); pourIntoHole(2)
        next()
        XCTAssertTrue(app.staticTexts["home.stage.title"].waitForExistence(timeout: 5))
        checkKoredActivity()
    }

    func testKoredDraggingAndThreeStrokes() {
        prepare(["--uitest-ngored"]); tap("resume")
        checkKoredActivity()
    }

    private func checkKoredActivity() {
        start(); tap("ngored.field.begin")
        XCTAssertTrue(app.buttons["activity.help"].waitForExistence(timeout: 5))
        capture("Ngored-kored-field")
        tap("field.rice")
        XCTAssertTrue(app.staticTexts["ngored.rice.feedback"].exists)
        XCTAssertTrue(app.buttons["activity.help"].exists, "Help disappeared after rice")
        let weed = app.descendants(matching: .any)["field.weed.0"].firstMatch
        weed.tap()
        XCTAssertTrue(app.buttons["activity.help"].exists, "Help disappeared after weed")
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
        capture("Ngored-time-passing-rain")
        tap("ngored.finishRain"); next()
        XCTAssertTrue(app.staticTexts["home.stage.title"].waitForExistence(timeout: 5))
    }

    func testNukuhStartsFireByTappingClearedLand() {
        prepare(); intro(); start()
        XCTAssertTrue(app.staticTexts["nukuh.sceneReady"].waitForExistence(timeout: 30))
        tap("activity.card.start")
        capture("Nukuh-four-trees")
        // Preserve the horizontal camera angle across portrait aspect ratios.
        func tapField(_ x: CGFloat, _ y: CGFloat) {
            let aspect = app.frame.width / app.frame.height
            let normalizedX = 0.5 + (x - 0.5) * (402.0 / 874.0) / aspect
            app.coordinate(withNormalizedOffset: CGVector(dx: normalizedX, dy: y)).tap()
        }
        for x in [0.37, 0.12, 0.63, 0.88] {
            tapField(x, 0.46)
        }
        tap("nukuh.fire.begin")
        XCTAssertTrue(app.staticTexts["nukuh.fire.hint"].exists)
        // Sky taps must not start a fire; only cleared ground receives ignition.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.3)).tap()
        XCTAssertTrue(app.staticTexts["nukuh.fire.hint"].exists)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.86)).tap()
        XCTAssertTrue(app.staticTexts["nukuh.fire.hint"].label.hasSuffix("0/4"))
        capture("Nukuh-ready-for-ground-tap")
        tapField(0.36, 0.61)
        XCTAssertTrue(app.staticTexts["nukuh.fire.hint"].exists)
        // Repeating the same ground tap must not light a second patch.
        tapField(0.36, 0.61)
        capture("Nukuh-ground-ignition")
        tap("activity.help")
        XCTAssertEqual(app.staticTexts["nukuh.fire.progress"].label, "1 / 4 lahan dinyalakan")
        XCTAssertFalse(app.buttons["nukuh.finishBurn"].exists)
        XCTAssertFalse(app.buttons["lesson.result.continue"].exists)
        tap("activity.card.close")
        for (x, y) in [(0.12, 0.57), (0.63, 0.57), (0.88, 0.59)] {
            tapField(x, y)
        }
        tap("nukuh.finishBurn")
        next()
        XCTAssertTrue(app.staticTexts["home.stage.title"].waitForExistence(timeout: 5))
    }

    func testNukuhDemoAndReplay() {
        prepare(); intro(); start()
        XCTAssertTrue(app.staticTexts["nukuh.sceneReady"].waitForExistence(timeout: 30))
        tap("demonstrate")
        XCTAssertTrue(app.buttons["lesson.result.continue"].waitForExistence(timeout: 40))
        capture("Nukuh-observed"); tap("replay")
        for index in 0..<4 { tap("nukuh.cut.\(index)") }
        for index in 0..<4 { tap("nukuh.ignite.\(index)") }; tap("nukuh.finishBurn"); next()
        XCTAssertTrue(app.staticTexts["home.stage.title"].exists)
    }
    func testLargeTextButtonFlow() {
        prepare(["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        intro(); capture("Nukuh-large-text"); completeNukuh(); next()
        XCTAssertTrue(app.staticTexts["home.stage.title"].waitForExistence(timeout: 5))
    }
    func testActivityCardLargeTextAccessibility() throws {
        prepare(["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        intro(); start()
        XCTAssertTrue(app.staticTexts["nukuh.sceneReady"].waitForExistence(timeout: 30))
        capture("Activity-card-large-text")
        try app.performAccessibilityAudit(for: [.contrast, .dynamicType, .textClipped, .hitRegion])
        tap("activity.card.start"); capture("Activity-field-large-text")
        tap("activity.help")
        XCTAssertTrue(app.scrollViews["activity.card.scroll"].exists)
    }
    func testLargeTextDarkLayoutAndAccessibility() throws {
        prepare(["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL", "--dark-appearance"])
        capture("Intro-large-text-dark")
        try app.performAccessibilityAudit(for: [.contrast, .dynamicType, .textClipped, .hitRegion])
        intro(); capture("Nukuh-large-text-dark")
        try app.performAccessibilityAudit(for: [.contrast, .dynamicType, .textClipped, .hitRegion]) { issue in
            print("Accessibility issue: \(issue.detailedDescription), element: \(issue.element?.debugDescription ?? "unavailable")")
            return false
        }
    }
}
