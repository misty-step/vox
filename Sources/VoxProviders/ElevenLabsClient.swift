import Foundation
import VoxCore

public final class ElevenLabsClient: STTProvider {
    private let apiKey: String
    private let session: URLSession

    public init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    public func transcribe(audioURL: URL) async throws -> String {
        let url = URL(string: "https://api.elevenlabs.io/v1/speech-to-text")!

        let fileExt = audioURL.pathExtension.lowercased()
        let mimeType = mimeTypeForExtension(fileExt)

        // Build multipart form data as a temporary file for streaming upload
        let (uploadFileURL, fileSize) = try MultipartFileBuilder.build(
            audioURL: audioURL,
            mimeType: mimeType,
            boundary: boundary,
            additionalFields: [(name: "model_id", value: "scribe_v2")]
        )
        defer {
            // Clean up temporary multipart file
            SecureFileDeleter.delete(at: uploadFileURL)
        }

        let sizeMB = String(format: "%.1f", Double(fileSize) / 1_048_576)
        print("[ElevenLabs] Transcribing \(sizeMB)MB \(fileExt) (streaming)")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let processingTimeoutSeconds = BatchSTTTimeouts.processingTimeoutSeconds(forExpectedBytes: Int64(fileSize))
        let (data, response) = try await session.uploadWithPhaseAwareSTTTimeout(
            for: request,
            fromFile: uploadFileURL,
            expectedBytes: Int64(fileSize),
            uploadStallTimeoutSeconds: BatchSTTTimeouts.uploadStallTimeoutSeconds,
            processingTimeoutSeconds: processingTimeoutSeconds
        )

        guard let httpResponse = response as? HTTPURLResponse else {
            throw STTError.network("Invalid response")
        }

        switch httpResponse.statusCode {
        case 200:
            let result = try JSONDecoder().decode(ElevenLabsResponse.self, from: data)
            return result.text
        case 401:
            print("[ElevenLabs] Auth failed (HTTP 401)")
            throw STTError.auth
        case 429:
            print("[ElevenLabs] Rate limited (HTTP 429)")
            throw STTError.throttled
        default:
            let body = String(data: data.prefix(512), encoding: .utf8) ?? ""
            let excerpt = String(body.prefix(200)).replacingOccurrences(of: "\n", with: " ")
            print("[ElevenLabs] Failed: HTTP \(httpResponse.statusCode) — \(excerpt)")
            throw STTError.unknown("HTTP \(httpResponse.statusCode): \(excerpt)")
        }
    }

}

private struct ElevenLabsResponse: Decodable { let text: String }

private let boundary = "vox.boundary.\(UUID().uuidString)"

private func mimeTypeForExtension(_ ext: String) -> String {
    switch ext {
    case "ogg", "opus": return "audio/ogg"
    case "caf": return "audio/x-caf"
    case "wav": return "audio/wav"
    case "mp3": return "audio/mpeg"
    case "m4a", "mp4": return "audio/mp4"
    default: return "audio/x-caf"
    }
}
