import XCTest
@testable import VoxApp

final class ProcessingLevelOverrideTests: XCTestCase {
    func testUsesVoxProcessingLevelWhenPresent() {
        let env = [
            "VOX_PROCESSING_LEVEL": "Aggressive",
            "VOX_REWRITE_LEVEL": "light"
        ]

        let override = ConfigLoader.processingLevelOverride(from: env)

        XCTAssertEqual(override?.level, .aggressive)
        XCTAssertEqual(override?.sourceKey, "VOX_PROCESSING_LEVEL")
    }

    func testFallsBackToVoxRewriteLevel() {
        let env = ["VOX_REWRITE_LEVEL": "off"]

        let override = ConfigLoader.processingLevelOverride(from: env)

        XCTAssertEqual(override?.level, .off)
        XCTAssertEqual(override?.sourceKey, "VOX_REWRITE_LEVEL")
    }

    func testIgnoresInvalidProcessingLevelValue() {
        let env = [
            "VOX_PROCESSING_LEVEL": "unknown",
            "VOX_REWRITE_LEVEL": "light"
        ]

        let override = ConfigLoader.processingLevelOverride(from: env)

        XCTAssertEqual(override?.level, .light)
        XCTAssertEqual(override?.sourceKey, "VOX_REWRITE_LEVEL")
    }

    func testReturnsNilWhenMissing() {
        let override = ConfigLoader.processingLevelOverride(from: [:])

        XCTAssertNil(override)
    }
}
