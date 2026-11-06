import XCTest
import UIKit
@testable import BeBaduy

final class ThemeResourceTests: XCTestCase {
    @MainActor func testSceneAssetsResolveFromAppBundle() {
        for phase in PhaseCatalog.all {
            for state in [phase.before, phase.after] {
                let image = UIImage(named: state.assetName)
                XCTAssertNotNil(image, state.assetName)
                XCTAssertGreaterThan(image?.size.width ?? 0, 0)
            }
        }
    }
    @MainActor func testThemeOpacityAndPrimaryButtonContrast() throws {
        for style in [UIUserInterfaceStyle.light, .dark] {
            let traits = UITraitCollection(userInterfaceStyle: style)
            for name in ["AccentColor", "Paper", "Earth"] {
                let color = try XCTUnwrap(UIColor(named: name, in: .main, compatibleWith: traits)).resolvedColor(with: traits)
                var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
                XCTAssertTrue(color.getRed(&red, green: &green, blue: &blue, alpha: &alpha))
                XCTAssertEqual(alpha, 1, accuracy: 0.001, "\(name) must be opaque")
                if name == "AccentColor" {
                    func linear(_ component: CGFloat) -> Double {
                        let value = Double(component)
                        return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
                    }
                    let luminance = 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
                    let contrast = style == .light ? 1.05 / (luminance + 0.05) : (luminance + 0.05) / 0.05
                    XCTAssertGreaterThanOrEqual(contrast, 4.5)
                }
            }
        }
    }
}
