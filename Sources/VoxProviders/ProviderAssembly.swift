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
    public let inceptionAPIKey: String

    /// Optional hook called for each cloud STT provider before chain assembly.
    /// Parameters: (providerName, modelName, provider) → wrappedProvider.
    /// Perf-audit uses this to inject `InstrumentedSTTProvider`.
    public let sttInstrument: @Sendable (String, String, any STTProvider) -> any STTProvider

    /// Optional hook called for rewrite providers before returning.
    /// Parameter: (routingPath, provider) → wrappedProvider.
    /// Perf-audit uses this to inject `InstrumentedRewriteProvider` for Gemini.
    public let rewriteInstrument: @Sendable (String, any RewriteProvider) -> any RewriteProvider

    /// Optional callback forwarded to `OpenRouterClient.onModelUsed`.
    /// Fires with the actual served model + whether it was a fallback selection.
    /// Perf-audit uses this to record per-call model usage.
    public let openRouterOnModelUsed: (@Sendable (String, Bool) -> Void)?

    /// Optional callback forwarded to `OpenRouterClient.onDiagnostic`.
    /// Emits structured attempt/success/failure routing details for diagnostics.
    public let openRouterOnDiagnostic: (@Sendable (OpenRouterRewriteDiagnostic) -> Void)?

    public init(
        elevenLabsAPIKey: String,
        deepgramAPIKey: String,
        geminiAPIKey: String,
        openRouterAPIKey: String,
        inceptionAPIKey: String = "",
        sttInstrument: @escaping @Sendable (String, String, any STTProvider) -> any STTProvider = { _, _, p in p },
        rewriteInstrument: @escaping @Sendable (String, any RewriteProvider) -> any RewriteProvider = { _, p in p },
        openRouterOnModelUsed: (@Sendable (String, Bool) -> Void)? = nil,
        openRouterOnDiagnostic: (@Sendable (OpenRouterRewriteDiagnostic) -> Void)? = nil
    ) {
        func trimmed(_ s: String) -> String { s.trimmingCharacters(in: .whitespacesAndNewlines) }
        self.elevenLabsAPIKey = trimmed(elevenLabsAPIKey)
        self.deepgramAPIKey = trimmed(deepgramAPIKey)
        self.geminiAPIKey = trimmed(geminiAPIKey)
        self.openRouterAPIKey = trimmed(openRouterAPIKey)
        self.inceptionAPIKey = trimmed(inceptionAPIKey)
        self.sttInstrument = sttInstrument
        self.rewriteInstrument = rewriteInstrument
        self.openRouterOnModelUsed = openRouterOnModelUsed
        self.openRouterOnDiagnostic = openRouterOnDiagnostic
    }
}

// MARK: - CloudSTTEntry

/// A single cloud STT provider entry: retry-wrapped and instrumented, ready for chain assembly.
public struct CloudSTTEntry: Sendable {
    public let name: String
    public let model: String
    /// Retry-wrapped (and instrumentation-hooked) provider. Not yet chained or concurrency-limited.
    public let provider: any STTProvider
}

// MARK: - CloudSTTResult

/// Result of assembling the cloud STT provider tier.
public struct CloudSTTResult: Sendable {
    /// Individual retry-wrapped entries in preference order.
    /// Use `entries` for hedged routing, forced-provider reordering, or display.
    /// Empty when no cloud keys are configured.
    public let entries: [CloudSTTEntry]
}

// MARK: - ProviderAssembly

/// Single source of truth for cloud STT and rewrite provider chain assembly.
///
/// Shared by `VoxSession` (app runtime) and `VoxPerfAudit` (CLI).
/// VoxSession adds Apple on-device STT on top of the cloud chain and wraps
/// with `ConcurrencyLimitedSTTProvider`. VoxPerfAudit passes instrumentation
/// hooks to record per-provider usage metrics.
public enum ProviderAssembly {

    // Retry parameters — single source of truth for both consumers.
    static let elevenLabsMaxRetries = 3
    static let deepgramMaxRetries = 2
    static let retryBaseDelay: TimeInterval = 0.5

    // Model names — single source of truth for provider identification and instrumentation.
    static let elevenLabsModel = "scribe_v2"
    static let deepgramModel = "nova-3"

    // OpenRouter fallback model list — keeps both consumers in sync.
    static let openRouterFallbackModels = [
        "google/gemini-2.5-flash",
        "google/gemini-2.0-flash-001",
    ]

