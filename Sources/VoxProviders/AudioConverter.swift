import Foundation

public enum AudioConversionError: Error, LocalizedError {
    case launchFailed(underlying: Error)
    case conversionFailed(exitCode: Int32, stderr: String? = nil)
    case converterUnavailable(reason: String)
    case emptyOutput

    public var errorDescription: String? {
        switch self {
        case .launchFailed(let underlying):
            return "Audio conversion failed to launch: \(underlying.localizedDescription)"
        case .conversionFailed(let exitCode, let stderr):
            if let stderr {
                return "Audio conversion failed (exit \(exitCode)): \(stderr)"
            }
            return "Audio conversion failed (exit \(exitCode))"
        case .converterUnavailable(let reason):
            return "Audio converter unavailable: \(reason)"
        case .emptyOutput:
            return "Audio conversion produced empty output"
        }
    }
}

public enum AudioConverter {
    public static let conversionExecutable = "/usr/bin/afconvert"
    public static var conversionExecutableName: String {
        URL(fileURLWithPath: conversionExecutable).lastPathComponent
    }

    public static func opusConversionAvailability() async -> (isAvailable: Bool, unavailableReason: String?) {
        switch await cachedOpusConversionAvailability() {
        case .available:
            return (isAvailable: true, unavailableReason: nil)
        case .unavailable(let reason):
            return (isAvailable: false, unavailableReason: reason)
        case .unknown:
            return (isAvailable: false, unavailableReason: "Opus conversion availability unknown")
        }
    }

    private enum OpusConversionAvailability {
        case unknown
        case available
        case unavailable(reason: String)
    }

    private static let opusBitrate = 32_000
    private static let errorPreviewLimit = 500
    private static let availabilityState = OpusConversionAvailabilityState()

    public static func convertCAFToOpus(from inputURL: URL) async throws -> URL {
        try await assertOpusConversionAvailable()
        let outputURL = temporaryOutputURL(prefix: "vox-opus", extension: "ogg")
        let arguments = [
            inputURL.path,
            "-o", outputURL.path,
            "-f", "OggS",
            "-d", "opus",
            "-b", "\(opusBitrate)",
        ]
        return try await runConversion(arguments: arguments, outputURL: outputURL)
    }

    public static func convertCAFToWAV(from inputURL: URL) async throws -> URL {
        let outputURL = temporaryOutputURL(prefix: "vox-wav", extension: "wav")
        let arguments = [
            inputURL.path,
            "-o", outputURL.path,
            "-f", "WAVE",
            "-d", "LEI16",
        ]
        return try await runConversion(arguments: arguments, outputURL: outputURL)
    }

    private static let processTimeout: TimeInterval = 30

    public static func isOpusConversionAvailable() async -> Bool {
        switch await cachedOpusConversionAvailability() {
        case .available:
            return true
        case .unavailable, .unknown:
            return false
        }
    }

    private static func assertOpusConversionAvailable() async throws {
        switch await cachedOpusConversionAvailability() {
        case .available:
            return
        case .unavailable(let reason):
            throw AudioConversionError.converterUnavailable(reason: reason)
        case .unknown:
            throw AudioConversionError.converterUnavailable(reason: "Opus conversion availability unknown")
        }
    }

    private static func cachedOpusConversionAvailability() async -> OpusConversionAvailability {
        let current = await availabilityState.currentAvailability()
        switch current {
        case .available, .unavailable:
            return current
        case .unknown:
            let task = await availabilityState.startLookupIfNeeded(using: conversionExecutable)
            let discovered = await task.value

            if let reason = await availabilityState.finishLookupIfNeeded(with: discovered) {
                #if DEBUG
                print("[AudioConverter] Opus unavailable: \(reason)")
                #endif
            }
            return await availabilityState.currentAvailability()
        }
    }

