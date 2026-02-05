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

        var form = MultipartFormData()
        let audioData = try Data(contentsOf: audioURL)
        let sizeMB = String(format: "%.1f", Double(audioData.count) / 1_048_576)
        print("[ElevenLabs] Transcribing \(sizeMB)MB audio")
        form.addFile(name: "file", filename: "audio.caf", mimeType: "audio/x-caf", data: audioData)
        form.addField(name: "model_id", value: "scribe_v2")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("multipart/form-data; boundary=\(form.boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = form.finalize()

        let (data, response) = try await session.data(for: request)
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
