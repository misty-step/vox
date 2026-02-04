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
                try AudioConverter.convertCAFToWAV(from: audioURL, to: t)
            } catch {
                throw STTError.invalidAudio
            }
            tempURL = t
            audioData = try Data(contentsOf: t)
        } else {
            audioData = try Data(contentsOf: audioURL)
        }

        var form = MultipartFormData()
        let ext = tempURL != nil ? "wav" : audioURL.pathExtension.lowercased()
        let mimeType = ext == "wav" ? "audio/wav" : "audio/x-caf"
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
        case 401: throw STTError.auth
        case 429: throw STTError.throttled
        default:
            throw STTError.unknown("HTTP \(httpResponse.statusCode)")
        }
    }
}

private struct WhisperResponse: Decodable { let text: String }
