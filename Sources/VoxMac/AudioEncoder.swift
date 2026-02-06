import AVFoundation
import Foundation
import VoxCore

/// Converts audio files to Opus format for efficient upload.
/// Opus at 48kbps provides excellent voice quality at ~8x smaller than CAF.
public enum AudioEncoder {
    /// Converts CAF (PCM) to Opus format.
    /// - Parameters:
    ///   - inputURL: Source CAF file URL
    ///   - outputURL: Destination Opus file URL (should end in .ogg for ElevenLabs compatibility)
    /// - Throws: VoxError if conversion fails
    public static func convertToOpus(inputURL: URL, outputURL: URL) async throws {
        let inputFile = try AVAudioFile(forReading: inputURL)
        guard let inputFormat = inputFile.processingFormat.standardized else {
            throw VoxError.internalError("Failed to get input audio format")
        }

        // Opus output format: 48kbps, mono, 48kHz (Opus native rate)
        let opusSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatOpus,
            AVSampleRateKey: 48000,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 48000  // 48 kbps - optimal for voice
        ]

        guard let outputFormat = AVAudioFormat(settings: opusSettings) else {
            throw VoxError.internalError("Failed to create Opus output format")
        }

        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            throw VoxError.internalError("Failed to create audio converter")
        }

        let outputFile = try AVAudioFile(forWriting: outputURL, settings: opusSettings)

        // Convert in chunks to handle large files efficiently
        let bufferSize = 4096  // frames
        let inputBuffer = AVAudioPCMBuffer(
            pcmFormat: inputFormat,
            frameCapacity: AVAudioFrameCount(bufferSize)
        )!

        while inputFile.framePosition < inputFile.length {
            try inputFile.read(into: inputBuffer)

            let status = try convertBuffer(
                inputBuffer: inputBuffer,
                converter: converter,
                outputFormat: outputFormat
            )

            if let outputBuffer = status.buffer {
                try outputFile.write(from: outputBuffer)
            }

            if status.status == .endOfStream {
                break
            }
        }
    }

    private static func convertBuffer(
        inputBuffer: AVAudioPCMBuffer,
        converter: AVAudioConverter,
        outputFormat: AVAudioFormat
    ) throws -> (buffer: AVAudioPCMBuffer?, status: AVAudioConverterOutputStatus) {
        let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: outputFormat,
            frameCapacity: AVAudioFrameCount(4096)
        )!

        var error: NSError?
        let status = converter.convert(
            to: outputBuffer,
            error: &error
        ) { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return inputBuffer
        }

        if let error {
            throw error
        }
        return (outputBuffer, status)
    }

    /// Converts CAF to Opus with fallback.
    /// Returns the Opus URL on success, or the original CAF URL on failure.
    public static func encodeForUpload(cafURL: URL) async -> (url: URL, format: AudioFormat, bytes: Int) {
        let opusURL = cafURL.deletingPathExtension().appendingPathExtension("ogg")
        let cafAttributes = try? FileManager.default.attributesOfItem(atPath: cafURL.path)
        let cafSize = cafAttributes?[.size] as? Int ?? 0

        let startTime = CFAbsoluteTimeGetCurrent()
        do {
            try await convertToOpus(inputURL: cafURL, outputURL: opusURL)
            let encodeTime = CFAbsoluteTimeGetCurrent() - startTime
            let opusAttributes = try? FileManager.default.attributesOfItem(atPath: opusURL.path)
            let opusSize = opusAttributes?[.size] as? Int ?? 0
            let ratio = Double(opusSize) / Double(max(cafSize, 1))
            print("[Encoder] Opus conversion: \(String(format: "%.3f", encodeTime))s, \(ratio*100)% of original")
            return (opusURL, .opus, opusSize)
        } catch {
            print("[Encoder] Opus conversion failed: \(error.localizedDescription), using CAF fallback")
            // Clean up partial output if exists
            SecureFileDeleter.delete(at: opusURL)
            return (cafURL, .caf, cafSize)
        }
    }
}

public enum AudioFormat {
    case opus
    case caf

    public var mimeType: String {
        switch self {
        case .opus: return "audio/ogg"
        case .caf: return "audio/x-caf"
        }
    }

    public var fileExtension: String {
        switch self {
        case .opus: return "ogg"
        case .caf: return "caf"
        }
    }
}

// MARK: - AVAudioFormat Helpers

private extension AVAudioFormat {
    /// Returns a standardized format suitable for conversion.
    var standardized: AVAudioFormat? {
        guard let commonFormat = commonFormat,
              commonFormat != .otherFormat else {
            // For non-standard formats, create a PCM equivalent
            return AVAudioFormat(
                standardFormatWithSampleRate: sampleRate,
                channels: channelCount
            )
        }
        return self
    }
}
