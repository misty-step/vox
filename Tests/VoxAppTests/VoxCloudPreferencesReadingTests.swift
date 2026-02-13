import Foundation
import Testing
import VoxCore
import VoxMac
@testable import VoxAppKit

@Suite("VoxCloudPreferencesReading")
struct VoxCloudPreferencesReadingTests {
    private let testGatewayURL = URL(string: "https://vox-cloud.example.com")!
    private let testToken = "test-vox-cloud-token"
    
    // MARK: - Test Lifecycle
    
    init() {
        // Clean up any existing keys before each test
        KeychainHelper.delete(.voxCloudToken)
        KeychainHelper.delete(.elevenLabsAPIKey)
        KeychainHelper.delete(.openRouterAPIKey)
        KeychainHelper.delete(.deepgramAPIKey)
        KeychainHelper.delete(.openAIAPIKey)
        KeychainHelper.delete(.geminiAPIKey)
    }
    
    deinit {
        // Clean up after each test
        KeychainHelper.delete(.voxCloudToken)
        KeychainHelper.delete(.elevenLabsAPIKey)
        KeychainHelper.delete(.openRouterAPIKey)
        KeychainHelper.delete(.deepgramAPIKey)
        KeychainHelper.delete(.openAIAPIKey)
        KeychainHelper.delete(.geminiAPIKey)
    }
    
    // MARK: - Mock URLSession
    
    private func createMockSession(
        response: VoxCloudKeysResponse,
        statusCode: Int = 200,
        error: Error? = nil
    ) -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        
        MockURLProtocol.mockResponse = (response, statusCode, error)
        
