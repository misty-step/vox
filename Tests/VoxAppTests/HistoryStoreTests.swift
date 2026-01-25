import XCTest
@testable import VoxApp

final class HistoryStoreTests: XCTestCase {
    func testWritesTranscriptAndMetadata() async throws {
        let baseURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = HistoryStore(env: ["VOX_HISTORY": "1"], baseURL: baseURL)
        let sessionId = UUID()
        let startedAt = Date()
        let metadata = makeMetadata(sessionId: sessionId, startedAt: startedAt)

        let session = try XCTUnwrap(store.startSession(metadata: metadata))
        await session.recordTranscript("hello world")

        let dayFolder = dayFolder(for: startedAt)

        let sessionDir = baseURL
            .appendingPathComponent(dayFolder)
            .appendingPathComponent(sessionId.uuidString)

        let transcriptURL = sessionDir.appendingPathComponent("transcript.txt")
        let metadataURL = sessionDir.appendingPathComponent("metadata.json")

        XCTAssertTrue(FileManager.default.fileExists(atPath: transcriptURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: metadataURL.path))
    }

    func testDisabledHistoryReturnsNil() {
        let store = HistoryStore(env: ["VOX_HISTORY": "0"], baseURL: FileManager.default.temporaryDirectory)
        let metadata = makeMetadata()

        XCTAssertNil(store.startSession(metadata: metadata))
    }

    func testHistoryDisabledByDefault() {
        let store = HistoryStore(env: [:], baseURL: FileManager.default.temporaryDirectory)
        let metadata = makeMetadata()

        XCTAssertNil(store.startSession(metadata: metadata))
    }

    func testCleanupOldHistoryRemovesExpiredFolders() throws {
        let baseURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)

        let calendar = Calendar(identifier: .gregorian)
        let oldDate = calendar.date(byAdding: .day, value: -10, to: Date())!
        let keepDate = calendar.date(byAdding: .day, value: -1, to: Date())!
        let oldDir = baseURL.appendingPathComponent(dayFolder(for: oldDate))
        let keepDir = baseURL.appendingPathComponent(dayFolder(for: keepDate))
        try FileManager.default.createDirectory(at: oldDir, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: keepDir, withIntermediateDirectories: true)

        _ = HistoryStore(
            env: ["VOX_HISTORY": "1", "VOX_HISTORY_DAYS": "3"],
            baseURL: baseURL
        )

        XCTAssertFalse(FileManager.default.fileExists(atPath: oldDir.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: keepDir.path))
    }

    private func dayFolder(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func makeMetadata(sessionId: UUID = UUID(), startedAt: Date = Date()) -> HistoryMetadata {
        HistoryMetadata(
            sessionId: sessionId,
            startedAt: startedAt,
            updatedAt: startedAt,
            processingLevel: "light",
            locale: "en_US",
            sttModelId: "scribe_v2",
            rewriteModelId: "gemini-3-flash-preview",
            maxOutputTokens: 65536,
            temperature: 0.2,
            thinkingLevel: "high",
            targetAppBundleId: "com.example.app",
            audioFileName: "audio.caf",
            audioFileSizeBytes: 42,
            transcriptLength: nil,
            rewriteLength: nil,
            finalLength: nil,
            rewriteRatio: nil,
            pasteSucceeded: nil,
            errors: []
        )
    }
}
