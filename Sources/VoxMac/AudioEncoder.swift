import Foundation
import VoxCore

/// Converts audio files to Opus format for efficient upload.
/// Uses `afconvert` (macOS built-in) which reliably produces compact Opus-in-CAF files.
/// AVAudioFile cannot write Opus to Ogg containers (ExtAudioFileWrite 'pck?' error)
/// and produces bloated CAF files (~240KB overhead from pre-allocated packet tables).
public enum AudioEncoder {
    /// Bitrate for Opus voice encoding (24 kbps — optimal for speech).
    static let opusBitrate = 24_000

    /// Converts CAF (PCM) to Opus in a CAF container via `afconvert`.
    /// - Parameters:
    ///   - inputURL: Source CAF file URL (PCM 16kHz mono expected)
    ///   - outputURL: Destination file URL (must have `.caf` extension)
    /// - Throws: VoxError if conversion fails
    public static func convertToOpus(inputURL: URL, outputURL: URL) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/afconvert")
        process.arguments = [
            inputURL.path,
            "-o", outputURL.path,
            "-f", "caff",
            "-d", "opus",
            "-b", "\(opusBitrate)",
        ]

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            process.terminationHandler = { proc in
                if proc.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: VoxError.internalError(
                        "Opus encoding failed (afconvert exit \(proc.terminationStatus))"
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

    /// Converts CAF to Opus with fallback.
    /// Returns the Opus URL on success, or the original CAF URL on failure.
    public static func encodeForUpload(cafURL: URL) async -> (url: URL, format: AudioFormat, bytes: Int) {
        let opusURL = cafURL.deletingPathExtension().appendingPathExtension("opus.caf")
        let cafAttributes = try? FileManager.default.attributesOfItem(atPath: cafURL.path)
        let cafSize = cafAttributes?[.size] as? Int ?? 0

        let startTime = CFAbsoluteTimeGetCurrent()
        do {
            try await convertToOpus(inputURL: cafURL, outputURL: opusURL)
            let encodeTime = CFAbsoluteTimeGetCurrent() - startTime
            let opusAttributes = try? FileManager.default.attributesOfItem(atPath: opusURL.path)
            let opusSize = opusAttributes?[.size] as? Int ?? 0
            guard opusSize > 0 else {
                throw VoxError.internalError("Opus conversion produced empty output")
            }
            let ratio = Double(opusSize) / Double(max(cafSize, 1))
            let pct = String(format: "%.0f", ratio * 100)
            print("[Encoder] Opus: \(String(format: "%.2f", encodeTime))s, \(pct)% of original")
            return (opusURL, .opus, opusSize)
        } catch {
            print("[Encoder] Opus failed: \(error.localizedDescription), using CAF fallback")
            SecureFileDeleter.delete(at: opusURL)
            return (cafURL, .caf, cafSize)
        }
    }
}

public enum AudioFormat: Sendable {
    case opus
    case caf

    public var mimeType: String {
        switch self {
        case .opus: return "audio/x-caf"
        case .caf: return "audio/x-caf"
        }
    }

    public var fileExtension: String {
        switch self {
        case .opus: return "caf"
        case .caf: return "caf"
        }
    }
}
