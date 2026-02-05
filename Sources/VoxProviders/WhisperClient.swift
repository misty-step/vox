import Foundation
import VoxCore

public final class WhisperClient: STTProvider {
    private let apiKey: String
    private let session: URLSession

    public init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    public func transcribe(audioURL: URL) async throws -> String {
        let url = URL(string: "https://api.openai.com/v1/audio/transcriptions")!

        let audioData: Data
        var tempURL: URL?
        defer { if let t = tempURL { try? FileManager.default.removeItem(at: t) } }

        if audioURL.pathExtension.lowercased() == "caf" {
            let t = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("wav")
            do {
                try await AudioConverter.convertCAFToWAV(from: audioURL, to: t)
            } catch {
                throw STTError.invalidAudio
            }
            tempURL = t
            audioData = try Data(contentsOf: t)
        } else {
            audioData = try Data(contentsOf: audioURL)
        }

        let sizeMB = String(format: "%.1f", Double(audioData.count) / 1_048_576)
        print("[Whisper] Transcribing \(sizeMB)MB audio")

        // OpenAI Whisper API has a 25MB file size limit
        if audioData.count > 25_000_000 {
            print("[Whisper] File size \(sizeMB)MB exceeds 25MB limit — skipping")
            throw STTError.unknown("File size \(sizeMB)MB exceeds Whisper 25MB limit")
        }

        var form = MultipartFormData()
        let ext = tempURL != nil ? "wav" : audioURL.pathExtension.lowercased()
        let mimeType: String
        switch ext {
        case "wav": mimeType = "audio/wav"
        case "mp3": mimeType = "audio/mpeg"
        case "m4a", "mp4": mimeType = "audio/mp4"
        case "webm": mimeType = "audio/webm"
        default: mimeType = "application/octet-stream"
        }
        form.addFile(name: "file", filename: "audio.\(ext)", mimeType: mimeType, data: audioData)
        form.addField(name: "model", value: "whisper-1")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(form.boundary)", forHTTPHeaderField: "Content-Type")
        request.httpBody = form.finalize()

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw STTError.network("Invalid response")
        }

        switch httpResponse.statusCode {
        case 200:
            let result = try JSONDecoder().decode(WhisperResponse.self, from: data)
            return result.text
        case 400:
            let body = String(data: data.prefix(512), encoding: .utf8) ?? ""
            let excerpt = String(body.prefix(200)).replacingOccurrences(of: "\n", with: " ")
            print("[Whisper] Invalid audio (HTTP 400) — \(excerpt)")
            throw STTError.invalidAudio
        case 401:
            print("[Whisper] Auth failed (HTTP 401)")
            throw STTError.auth
        case 429:
            print("[Whisper] Rate limited (HTTP 429)")
            throw STTError.throttled
        default:
            let body = String(data: data.prefix(512), encoding: .utf8) ?? ""
            let excerpt = String(body.prefix(200)).replacingOccurrences(of: "\n", with: " ")
            print("[Whisper] Failed: HTTP \(httpResponse.statusCode) — \(excerpt)")
            throw STTError.unknown("HTTP \(httpResponse.statusCode): \(excerpt)")
        }
    }
}

private struct WhisperResponse: Decodable { let text: String }
