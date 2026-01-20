import XCTest
@testable import VoxProviders

final class ElevenLabsLanguageTests: XCTestCase {
    func testNormalizesTwoLetterCodes() {
        XCTAssertEqual(ElevenLabsLanguage.normalize("en"), "eng")
        XCTAssertEqual(ElevenLabsLanguage.normalize("fr"), "fra")
    }

    func testNormalizesLocaleCodes() {
        XCTAssertEqual(ElevenLabsLanguage.normalize("en_US"), "eng")
        XCTAssertEqual(ElevenLabsLanguage.normalize("fr-FR"), "fra")
    }

    func testPassesThroughThreeLetterCodes() {
        XCTAssertEqual(ElevenLabsLanguage.normalize("eng"), "eng")
    }

    func testUnknownReturnsNil() {
        XCTAssertNil(ElevenLabsLanguage.normalize("xx"))
        XCTAssertNil(ElevenLabsLanguage.normalize(nil))
    }
}
