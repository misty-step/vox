@preconcurrency import AVFoundation
import Foundation
import VoxCore

/// Verifies that captured audio files contain at least one decodable frame.
/// This guards against regressions where recording writes container headers but no payload.
public enum CapturedAudioInspector {
    public static func ensureHasAudioFrames(at url: URL) throws {
        guard shouldValidate(url: url) else { return }
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        do {
            let file = try AVAudioFile(forReading: url)
            guard file.length > 0 else {
                throw VoxError.emptyCapture
            }
        } catch let error as VoxError {
            throw error
        } catch {
            throw VoxError.emptyCapture
        }
    }

    static func shouldValidate(url: URL) -> Bool {
        url.pathExtension.lowercased() == "caf"
    }
}
