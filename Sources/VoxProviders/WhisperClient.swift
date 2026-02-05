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

        // Prepare audio file (convert CAF to WAV if needed)
        let (fileURL, mimeType, tempURL) = try await prepareAudioFile(for: audioURL)
        defer { if let t = tempURL { SecureFileDeleter.delete(at: t) } }

        let fileSize = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int) ?? 0
        let sizeMB = String(format: "%.1f", Double(fileSize) / 1_048_576)
        print("[Whisper] Transcribing \(sizeMB)MB audio (streaming)")

        // OpenAI Whisper API has a 25MB file size limit
        if fileSize > 25_000_000 {
            print("[Whisper] File size \(sizeMB)MB exceeds 25MB limit — skipping")
            throw STTError.unknown("File size \(sizeMB)MB exceeds Whisper 25MB limit")
        }

        // Build multipart form data as a temporary file for streaming upload
        let (multipartURL, multipartSize) = try await buildMultipartFile(
            audioURL: fileURL,
            mimeType: mimeType
        )
        defer { try? FileManager.default.removeItem(at: multipartURL) }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")

        let (data, response) = try await session.upload(for: request, fromFile: multipartURL)

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
        case "mp3":
            mimeType = "audio/mpeg"
        case "m4a", "mp4":
            mimeType = "audio/mp4"
        case "webm":
            mimeType = "audio/webm"
        default:
            mimeType = "application/octet-stream"
        }

        return (url, mimeType, nil)
    }

    /// Writes multipart form data to a temporary file and returns (fileURL, totalSize).
    private func buildMultipartFile(audioURL: URL, mimeType: String) async throws -> (URL, Int) {
        let tempDir = FileManager.default.temporaryDirectory
        let multipartURL = tempDir.appendingPathComponent("vox-whisper-\(UUID().uuidString).tmp")

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
            Content-Disposition: form-data; name=\"model\"\r\n\r\n\
            whisper-1\r\n\
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

private struct WhisperResponse: Decodable { let text: String }

private let boundary = "vox.boundary.\(UUID().uuidString)"
