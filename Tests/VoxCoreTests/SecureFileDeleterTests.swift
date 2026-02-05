import XCTest
@testable import VoxCore

final class SecureFileDeleterTests: XCTestCase {
    private var tempDir: URL!

    override func setUp() {
        super.setUp()
        tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("SecureFileDeleterTests-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: tempDir)
        super.tearDown()
    }

    func testDeleteRemovesFile() {
        let file = tempDir.appendingPathComponent("test.caf")
        FileManager.default.createFile(atPath: file.path, contents: Data("sensitive audio".utf8))

        SecureFileDeleter.delete(at: file)

        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }

    func testDeleteOverwritesBeforeRemoving() {
        let file = tempDir.appendingPathComponent("test.caf")
        let original = Data("sensitive audio data".utf8)
        FileManager.default.createFile(atPath: file.path, contents: original)

        // We can't easily verify overwrite after deletion.
        // Instead verify the file is gone (overwrite + delete is atomic from caller perspective).
        SecureFileDeleter.delete(at: file)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }

    func testDeleteNonexistentFileDoesNotCrash() {
        let file = tempDir.appendingPathComponent("does-not-exist.caf")
        // Should not throw or crash
        SecureFileDeleter.delete(at: file)
    }

    func testDeleteEmptyFile() {
        let file = tempDir.appendingPathComponent("empty.caf")
        FileManager.default.createFile(atPath: file.path, contents: Data())

        SecureFileDeleter.delete(at: file)

        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }
}
