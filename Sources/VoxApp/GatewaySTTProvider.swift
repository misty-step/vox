import Foundation
import VoxCore

/// STT provider that proxies audio through the gateway
final class GatewaySTTProvider: STTProvider, @unchecked Sendable {
    let id = "gateway-stt"
    private let gateway: GatewayClient
    private let config: AppConfig.STTConfig

    init(gateway: GatewayClient, config: AppConfig.STTConfig) {
        self.gateway = gateway
        self.config = config
    }

    public func transcribe(_ request: TranscriptionRequest) async throws -> Transcript {
        let audioData = try Data(contentsOf: request.audioFileURL)
        let filename = request.audioFileURL.lastPathComponent.isEmpty
            ? "audio"
            : request.audioFileURL.lastPathComponent
        let mimeType = mimeTypeForURL(request.audioFileURL)
        let modelId = request.modelId ?? config.modelId
        let languageCode = normalizeLanguageCode(request.locale ?? config.languageCode)

        let response = try await gateway.transcribe(
            audioData: audioData,
            filename: filename,
            mimeType: mimeType,
            modelId: modelId,
            languageCode: languageCode,
            sessionId: request.sessionId.uuidString,
            fileFormat: config.fileFormat
        )

        return Transcript(
            sessionId: request.sessionId,
            text: response.text,
            language: response.languageCode
        )
    }
}

private func normalizeLanguageCode(_ value: String?) -> String? {
    guard let raw = value?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
        return nil
    }

    let lowered = raw.lowercased()
    let primary = lowered.components(separatedBy: CharacterSet(charactersIn: "-_")).first ?? lowered

    if primary.count == 3 {
        return primary
    }

    if let mapped = twoToThreeLetter[primary] {
        return mapped
    }

    return nil
}

private let twoToThreeLetter: [String: String] = [
    "en": "eng",
    "es": "spa",
    "fr": "fra",
    "de": "deu",
    "it": "ita",
    "pt": "por",
    "zh": "zho",
    "ja": "jpn",
    "ko": "kor",
    "ru": "rus",
    "nl": "nld",
    "sv": "swe",
    "no": "nor",
    "da": "dan",
    "fi": "fin",
    "pl": "pol",
    "tr": "tur"
]

private func mimeTypeForURL(_ url: URL) -> String {
    switch url.pathExtension.lowercased() {
    case "wav": return "audio/wav"
    case "caf": return "audio/x-caf"
    case "m4a": return "audio/m4a"
    case "mp3": return "audio/mpeg"
    default: return "application/octet-stream"
    }
}
