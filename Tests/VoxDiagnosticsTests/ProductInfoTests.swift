import Foundation
import Testing
@testable import VoxDiagnostics

@Suite("ProductInfo")
struct ProductInfoTests {
    @Test("Reads version and build from bundle info dictionary")
    func current_readsBundleInfo() {
        let infoDictionary: [String: Any] = [
            "CFBundleShortVersionString": "1.2.3",
            "CFBundleVersion": "456"
        ]

        let productInfo = ProductInfo.resolved(infoDictionary: infoDictionary)

        #expect(productInfo.version == "1.2.3")
        #expect(productInfo.build == "456")
        #expect(productInfo.attribution == "Vox by Misty Step")
        #expect(productInfo.supportURL.absoluteString == "https://github.com/misty-step/vox/issues")
    }

    @Test("Falls back to deterministic defaults when bundle info is missing")
    func current_fallsBackToDeterministicDefaults() {
        let productInfo = ProductInfo.resolved(infoDictionary: nil)

        #expect(productInfo.version == "0.0.0-dev")
        #expect(productInfo.build == "local")
    }

    @Test("Treats empty bundle values as missing")
    func current_usesFallbackForEmptyValues() {
        let infoDictionary: [String: Any] = [
            "CFBundleShortVersionString": "   ",
            "CFBundleVersion": ""
        ]

        let productInfo = ProductInfo.resolved(infoDictionary: infoDictionary)

        #expect(productInfo.version == "0.0.0-dev")
        #expect(productInfo.build == "local")
    }

    @Test("Uses runtime environment overrides when bundle info is missing")
    func current_usesEnvironmentOverrides() {
        let environment = [
            "VOX_APP_VERSION": "9.9.9",
            "VOX_BUILD_NUMBER": "12345",
        ]

        let productInfo = ProductInfo.resolved(infoDictionary: nil, environment: environment)

        #expect(productInfo.version == "9.9.9")
        #expect(productInfo.build == "12345")
    }
}
