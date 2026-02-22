import Foundation
import XCTest
@testable import VoxMac

final class AudioFileEncryptionTests: XCTestCase {
    func test_encryptAndDecrypt_roundTripsFileContents() throws {
        let plainURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("audio-encryption-\(UUID().uuidString).caf")
        let encryptedURL = AudioFileEncryption.encryptedURL(for: plainURL)
        let decryptedURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("audio-decrypted-\(UUID().uuidString).caf")

        defer {
            try? FileManager.default.removeItem(at: plainURL)
            try? FileManager.default.removeItem(at: encryptedURL)
            try? FileManager.default.removeItem(at: decryptedURL)
        }

        let sourceData = Data([0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07])
        try sourceData.write(to: plainURL)
        let key = AudioFileEncryption.randomKey()

        try AudioFileEncryption.encrypt(plainURL: plainURL, outputURL: encryptedURL, key: key)
        try AudioFileEncryption.decrypt(encryptedURL: encryptedURL, outputURL: decryptedURL, key: key)

        let restoredData = try Data(contentsOf: decryptedURL)
        XCTAssertEqual(restoredData, sourceData)
        XCTAssertTrue(AudioFileEncryption.isEncrypted(url: encryptedURL))
    }

    func test_decryptWithWrongKeyThrows() throws {
        let plainURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("audio-encryption-wrong-\(UUID().uuidString).caf")
        let encryptedURL = AudioFileEncryption.encryptedURL(for: plainURL)
        let decryptedURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("audio-decrypted-wrong-\(UUID().uuidString).caf")
        defer {
            try? FileManager.default.removeItem(at: plainURL)
            try? FileManager.default.removeItem(at: encryptedURL)
            try? FileManager.default.removeItem(at: decryptedURL)
        }

        let sourceData = Data([0x10, 0x11, 0x12, 0x13])
        try sourceData.write(to: plainURL)
        let key = AudioFileEncryption.randomKey()
        let wrongKey = AudioFileEncryption.randomKey()

        try AudioFileEncryption.encrypt(plainURL: plainURL, outputURL: encryptedURL, key: key)
        XCTAssertThrowsError(try AudioFileEncryption.decrypt(
            encryptedURL: encryptedURL,
            outputURL: decryptedURL,
            key: wrongKey
        ))
    }

    func test_randomKey_produces256BitKey() {
        let key = AudioFileEncryption.randomKey()
        XCTAssertEqual(key.count, 32)
    }

    func test_randomKey_producesUniqueKeys() {
        let key1 = AudioFileEncryption.randomKey()
        let key2 = AudioFileEncryption.randomKey()
        XCTAssertNotEqual(key1, key2)
    }

    func test_zeroizeKey_clearsAllBytes() {
        var key = AudioFileEncryption.randomKey()
        XCTAssertFalse(key.allSatisfy { $0 == 0 })
        AudioFileEncryption.zeroizeKey(&key)
        XCTAssertTrue(key.allSatisfy { $0 == 0 })
    }

    func test_isEncrypted_returnsTrueForEncExtension() {
        let url = URL(fileURLWithPath: "/tmp/audio.caf.enc")
        XCTAssertTrue(AudioFileEncryption.isEncrypted(url: url))
    }

    func test_isEncrypted_returnsFalseForCafExtension() {
        let url = URL(fileURLWithPath: "/tmp/audio.caf")
        XCTAssertFalse(AudioFileEncryption.isEncrypted(url: url))
    }

    func test_encryptedURL_appendsEncExtension() {
        let plainURL = URL(fileURLWithPath: "/tmp/audio.caf")
        let encryptedURL = AudioFileEncryption.encryptedURL(for: plainURL)
        XCTAssertEqual(encryptedURL.pathExtension, "enc")
        XCTAssertEqual(encryptedURL.deletingPathExtension(), plainURL)
    }

    func test_encrypt_withEmptyKey_throwsKeyMissing() throws {
        let plainURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("enc-empty-key-\(UUID().uuidString).caf")
        let encryptedURL = AudioFileEncryption.encryptedURL(for: plainURL)
        defer {
            try? FileManager.default.removeItem(at: plainURL)
            try? FileManager.default.removeItem(at: encryptedURL)
        }
        try Data([0x01]).write(to: plainURL)
        XCTAssertThrowsError(
            try AudioFileEncryption.encrypt(plainURL: plainURL, outputURL: encryptedURL, key: Data())
        )
    }

    func test_decrypt_withEmptyKey_throwsKeyMissing() throws {
        let plainURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("dec-empty-key-in-\(UUID().uuidString).caf")
        let encryptedURL = AudioFileEncryption.encryptedURL(for: plainURL)
        let decryptedURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("dec-empty-key-out-\(UUID().uuidString).caf")
        defer {
            try? FileManager.default.removeItem(at: plainURL)
            try? FileManager.default.removeItem(at: encryptedURL)
            try? FileManager.default.removeItem(at: decryptedURL)
        }
        try Data([0x01]).write(to: plainURL)
        let key = AudioFileEncryption.randomKey()
        try AudioFileEncryption.encrypt(plainURL: plainURL, outputURL: encryptedURL, key: key)
        XCTAssertThrowsError(
            try AudioFileEncryption.decrypt(encryptedURL: encryptedURL, outputURL: decryptedURL, key: Data())
        )
    }

    func test_encryptAndDecrypt_roundTrips_largeMultiChunkFile() throws {
        // 200KB — exceeds the 64KB chunk size, exercising multi-chunk path
        let sourceData = Data((0..<(200 * 1024)).map { UInt8($0 & 0xFF) })
        let plainURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("enc-large-\(UUID().uuidString).caf")
        let encryptedURL = AudioFileEncryption.encryptedURL(for: plainURL)
        let decryptedURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("dec-large-\(UUID().uuidString).caf")
        defer {
            try? FileManager.default.removeItem(at: plainURL)
            try? FileManager.default.removeItem(at: encryptedURL)
            try? FileManager.default.removeItem(at: decryptedURL)
        }

        try sourceData.write(to: plainURL)
        let key = AudioFileEncryption.randomKey()
        try AudioFileEncryption.encrypt(plainURL: plainURL, outputURL: encryptedURL, key: key)
        try AudioFileEncryption.decrypt(encryptedURL: encryptedURL, outputURL: decryptedURL, key: key)

        let restored = try Data(contentsOf: decryptedURL)
        XCTAssertEqual(restored, sourceData)
    }
}
