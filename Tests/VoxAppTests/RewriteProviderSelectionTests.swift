import XCTest
@testable import VoxApp

final class RewriteProviderSelectionTests: XCTestCase {
    func testResolvesLegacyGeminiConfig() throws {
        let config = AppConfig.RewriteConfig(
            provider: "gemini",
            providers: nil,
            apiKey: "test-key",
            modelId: "gemini-3-pro-preview",
            temperature: 0.1,
            maxOutputTokens: 123,
            thinkingLevel: "high"
        )

        let selection = try RewriteConfigResolver.resolve(config)

        XCTAssertEqual(selection.id, "gemini")
        XCTAssertEqual(selection.apiKey, "test-key")
        XCTAssertEqual(selection.modelId, "gemini-3-pro-preview")
        XCTAssertEqual(selection.temperature, 0.1)
        XCTAssertEqual(selection.maxOutputTokens, 123)
        XCTAssertEqual(selection.thinkingLevel, "high")
    }

    func testResolvesProvidersArrayConfig() throws {
        let providers = [
            RewriteProviderConfig(
                id: "gemini",
                apiKey: "gemini-key",
                modelId: "gemini-3-pro-preview",
                temperature: 0.2,
                maxOutputTokens: 100,
                thinkingLevel: nil
            ),
            RewriteProviderConfig(
                id: "openrouter",
                apiKey: "openrouter-key",
                modelId: "openai/gpt-4o-mini",
                temperature: 0.3,
                maxOutputTokens: 200,
                thinkingLevel: nil
            )
        ]
        let config = AppConfig.RewriteConfig(
            provider: "openrouter",
            providers: providers,
            apiKey: nil,
            modelId: nil,
            temperature: nil,
            maxOutputTokens: nil,
            thinkingLevel: nil
        )

        let selection = try RewriteConfigResolver.resolve(config)

        XCTAssertEqual(selection.id, "openrouter")
        XCTAssertEqual(selection.apiKey, "openrouter-key")
        XCTAssertEqual(selection.modelId, "openai/gpt-4o-mini")
        XCTAssertEqual(selection.temperature, 0.3)
        XCTAssertEqual(selection.maxOutputTokens, 200)
    }

    func testDecodeProvidersConfig() throws {
        let json = """
        {
          "provider": "openrouter",
          "providers": [
            {
              "id": "openrouter",
              "apiKey": "test-key",
              "modelId": "openai/gpt-4o-mini",
              "temperature": 0.25,
              "maxOutputTokens": 900
            }
          ]
        }
        """
        let data = try XCTUnwrap(json.data(using: .utf8))
        let decoded = try JSONDecoder().decode(AppConfig.RewriteConfig.self, from: data)
        let selection = try RewriteConfigResolver.resolve(decoded)

        XCTAssertEqual(selection.id, "openrouter")
        XCTAssertEqual(selection.apiKey, "test-key")
        XCTAssertEqual(selection.modelId, "openai/gpt-4o-mini")
        XCTAssertEqual(selection.temperature, 0.25)
        XCTAssertEqual(selection.maxOutputTokens, 900)
    }

    func testProviderFactorySelectsOpenRouter() throws {
        let config = AppConfig.RewriteConfig(
            provider: "openrouter",
            providers: [
                RewriteProviderConfig(
                    id: "openrouter",
                    apiKey: "openrouter-key",
                    modelId: "openai/gpt-4o-mini",
                    temperature: 0.2,
                    maxOutputTokens: 300,
                    thinkingLevel: nil
                )
            ],
            apiKey: nil,
            modelId: nil,
            temperature: nil,
            maxOutputTokens: nil,
            thinkingLevel: nil
        )

        let provider = try ProviderFactory.makeRewrite(config: config)

        XCTAssertEqual(provider.id, "openrouter")
    }
}
