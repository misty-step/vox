import Foundation
import VoxCore
import VoxMac

/// Preferences reader that fetches API keys from Vox Cloud gateway.
/// Falls back to UserDefaults for processingLevel and selectedInputDeviceUID.
/// API keys are fetched asynchronously and cached; synchronous accessors read from cache.
@MainActor
public final class VoxCloudPreferencesReading: ObservableObject, PreferencesReading {
    private let gatewayURL: URL
    private let session: URLSession
    private let defaults: UserDefaults
    private let cache: VoxCloudKeyCache
    private let onError: (String) -> Void
    
    /// Published error state for UI observation.
    @Published public private(set) var lastError: String?
    
    /// Processing level preference.
    @Published public var processingLevel: ProcessingLevel {
        didSet {
            defaults.set(processingLevel.rawValue, forKey: "processingLevel")
        }
    }
    
    /// Selected input device UID.
    @Published public var selectedInputDeviceUID: String? {
        didSet {
            if let uid = selectedInputDeviceUID {
                defaults.set(uid, forKey: "selectedInputDeviceUID")
            } else {
                defaults.removeObject(forKey: "selectedInputDeviceUID")
            }
        }
    }
    
    // MARK: - PreferencesReading API Keys (Synchronous)
    
    public var elevenLabsAPIKey: String {
        // Trigger background refresh if needed, return cached value
        refreshIfNeeded()
        return KeychainHelper.load(.elevenLabsAPIKey) ?? ""
    }
    
    public var openRouterAPIKey: String {
        refreshIfNeeded()
        return KeychainHelper.load(.openRouterAPIKey) ?? ""
    }
    
    public var deepgramAPIKey: String {
        refreshIfNeeded()
        return KeychainHelper.load(.deepgramAPIKey) ?? ""
    }
    
    public var openAIAPIKey: String {
        refreshIfNeeded()
        return KeychainHelper.load(.openAIAPIKey) ?? ""
    }
    
    public var geminiAPIKey: String {
        refreshIfNeeded()
        return KeychainHelper.load(.geminiAPIKey) ?? ""
    }
    
    // MARK: - Initialization
    
    public init(
        gatewayURL: URL,
        session: URLSession = .shared,
        defaults: UserDefaults = .standard,
        cache: VoxCloudKeyCache = VoxCloudKeyCache(),
        onError: @escaping (String) -> Void = { _ in }
    ) {
        self.gatewayURL = gatewayURL
        self.session = session
        self.defaults = defaults
        self.cache = cache
        self.onError = onError
        
        // Initialize from UserDefaults
        self.processingLevel = ProcessingLevel(
            rawValue: defaults.string(forKey: "processingLevel") ?? "light"
        ) ?? .light
        self.selectedInputDeviceUID = defaults.string(forKey: "selectedInputDeviceUID")
        
        // Trigger initial fetch in background
        Task {
            await refreshKeysIfNeeded()
        }
    }
    
    // MARK: - Private Helpers
    
    private func refreshIfNeeded() {
        Task {
            await refreshKeysIfNeeded()
        }
    }
    
    private func refreshKeysIfNeeded() async {
        // Only fetch if cache is invalid
        guard await !cache.isCacheValid else { return }
        await fetchKeys()
    }
    
    private func fetchKeys() async {
        guard let token = KeychainHelper.load(.voxCloudToken), !token.isEmpty else {
            let error = "Vox Cloud token not configured. Please sign in to Vox Cloud."
            lastError = error
            onError(error)
            return
        }
        
        var request = URLRequest(url: gatewayURL.appendingPathComponent("v1/keys"))
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        do {
            let (data, response) = try await session.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw VoxCloudError.invalidResponse
            }
            
            guard httpResponse.statusCode == 200 else {
                if httpResponse.statusCode == 401 {
                    throw VoxCloudError.unauthorized
                }
                throw VoxCloudError.httpError(statusCode: httpResponse.statusCode)
            }
            
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let keysResponse = try decoder.decode(VoxCloudKeysResponse.self, from: data)
            
            // Cache the keys with TTL
            await cache.setKeys(keysResponse.keys, expiresAt: keysResponse.expiresAt)
            
            // Store keys in keychain for synchronous access
            saveKeysToKeychain(keysResponse.keys)
            
            lastError = nil
            
        } catch let error as VoxCloudError {
            let message = error.localizedDescription
            lastError = message
            onError(message)
        } catch {
            let message = "Failed to fetch keys: \(error.localizedDescription)"
            lastError = message
            onError(message)
        }
    }
    
    private func saveKeysToKeychain(_ keys: VoxCloudKeys) {
        if !keys.elevenLabs.isEmpty {
            KeychainHelper.save(keys.elevenLabs, for: .elevenLabsAPIKey)
        }
        if !keys.deepgram.isEmpty {
            KeychainHelper.save(keys.deepgram, for: .deepgramAPIKey)
        }
        if !keys.openAI.isEmpty {
            KeychainHelper.save(keys.openAI, for: .openAIAPIKey)
        }
        if !keys.gemini.isEmpty {
            KeychainHelper.save(keys.gemini, for: .geminiAPIKey)
        }
        if !keys.openRouter.isEmpty {
            KeychainHelper.save(keys.openRouter, for: .openRouterAPIKey)
        }
    }
    
    // MARK: - Public Methods
    
    /// Force refresh keys from the server.
    public func refreshKeys() async {
        await cache.clear()
        await fetchKeys()
    }
    
    /// Async method to ensure keys are fetched and return current values.
    /// Use this when you need to guarantee fresh keys before an operation.
    public func ensureKeys() async -> VoxCloudKeysStatus {
        await refreshKeysIfNeeded()
        return VoxCloudKeysStatus(
            elevenLabsAPIKey: elevenLabsAPIKey,
            openRouterAPIKey: openRouterAPIKey,
            deepgramAPIKey: deepgramAPIKey,
            openAIAPIKey: openAIAPIKey,
            geminiAPIKey: geminiAPIKey,
            error: lastError
        )
    }
}

// MARK: - Response Models

struct VoxCloudKeysResponse: Codable {
    let keys: VoxCloudKeys
    let expiresAt: Date
}

/// API keys fetched from Vox Cloud gateway.
public struct VoxCloudKeys: Codable {
    public let elevenLabs: String
    public let deepgram: String
    public let openAI: String
    public let gemini: String
    public let openRouter: String
    
    public init(
        elevenLabs: String = "",
        deepgram: String = "",
        openAI: String = "",
        gemini: String = "",
        openRouter: String = ""
    ) {
        self.elevenLabs = elevenLabs
        self.deepgram = deepgram
        self.openAI = openAI
        self.gemini = gemini
        self.openRouter = openRouter
    }
}

/// Status snapshot of Vox Cloud keys.
public struct VoxCloudKeysStatus: Sendable {
    public let elevenLabsAPIKey: String
    public let openRouterAPIKey: String
    public let deepgramAPIKey: String
    public let openAIAPIKey: String
    public let geminiAPIKey: String
    public let error: String?
    
    public var isReady: Bool {
        !elevenLabsAPIKey.isEmpty && !geminiAPIKey.isEmpty
    }
}

// MARK: - Errors

enum VoxCloudError: LocalizedError {
    case invalidResponse
    case httpError(statusCode: Int)
    case noToken
    case unauthorized
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid response from Vox Cloud"
        case .httpError(let statusCode):
            return "Vox Cloud API error: HTTP \(statusCode)"
        case .noToken:
            return "Vox Cloud token not configured"
        case .unauthorized:
            return "Vox Cloud token invalid or expired"
        }
    }
}
