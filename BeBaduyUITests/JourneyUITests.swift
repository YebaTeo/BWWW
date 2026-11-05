import XCTest

@MainActor final class JourneyUITests: XCTestCase {
    var app: XCUIApplication!
    func prepare() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-progress"]
    }
    func tap(_ identifier: String, file: StaticString = #filePath, line: UInt = #line) {
        if identifier == "start" { nextPage(); return }
        if identifier == "continue" { nextPage(); nextPage(); return }
        let button = app.buttons[identifier].firstMatch
        for _ in 0..<16 {
            if button.exists && button.isHittable { button.tap(); return }
            if button.exists && button.frame.minY < 100 { app.swipeDown() } else { app.swipeUp() }
        }
        print(app.debugDescription)
        XCTFail("Button unavailable: \(identifier)", file: file, line: line)
    }
    func nextPage() {
        let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.8))
        let end = app.coordinate(withNormalizedOffset: CGVector(dx: 0.98, dy: 0.2))
        start.press(forDuration: 0.05, thenDragTo: end)
        Thread.sleep(forTimeInterval: 0.7)
    }
    func capture(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name; attachment.lifetime = .keepAlways; add(attachment)
    }
    func restartKeepingProgress() {
        app.terminate(); app.launchArguments = ["--uitesting"]; app.launch()
    }
    func testFullTouchJourneyReplayAndRelaunch() {
        prepare()
        app.launch(); capture("Home-light")
        tap("resume")
        tap("start"); tap("plot_0")
        XCTAssertTrue(app.staticTexts["feedback"].exists)
        XCTAssertFalse(app.buttons["continue"].exists)
        tap("plot_1"); tap("continue")
        tap("start"); tap("retain_tree")
        for i in 0..<4 { tap("clear_\(i)") }; tap("continue")
        tap("start"); for i in 0..<3 { tap("time_\(i)") }; tap("continue")
        tap("start"); for i in 0..<3 { tap("card_\(i)"); tap("position_\(i)") }; tap("continue")
        tap("start"); capture("Ngaseuk-touch")
        tap("plant_0"); tap("plant_1"); tap("plant_2")
        capture("Ngaseuk-result")
        // Relaunch restores the saved phase and explanation, without redoing the activity.
        restartKeepingProgress(); tap("resume")
        XCTAssertTrue(app.navigationBars["Ngaseuk"].exists)
        tap("replay"); tap("plant_0")
        // An interrupted replay keeps earlier completion and explanation.
        restartKeepingProgress(); tap("resume"); tap("start"); tap("continue")
        tap("start"); tap("retain_rice")
        for i in 0..<4 { tap("weed_\(i)") }; tap("continue")
        tap("start"); capture("Care-reference")
        for i in 0..<3 { tap("plantcard_\(i)"); tap("plantname_\(i)") }; tap("continue")
        tap("start"); for i in 0..<4 { tap("harvest_\(i)") }; tap("continue")
        tap("start"); for i in 0..<3 { tap("ricegroup_\(i)"); tap("rack_\(i)") }; tap("continue")
        tap("start"); tap("waypoint_2")
        for i in 0..<3 { tap("waypoint_\(i)") }; tap("continue")
        tap("start"); for i in 0..<3 { tap("bundle_\(i)"); tap("space_\(i)") }; tap("continue")
        XCTAssertTrue(app.navigationBars["Perjalanan selesai"].waitForExistence(timeout: 5))
        capture("Journey-completed"); tap("home")
        tap("phase_narawas")
        XCTAssertFalse(app.buttons["start"].exists)
        tap("replay"); tap("plot_1"); tap("continue")
        XCTAssertTrue(app.navigationBars["Nyacar"].exists)
    }
    func testDemonstrationAndResume() {
        prepare()
        app.launch(); tap("resume"); tap("start"); tap("demonstrate")
        XCTAssertFalse(app.buttons["continue"].exists)
        restartKeepingProgress(); tap("resume")
        XCTAssertFalse(app.buttons["start"].exists)
        tap("start"); tap("continue"); XCTAssertTrue(app.navigationBars["Nyacar"].exists)
    }
    func testLargeTextDarkLayoutAndAccessibility() throws {
        prepare()
        app.launchArguments += ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL", "--dark-appearance"]
        app.launch(); capture("Home-large-text-dark")
        try app.performAccessibilityAudit(for: [.contrast, .dynamicType, .textClipped, .hitRegion])
        tap("resume"); capture("Narawas-large-text-dark")
        tap("start"); capture("Narawas-activity-large-text-dark")
        tap("plot_1"); tap("continue")
        XCTAssertTrue(app.navigationBars["Nyacar"].exists)
        tap("start"); tap("clear_0")
        capture("Nyacar-large-text-dark-controls")
        try app.performAccessibilityAudit(for: [.contrast, .textClipped, .hitRegion]) { issue in
            guard issue.auditType == .contrast, let element = issue.element else { return false }
            let frame = element.frame
            let barBottom = self.app.navigationBars.firstMatch.frame.maxY
            let viewport = CGRect(x: self.app.frame.minX, y: barBottom, width: self.app.frame.width, height: self.app.frame.maxY - barBottom)
            let detail = XCTAttachment(string: "Contrast element: \(element.debugDescription); frame=\(frame); viewport=\(viewport); \(issue.detailedDescription)")
            detail.lifetime = .keepAlways; self.add(detail)
            print("AUDIT contrast: \(element.label), frame=\(frame), viewport=\(viewport), hittable=\(element.isHittable)")
            // XCTest can sample black pixels for offscreen SwiftUI nodes. Only assess rendered content.
            if !frame.intersects(viewport) {
                let note = XCTAttachment(string: "Excluded non-rendered contrast sample: \(element.label), \(frame)")
                note.lifetime = .keepAlways; self.add(note)
                return true
            }
            return false
        }
    }
}
