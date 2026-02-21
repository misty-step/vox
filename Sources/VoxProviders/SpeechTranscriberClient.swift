import AVFoundation
import Speech
import VoxCore

/// macOS 26+ on-device STT using Apple's SpeechTranscriber + SpeechAnalyzer pipeline.
/// Availability-gated: only constructed when @available(macOS 26.0, *).
/// Falls back to AppleSpeechClient on older macOS (handled in VoxSession).
@available(macOS 26.0, *)
public final class SpeechTranscriberClient: STTProvider {
    public init() {}

    public func transcribe(audioURL: URL) async throws -> String {
        print("[SpeechTranscriber] Transcribing \(audioURL.lastPathComponent)")

        let audioFile: AVAudioFile
        do {
            audioFile = try AVAudioFile(forReading: audioURL)
        } catch {
            throw STTError.invalidAudio
        }

        let transcriber = SpeechTranscriber(locale: .current, preset: .transcription)
        let analyzer = SpeechAnalyzer(modules: [transcriber])

        // Feed audio through analyzer concurrently while collecting results.
        // analyzeSequence completes -> transcriber.results terminates.
        let analysisTask = Task {
            _ = try await analyzer.analyzeSequence(from: audioFile)
        }

        var parts: [String] = []
        do {
            for try await result in transcriber.results {
                let segment = String(result.text.characters)
                if !segment.isEmpty {
                    parts.append(segment)
                }
            }
        } catch is CancellationError {
            analysisTask.cancel()
            throw CancellationError()
        } catch {
            analysisTask.cancel()
            throw STTError.unknown(error.localizedDescription)
        }

        do {
            try await analysisTask.value
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            // Analysis error after results collection - map it
            throw STTError.unknown(error.localizedDescription)
        }

        let transcript = parts.joined(separator: " ").trimmingCharacters(in: .whitespaces)
        guard !transcript.isEmpty else {
            throw STTError.unknown("No speech detected")
        }
        return transcript
    }
}