    private static func probeOpusConversionAvailability(using executable: String) async -> OpusConversionAvailability {
        guard FileManager.default.fileExists(atPath: executable) else {
            return .unavailable(reason: "afconvert executable missing: \(executable)")
        }
        guard FileManager.default.isExecutableFile(atPath: executable) else {
            return .unavailable(reason: "afconvert is not executable: \(executable)")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = ["-h"]
        let stderrPipe = Pipe()
        process.standardError = stderrPipe
        process.standardOutput = stderrPipe

        return await withCheckedContinuation { continuation in
            process.terminationHandler = { proc in
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let stderr = String(data: stderrData, encoding: .utf8) ?? ""
                if proc.terminationStatus != 0 {
                    continuation.resume(returning: .unavailable(reason: "afconvert --help failed: exit \(proc.terminationStatus)"))
                } else if !stderr.lowercased().contains("opus") {
                    continuation.resume(returning: .unavailable(reason: "afconvert does not report opus support"))
                } else {
                    continuation.resume(returning: .available)
                }
            }
            do {
                try process.run()
            } catch {
                continuation.resume(returning: .unavailable(reason: "afconvert failed to launch: \(error.localizedDescription)"))
            }
        }
    }

    private static func runConversion(arguments: [String], outputURL: URL) async throws -> URL {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: conversionExecutable)
        process.arguments = arguments
        process.standardOutput = FileHandle.nullDevice

        let stderrPipe = Pipe()
        process.standardError = stderrPipe

        do {
            try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    process.terminationHandler = { proc in
                        if proc.terminationStatus == 0 {
                            continuation.resume()
                        } else {
                            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                            let stderr = String(data: stderrData, encoding: .utf8)?
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                            let preview = sanitizedPreview(stderr, limit: errorPreviewLimit)
                            if let preview, !preview.isEmpty {
                                #if DEBUG
                                print("[AudioConverter] \(conversionExecutableName) stderr: \(preview)")
                                #endif
                            }
                            continuation.resume(
                                throwing: AudioConversionError.conversionFailed(
                                    exitCode: proc.terminationStatus,
                                    stderr: preview
                                )
                            )
                        }
                    }
                    do {
                        try process.run()
                        // Enforce process timeout
                        DispatchQueue.global().asyncAfter(deadline: .now() + processTimeout) {
                            if process.isRunning {
                                print("[AudioConverter] afconvert timed out after \(Int(processTimeout))s, killing")
                                process.terminate()
                            }
                        }
                    } catch {
                        continuation.resume(throwing: AudioConversionError.launchFailed(underlying: error))
                    }
                }
            } onCancel: {
                if process.isRunning {
                    process.terminate()
                }
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

    private static func temporaryOutputURL(prefix: String, extension ext: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)-\(UUID().uuidString)")
            .appendingPathExtension(ext)
    }

    private static func sanitizedPreview(_ value: String?, limit: Int) -> String? {
        guard
            let value,
            !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return nil
        }
        return String(value.prefix(limit))
    }

    private actor OpusConversionAvailabilityState {
        private var conversionAvailability: OpusConversionAvailability = .unknown
        private var lookupTask: Task<OpusConversionAvailability, Never>?
        private var didLogUnavailable = false

        func currentAvailability() -> OpusConversionAvailability {
            conversionAvailability
        }

        func startLookupIfNeeded(using executable: String) -> Task<OpusConversionAvailability, Never> {
            if let task = lookupTask {
                return task
            }
            let task = Task { await AudioConverter.probeOpusConversionAvailability(using: executable) }
            lookupTask = task
            return task
        }

        func finishLookupIfNeeded(with discovered: OpusConversionAvailability) -> String? {
            if case .unknown = conversionAvailability {
                conversionAvailability = discovered
            }
            lookupTask = nil
            if case .unavailable(let reason) = conversionAvailability,
               !didLogUnavailable {
                didLogUnavailable = true
                return reason
            }
            return nil
        }
    }
}
