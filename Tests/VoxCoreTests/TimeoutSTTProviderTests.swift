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