        return URLSession(configuration: config)
    }
    
    // MARK: - Key Caching Tests
    
    @Test("Keys are fetched and stored in keychain")
    func keysAreFetchedAndStored() async throws {
        // Given
        KeychainHelper.save(testToken, for: .voxCloudToken)
        
        let response = VoxCloudKeysResponse(
            keys: VoxCloudKeys(
                elevenLabs: "cached-eleven-labs-key",
                deepgram: "cached-deepgram-key",
                openAI: "cached-openai-key",
                gemini: "cached-gemini-key",
                openRouter: "cached-openrouter-key"
            ),
            expiresAt: Date().addingTimeInterval(3600)
        )
        
        let session = createMockSession(response: response)
        let _ = VoxCloudPreferencesReading(
            gatewayURL: testGatewayURL,
            session: session
        )
        
        // Wait for async fetch to complete
        try await Task.sleep(for: .milliseconds(100))
        
        // Then - Keys should be stored in keychain
        #expect(KeychainHelper.load(.elevenLabsAPIKey) == "cached-eleven-labs-key")
        #expect(KeychainHelper.load(.deepgramAPIKey) == "cached-deepgram-key")
        #expect(KeychainHelper.load(.openAIAPIKey) == "cached-openai-key")
        #expect(KeychainHelper.load(.geminiAPIKey) == "cached-gemini-key")
        #expect(KeychainHelper.load(.openRouterAPIKey) == "cached-openrouter-key")
    }
    
    @Test("Synchronous API key accessors return cached values")
    func synchronousAccessorsReturnCachedValues() async throws {
        // Given - Pre-populate keychain
        KeychainHelper.save(testToken, for: .voxCloudToken)
        KeychainHelper.save("sync-eleven-labs", for: .elevenLabsAPIKey)
        KeychainHelper.save("sync-gemini", for: .geminiAPIKey)
        
        let response = VoxCloudKeysResponse(
            keys: VoxCloudKeys(
                elevenLabs: "api-eleven-labs",
                deepgram: "api-deepgram",
                openAI: "api-openai",
                gemini: "api-gemini",
                openRouter: "api-openrouter"
            ),
            expiresAt: Date().addingTimeInterval(3600)
        )
        
        let session = createMockSession(response: response)
        let store = VoxCloudPreferencesReading(
            gatewayURL: testGatewayURL,
            session: session
        )
        
        // When - Access synchronously (returns keychain values)
        let elevenLabsKey = store.elevenLabsAPIKey
        let geminiKey = store.geminiAPIKey
        
        // Then - Should return the cached keychain values
        #expect(elevenLabsKey == "sync-eleven-labs")
        #expect(geminiKey == "sync-gemini")
    }
    
    // MARK: - TTL Expiry Refresh Tests
    
    @Test("Cache respects TTL expiration")
    func cacheRespectsTTL() async throws {
        // Given - Create cache with expired entry
        let cache = VoxCloudKeyCache()
        let expiredKeys = VoxCloudKeys(
            elevenLabs: "expired",
            deepgram: "expired",
            openAI: "expired",
            gemini: "expired",
            openRouter: "expired"
        )
        await cache.setKeys(expiredKeys, expiresAt: Date().addingTimeInterval(-1))
        
        // Then - Cache should be invalid
        let isValid = await cache.isCacheValid
        #expect(!isValid)
    }
    
    @Test("Cache valid when not expired")
    func cacheValidWhenNotExpired() async throws {
        // Given - Create cache with valid entry
        let cache = VoxCloudKeyCache()
        let validKeys = VoxCloudKeys(
            elevenLabs: "valid",
            deepgram: "valid",
            openAI: "valid",
            gemini: "valid",
            openRouter: "valid"
        )
        await cache.setKeys(validKeys, expiresAt: Date().addingTimeInterval(3600))
        
        // Then - Cache should be valid
        let isValid = await cache.isCacheValid
        #expect(isValid)
        
        // And - Should return keys
        let keys = await cache.getKeys()
        #expect(keys?.elevenLabs == "valid")
    }
    
    // MARK: - Error Handling Tests
    
    @Test("Clear error message when token missing")
    func errorMessageWhenTokenMissing() async throws {
        // Given - No token in keychain
        var capturedError: String?
        let store = VoxCloudPreferencesReading(
            gatewayURL: testGatewayURL,
            onError: { error in
                capturedError = error
            }
        )
        
        // When - Trigger fetch via refresh
        await store.refreshKeys()
        
        // Then - Error should indicate missing token
        #expect(capturedError != nil)
        #expect(capturedError?.contains("token") == true)
        #expect(store.lastError?.contains("token") == true)
    }
    
    @Test("Error on HTTP failure")
    func errorOnHTTPFailure() async throws {
        // Given
        KeychainHelper.save(testToken, for: .voxCloudToken)
        
        var capturedError: String?
        let session = createMockSession(
            response: VoxCloudKeysResponse(
                keys: VoxCloudKeys(),
                expiresAt: Date()
            ),
            statusCode: 500
        )
        
        let store = VoxCloudPreferencesReading(
            gatewayURL: testGatewayURL,
            session: session,
            onError: { error in
                capturedError = error
            }
        )
        
        // When
        await store.refreshKeys()
        
        // Then
        #expect(capturedError != nil)
        #expect(capturedError?.contains("500") == true)
    }
    
    @Test("Unauthorized error on 401")
    func unauthorizedErrorOn401() async throws {
        // Given
        KeychainHelper.save(testToken, for: .voxCloudToken)
        
        let session = createMockSession(
            response: VoxCloudKeysResponse(
                keys: VoxCloudKeys(),
                expiresAt: Date()
            ),
            statusCode: 401
        )
        
        let store = VoxCloudPreferencesReading(
            gatewayURL: testGatewayURL,
            session: session
        )
        
        // When
        await store.refreshKeys()
        
        // Then
        #expect(store.lastError?.contains("unauthorized") == true || store.lastError?.contains("invalid") == true)
    }
    
    // MARK: - UserDefaults Delegation Tests
    
    @Test("Processing level delegates to UserDefaults")
    func processingLevelDelegatesToUserDefaults() throws {
        // Given
        let defaults = UserDefaults(suiteName: "test-vox-cloud-prefs-\(UUID().uuidString)")!
        
        // Set a known value in UserDefaults
        defaults.set(ProcessingLevel.aggressive.rawValue, forKey: "processingLevel")
        
        let store = VoxCloudPreferencesReading(
            gatewayURL: testGatewayURL,
            defaults: defaults
        )
        
        // Then
        #expect(store.processingLevel == .aggressive)
        
        // When - Update via store
        store.processingLevel = .enhance
        
        // Then - Should persist to UserDefaults
        #expect(defaults.string(forKey: "processingLevel") == "enhance")
        
        defaults.removeObject(forKey: "processingLevel")
    }
    
    @Test("Selected input device UID delegates to UserDefaults")
    func selectedInputDeviceDelegatesToUserDefaults() throws {
        // Given
        let defaults = UserDefaults(suiteName: "test-vox-cloud-input-\(UUID().uuidString)")!
        
        // Set a known value in UserDefaults
        defaults.set("Built-in Microphone", forKey: "selectedInputDeviceUID")
        
        let store = VoxCloudPreferencesReading(
            gatewayURL: testGatewayURL,
            defaults: defaults
        )
        
        // Then
        #expect(store.selectedInputDeviceUID == "Built-in Microphone")
        
        // When - Update via store
        store.selectedInputDeviceUID = "USB Microphone"
        
        // Then - Should persist to UserDefaults
        #expect(defaults.string(forKey: "selectedInputDeviceUID") == "USB Microphone")
        
        // When - Set to nil
        store.selectedInputDeviceUID = nil
        
        // Then - Should remove from UserDefaults
        #expect(defaults.string(forKey: "selectedInputDeviceUID") == nil)
        
        defaults.removeObject(forKey: "selectedInputDeviceUID")
    }
    
    // MARK: - Keychain Token Tests
    
    @Test("Vox Cloud token is stored and retrieved from Keychain")
    func voxCloudTokenStoredInKeychain() throws {
        // Given
        KeychainHelper.save(testToken, for: .voxCloudToken)
        
        // Then - Should be retrievable
        #expect(KeychainHelper.load(.voxCloudToken) == testToken)
    }
    
    // MARK: - Protocol Conformance Tests
    
    @Test("Conforms to PreferencesReading protocol")
    func conformsToPreferencesReading() throws {
        let store = VoxCloudPreferencesReading(gatewayURL: testGatewayURL)
        
        // Verify all required properties exist and are accessible
        let _: ProcessingLevel = store.processingLevel
        let _: String? = store.selectedInputDeviceUID
        let _: String = store.elevenLabsAPIKey
        let _: String = store.openRouterAPIKey
        let _: String = store.deepgramAPIKey
        let _: String = store.openAIAPIKey
        let _: String = store.geminiAPIKey
    }
}

// MARK: - Mock URL Protocol

class MockURLProtocol: URLProtocol {
    static var mockResponse: (VoxCloudKeysResponse, Int, Error?)?
    
    override class func canInit(with request: URLRequest) -> Bool {
        return true
    }
    
    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        return request
    }
    
    override func startLoading() {
        guard let (response, statusCode, error) = MockURLProtocol.mockResponse else {
            let error = NSError(domain: "MockURLProtocol", code: -1, userInfo: [NSLocalizedDescriptionKey: "No mock response set"])
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        
        if let error = error {
            client?.urlProtocol(self, didFailWithError: error)
            return
        }
        
        let httpResponse = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: "1.1",
            headerFields: ["Content-Type": "application/json"]
        )!
        
        client?.urlProtocol(self, didReceive: httpResponse, cacheStoragePolicy: .notAllowed)
        
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try! encoder.encode(response)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }
    
    override func stopLoading() {}
}

// MARK: - Response Model

struct VoxCloudKeysResponse: Codable {
    let keys: VoxCloudKeys
    let expiresAt: Date
}
