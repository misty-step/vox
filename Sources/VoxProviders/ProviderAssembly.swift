import Foundation
import VoxCore

// MARK: - ProviderAssemblyConfig

/// Configuration for building cloud STT and rewrite provider chains.
///
/// Both `VoxSession` (app runtime) and `VoxPerfAudit` (perf-audit CLI) use
/// `ProviderAssembly` to avoid duplicating provider ordering, retry parameters,
/// and fallback chain semantics.
public struct ProviderAssemblyConfig: Sendable {
    public let elevenLabsAPIKey: String
    public let deepgramAPIKey: String
    public let geminiAPIKey: String
    public let openRouterAPIKey: String

    /// Maximum in-flight STT transcriptions (default: 8).
    public let maxConcurrentSTT: Int

    /// Optional hook called for each cloud STT provider before chain assembly.
    /// Parameters: (providerName, modelName, provider) → wrappedProvider.
    /// Perf-audit uses this to inject `InstrumentedSTTProvider`.
    public let sttInstrument: @Sendable (String, String, any STTProvider) -> any STTProvider

    /// Optional hook called for rewrite providers before returning.
    /// Parameter: (routingPath, provider) → wrappedProvider.
    /// Perf-audit uses this to inject `InstrumentedRewriteProvider`.
    public let rewriteInstrument: @Sendable (String, any RewriteProvider) -> any RewriteProvider

    public init(
        elevenLabsAPIKey: String,
        deepgramAPIKey: String,
        geminiAPIKey: String,
        openRouterAPIKey: String,
        maxConcurrentSTT: Int = 8,
        sttInstrument: @escaping @Sendable (String, String, any STTProvider) -> any STTProvider = { _, _, p in p },
        rewriteInstrument: @escaping @Sendable (String, any RewriteProvider) -> any RewriteProvider = { _, p in p }
    ) {
        func trimmed(_ s: String) -> String { s.trimmingCharacters(in: .whitespacesAndNewlines) }
        self.elevenLabsAPIKey = trimmed(elevenLabsAPIKey)
        self.deepgramAPIKey = trimmed(deepgramAPIKey)
        self.geminiAPIKey = trimmed(geminiAPIKey)
        self.openRouterAPIKey = trimmed(openRouterAPIKey)
        self.maxConcurrentSTT = max(1, maxConcurrentSTT)
        self.sttInstrument = sttInstrument
        self.rewriteInstrument = rewriteInstrument
    }
}

// MARK: - CloudSTTResult

/// The result of assembling the cloud STT chain.
public struct CloudSTTResult: Sendable {
    /// The assembled provider, wrapped with retry + fallback + concurrency limit.
    /// `nil` when no cloud API keys are configured.
    public let provider: (any STTProvider)?

    /// Chain members in preference order, for logging/metadata.
    public let descriptors: [(name: String, model: String)]
}

// MARK: - ProviderAssembly

/// Single source of truth for cloud STT and rewrite provider chain assembly.
///
/// Shared by `VoxSession` (app runtime) and `VoxPerfAudit` (CLI).
/// VoxSession adds Apple on-device STT on top of the cloud chain.
/// VoxPerfAudit passes instrumentation hooks to record per-provider usage.
public enum ProviderAssembly {

    // Retry parameters — single source of truth for both consumers.
    static let elevenLabsMaxRetries = 3
    static let deepgramMaxRetries = 2
    static let retryBaseDelay: TimeInterval = 0.5

    // OpenRouter fallback model list — keeps both consumers in sync.
    static let openRouterFallbackModels = [
        "google/gemini-2.5-flash",
        "google/gemini-2.0-flash-001",
    ]

    /// Builds the cloud STT provider chain from configured keys.
    ///
    /// Chain shape: ElevenLabs→Retry → Deepgram→Retry → sequential FallbackChain → ConcurrencyLimited.
    /// Returns `nil` provider when no cloud keys are configured.
    public static func makeCloudSTTProvider(config: ProviderAssemblyConfig) -> CloudSTTResult {
        var entries: [(name: String, model: String, provider: any STTProvider)] = []

        if !config.elevenLabsAPIKey.isEmpty {
            let base: any STTProvider = ElevenLabsClient(apiKey: config.elevenLabsAPIKey)
            let retried: any STTProvider = RetryingSTTProvider(
                provider: base,
                maxRetries: elevenLabsMaxRetries,
                baseDelay: retryBaseDelay,
                name: "ElevenLabs"
            )
            let instrumented = config.sttInstrument("ElevenLabs", "scribe_v2", retried)
            entries.append((name: "ElevenLabs", model: "scribe_v2", provider: instrumented))
        }

        if !config.deepgramAPIKey.isEmpty {
            let base: any STTProvider = DeepgramClient(apiKey: config.deepgramAPIKey)
            let retried: any STTProvider = RetryingSTTProvider(
                provider: base,
                maxRetries: deepgramMaxRetries,
                baseDelay: retryBaseDelay,
                name: "Deepgram"
            )
            let instrumented = config.sttInstrument("Deepgram", "nova-3", retried)
            entries.append((name: "Deepgram", model: "nova-3", provider: instrumented))
        }

        guard !entries.isEmpty else {
            return CloudSTTResult(provider: nil, descriptors: [])
        }

        // Sequential fallback chain: first → FallbackSTT(first, second) → FallbackSTT(…, third) → …
        let chain = entries.dropFirst().reduce((name: entries[0].name, provider: entries[0].provider)) { acc, next in
            let wrapper: any STTProvider = FallbackSTTProvider(
                primary: acc.provider,
                fallback: next.provider,
                primaryName: acc.name
            )
            return (name: "\(acc.name) + \(next.name)", provider: wrapper)
        }

        let limited: any STTProvider = ConcurrencyLimitedSTTProvider(
            provider: chain.provider,
            maxConcurrent: config.maxConcurrentSTT
        )

        let descriptors = entries.map { (name: $0.name, model: $0.model) }
        return CloudSTTResult(provider: limited, descriptors: descriptors)
    }

    /// Builds the rewrite provider from configured keys.
    ///
    /// - Gemini + OpenRouter → `ModelRoutedRewriteProvider`
    /// - Gemini only → `ModelRoutedRewriteProvider` (no openRouter fallback)
    /// - OpenRouter only → `OpenRouterClient`
    /// - Neither → bare `OpenRouterClient("")` (will fail at runtime; caller should warn)
    public static func makeRewriteProvider(config: ProviderAssemblyConfig) -> any RewriteProvider {
        let gemini: GeminiClient? = config.geminiAPIKey.isEmpty
            ? nil
            : GeminiClient(apiKey: config.geminiAPIKey)

        let openRouter: OpenRouterClient? = config.openRouterAPIKey.isEmpty
            ? nil
            : OpenRouterClient(apiKey: config.openRouterAPIKey, fallbackModels: openRouterFallbackModels)

        guard gemini != nil || openRouter != nil else {
            return OpenRouterClient(apiKey: "")
        }

        if let gemini {
            let instrumentedGemini = config.rewriteInstrument("gemini_direct", gemini)
            return ModelRoutedRewriteProvider(
                gemini: instrumentedGemini,
                openRouter: openRouter,
                fallbackGeminiModel: ProcessingLevel.defaultCleanRewriteModel
            )
        }

        // openRouter only
        return openRouter!
    }
}
