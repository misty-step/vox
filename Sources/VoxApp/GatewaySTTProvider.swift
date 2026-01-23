import Foundation
import VoxCore
import VoxProviders

/// STT provider that fetches credentials from the gateway and calls ElevenLabs directly
final class GatewaySTTProvider: STTProvider, @unchecked Sendable {
    let id = "gateway-stt"
    private let gateway: GatewayClient
    private let config: AppConfig.STTConfig

    init(gateway: GatewayClient, config: AppConfig.STTConfig) {
        self.gateway = gateway
        self.config = config
    }

    public func transcribe(_ request: TranscriptionRequest) async throws -> Transcript {
        // Get fresh token from gateway
        let tokenResponse = try await gateway.getSTTToken()

        // Create ElevenLabs provider with the gateway-provided token
        let elevenLabs = ElevenLabsSTTProvider(
            config: ElevenLabsSTTConfig(
                apiKey: tokenResponse.token,
                modelId: config.modelId,
                languageCode: config.languageCode,
                fileFormat: config.fileFormat,
                enableLogging: true
            )
        )

        // Delegate to ElevenLabs
        return try await elevenLabs.transcribe(request)
    }
}
