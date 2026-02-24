import Foundation
import VoxCore
import VoxProviders

enum DiagnosticsValue: Codable, Sendable, Equatable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Bool.self) {
            self = .bool(value)
            return
        }
        if let value = try? container.decode(Int.self) {
            self = .int(value)
            return
        }
        if let value = try? container.decode(Double.self) {
            self = .double(value)
            return
        }
        self = .string(try container.decode(String.self))
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value):
            try container.encode(value)
        case .int(let value):
            try container.encode(value)
        case .double(let value):
            try container.encode(value)
        case .bool(let value):
            try container.encode(value)
        }
    }
}

struct DiagnosticsEvent: Codable, Sendable, Equatable {
    let timestamp: String
    let name: String
    let sessionID: String?
    let fields: [String: DiagnosticsValue]
}

struct DiagnosticsContext: Codable, Sendable, Equatable {
    struct KeysPresent: Codable, Sendable, Equatable {
        let elevenLabs: Bool
        let deepgram: Bool
        let gemini: Bool
        let openRouter: Bool
    }

    @MainActor
    private static let exportFormatter = ISO8601DateFormatter()

    let exportedAt: String
    let appVersion: String
    let appBuild: String
    let osVersion: String
    let processingLevel: String
    let selectedInputDeviceConfigured: Bool

    let sttRouting: String
    let streamingAllowed: Bool
    let audioBackend: String
    let maxConcurrentSTT: Int

    let keysPresent: KeysPresent

    @MainActor
    static func current(
        prefs: PreferencesReading? = nil,
        productInfo: ProductInfo = .current(),
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> DiagnosticsContext {
        let prefs = prefs ?? PreferencesStore.shared
        func configured(_ value: String) -> Bool {
            !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        func flag(_ key: String) -> String {
            environment[key]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }

        let routing = flag("VOX_STT_ROUTING").lowercased() == "hedged" ? "hedged" : "sequential"
        let streamingDisabled = ["1", "true", "yes"].contains(flag("VOX_DISABLE_STREAMING_STT").lowercased())
        let streamingAllowed = !streamingDisabled
        let audioBackend = flag("VOX_AUDIO_BACKEND").lowercased() == "recorder" ? "recorder" : "engine"
        let maxConcurrent = Int(flag("VOX_MAX_CONCURRENT_STT")) ?? 8

        return DiagnosticsContext(
            exportedAt: exportFormatter.string(from: Date()),
            appVersion: productInfo.version,
            appBuild: productInfo.build,
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            processingLevel: prefs.processingLevel.rawValue,
            selectedInputDeviceConfigured: prefs.selectedInputDeviceUID != nil,
            sttRouting: routing,
            streamingAllowed: streamingAllowed,
            audioBackend: audioBackend,
            maxConcurrentSTT: maxConcurrent,
            keysPresent: KeysPresent(
                elevenLabs: configured(prefs.elevenLabsAPIKey),
                deepgram: configured(prefs.deepgramAPIKey),
                gemini: configured(prefs.geminiAPIKey),
                openRouter: configured(prefs.openRouterAPIKey)
            )
        )
    }
}

actor DiagnosticsStore {
    static let shared = DiagnosticsStore()

    private let fm: FileManager
    private let directoryURL: URL?
    private let maxRotatedFiles: Int
    private let maxFileBytes: Int
    private let encoder: JSONEncoder
    private let isoFormatter: ISO8601DateFormatter
    private var hasCreatedDirectory: Bool = false
    private var currentFileHandle: FileHandle?
    private var currentFileHandleURL: URL?

    private let currentFileName = "diagnostics-current.jsonl"

    init(
        directoryURL: URL? = nil,
        maxFileBytes: Int = 512 * 1024,
        maxRotatedFiles: Int = 4
    ) {
        let fm = FileManager.default
        self.fm = fm
        if let directoryURL {
            self.directoryURL = directoryURL
        } else {
            let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            let appName = Bundle.main.bundleIdentifier?.components(separatedBy: ".").last ?? "Vox"
            self.directoryURL = support?.appendingPathComponent("\(appName)/Diagnostics", isDirectory: true)
        }
        self.maxRotatedFiles = max(0, maxRotatedFiles)
        self.maxFileBytes = max(1, maxFileBytes)
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.withoutEscapingSlashes]
        self.isoFormatter = ISO8601DateFormatter()
    }

    func record(name: String, sessionID: String? = nil, fields: [String: DiagnosticsValue] = [:]) {
        let timestamp = isoFormatter.string(from: Date())
        record(DiagnosticsEvent(timestamp: timestamp, name: name, sessionID: sessionID, fields: fields))
    }

    func record(_ event: DiagnosticsEvent) {
        guard let directoryURL else { return }
        do {
            try ensureDirectoryExists(directoryURL)
            try rotateIfNeeded(in: directoryURL)
            let fileURL = directoryURL.appendingPathComponent(currentFileName)
            try append(event, to: fileURL)
            if event.name == DiagnosticsEventNames.pipelineTiming {
                PerformanceIngestClient.recordAsync(event)
            }
        } catch {
            #if DEBUG
            print("[Vox] Diagnostics record failed: \(error)")
            #endif
        }
    }

    func exportZip(to destinationURL: URL, context: DiagnosticsContext) async throws {
        guard let directoryURL else {
            throw VoxError.internalError("Diagnostics directory unavailable")
        }

        closeCurrentHandle()

        let tmpRoot = fm.temporaryDirectory.appendingPathComponent("vox-diagnostics-\(UUID().uuidString)")
        let bundleDir = tmpRoot.appendingPathComponent("VoxDiagnostics", isDirectory: true)
        try fm.createDirectory(at: bundleDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: tmpRoot) }

        let contextURL = bundleDir.appendingPathComponent("context.json")
        try encoder.encode(context).write(to: contextURL, options: [.atomic])

        let logFiles = (try? latestLogFiles(in: directoryURL)) ?? []
        for file in logFiles {
            let dest = bundleDir.appendingPathComponent(file.lastPathComponent)
            try? fm.removeItem(at: dest)
            try fm.copyItem(at: file, to: dest)
        }

        try await zipDirectory(bundleDir, to: destinationURL)
    }

