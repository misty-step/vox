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
}
