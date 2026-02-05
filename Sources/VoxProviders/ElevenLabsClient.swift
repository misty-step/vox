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
        let (uploadFileURL, fileSize) = try await buildMultipartFile(audioURL: audioURL, mimeType: mimeType)
        defer {
            // Clean up temporary multipart file
            try? FileManager.default.removeItem(at: uploadFileURL)
        }

        let sizeMB = String(format: "%.1f", Double(fileSize) / 1_048_576)
        print("[ElevenLabs] Transcribing \(sizeMB)MB \(fileExt) (streaming)")

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "xi-api-key")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await session.upload(for: request, fromFile: uploadFileURL)

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

    /// Writes multipart form data to a temporary file and returns (fileURL, totalSize).
    /// This allows URLSession to stream from disk instead of loading everything into memory.
    private func buildMultipartFile(audioURL: URL, mimeType: String) async throws -> (URL, Int) {
        let tempDir = FileManager.default.temporaryDirectory
        let multipartURL = tempDir.appendingPathComponent("vox-multipart-\(UUID().uuidString).tmp")

        let filename = "audio.\(audioURL.pathExtension)"
        let audioFileHandle = try FileHandle(forReadingFrom: audioURL)
        defer { audioFileHandle.closeFile() }

        // Build multipart body parts
        let preamble = """
            --\(boundary)\r\n\
            Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n\
            Content-Type: \(mimeType)\r\n\r\n
            """.data(using: .utf8)!

        let postamble = """

            --\(boundary)\r\n\
            Content-Disposition: form-data; name=\"model_id\"\r\n\r\n\
            scribe_v2\r\n\
            --\(boundary)--\r\n
            """.data(using: .utf8)!

        // Write preamble + audio file + postamble to temp file
        FileManager.default.createFile(atPath: multipartURL.path, contents: nil)
        let handle = try FileHandle(forWritingTo: multipartURL)

        handle.write(preamble)

        // Stream audio file in chunks to avoid loading into memory
        let chunkSize = 64 * 1024  // 64KB chunks
        while let chunk = audioFileHandle.readData(ofLength: chunkSize), !chunk.isEmpty {
            handle.write(chunk)
        }

        handle.write(postamble)
        try handle.close()

        // Get total size
        let attributes = try FileManager.default.attributesOfItem(atPath: multipartURL.path)
        let totalSize = attributes[.size] as? Int ?? 0

        return (multipartURL, totalSize)
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
