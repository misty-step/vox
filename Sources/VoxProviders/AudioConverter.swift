import Foundation

public enum AudioConversionError: Error, LocalizedError {
    case launchFailed(underlying: Error)
    case conversionFailed(exitCode: Int32)
    case emptyOutput

    public var errorDescription: String? {
        switch self {
        case .launchFailed(let underlying):
            return "Audio conversion failed to launch: \(underlying.localizedDescription)"
        case .conversionFailed(let exitCode):
            return "Audio conversion failed (exit \(exitCode))"
        case .emptyOutput:
            return "Audio conversion produced empty output"
        }
    }
}

public enum AudioConverter {
    private static let opusBitrate = 32_000

    public static func convertCAFToOpus(from inputURL: URL) async throws -> URL {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("vox-opus-\(UUID().uuidString)")
            .appendingPathExtension("ogg")

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/afconvert")
        process.arguments = [
            inputURL.path,
            "-o", outputURL.path,
            "-f", "OggS",
            "-d", "opus",
            "-b", "\(opusBitrate)",
        ]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    process.terminationHandler = { proc in
                        if proc.terminationStatus == 0 {
                            continuation.resume()
                        } else {
                            continuation.resume(
                                throwing: AudioConversionError.conversionFailed(exitCode: proc.terminationStatus)
                            )
                        }
                    }
                    do {
                        try process.run()
                    } catch {
                        continuation.resume(throwing: AudioConversionError.launchFailed(underlying: error))
                    }
                }
            } onCancel: {
                process.terminate()
            }

            let attrs = try FileManager.default.attributesOfItem(atPath: outputURL.path)
            let size = attrs[.size] as? Int ?? 0
            guard size > 0 else {
                throw AudioConversionError.emptyOutput
            }
            return outputURL
        } catch {
            try? FileManager.default.removeItem(at: outputURL)
            throw error
        }
    }
}
