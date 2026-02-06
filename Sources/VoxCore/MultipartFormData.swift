import Foundation

public struct MultipartFormData {
    public let boundary: String
    private var body = Data()

    public init(boundary: String = "vox.boundary.\(UUID().uuidString)") {
        self.boundary = boundary
    }

    public mutating func addField(name: String, value: String) {
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"\(name)\"\r\n\r\n")
        body.append("\(value)\r\n")
    }

    public mutating func addFile(name: String, filename: String, mimeType: String, data: Data) {
        body.append("--\(boundary)\r\n")
        body.append("Content-Disposition: form-data; name=\"\(name)\"; filename=\"\(filename)\"\r\n")
        body.append("Content-Type: \(mimeType)\r\n\r\n")
        body.append(data)
        body.append("\r\n")
    }

    public mutating func finalize() -> Data {
        body.append("--\(boundary)--\r\n")
        return body
    }
}

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}

// MARK: - File-Based Streaming Multipart Builder

/// Builds multipart form data as a temporary file for streaming upload.
/// This allows URLSession to stream from disk instead of loading everything into memory.
public enum MultipartFileBuilder {
    /// Writes multipart form data to a temporary file and returns (fileURL, totalSize).
    /// - Parameters:
    ///   - audioURL: URL of the audio file to include
    ///   - mimeType: MIME type of the audio file
    ///   - boundary: The multipart boundary string
    ///   - additionalFields: Additional form fields to include (name, value pairs)
    /// - Returns: Tuple of (temporary file URL, total size in bytes)
    public static func build(
        audioURL: URL,
        mimeType: String,
        boundary: String,
        additionalFields: [(name: String, value: String)] = []
    ) throws -> (URL, Int) {
        let tempDir = FileManager.default.temporaryDirectory
        let multipartURL = tempDir.appendingPathComponent("vox-multipart-\(UUID().uuidString).tmp")

        let filename = "audio.\(audioURL.pathExtension)"
        let audioFileHandle = try FileHandle(forReadingFrom: audioURL)
        defer { audioFileHandle.closeFile() }

        // Build preamble with file field
        var preamble = """
            --\(boundary)\r\n\
            Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n\
            Content-Type: \(mimeType)\r\n\r\n
            """

        // Add additional fields
        for field in additionalFields {
            preamble += """

                --\(boundary)\r\n\
                Content-Disposition: form-data; name=\"\(field.name)\"\r\n\r\n\
                \(field.value)\r\n
                """
        }

        let postamble = "\n--\(boundary)--\r\n"

        guard let preambleData = preamble.data(using: .utf8),
              let postambleData = postamble.data(using: .utf8) else {
            throw VoxError.internalError("Failed to encode multipart data")
        }

        // Write preamble + audio file + postamble to temp file
        FileManager.default.createFile(atPath: multipartURL.path, contents: nil)
        let handle = try FileHandle(forWritingTo: multipartURL)

        handle.write(preambleData)

        // Stream audio file in chunks to avoid loading into memory
        let chunkSize = 64 * 1024  // 64KB chunks
        var chunk = audioFileHandle.readData(ofLength: chunkSize)
        while !chunk.isEmpty {
            handle.write(chunk)
            chunk = audioFileHandle.readData(ofLength: chunkSize)
        }

        handle.write(postambleData)
        try handle.close()

        // Get total size
        let attributes = try FileManager.default.attributesOfItem(atPath: multipartURL.path)
        let totalSize = attributes[.size] as? Int ?? 0

        return (multipartURL, totalSize)
    }
}
