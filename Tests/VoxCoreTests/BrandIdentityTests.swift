import XCTest
@testable import VoxCore

final class BrandIdentityTests: XCTestCase {
    func test_accentColorChannels_areStable() {
        XCTAssertEqual(BrandIdentity.accent.red, 1.0, accuracy: 0.000_1)
        XCTAssertEqual(BrandIdentity.accent.green, 0.25, accuracy: 0.000_1)
        XCTAssertEqual(BrandIdentity.accent.blue, 0.25, accuracy: 0.000_1)
    }

    func test_menuIconStrokeWidth_scalesByProcessingLevel() {
        XCTAssertEqual(BrandIdentity.menuIconStrokeWidth(for: .raw), 1.6, accuracy: 0.000_1)
        XCTAssertEqual(BrandIdentity.menuIconStrokeWidth(for: .clean), 2.2, accuracy: 0.000_1)
        XCTAssertEqual(BrandIdentity.menuIconStrokeWidth(for: .polish), 2.8, accuracy: 0.000_1)
    }
}
