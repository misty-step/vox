import XCTest
@testable import VoxCore

final class ProcessingLevelTests: XCTestCase {
    func test_allCases_existInExpectedOrder() {
        XCTAssertEqual(ProcessingLevel.allCases, [.off, .light, .aggressive])
    }

    func test_rawValue_isCorrect() {
        XCTAssertEqual(ProcessingLevel.off.rawValue, "off")
        XCTAssertEqual(ProcessingLevel.light.rawValue, "light")
        XCTAssertEqual(ProcessingLevel.aggressive.rawValue, "aggressive")
    }

    func test_codable_roundTrip_preservesValues() throws {
        let levels: [ProcessingLevel] = [.off, .light, .aggressive]
        let data = try JSONEncoder().encode(levels)
        let decoded = try JSONDecoder().decode([ProcessingLevel].self, from: data)

        XCTAssertEqual(decoded, levels)
    }
}
