import XCTest
@testable import VoxCore

final class ProcessingLevelTests: XCTestCase {
    func test_allCases_existInExpectedOrder() {
        XCTAssertEqual(ProcessingLevel.allCases, [.raw, .clean, .polish])
    }

    func test_rawValue_isCorrect() {
        XCTAssertEqual(ProcessingLevel.raw.rawValue, "raw")
        XCTAssertEqual(ProcessingLevel.clean.rawValue, "clean")
        XCTAssertEqual(ProcessingLevel.polish.rawValue, "polish")
    }

    func test_init_rawValue_migratesLegacyValues() {
        XCTAssertEqual(ProcessingLevel(rawValue: "off"), .raw)
        XCTAssertEqual(ProcessingLevel(rawValue: "light"), .clean)
        XCTAssertEqual(ProcessingLevel(rawValue: "aggressive"), .polish)
        XCTAssertEqual(ProcessingLevel(rawValue: "enhance"), .clean)
    }

    func test_codable_roundTrip_preservesValues() throws {
        let levels: [ProcessingLevel] = [.raw, .clean, .polish]
        let data = try JSONEncoder().encode(levels)
        let decoded = try JSONDecoder().decode([ProcessingLevel].self, from: data)

        XCTAssertEqual(decoded, levels)
    }

    func test_defaultRewriteModels_areMercury() {
        XCTAssertEqual(ProcessingLevel.defaultCleanRewriteModel, "inception/mercury")
        XCTAssertEqual(ProcessingLevel.defaultPolishRewriteModel, "inception/mercury")
    }

    func test_defaultGeminiFallbackModel_isGeminiFlashLite() {
        XCTAssertEqual(ProcessingLevel.defaultGeminiFallbackModel, "gemini-2.5-flash-lite")
    }
}
