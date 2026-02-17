import CryptoKit
import Foundation
import VoxCore

public enum AudioFileEncryption {
    public static let encryptedFileExtension = "enc"
    private static let magic = Data("VOXENC1".utf8)
    private static let chunkSize = 64 * 1024
    private static let maxChunkLength = 10_000_000

    public enum Error: Swift.Error, LocalizedError {
        case invalidInput
        case invalidEncryptedFormat
        case keyMissing
        case tooLargeChunk
        case readFailure
        case writeFailure
        case cipherFailure

        public var errorDescription: String? {
            switch self {
            case .invalidInput:
                return "Audio encryption input/output is invalid"
            case .invalidEncryptedFormat:
                return "Audio encryption format is invalid"
            case .keyMissing:
                return "Audio encryption key is missing"
            case .tooLargeChunk:
                return "Encrypted chunk is too large"
            case .readFailure:
                return "Failed to read encrypted audio"
            case .writeFailure:
                return "Failed to write encrypted audio"
            case .cipherFailure:
                return "Audio encryption/decryption failed"
            }
        }
    }

    public static func randomKey() -> Data {
        let key = SymmetricKey(size: .bits256)
        return key.withUnsafeBytes { Data($0) }
    }

    public static func zeroizeKey(_ key: inout Data) {
        _ = key.withUnsafeMutableBytes { bytes in
            bytes.initializeMemory(as: UInt8.self, repeating: 0)
        }
    }

    public static func isEncrypted(url: URL) -> Bool {
        url.pathExtension.lowercased() == encryptedFileExtension
    }

    public static func encryptedURL(for plainURL: URL) -> URL {
        plainURL.appendingPathExtension(encryptedFileExtension)
    }

    public static func encryptedOutputFrom(plainURL: URL) -> URL {
        encryptedURL(for: plainURL)
    }

    public static func encrypt(
        plainURL: URL,
        outputURL: URL,
        key: Data
    ) throws {
        guard !key.isEmpty else {
            throw Error.keyMissing
        }
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try FileManager.default.removeItem(at: outputURL)
        }
        let symmetricKey = SymmetricKey(data: key)

        guard let inputStream = InputStream(url: plainURL),
              let outputStream = OutputStream(url: outputURL, append: false) else {
            throw Error.invalidInput
        }
        inputStream.open()
        outputStream.open()
        defer {
            inputStream.close()
            outputStream.close()
        }

        try write(data: magic, to: outputStream)
        var buffer = [UInt8](repeating: 0, count: chunkSize)
        while true {
            let read = inputStream.read(&buffer, maxLength: chunkSize)
            if read < 0 {
                throw Error.readFailure
            }
            if read == 0 {
                break
            }
            let chunk = Data(buffer[0..<read])
            do {
                let sealed = try AES.GCM.seal(chunk, using: symmetricKey)
                guard let combined = sealed.combined else {
                    throw Error.cipherFailure
                }
                try writeLengthPrefix(combined.count, to: outputStream)
                try write(data: combined, to: outputStream)
            } catch {
                throw Error.cipherFailure
            }
        }
    }

    public static func decrypt(
        encryptedURL: URL,
        outputURL: URL,
        key: Data
    ) throws {
        guard !key.isEmpty else {
            throw Error.keyMissing
        }
        guard let inputStream = InputStream(url: encryptedURL),
              let outputStream = OutputStream(url: outputURL, append: false) else {
            throw Error.invalidInput
        }
        inputStream.open()
        outputStream.open()
        defer {
            inputStream.close()
            outputStream.close()
        }

        guard let observedMagic = try readBytes(count: magic.count, from: inputStream),
              observedMagic == magic else {
            throw Error.invalidEncryptedFormat
        }

        let symmetricKey = SymmetricKey(data: key)

        while true {
            guard let chunkLength = try readLengthPrefix(from: inputStream) else {
                break
            }
            guard chunkLength <= maxChunkLength else {
                throw Error.tooLargeChunk
            }
            guard let combined = try readBytes(count: chunkLength, from: inputStream) else {
                throw Error.invalidEncryptedFormat
            }
            let sealed = try AES.GCM.SealedBox(combined: combined)
            do {
                let plain = try AES.GCM.open(sealed, using: symmetricKey)
                if !plain.isEmpty {
                    try write(data: plain, to: outputStream)
                }
            } catch {
                throw Error.cipherFailure
            }
        }
    }

    private static func write(_ value: UInt32, to stream: OutputStream) throws {
        var mutable = value.littleEndian
        let bytes = withUnsafeBytes(of: &mutable) { Data($0) }
        try write(data: bytes, to: stream)
    }

    private static func writeLengthPrefix(_ length: Int, to stream: OutputStream) throws {
        guard let clamped = UInt32(exactly: length) else {
            throw Error.tooLargeChunk
        }
        try write(clamped, to: stream)
    }

    private static func write(data: Data, to stream: OutputStream) throws {
        try data.withUnsafeBytes { rawBuffer in
            var written = 0
            while written < rawBuffer.count {
                let pointer = rawBuffer.baseAddress!.advanced(by: written).assumingMemoryBound(to: UInt8.self)
                let count = stream.write(pointer, maxLength: rawBuffer.count - written)
                if count < 0 {
                    throw Error.writeFailure
                }
                written += count
            }
        }
    }

    private static func readBytes(count: Int, from stream: InputStream) throws -> Data? {
        if count == 0 {
            return Data()
        }
        guard count > 0 else {
            throw Error.invalidEncryptedFormat
        }

        var remaining = count
        var collected = Data()
        collected.reserveCapacity(count)
        var buffer = [UInt8](repeating: 0, count: min(chunkSize, count))
        while remaining > 0 {
            let chunkCount = min(remaining, buffer.count)
            let read = stream.read(&buffer, maxLength: chunkCount)
            if read < 0 {
                throw Error.readFailure
            }
            if read == 0 {
                return nil
            }
            collected.append(contentsOf: buffer[0..<read])
            remaining -= read
        }
        return collected
    }

    private static func readLengthPrefix(from stream: InputStream) throws -> Int? {
        guard let bytes = try readBytes(count: MemoryLayout<UInt32>.size, from: stream) else {
            return nil
        }
        return Int(UInt32(littleEndian: bytes.withUnsafeBytes { $0.load(as: UInt32.self) }))
    }
}