    // MARK: - Files

    private func ensureDirectoryExists(_ directoryURL: URL) throws {
        if hasCreatedDirectory, fm.fileExists(atPath: directoryURL.path) {
            return
        }
        try fm.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        hasCreatedDirectory = true
    }

    private func closeCurrentHandle() {
        if let handle = currentFileHandle {
            try? handle.close()
        }
        currentFileHandle = nil
        currentFileHandleURL = nil
    }

    private func writableHandle(for fileURL: URL) throws -> FileHandle {
        if currentFileHandleURL != fileURL {
            closeCurrentHandle()
        }

        if let handle = currentFileHandle {
            return handle
        }

        if !fm.fileExists(atPath: fileURL.path) {
            fm.createFile(atPath: fileURL.path, contents: nil)
        }
        let handle = try FileHandle(forWritingTo: fileURL)
        do {
            try handle.seekToEnd()
        } catch {
            try? handle.close()
            throw error
        }
        currentFileHandle = handle
        currentFileHandleURL = fileURL
        return handle
    }

    private func append(_ event: DiagnosticsEvent, to fileURL: URL) throws {
        let data = try encoder.encode(event) + Data([0x0A])
        let handle = try writableHandle(for: fileURL)
        do {
            try handle.write(contentsOf: data)
        } catch {
            closeCurrentHandle()
            throw error
        }
    }

    private func rotateIfNeeded(in directoryURL: URL) throws {
        let fileURL = directoryURL.appendingPathComponent(currentFileName)
        let attrs = try? fm.attributesOfItem(atPath: fileURL.path)
        let size = attrs?[.size] as? Int ?? 0
        guard size >= maxFileBytes, fm.fileExists(atPath: fileURL.path) else { return }

        closeCurrentHandle()

        let ts = isoFormatter.string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
        let rotated = directoryURL.appendingPathComponent("diagnostics-\(ts)-\(UUID().uuidString.prefix(8)).jsonl")
        try fm.moveItem(at: fileURL, to: rotated)

        try pruneRotatedFiles(in: directoryURL)
    }

    private func pruneRotatedFiles(in directoryURL: URL) throws {
        guard maxRotatedFiles > 0 else {
            try deleteAllRotatedFiles(in: directoryURL)
            return
        }

        let rotated = try rotatedLogFiles(in: directoryURL)
        guard rotated.count > maxRotatedFiles else { return }

        for url in rotated.dropFirst(maxRotatedFiles) {
            try? fm.removeItem(at: url)
        }
    }

    private func deleteAllRotatedFiles(in directoryURL: URL) throws {
        for url in try rotatedLogFiles(in: directoryURL) {
            try? fm.removeItem(at: url)
        }
    }

    private func rotatedLogFiles(in directoryURL: URL) throws -> [URL] {
        guard fm.fileExists(atPath: directoryURL.path) else { return [] }
        let urls = try fm.contentsOfDirectory(at: directoryURL, includingPropertiesForKeys: [.creationDateKey])
        let rotated = urls.filter { url in
            url.pathExtension.lowercased() == "jsonl"
                && url.lastPathComponent.hasPrefix("diagnostics-")
                && url.lastPathComponent != currentFileName
        }
        return rotated.sorted { lhs, rhs in
            (lhs.creationDate ?? .distantPast) > (rhs.creationDate ?? .distantPast)
        }
    }

