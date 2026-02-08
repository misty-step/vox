import Foundation
import XCTest
@testable import VoxCore

final class HealthAwareSTTProviderTests: XCTestCase {
    private let audioURL = URL(fileURLWithPath: "/tmp/audio.wav")

    func test_transcribe_routesToHealthierProviderAfterPrimaryDegrades() async throws {
        let primary = ScriptedSTTProvider(steps: [
            .failure(STTError.throttled),
            .success("primary"),
        ])
        let backup = ScriptedSTTProvider(steps: [
            .success("backup-1"),
            .success("backup-2"),
        ])
        let provider = HealthAwareSTTProvider(
            providers: [
                .init(name: "primary", provider: primary),
                .init(name: "backup", provider: backup),
            ],
            windowSize: 5
        )

        let first = try await provider.transcribe(audioURL: audioURL)
        let second = try await provider.transcribe(audioURL: audioURL)

        XCTAssertEqual(first, "backup-1")
        XCTAssertEqual(second, "backup-2")
        XCTAssertEqual(primary.callCount, 1)
        XCTAssertEqual(backup.callCount, 2)
    }

    func test_healthSnapshot_tracksSuccessRateLatencyAndErrorClasses() async throws {
        let solo = ScriptedSTTProvider(steps: [
            .success("ok", delay: 0.02),
            .failure(STTError.network("offline"), delay: 0.01),
        ])
        let provider = HealthAwareSTTProvider(
            providers: [.init(name: "solo", provider: solo)],
            windowSize: 10
        )

        _ = try await provider.transcribe(audioURL: audioURL)
        do {
            _ = try await provider.transcribe(audioURL: audioURL)
            XCTFail("Expected error")
        } catch let error as STTError {
            XCTAssertEqual(error, .network("offline"))
        } catch {
            XCTFail("Expected STTError, got \(error)")
        }

        let snapshot = await provider.healthSnapshot()
        let soloHealth = try XCTUnwrap(snapshot.first { $0.name == "solo" })
        XCTAssertEqual(soloHealth.sampleCount, 2)
        XCTAssertEqual(soloHealth.successRate, 0.5, accuracy: 0.001)
        XCTAssertEqual(soloHealth.transientFailures, 1)
        XCTAssertEqual(soloHealth.permanentFailures, 0)
        XCTAssertGreaterThan(soloHealth.averageLatency, 0)
    }

    func test_transcribe_keepsConfiguredOrderWhenCompetitorHasNoSamples() async throws {
        let primary = ScriptedSTTProvider(steps: [
            .success("primary-1", delay: 0.02),
            .success("primary-2"),
        ])
        let backup = ScriptedSTTProvider(steps: [
            .success("backup-1"),
        ])
        let provider = HealthAwareSTTProvider(
            providers: [
                .init(name: "primary", provider: primary),
                .init(name: "backup", provider: backup),
            ]
        )

        let first = try await provider.transcribe(audioURL: audioURL)
        let second = try await provider.transcribe(audioURL: audioURL)

        XCTAssertEqual(first, "primary-1")
        XCTAssertEqual(second, "primary-2")
        XCTAssertEqual(primary.callCount, 2)
        XCTAssertEqual(backup.callCount, 0)
    }

    func test_healthSnapshot_usesRollingWindow() async throws {
        let solo = ScriptedSTTProvider(steps: [
            .success("one"),
            .success("two"),
            .failure(STTError.throttled),
        ])
        let provider = HealthAwareSTTProvider(
            providers: [.init(name: "solo", provider: solo)],
            windowSize: 2
        )

        _ = try await provider.transcribe(audioURL: audioURL)
        _ = try await provider.transcribe(audioURL: audioURL)
        do {
            _ = try await provider.transcribe(audioURL: audioURL)
            XCTFail("Expected throttled")
        } catch let error as STTError {
            XCTAssertEqual(error, .throttled)
        } catch {
            XCTFail("Expected STTError, got \(error)")
        }

        let snapshot = await provider.healthSnapshot()
        let soloHealth = try XCTUnwrap(snapshot.first { $0.name == "solo" })
        XCTAssertEqual(soloHealth.sampleCount, 2)
        XCTAssertEqual(soloHealth.successRate, 0.5, accuracy: 0.001)
        XCTAssertEqual(soloHealth.transientFailures, 1)
    }

    func test_transcribe_invalidAudioDoesNotFallback() async {
        let primary = ScriptedSTTProvider(steps: [.failure(STTError.invalidAudio)])
        let backup = ScriptedSTTProvider(steps: [.success("backup")])
        let provider = HealthAwareSTTProvider(
            providers: [
                .init(name: "primary", provider: primary),
                .init(name: "backup", provider: backup),
            ]
        )

        do {
            _ = try await provider.transcribe(audioURL: audioURL)
            XCTFail("Expected invalidAudio")
        } catch let error as STTError {
            XCTAssertEqual(error, .invalidAudio)
        } catch {
            XCTFail("Expected STTError, got \(error)")
        }

        XCTAssertEqual(primary.callCount, 1)
        XCTAssertEqual(backup.callCount, 0)
    }

    func test_transcribe_cancellationPropagatesWithoutFallback() async {
        let primary = ScriptedSTTProvider(steps: [.failure(CancellationError())])
        let backup = ScriptedSTTProvider(steps: [.success("backup")])
        let provider = HealthAwareSTTProvider(
            providers: [
                .init(name: "primary", provider: primary),
                .init(name: "backup", provider: backup),
            ]
        )

        do {
            _ = try await provider.transcribe(audioURL: audioURL)
            XCTFail("Expected CancellationError")
        } catch is CancellationError {
            // Expected.
        } catch {
            XCTFail("Expected CancellationError, got \(error)")
        }

        XCTAssertEqual(primary.callCount, 1)
        XCTAssertEqual(backup.callCount, 0)
    }
}

private struct ScriptedStep {
    let delay: TimeInterval
    let result: Result<String, Error>

    static func success(_ text: String, delay: TimeInterval = 0) -> Self {
        Self(delay: delay, result: .success(text))
    }

    static func failure(_ error: Error, delay: TimeInterval = 0) -> Self {
        Self(delay: delay, result: .failure(error))
    }
}

private final class ScriptedSTTProvider: STTProvider, @unchecked Sendable {
    private let lock = NSLock()
    private var _callCount = 0
    private let steps: [ScriptedStep]

    var callCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return _callCount
    }

    init(steps: [ScriptedStep]) {
        self.steps = steps
    }

    func transcribe(audioURL: URL) async throws -> String {
        let step = nextStep()
        if step.delay > 0 {
            try await Task.sleep(nanoseconds: UInt64(step.delay * 1_000_000_000))
        }
        switch step.result {
        case .success(let text):
            return text
        case .failure(let error):
            throw error
        }
    }

    private func nextStep() -> ScriptedStep {
        lock.lock()
        defer { lock.unlock() }
        let index = _callCount
        _callCount += 1
        guard index < steps.count else {
            return .failure(STTError.unknown("No more scripted results"))
        }
        return steps[index]
    }
}