    /// Builds the cloud STT provider tier from configured keys.
    ///
    /// Each configured provider is wrapped with `RetryingSTTProvider`, then passed through
    /// the optional `sttInstrument` hook. The result does **not** include Apple on-device STT
    /// or a concurrency limit — callers are responsible for both.
    ///
    /// Chain: ElevenLabs→Retry→[Instrument] → Deepgram→Retry→[Instrument]
    public static func makeCloudSTTProvider(config: ProviderAssemblyConfig) -> CloudSTTResult {
        var entries: [CloudSTTEntry] = []

        if !config.elevenLabsAPIKey.isEmpty {
            let base: any STTProvider = ElevenLabsClient(apiKey: config.elevenLabsAPIKey)
            let retried: any STTProvider = RetryingSTTProvider(
                provider: base,
                maxRetries: elevenLabsMaxRetries,
                baseDelay: retryBaseDelay,
                name: "ElevenLabs"
            )
            let instrumented = config.sttInstrument("ElevenLabs", elevenLabsModel, retried)
            entries.append(CloudSTTEntry(name: "ElevenLabs", model: elevenLabsModel, provider: instrumented))
        }

        if !config.deepgramAPIKey.isEmpty {
            let base: any STTProvider = DeepgramClient(apiKey: config.deepgramAPIKey)
            let retried: any STTProvider = RetryingSTTProvider(
                provider: base,
                maxRetries: deepgramMaxRetries,
                baseDelay: retryBaseDelay,
                name: "Deepgram"
            )
            let instrumented = config.sttInstrument("Deepgram", deepgramModel, retried)
            entries.append(CloudSTTEntry(name: "Deepgram", model: deepgramModel, provider: instrumented))
        }

        return CloudSTTResult(entries: entries)
    }

    /// Builds a sequential `FallbackSTTProvider` chain from ordered entries.
    ///
    /// Returns `nil` when `entries` is empty. Callers typically append Apple on-device STT
    /// as a final fallback after this chain.
    public static func buildFallbackChain(from entries: [CloudSTTEntry]) -> (any STTProvider)? {
        guard let first = entries.first else { return nil }
        return entries.dropFirst().reduce(
            (name: first.name, provider: first.provider)
        ) { acc, next in
            let wrapper: any STTProvider = FallbackSTTProvider(
                primary: acc.provider,
                fallback: next.provider,
                primaryName: acc.name
            )
            return (name: "\(acc.name) + \(next.name)", provider: wrapper)
        }.provider
    }

    /// Human-readable label for a chain of entries (e.g. "ElevenLabs + Deepgram").
    public static func chainLabel(for entries: [CloudSTTEntry]) -> String {
        entries.map(\.name).joined(separator: " + ")
    }

    /// Builds the rewrite provider from configured keys.
    ///
    /// - Gemini + any → `ModelRoutedRewriteProvider` (gemini as primary for Gemini models)
    /// - Inception + any (no gemini) → `ModelRoutedRewriteProvider` (inception for Mercury models)
    /// - OpenRouter only → `OpenRouterClient`
    /// - None → bare `OpenRouterClient("")` (will fail at runtime; caller should warn)
    public static func makeRewriteProvider(config: ProviderAssemblyConfig) -> any RewriteProvider {
        let gemini: GeminiClient? = config.geminiAPIKey.isEmpty
            ? nil
            : GeminiClient(apiKey: config.geminiAPIKey)

        let openRouter: OpenRouterClient? = config.openRouterAPIKey.isEmpty
            ? nil
            : OpenRouterClient(
                apiKey: config.openRouterAPIKey,
                fallbackModels: openRouterFallbackModels,
                onModelUsed: config.openRouterOnModelUsed,
                onDiagnostic: config.openRouterOnDiagnostic
            )

        let inception: InceptionLabsClient? = config.inceptionAPIKey.isEmpty
            ? nil
            : InceptionLabsClient(apiKey: config.inceptionAPIKey)

        if let gemini {
            let instrumented = config.rewriteInstrument("gemini_direct", gemini)
            return ModelRoutedRewriteProvider(
                gemini: instrumented,
                openRouter: openRouter,
                inception: inception,
                fallbackGeminiModel: ProcessingLevel.defaultGeminiFallbackModel
            )
        }

        if let inception {
            return ModelRoutedRewriteProvider(
                gemini: nil,
                openRouter: openRouter,
                inception: inception,
                fallbackGeminiModel: ProcessingLevel.defaultGeminiFallbackModel
            )
        }

        if let openRouter {
            return openRouter
        }

        return OpenRouterClient(apiKey: "")
    }
}