    private func latestLogFiles(in directoryURL: URL) throws -> [URL] {
        var files: [URL] = []
        let current = directoryURL.appendingPathComponent(currentFileName)
        if fm.fileExists(atPath: current.path) {
            files.append(current)
        }
        files.append(contentsOf: try rotatedLogFiles(in: directoryURL))
        return files
    }

    private func zipDirectory(_ sourceDir: URL, to destinationURL: URL) async throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        process.arguments = [
            "-c",
            "-k",
            "--sequesterRsrc",
            "--keepParent",
            sourceDir.path,
            destinationURL.path,
        ]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            process.terminationHandler = { proc in
                if proc.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: VoxError.internalError(
                        "Diagnostics export failed (ditto exit \(proc.terminationStatus))"
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

private extension URL {
    var creationDate: Date? {
        (try? resourceValues(forKeys: [.creationDateKey]))?.creationDate
    }
}

extension DiagnosticsStore {
    nonisolated static func recordAsync(
        name: String,
        sessionID: String? = nil,
        fields: [String: DiagnosticsValue] = [:]
    ) {
        Task {
            await shared.record(name: name, sessionID: sessionID, fields: fields)
        }
    }

    nonisolated static func errorFields(
        for error: Error,
        additional: [String: DiagnosticsValue] = [:]
    ) -> [String: DiagnosticsValue] {
        var fields = additional
        fields["error_code"] = .string(errorCode(for: error))
        fields["error_type"] = .string(String(describing: type(of: error)))
        if let audioConversionError = error as? AudioConversionError {
            for (key, value) in audioConversionError.diagnosticsPayload {
                fields[key] = value
            }
        }
        return fields
    }

    nonisolated static func errorCode(for error: Error) -> String {
        if let err = error as? STTError {
            return "stt.\(err.diagnosticsCode)"
        }
        if let err = error as? StreamingSTTError {
            return "streaming.\(err.diagnosticsCode)"
        }
        if let err = error as? RewriteError {
            return "rewrite.\(err.diagnosticsCode)"
        }
        if let err = error as? VoxError {
            return "vox.\(err.diagnosticsCode)"
        }
        if let err = error as? AudioConversionError {
            return "audio_conversion.\(err.diagnosticsCode)"
        }
        return String(describing: type(of: error))
    }
}

private extension STTError {
    var diagnosticsCode: String {
        switch self {
        case .auth: return "auth"
        case .quotaExceeded: return "quota_exceeded"
        case .throttled: return "throttled"
        case .sessionLimit: return "session_limit"
        case .invalidAudio: return "invalid_audio"
        case .network: return "network"
        case .unknown: return "unknown"
        }
    }
}

private extension StreamingSTTError {
    var diagnosticsCode: String {
        switch self {
        case .connectionFailed: return "connection_failed"
        case .sendFailed: return "send_failed"
        case .receiveFailed: return "receive_failed"
        case .provider: return "provider"
        case .finalizationTimeout: return "finalization_timeout"
        case .cancelled: return "cancelled"
        case .invalidState: return "invalid_state"
        }
    }
}

private extension RewriteError {
    var diagnosticsCode: String {
        switch self {
        case .auth: return "auth"
        case .quotaExceeded: return "quota_exceeded"
        case .throttled: return "throttled"
        case .invalidRequest: return "invalid_request"
        case .network: return "network"
        case .timeout: return "timeout"
        case .unknown: return "unknown"
        }
    }
}

private extension VoxError {
    var diagnosticsCode: String {
        switch self {
        case .permissionDenied: return "permission_denied"
        case .noFocusedElement: return "no_focused_element"
        case .noTranscript: return "no_transcript"
        case .emptyCapture: return "empty_capture"
        case .audioCaptureFailed: return "audio_capture_failed"
        case .insertionFailed: return "insertion_failed"
        case .provider: return "provider"
        case .internalError: return "internal_error"
        case .pipelineTimeout: return "pipeline_timeout"
        }
    }
}

private extension AudioConversionError {
    var diagnosticsCode: String {
        switch self {
        case .launchFailed:
            return "launch_failed"
        case .conversionFailed:
            return "conversion_failed"
        case .converterUnavailable:
            return "converter_unavailable"
        case .emptyOutput:
            return "empty_output"
        }
    }

    var diagnosticsPayload: [String: DiagnosticsValue] {
        switch self {
        case .launchFailed(let underlying):
            return ["launch_error": .string(underlying.localizedDescription)]
        case .conversionFailed(_, let stderr):
            var fields: [String: DiagnosticsValue] = [:]
            if let stderr {
                fields["conversion_stderr"] = .string(stderr)
            }
            return fields
        case .converterUnavailable(let reason):
            return ["converter_unavailable_reason": .string(reason)]
        case .emptyOutput:
            return ["conversion_output_empty": .bool(true)]
        }
    }
}
