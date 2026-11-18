import XCTest
import SceneKit
@testable import BeBaduy

final class SceneLifetimeTests: XCTestCase {
    @MainActor func testClosingDuringNgoredGrowthReleasesRenderer() async {
        for _ in 0..<3 {
            var renderer: NgahumaScene? = NgahumaScene()
            weak var releasedRenderer = renderer
            var view: SCNView? = SCNView()
            renderer!.attach(view!)
            await renderer!.prepareAssets()
            XCTAssertNil(renderer!.assetError)
            renderer!.showNgoredField()
            renderer!.growNgoredRice()
            renderer!.stop()
            view = nil
            renderer = nil
            XCTAssertNil(releasedRenderer)
        }
    }
}
