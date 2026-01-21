import Foundation

struct HistoryMetadata: Codable {
    let sessionId: UUID
    let startedAt: Date
    var updatedAt: Date
    var processingLevel: String
    var locale: String?
    var sttModelId: String?
    var rewriteModelId: String?
    var maxOutputTokens: Int?
    var temperature: Double?
    var thinkingLevel: String?
    var targetAppBundleId: String?
    var audioFileName: String?
    var audioFileSizeBytes: Int?
    var transcriptLength: Int?
    var rewriteLength: Int?
    var finalLength: Int?
    var rewriteRatio: Double?
    var pasteSucceeded: Bool?
    var errors: [String]
}

actor HistorySession {
    private let directoryURL: URL
    private let redactText: Bool
    private var metadata: HistoryMetadata

    init(directoryURL: URL, redactText: Bool, metadata: HistoryMetadata) {
        self.directoryURL = directoryURL
        self.redactText = redactText
        self.metadata = metadata
    }

    func recordStart() {
        persistMetadata()
    }

    func recordAudioInfo(fileName: String, sizeBytes: Int?) {
        metadata.audioFileName = fileName
        metadata.audioFileSizeBytes = sizeBytes
        persistMetadata()
    }

    func recordTranscript(_ text: String) {
        writeText(text, fileName: "transcript.txt")
        metadata.transcriptLength = text.count
        persistMetadata()
    }

    func recordRewrite(_ text: String, ratio: Double) {
        writeText(text, fileName: "rewrite.txt")
        metadata.rewriteLength = text.count
        metadata.rewriteRatio = ratio
        persistMetadata()
    }

    func recordFinal(_ text: String) {
        writeText(text, fileName: "final.txt")
        metadata.finalLength = text.count
        persistMetadata()
    }

    func recordPaste(success: Bool, error: String? = nil) {
        metadata.pasteSucceeded = success
        if let error {
            metadata.errors.append(error)
        }
        persistMetadata()
    }

    func recordError(_ message: String) {
        metadata.errors.append(message)
        persistMetadata()
    }

    private func writeText(_ text: String, fileName: String) {
        let output = redactText ? "[REDACTED]" : text
        let url = directoryURL.appendingPathComponent(fileName)
        do {
            try Data(output.utf8).write(to: url, options: .atomic)
        } catch {
            Diagnostics.error("History write failed: \(String(describing: error))")
        }
    }

    private func persistMetadata() {
        metadata.updatedAt = Date()
        let url = directoryURL.appendingPathComponent("metadata.json")
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(metadata)
            try data.write(to: url, options: .atomic)
        } catch {
            Diagnostics.error("History metadata write failed: \(String(describing: error))")
        }
    }
}

final class HistoryStore {
    let baseURL: URL
    let isEnabled: Bool
    let redactText: Bool

    init(env: [String: String] = ProcessInfo.processInfo.environment, baseURL: URL? = nil) {
        let enabledValue = env["VOX_HISTORY"]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        self.isEnabled = enabledValue != "0" && enabledValue != "false"
        self.redactText = env["VOX_HISTORY_REDACT"] == "1"
        if let override = env["VOX_HISTORY_DIR"], !override.isEmpty {
            self.baseURL = URL(fileURLWithPath: override)
        } else if let baseURL {
            self.baseURL = baseURL
        } else {
            self.baseURL = Self.defaultBaseURL()
        }
    }

    func startSession(metadata: HistoryMetadata) -> HistorySession? {
        guard isEnabled else { return nil }
        let dayFolder = Self.dayFolder(from: metadata.startedAt)
        let sessionDir = baseURL
            .appendingPathComponent(dayFolder)
            .appendingPathComponent(metadata.sessionId.uuidString)
        do {
            try FileManager.default.createDirectory(at: sessionDir, withIntermediateDirectories: true)
            let session = HistorySession(directoryURL: sessionDir, redactText: redactText, metadata: metadata)
            Task { await session.recordStart() }
            return session
        } catch {
            Diagnostics.error("History directory create failed: \(String(describing: error))")
            return nil
        }
    }

    static func defaultBaseURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/Vox/history")
    }

    private static func dayFolder(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
