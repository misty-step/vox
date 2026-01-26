import XCTest

final class InfoPlistTests: XCTestCase {
    func testVoxURLSchemeRegistered() throws {
        // This test runs against the built bundle
        // Fails fast if URL scheme missing
        guard let bundlePath = ProcessInfo.processInfo.environment["VOX_BUNDLE_PATH"],
              let bundle = Bundle(path: bundlePath) else {
            throw XCTSkip("VOX_BUNDLE_PATH not set - run against built .app bundle")
        }

        let urlTypes = bundle.infoDictionary?["CFBundleURLTypes"] as? [[String: Any]]
        let schemes = urlTypes?.flatMap { $0["CFBundleURLSchemes"] as? [String] ?? [] }

        XCTAssertTrue(schemes?.contains("vox") == true,
                      "vox:// URL scheme not registered in Info.plist")
    }
}
