import XCTest
@testable import VoxApp

final class HistoryStoreTests: XCTestCase {
    func testWritesTranscriptAndMetadata() async throws {
        let baseURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let store = HistoryStore(env: ["VOX_HISTORY": "1"], baseURL: baseURL)
        let sessionId = UUID()
        let startedAt = Date()
        let metadata = HistoryMetadata(
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

        let session = try XCTUnwrap(store.startSession(metadata: metadata))
        await session.recordTranscript("hello world")

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        let dayFolder = formatter.string(from: startedAt)

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
        let metadata = HistoryMetadata(
            sessionId: UUID(),
            startedAt: Date(),
            updatedAt: Date(),
            processingLevel: "light",
            locale: nil,
            sttModelId: nil,
            rewriteModelId: "gemini-3-flash-preview",
            maxOutputTokens: 65536,
            temperature: nil,
            thinkingLevel: nil,
            targetAppBundleId: nil,
            audioFileName: nil,
            audioFileSizeBytes: nil,
            transcriptLength: nil,
            rewriteLength: nil,
            finalLength: nil,
            rewriteRatio: nil,
            pasteSucceeded: nil,
            errors: []
        )

        XCTAssertNil(store.startSession(metadata: metadata))
    }
}
