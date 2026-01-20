import Foundation
import VoxCore

public struct ElevenLabsSTTConfig: Sendable {
    public let apiKey: String
    public let endpoint: URL
    public let modelId: String
    public let languageCode: String?
    public let fileFormat: String?
    public let enableLogging: Bool?

    public init(
        apiKey: String,
        endpoint: URL? = nil,
        modelId: String,
        languageCode: String?,
        fileFormat: String?,
        enableLogging: Bool?
    ) {
        self.apiKey = apiKey
        self.endpoint = endpoint
            ?? URL(string: "https://api.elevenlabs.io/v1/speech-to-text")!
        self.modelId = modelId
        self.languageCode = languageCode
        self.fileFormat = fileFormat
        self.enableLogging = enableLogging
    }
}

public final class ElevenLabsSTTProvider: STTProvider {
    public let id = "elevenlabs"
    private let config: ElevenLabsSTTConfig

    public init(config: ElevenLabsSTTConfig) {
        self.config = config
    }

    public func transcribe(_ request: TranscriptionRequest) async throws -> Transcript {
        let audioData = try Data(contentsOf: request.audioFileURL)
        var form = MultipartFormData()

        let modelId = request.modelId ?? config.modelId
        form.addField(name: "model_id", value: modelId)

        if let languageCode = ElevenLabsLanguage.normalize(request.locale ?? config.languageCode) {
            form.addField(name: "language_code", value: languageCode)
        }

        if let fileFormat = config.fileFormat {
            form.addField(name: "file_format", value: fileFormat)
        }

        if let enableLogging = config.enableLogging {
            form.addField(name: "enable_logging", value: enableLogging ? "true" : "false")
        }

        let mimeType = mimeTypeForURL(request.audioFileURL)
        form.addFile(
            name: "file",
            filename: request.audioFileURL.lastPathComponent,
            mimeType: mimeType,
            data: audioData
        )

        let body = form.finalize()

        var urlRequest = URLRequest(url: config.endpoint)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("multipart/form-data; boundary=\(form.boundary)", forHTTPHeaderField: "Content-Type")
        urlRequest.setValue(config.apiKey, forHTTPHeaderField: "xi-api-key")
        urlRequest.httpBody = body

        let (data, response) = try await URLSession.shared.data(for: urlRequest)
        guard let http = response as? HTTPURLResponse else {
            throw STTError.network("Missing HTTP response.")
        }

        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            let message = body.isEmpty ? "STT failed with status \(http.statusCode)." : "STT failed with status \(http.statusCode): \(body)"
            throw STTError.network(message)
        }

        let decoded = try JSONDecoder().decode(ElevenLabsSTTResponse.self, from: data)
        return Transcript(sessionId: request.sessionId, text: decoded.text, language: decoded.languageCode)
    }
}

private struct ElevenLabsSTTResponse: Decodable {
    let text: String
    let languageCode: String?

    enum CodingKeys: String, CodingKey {
        case text
        case languageCode = "language_code"
    }
}

private func mimeTypeForURL(_ url: URL) -> String {
    switch url.pathExtension.lowercased() {
    case "wav": return "audio/wav"
    case "caf": return "audio/x-caf"
    case "m4a": return "audio/m4a"
    case "mp3": return "audio/mpeg"
    default: return "application/octet-stream"
    }
}
