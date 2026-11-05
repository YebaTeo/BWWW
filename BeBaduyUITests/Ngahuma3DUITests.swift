import XCTest

@MainActor final class Ngahuma3DUITests: XCTestCase {
    func testCameraFreeSceneInteractionAndReopening() throws {
        let app = XCUIApplication()
        app.launchArguments = ["--uitesting", "--reset-progress"]
        app.launch()
        func openScene() {
            let open = app.buttons["ngahuma.open"]
            for _ in 0..<8 {
                if open.exists && open.isHittable { break }
                app.swipeUp()
            }
            open.tap()
            XCTAssertTrue(app.buttons["ngahuma.nextPlot"].waitForExistence(timeout: 30))
            XCTAssertEqual(app.alerts.count, 0)
        }
        openScene()
        let image = XCTAttachment(screenshot: app.screenshot())
        image.name = "Ngahuma-camera-free"; image.lifetime = .keepAlways; add(image)
        for _ in 0..<9 { app.buttons["ngahuma.nextPlot"].tap() }
        XCTAssertTrue(app.buttons["ngahuma.ignite"].exists)
        app.buttons["ngahuma.ignite"].tap()
        app.buttons["ngahuma.finishBurn"].tap()
        for _ in 0..<9 { app.buttons["ngahuma.nextPlot"].tap() }
        XCTAssertTrue(app.staticTexts["Lahan kembali tumbuh"].exists)
        app.buttons["ngahuma.replay"].tap()
        XCTAssertTrue(app.buttons["ngahuma.nextPlot"].exists)
        app.buttons["ngahuma.close"].tap()
        openScene()
        XCTAssertTrue(app.buttons["Petak berikutnya (0/9)"].exists)
        app.buttons["ngahuma.close"].tap()
    }
}
