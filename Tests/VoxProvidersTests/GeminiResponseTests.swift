import XCTest
@testable import VoxProviders

final class GeminiResponseTests: XCTestCase {
    func testFirstTextJoinsMultipleParts() throws {
        let json = """
        {
          "candidates": [
            {
              "content": {
                "parts": [
                  { "text": "Hello " },
                  { "text": "world" }
                ]
              }
            }
          ]
        }
        """
        let data = Data(json.utf8)
        let response = try JSONDecoder().decode(GeminiResponse.self, from: data)

        XCTAssertEqual(response.firstText, "Hello world")
    }
}
