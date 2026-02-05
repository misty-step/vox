import XCTest
@testable import VoxCore

final class TimeoutSTTProviderTests: XCTestCase {
    private let audioURL = URL(fileURLWithPath: "/tmp/audio.wav")

    func test_completesBeforeTimeout() async throws {
        let mock = MockSTTProvider(results: [.success("done")])
        let provider = TimeoutSTTProvider(provider: mock, timeout: 5.0)

        let result = try await provider.transcribe(audioURL: audioURL)

        XCTAssertEqual(result, "done")
    }

    func test_throwsOnTimeout() async {
        let slow = SlowSTTProvider(delay: 10.0)
        let provider = TimeoutSTTProvider(provider: slow, timeout: 0.1)

        do {
            _ = try await provider.transcribe(audioURL: audioURL)
            XCTFail("Expected timeout error")
        } catch let error as STTError {
            if case .network(let msg) = error {
                XCTAssertTrue(msg.contains("timed out"))
            } else {
                XCTFail("Expected network timeout error, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func test_propagatesFastErrors() async {
        let mock = MockSTTProvider(results: [.failure(STTError.auth)])
        let provider = TimeoutSTTProvider(provider: mock, timeout: 5.0)

        do {
            _ = try await provider.transcribe(audioURL: audioURL)
            XCTFail("Expected auth error")
        } catch let error as STTError {
            XCTAssertEqual(error, .auth)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Dynamic timeout tests

    func test_dynamicTimeout_scalesWithFileSize() async throws {
        // Create a 10MB temp file
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")
        let tenMB = Data(count: 10_485_760)
        try tenMB.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        // baseTimeout=30, secondsPerMB=2 → 30 + 10*2 = 50s
        let mock = MockSTTProvider(results: [.success("done")])
        let provider = TimeoutSTTProvider(provider: mock, baseTimeout: 30, secondsPerMB: 2)

        let result = try await provider.transcribe(audioURL: tempURL)
        XCTAssertEqual(result, "done")
    }

    func test_dynamicTimeout_smallFile_usesBaseTimeout() async {
        // Create a tiny file (< 1KB)
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")
        try? Data(count: 100).write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        // baseTimeout=0.05s, secondsPerMB=2 → ~0.05s for tiny file
        // SlowSTTProvider taking 1s should timeout
        let slow = SlowSTTProvider(delay: 1.0)
        let provider = TimeoutSTTProvider(provider: slow, baseTimeout: 0.05, secondsPerMB: 2)

        do {
            _ = try await provider.transcribe(audioURL: tempURL)
            XCTFail("Expected timeout")
        } catch let error as STTError {
            if case .network(let msg) = error {
                XCTAssertTrue(msg.contains("timed out"))
            } else {
                XCTFail("Expected network timeout, got \(error)")
            }
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func test_dynamicTimeout_largeFile_getsMoreTime() async throws {
        // Create a 5MB file
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("wav")
        try Data(count: 5_242_880).write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }

        // baseTimeout=0.05, secondsPerMB=0.1 → 0.05 + 5*0.1 = 0.55s
        // SlowSTTProvider at 0.3s should succeed within 0.55s budget
        let slow = SlowSTTProvider(delay: 0.3)
        let provider = TimeoutSTTProvider(provider: slow, baseTimeout: 0.05, secondsPerMB: 0.1)

        let result = try await provider.transcribe(audioURL: tempURL)
        XCTAssertEqual(result, "slow")
    }

    func test_dynamicTimeout_missingFile_usesBaseTimeout() async {
        let missing = URL(fileURLWithPath: "/tmp/nonexistent_\(UUID().uuidString).wav")
        let mock = MockSTTProvider(results: [.success("ok")])
        let provider = TimeoutSTTProvider(provider: mock, baseTimeout: 5, secondsPerMB: 2)

        // Missing file → fileSize=0 → timeout=max(5, 5+0)=5s → should still work
        let result = try? await provider.transcribe(audioURL: missing)
        XCTAssertEqual(result, "ok")
    }
}

private final class SlowSTTProvider: STTProvider {
    let delay: TimeInterval

    init(delay: TimeInterval) {
        self.delay = delay
    }

    func transcribe(audioURL: URL) async throws -> String {
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        return "slow"
    }
}
