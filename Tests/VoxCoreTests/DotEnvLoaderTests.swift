import Foundation
import XCTest
@testable import VoxCore

final class DotEnvLoaderTests: XCTestCase {
    func testParsesKeyValuesAndQuotes() throws {
        let contents = """
        # comment
        FOO=bar
        QUOTED="hello world"
        SPACED = value
        EMPTY=
        """

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: url) }

        let result = try DotEnvLoader.load(from: url)

        XCTAssertEqual(result["FOO"], "bar")
        XCTAssertEqual(result["QUOTED"], "hello world")
        XCTAssertEqual(result["SPACED"], "value")
        XCTAssertEqual(result["EMPTY"], "")
    }
}
