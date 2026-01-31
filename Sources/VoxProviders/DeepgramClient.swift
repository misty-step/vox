import AVFoundation
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
        let payload = try prepareAudioFile(for: audioURL)
        defer {
            if let tempURL = payload.tempURL {
                try? FileManager.default.removeItem(at: tempURL)
            }
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue(payload.mimeType, forHTTPHeaderField: "Content-Type")

        let (data, response) = try await session.upload(for: request, fromFile: payload.fileURL)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw STTError.network("Invalid response")
        }

        switch httpResponse.statusCode {
        case 200:
            let result = try JSONDecoder().decode(DeepgramResponse.self, from: data)
            return result.results.channels.first?.alternatives.first?.transcript ?? ""
        case 400: throw STTError.invalidAudio
        case 401: throw STTError.auth
        case 402, 403: throw STTError.quotaExceeded
        case 429: throw STTError.throttled
        default:
            throw STTError.unknown("HTTP \(httpResponse.statusCode)")
        }
    }

    private func prepareAudioFile(for url: URL) throws -> (fileURL: URL, mimeType: String, tempURL: URL?) {
        if url.pathExtension.lowercased() == "caf" {
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("wav")

            try convertCAFToWAV(from: url, to: tempURL)
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
        default:
            mimeType = "application/octet-stream"
        }

        return (url, mimeType, nil)
    }

    private func convertCAFToWAV(from inputURL: URL, to outputURL: URL) throws {
        // Use macOS built-in afconvert for reliable format conversion
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/afconvert")
        process.arguments = [
            inputURL.path,
            "-o", outputURL.path,
            "-f", "WAVE",  // WAV format
            "-d", "LEI16"  // Little-endian 16-bit integer
        ]

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw STTError.invalidAudio
        }
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
