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
        if id.hasPrefix("narawas.cut.") || id.hasPrefix("narawas.ignite.") ||
            id.hasPrefix("seed_") || id.hasPrefix("weed_") ||
            id.hasPrefix("bundle_") || id.hasPrefix("space_") {
            for entry in ["activity.card.start", "narawas.fire.begin", "ngored.field.begin"] {
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
    func intro() {
        let story = app.scrollViews["intro.story"]
        XCTAssertTrue(app.staticTexts["Selamat Datang!"].waitForExistence(timeout: 10))
        story.swipeUp()
        XCTAssertTrue(app.staticTexts["Pikukuh"].isHittable)
        story.swipeUp()
        XCTAssertTrue(app.buttons["intro.continue"].waitForExistence(timeout: 5))
        app.buttons["intro.continue"].tap()
    }
    func start() {
        let inActivity = app.buttons["mipit.card.start"].exists ||
            app.buttons["lesson.equipment.reveal"].exists ||
            app.buttons["lesson.begin"].exists ||
            app.buttons["ngalantai.card.start"].exists ||
            app.buttons["leuit.card.start"].exists ||
            app.buttons["ngaseuk.card.start"].exists ||
            app.buttons["ngored.card.start"].exists

        if !inActivity && app.buttons["resume"].exists { tap("resume") }
        if app.buttons["lesson.equipment.reveal"].waitForExistence(timeout: 2) {
            tap("lesson.equipment.reveal")
            tap("lesson.begin")
        }
        if app.buttons["mipit.card.start"].exists { tap("mipit.card.start") }
    }
    func next() {
        if app.buttons["narawas.activity.result"].exists {
            tap("narawas.activity.result")
        } else {
            tap("lesson.activity.result")
            tap("lesson.result.continue")
        }
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
    func completeNarawas(captureScene: Bool = false) {
        start()
        XCTAssertTrue(app.staticTexts["narawas.sceneReady"].waitForExistence(timeout: 30))
        if captureScene {
            tap("activity.card.start"); capture("Narawas-fullscreen")
        }
        for index in 0..<4 { tap("narawas.cut.\(index)") }
        XCTAssertFalse(app.buttons["continue"].exists)
        for index in 0..<4 { tap("narawas.ignite.\(index)") }; tap("narawas.finishBurn")
    }
    func testCompletedStageReopensActivity() {
        verifyCompletedStageReopensActivity(largeText: false)
    }

    func testCompletedStageReopensActivityLargeText() {
        verifyCompletedStageReopensActivity(largeText: true)
    }

    private func verifyCompletedStageReopensActivity(largeText: Bool) {
        var arguments = ["--uitest-explanations"]
        if largeText {
            arguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"]
        }
        prepare(arguments)
        XCTAssertTrue(app.buttons["resume"].waitForExistence(timeout: 15))
        tap("resume")
        XCTAssertTrue(app.staticTexts["narawas.sceneReady"].waitForExistence(timeout: 30))
        XCTAssertFalse(app.scrollViews["lesson.explanation.page"].exists)
        XCTAssertFalse(app.buttons["replay"].exists)
        if largeText {
            let card = app.descendants(matching: .any)["activity.navigation.card"].firstMatch
            XCTAssertLessThanOrEqual(card.frame.height, 201)
            capture("Narawas-bottom-large-text")
            let scroll = app.scrollViews.matching(NSPredicate(
                format: "identifier IN %@", ["activity.card.scroll", "activity.navigation.card"]
            )).firstMatch
            XCTAssertTrue(scroll.exists, app.debugDescription)
            scroll.swipeUp()
        } else {
            capture("Completed-stage-activity-large-false")
        }
        tap("lesson.back")
    }

    private func completeLeuit() {
        let ladder = app.descendants(matching: .any)["field.ladder"].firstMatch
        XCTAssertTrue(ladder.waitForExistence(timeout: 20))
        XCTAssertTrue(app.otherElements["lesson.loading"].waitForNonExistence(timeout: 20))
        let ladderStart = app.coordinate(withNormalizedOffset: CGVector(dx: 0.42, dy: 0.65))
        let door = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.42))
        ladderStart.press(forDuration: 0.15, thenDragTo: door)
        XCTAssertTrue(app.otherElements["ngaleuitkeun.activity.completed"].waitForExistence(timeout: 8))
    }

    private func finishLeuitJourney() {
        XCTAssertTrue(app.staticTexts["journey.completed"].waitForExistence(timeout: 8))
        XCTAssertFalse(app.buttons["Ketuk untuk membuka kartu"].exists)
        tap("journey.finish")
        XCTAssertTrue(app.buttons["Ketuk untuk membuka kartu"].waitForExistence(timeout: 10))
        app.buttons["Ketuk untuk membuka kartu"].tap()
        XCTAssertTrue(app.buttons["continue"].waitForExistence(timeout: 5))
        tap("continue")
    }

    func testNgaleuitkeunEndsBeforeEpicCardReveal() {
        prepare(["--uitest-leuit"])
        tap("phase_ngaleuitkeun_pare")
        start()
        completeLeuit()
        finishLeuitJourney()
        XCTAssertTrue(app.buttons["phase_ngaleuitkeun_pare"].waitForExistence(timeout: 5))
    }

    func testFullSixChapterTouchJourneyAndReplay() {
        prepare(["--uitest-ngaseuk-motion"]); intro(); completeNarawas(); next()
        start(); waitForNgaseukHoles()
        XCTAssertFalse(app.buttons["lesson.result.continue"].exists)
        tap("ngaseuk.seeds.continue")
        for index in 0..<3 { tap("seed_\(index)") }
        next(); start()
        checkKoredActivity()
        next(); start()
        completeMipit(); next(); start()
        completeLeuit(); finishLeuitJourney()
        XCTAssertTrue(app.buttons["phase_ngaleuitkeun_pare"].waitForExistence(timeout: 5))
        app.terminate(); app.launchArguments = ["--uitesting"]; app.launch()
        tap("resume")
        XCTAssertFalse(app.scrollViews["lesson.explanation.page"].exists)
        XCTAssertFalse(app.buttons["replay"].exists)
        XCTAssertFalse(app.buttons["lesson.skip"].exists)
        tap("lesson.back")
        XCTAssertTrue(app.buttons["phase_ngaleuitkeun_pare"].waitForExistence(timeout: 5))
    }
    func testFullScreenFieldInteractionWithoutCard() {
        prepare(["--uitest-ngaseuk-motion"]); intro(); completeNarawas(captureScene: true); next(); start()
        waitForNgaseukHoles()
        capture("Ngaseuk-fullscreen")
        tap("ngaseuk.seeds.continue")
        let source = app.descendants(matching: .any)["field.seed"].firstMatch
        let target = app.buttons["field.hole.0"]
        XCTAssertTrue(source.waitForExistence(timeout: 5))
        source.press(forDuration: 0.6, thenDragTo: target)
        pourIntoHole(1); pourIntoHole(2)
        XCTAssertTrue(app.buttons["lesson.activity.result"].waitForExistence(timeout: 5))
        next(); start()
        checkKoredActivity()
        next(); start()
        completeMipit()
        next(); start()
        completeLeuit(); finishLeuitJourney()
    }
    func testMipitAndNgalantaiLandscapeFlow() {
        defer { XCUIDevice.shared.orientation = .portrait }
        prepare(["--uitest-mipit"]); tap("resume"); start()
        capture("Mipit-bottom-instructions")
        for index in 0..<3 {
            let plant = app.otherElements["field.harvest.\(index)"].firstMatch
            XCTAssertTrue(plant.waitForExistence(timeout: 5))
            plant.tap()
            XCTAssertEqual(plant.value as? String, "Siap dipanen")
            plant.pinch(withScale: 0.5, velocity: -1)
            XCTAssertEqual(plant.value as? String, "Sudah dipanen")
        }
        assertInformationCard(cue: "mipit.rotate")
        capture("Mipit-middle-success")
        tap("mipit.rotate"); next(); start()
        XCTAssertFalse(app.buttons["ngalantai.balance.continue"].exists)
        XCUIDevice.shared.orientation = .landscapeRight
        assertInformationCard(cue: "ngalantai.balance.continue")
        capture("Ngalantai-middle-landscape")
        tap("ngalantai.balance.continue")
        XCUIDevice.shared.orientation = .landscapeLeft
        tap("ngalantai.balance.continue")
        capture("Ngalantai-landscape-controls")
        tap("lesson.back")
        XCTAssertTrue(app.buttons["resume"].waitForExistence(timeout: 10))

        XCUIDevice.shared.orientation = .portrait
        tap("resume"); start()
        XCTAssertFalse(app.buttons["Lihat demonstrasi"].exists)
        XCUIDevice.shared.orientation = .landscapeRight
        tap("ngalantai.balance.continue")
        if app.buttons["ngalantai.balance.touch"].exists { tap("ngalantai.balance.touch") }
        tap("ngalantai.balance.center")
        capture("Ngalantai-bottom-touch-controls")
        waitForNgalantaiDrying()
        tap("ngalantai.drying.continue")
        tap("lesson.activity.result")
        tap("lesson.result.continue")
        XCTAssertTrue(app.scrollViews["lesson.explanation.page"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Ulangi"].exists)
        tap("continue")
        XCTAssertTrue(app.staticTexts["home.stage.title"].waitForExistence(timeout: 5))
    }

    func testMipitEquipmentCardBeforeHarvest() {
        prepare(["--uitest-mipit"])
        for _ in 0..<3 where !app.buttons["phase_dibuat"].isHittable { app.swipeUp() }
        tap("phase_dibuat")
        tap("resume")
        XCTAssertTrue(app.buttons["lesson.equipment.reveal"].waitForExistence(timeout: 10))
        capture("Mipit-equipment-before-harvest")
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
        tap("mipit.rotate"); next(); start()
        XCUIDevice.shared.orientation = .landscapeLeft
        tap("ngalantai.balance.continue")
        if app.buttons["ngalantai.balance.touch"].exists { tap("ngalantai.balance.touch") }
        tap("ngalantai.balance.center")
        waitForNgalantaiDrying()
        tap("ngalantai.drying.continue")
    }
    private func waitForNgalantaiDrying() {
        let drying = app.buttons["ngalantai.drying.continue"]
        let returnPrompt = app.staticTexts["Tegakkan ponsel untuk melihat padi dijemur."]
        if !drying.exists, returnPrompt.waitForExistence(timeout: 5) {
            XCUIDevice.shared.orientation = .portrait
        }
        XCTAssertTrue(drying.waitForExistence(timeout: 8))
        capture("Ngalantai-middle-drying")
    }

    func pourIntoHole(_ index: Int) {
        tap("field.hole.\(index)")
        XCTAssertTrue(app.buttons["ngaseuk.peek.pour"].waitForExistence(timeout: 5))
        capture("Ngaseuk-peek-\(index)")
        tap("ngaseuk.peek.pour")
        if index == 2 {
            XCTAssertTrue(app.buttons["lesson.activity.result"].waitForExistence(timeout: 5))
        } else {
            XCTAssertTrue(app.staticTexts["Benih sudah masuk"].waitForExistence(timeout: 5))
            tap("ngaseuk.peek.back")
        }
    }

    private func waitForNgaseukHoles() {
        let tutorial = app.staticTexts["ngaseuk.motion.tutorial"]
        XCTAssertTrue(tutorial.waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["field.hole.0"].exists)
        XCTAssertTrue(tutorial.waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["ngaseuk.seeds.continue"].waitForExistence(timeout: 12))
    }

    func testNgaseukMotionTutorialAndSeedDrag() {
        prepare(["--uitest-ngaseuk", "--uitest-ngaseuk-motion"]); start()
        waitForNgaseukHoles()
        capture("Ngaseuk-three-soil-holes")
        assertInformationCard(cue: "ngaseuk.seeds.continue")
        capture("Ngaseuk-middle-planting")
        tap("ngaseuk.seeds.continue")
        XCTAssertFalse(app.buttons["activity.help"].exists)
        let seed = app.descendants(matching: .any)["field.seed"].firstMatch
        XCTAssertTrue(seed.waitForExistence(timeout: 5))
        // The close-up replaces field elements during the gesture. Drag toward
        // the middle hole using a coordinate that remains stable as it opens.
        let middleHole = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.58))
        seed.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.6, thenDragTo: middleHole)
        XCTAssertTrue(app.staticTexts["1 / 3 lubang berisi benih"].waitForExistence(timeout: 8))
    }

    func testNgaseukPlantingAndCompletion() {
        prepare(["--uitest-ngaseuk", "--uitest-ngaseuk-motion"]); start()
        waitForNgaseukHoles()
        assertInformationCard(cue: "ngaseuk.seeds.continue")
        tap("ngaseuk.seeds.continue")
        XCTAssertFalse(app.buttons["activity.help"].exists)
        capture("Ngaseuk-bottom-seeding")
        for index in 0..<3 { tap("seed_\(index)") }
        next()
        XCTAssertTrue(app.staticTexts["home.stage.title"].waitForExistence(timeout: 5))
    }

    func testOneKoredSwipeUprootsWeed() {
        prepare(["--uitest-ngored"]); tap("phase_ngored"); tap("resume")
        XCTAssertTrue(app.buttons["lesson.equipment.reveal"].waitForExistence(timeout: 30))
        start()
        assertInformationCard(cue: "ngored.growth.begin")
        capture("Ngored-middle-instructions")
        tap("ngored.growth.begin")
        XCTAssertFalse(app.buttons["ngored.growth.begin"].exists)
        XCTAssertFalse(app.buttons["lesson.activity.result"].exists)
        if app.buttons["ngored.field.begin"].exists { tap("ngored.field.begin") }
        XCTAssertTrue(app.staticTexts["Usap sekali untuk mencabut gulma"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["weed_0"].exists)
        capture("Ngored-bottom-weeding")
        let visibleWeeds = (0..<4).filter {
            app.descendants(matching: .any)["field.weed.\($0)"].firstMatch.exists
        }
        XCTAssertFalse(visibleWeeds.isEmpty, app.debugDescription)
        if let index = visibleWeeds.first { swipeWeed(index) }
    }

    func testLeuitCardAcknowledgementAndResult() {
        prepare(["--uitest-leuit"]); tap("resume")
        let ladderHint = app.staticTexts["Seret tangga bambu ke pintu leuit."]
        XCTAssertTrue(ladderHint.waitForExistence(timeout: 10))
        capture("Leuit-bottom-instructions")
        XCTAssertFalse(app.buttons["activity.help"].exists)
        XCTAssertFalse(app.buttons["lesson.activity.result"].exists)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.22, dy: 0.27)).tap()
        XCTAssertTrue(ladderHint.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["lesson.activity.result"].exists)
        completeLeuit()
        assertInformationCard(cue: "lesson.activity.result")
        capture("Leuit-middle-success")
        tap("lesson.activity.result")
        assertInformationCard(cue: "lesson.result.continue")
        capture("Leuit-middle-result")
        XCTAssertFalse(app.buttons["Ulangi"].exists)
        tap("lesson.result.continue")
        XCTAssertTrue(app.scrollViews["lesson.explanation.page"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Ulangi"].exists)
    }

    private func assertInformationCard(cue identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        let card = app.descendants(matching: .any)["activity.navigation.card"].firstMatch
        let cue = app.buttons[identifier].firstMatch
        XCTAssertTrue(cue.waitForExistence(timeout: 10), file: file, line: line)
        XCTAssertTrue(card.exists, app.debugDescription, file: file, line: line)
        XCTAssertEqual(card.buttons.count, 0, file: file, line: line)
        XCTAssertEqual(card.sliders.count, 0, file: file, line: line)
        XCTAssertTrue(cue.frame.contains(card.frame), file: file, line: line)
    }

    private func swipeWeed(_ index: Int) {
        let weed = app.descendants(matching: .any)["field.weed.\(index)"].firstMatch
        XCTAssertTrue(weed.waitForExistence(timeout: 30))
        let frame = weed.frame
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let start = origin.withOffset(CGVector(dx: frame.midX - 28, dy: frame.midY))
        let end = origin.withOffset(CGVector(dx: frame.midX + 28, dy: frame.midY))
        start.press(forDuration: 0.05, thenDragTo: end)
        XCTAssertTrue(weed.waitForNonExistence(timeout: 5))
    }

    private func checkKoredActivity() {
        for index in 0..<4 {
            if app.buttons["ngored.field.begin"].exists { tap("ngored.field.begin") }
            swipeWeed(index)
        }
        XCTAssertTrue(app.buttons["lesson.activity.result"].waitForExistence(timeout: 30))
    }

    func testNarawasStartsFireByTappingClearedLand() {
        prepare(); intro(); start()
        XCTAssertTrue(app.staticTexts["narawas.sceneReady"].waitForExistence(timeout: 30))
        tap("activity.card.start")
        capture("Narawas-four-trees")
        // Preserve the horizontal camera angle across portrait aspect ratios.
        func tapField(_ x: CGFloat, _ y: CGFloat) {
            let aspect = app.frame.width / app.frame.height
            let normalizedX = 0.5 + (x - 0.5) * (402.0 / 874.0) / aspect
            app.coordinate(withNormalizedOffset: CGVector(dx: normalizedX, dy: y)).tap()
        }
        for x in [0.37, 0.12, 0.63, 0.88] {
            tapField(x, 0.46)
        }
        tap("narawas.fire.begin")
        XCTAssertTrue(app.staticTexts["narawas.fire.hint"].exists)
        // Sky taps must not start a fire; only cleared ground receives ignition.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.3)).tap()
        XCTAssertTrue(app.staticTexts["narawas.fire.hint"].exists)
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.86)).tap()
        XCTAssertTrue(app.staticTexts["narawas.fire.hint"].label.hasSuffix("0/4"))
        capture("Narawas-ready-for-ground-tap")
        tapField(0.36, 0.61)
        XCTAssertTrue(app.staticTexts["narawas.fire.hint"].exists)
        // Repeating the same ground tap must not light a second patch.
        tapField(0.36, 0.61)
        capture("Narawas-ground-ignition")
        XCTAssertFalse(app.buttons["activity.help"].exists)
        XCTAssertFalse(app.buttons["narawas.finishBurn"].exists)
        XCTAssertFalse(app.buttons["lesson.result.continue"].exists)
        for (x, y) in [(0.12, 0.57), (0.63, 0.57), (0.88, 0.59)] {
            tapField(x, y)
        }
        tap("narawas.finishBurn")
        next()
        XCTAssertTrue(app.staticTexts["home.stage.title"].waitForExistence(timeout: 5))
    }

    func testNarawasHasNoDemonstrationAction() {
        prepare(); intro(); start()
        XCTAssertTrue(app.staticTexts["narawas.sceneReady"].waitForExistence(timeout: 30))
        XCTAssertFalse(app.buttons["Lihat demonstrasi"].exists)
    }
    func testLargeTextButtonFlow() {
        prepare(["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        intro(); capture("Narawas-large-text"); completeNarawas(); next()
        XCTAssertTrue(app.staticTexts["home.stage.title"].waitForExistence(timeout: 5))
    }
    func testActivityCardLargeTextAccessibility() throws {
        prepare(["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        intro(); start()
        XCTAssertTrue(app.staticTexts["narawas.sceneReady"].waitForExistence(timeout: 30))
        capture("Activity-card-large-text")
        try app.performAccessibilityAudit(for: [.contrast, .dynamicType, .textClipped, .hitRegion])
        tap("activity.card.start"); capture("Activity-field-large-text")
        XCTAssertFalse(app.buttons["activity.help"].exists)
    }
    func testLargeTextDarkLayoutAndAccessibility() throws {
        prepare(["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL", "--dark-appearance"])
        capture("Intro-large-text-dark")
        try app.performAccessibilityAudit(for: [.contrast, .dynamicType, .textClipped, .hitRegion])
        intro(); capture("Narawas-large-text-dark")
        try app.performAccessibilityAudit(for: [.contrast, .dynamicType, .textClipped, .hitRegion]) { issue in
            print("Accessibility issue: \(issue.detailedDescription), element: \(issue.element?.debugDescription ?? "unavailable")")
            return false
        }
    }
}
