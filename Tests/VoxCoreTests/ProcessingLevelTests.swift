import XCTest
@testable import VoxCore

final class ProcessingLevelTests: XCTestCase {
    func testProcessingLevelDecodesFromString() throws {
        let data = Data(#""aggressive""#.utf8)
        let level = try JSONDecoder().decode(ProcessingLevel.self, from: data)
        XCTAssertEqual(level, .aggressive)
    }

    func testRewriteRequestDefaultsToLightWhenMissingLevel() throws {
        let json = """
        {
          "sessionId": "00000000-0000-0000-0000-000000000000",
          "locale": "en",
          "transcript": { "text": "Hello world" },
          "context": ""
        }
        """
        let data = Data(json.utf8)
        let request = try JSONDecoder().decode(RewriteRequest.self, from: data)
        XCTAssertEqual(request.processingLevel, .light)
    }
}
