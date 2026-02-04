import Foundation
import Speech
import VoxCore

public final class AppleSpeechClient: STTProvider {
    public init() {}

    public func transcribe(audioURL: URL) async throws -> String {
        guard let recognizer = SFSpeechRecognizer(locale: Locale.current)
                ?? SFSpeechRecognizer(locale: Locale(identifier: "en-US")) else {
            throw STTError.unknown("Speech recognition unavailable")
        }

        let request = SFSpeechURLRecognitionRequest(url: audioURL)
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }

        return try await withCheckedThrowingContinuation { continuation in
            var resumed = false
            recognizer.recognitionTask(with: request) { result, error in
                if let error {
                    if !resumed {
                        resumed = true
                        continuation.resume(throwing: STTError.unknown(error.localizedDescription))
                    }
                    return
                }
                guard let result, result.isFinal else { return }
                if !resumed {
                    resumed = true
                    continuation.resume(returning: result.bestTranscription.formattedString)
                }
            }
        }
    }
}
