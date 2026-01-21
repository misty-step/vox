import XCTest
@testable import VoxApp

final class DiagnosticsLogLevelTests: XCTestCase {
    func testDefaultsToInfoWhenMissing() {
        let level = Diagnostics.logLevel(from: [:])

        XCTAssertEqual(level, .info)
    }

    func testParsesLogLevelCaseInsensitiveAndTrimmed() {
        let level = Diagnostics.logLevel(from: ["VOX_LOG_LEVEL": "  DeBuG  "])

        XCTAssertEqual(level, .debug)
    }

    func testInvalidLogLevelFallsBackToInfo() {
        let level = Diagnostics.logLevel(from: ["VOX_LOG_LEVEL": "verbose"])

        XCTAssertEqual(level, .info)
    }

    func testShouldLogRespectsThreshold() {
        let errorOnly = ["VOX_LOG_LEVEL": "error"]
        XCTAssertFalse(Diagnostics.shouldLog(.info, env: errorOnly))
        XCTAssertTrue(Diagnostics.shouldLog(.error, env: errorOnly))

        let off = ["VOX_LOG_LEVEL": "off"]
        XCTAssertFalse(Diagnostics.shouldLog(.debug, env: off))
        XCTAssertFalse(Diagnostics.shouldLog(.info, env: off))
        XCTAssertFalse(Diagnostics.shouldLog(.error, env: off))
    }
}
