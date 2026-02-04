import Foundation

enum AudioConverter {
    static func convertCAFToWAV(from inputURL: URL, to outputURL: URL) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/afconvert")
        process.arguments = [
            inputURL.path,
            "-o", outputURL.path,
            "-f", "WAVE",
            "-d", "LEI16"
        ]

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            process.terminationHandler = { proc in
                if proc.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: NSError(
                        domain: "AudioConverter", code: Int(proc.terminationStatus),
                        userInfo: [NSLocalizedDescriptionKey: "Audio conversion failed (exit \(proc.terminationStatus))"]
                    ))
                }
            }
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
