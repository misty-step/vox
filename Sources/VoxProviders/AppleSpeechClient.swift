import Foundation
import Speech
import VoxCore

public final class AppleSpeechClient: STTProvider {
    public init() {}

    public func transcribe(audioURL: URL) async throws -> String {
        let status = SFSpeechRecognizer.authorizationStatus()
        switch status {
        case .authorized:
            break
        case .denied, .restricted:
            print("[AppleSpeech] Authorization \(status == .denied ? "denied" : "restricted")")
            throw STTError.auth
        case .notDetermined:
            // Calling requestAuthorization on an unbundled binary (e.g. `swift run`)
            // crashes with TCC_CRASHING_DUE_TO_PRIVACY_VIOLATION. Guard against it.
            guard Bundle.main.object(forInfoDictionaryKey: "NSSpeechRecognitionUsageDescription") != nil else {
                print("[AppleSpeech] Cannot request authorization: NSSpeechRecognitionUsageDescription missing from bundle")
                throw STTError.auth
            }
            print("[AppleSpeech] Requesting speech recognition authorization")
            let granted = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { newStatus in
                    continuation.resume(returning: newStatus == .authorized)
                }
            }
            guard granted else {
                print("[AppleSpeech] Authorization request denied by user")
                throw STTError.auth
            }
        @unknown default:
            print("[AppleSpeech] Unknown authorization status: \(status.rawValue)")
            throw STTError.auth
        }
        print("[AppleSpeech] Transcribing \(audioURL.lastPathComponent)")

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
