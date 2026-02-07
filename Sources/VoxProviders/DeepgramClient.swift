import Foundation
import VoxCore

public final class DeepgramClient: STTProvider {
    private let apiKey: String
    private let session: URLSession

    public init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    public func transcribe(audioURL: URL) async throws -> String {
        let url = URL(string: "https://api.deepgram.com/v1/listen?model=nova-3")!
        let (uploadURL, contentType, tempURL) = try await prepareAudioFile(for: audioURL)
        defer {
            if let tempURL {
                SecureFileDeleter.delete(at: tempURL)
            }
        }

        let fileSize = (try? FileManager.default.attributesOfItem(atPath: uploadURL.path)[.size] as? Int) ?? 0
        let sizeMB = String(format: "%.1f", Double(fileSize) / 1_048_576)
        print("[Deepgram] Transcribing \(sizeMB)MB audio (\(contentType))")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(contentType, forHTTPHeaderField: "Content-Type")

        let (data, response) = try await session.upload(for: request, fromFile: uploadURL)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw STTError.network("Invalid response")
        }

        switch httpResponse.statusCode {
        case 200:
            let result = try JSONDecoder().decode(DeepgramResponse.self, from: data)
            return result.results.channels.first?.alternatives.first?.transcript ?? ""
        case 400:
            let body = String(data: data.prefix(512), encoding: .utf8) ?? ""
            let excerpt = String(body.prefix(200)).replacingOccurrences(of: "\n", with: " ")
            print("[Deepgram] Invalid audio (HTTP 400) — \(excerpt)")
            throw STTError.invalidAudio
        case 401:
            print("[Deepgram] Auth failed (HTTP 401)")
            throw STTError.auth
        case 402, 403:
            print("[Deepgram] Quota exceeded (HTTP \(httpResponse.statusCode))")
            throw STTError.quotaExceeded
        case 429:
            print("[Deepgram] Rate limited (HTTP 429)")
            throw STTError.throttled
        default:
            let body = String(data: data.prefix(512), encoding: .utf8) ?? ""
            let excerpt = String(body.prefix(200)).replacingOccurrences(of: "\n", with: " ")
            print("[Deepgram] Failed: HTTP \(httpResponse.statusCode) — \(excerpt)")
            throw STTError.unknown("HTTP \(httpResponse.statusCode): \(excerpt)")
        }
    }

    /// CAF files must be converted to WAV — Deepgram's API does not accept CAF directly.
    private func prepareAudioFile(for url: URL) async throws -> (fileURL: URL, mimeType: String, tempURL: URL?) {
        if url.pathExtension.lowercased() == "caf" {
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("wav")

            do {
                try await AudioConverter.convertCAFToWAV(from: url, to: tempURL)
            } catch {
                throw STTError.invalidAudio
            }
            return (tempURL, "audio/wav", tempURL)
        }

        let mimeType: String
        switch url.pathExtension.lowercased() {
        case "wav":
            mimeType = "audio/wav"
        case "m4a":
            mimeType = "audio/mp4"
        case "mp3":
            mimeType = "audio/mpeg"
        case "ogg", "opus":
            mimeType = "audio/ogg"
        default:
            mimeType = "application/octet-stream"
        }

        return (url, mimeType, nil)
    }

}

private struct DeepgramResponse: Decodable {
    let results: DeepgramResults
}

private struct DeepgramResults: Decodable {
    let channels: [DeepgramChannel]
}

private struct DeepgramChannel: Decodable {
    let alternatives: [DeepgramAlternative]
}

private struct DeepgramAlternative: Decodable {
    let transcript: String
}
