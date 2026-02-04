import Foundation
import Speech
import VoxCore

public final class AppleSpeechClient: STTProvider {
    public init() {}

    public func transcribe(audioURL: URL) async throws -> String {
        let status = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        guard status == .authorized else {
            throw STTError.auth
        }

        guard let recognizer = SFSpeechRecognizer(locale: Locale.current)
                ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US")) else {
            throw STTError.unknown("Speech recognition unavailable")
        }

        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        return try await withCheckedThrowingContinuation { continuation in
            let guard_ = ContinuationGuard()
            recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    guard_.resumeOnce { continuation.resume(throwing: STTError.unknown(error.localizedDescription)) }
                    return
                }
                guard let result, result.isFinal else { return }
                guard_.resumeOnce { continuation.resume(returning: result.bestTranscription.formattedString) }
            }
        }
    }
}

/// Thread-safe one-shot guard for continuation resumption.
private final class ContinuationGuard: @unchecked Sendable {
    private var resumed = false
    private let lock = NSLock()

    func resumeOnce(_ body: () -> Void) {
        lock.lock()
        guard !resumed else { lock.unlock(); return }
        resumed = true
        lock.unlock()
        body()
    }
}
