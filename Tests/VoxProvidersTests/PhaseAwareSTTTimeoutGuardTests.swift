import Foundation
import VoxCore
import XCTest
@testable import VoxProviders

final class PhaseAwareSTTTimeoutGuardTests: XCTestCase {

    // MARK: - Guard validation in uploadWithPhaseAwareSTTTimeout

    func test_uploadWithPhaseAwareSTTTimeout_throwsOnNegativeExpectedBytes() async {
        let session = makeStubbedSession()
        let request = URLRequest(url: URL(string: "https://example.com")!)
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("guard-test.tmp")
        // swiftlint:disable:next force_try
        try! Data([0x00]).write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        do {
            _ = try await session.uploadWithPhaseAwareSTTTimeout(
                for: request, fromFile: fileURL,
                expectedBytes: -1,
                uploadStallTimeoutSeconds: 10,
                processingTimeoutSeconds: 30
            )
            XCTFail("Expected STTError.network")
        } catch let error as STTError {
            if case .network(let msg) = error {
                XCTAssertTrue(msg.contains("expectedBytes"), "Expected mention of expectedBytes: \(msg)")
            } else {
                XCTFail("Expected .network, got \(error)")
            }
        } catch {
            XCTFail("Expected STTError.network, got \(error)")
        }
    }

    func test_uploadWithPhaseAwareSTTTimeout_throwsOnZeroUploadStallTimeout() async {
        let session = makeStubbedSession()
        let request = URLRequest(url: URL(string: "https://example.com")!)
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("guard-test2.tmp")
        // swiftlint:disable:next force_try
        try! Data([0x00]).write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        do {
            _ = try await session.uploadWithPhaseAwareSTTTimeout(
                for: request, fromFile: fileURL,
                expectedBytes: 100,
                uploadStallTimeoutSeconds: 0,
                processingTimeoutSeconds: 30
            )
            XCTFail("Expected STTError.network")
        } catch let error as STTError {
            if case .network(let msg) = error {
                XCTAssertTrue(msg.contains("uploadStallTimeout"), "Expected mention of uploadStallTimeout: \(msg)")
            } else {
                XCTFail("Expected .network, got \(error)")
            }
        } catch {
            XCTFail("Expected STTError.network, got \(error)")
        }
    }

    func test_uploadWithPhaseAwareSTTTimeout_throwsOnZeroProcessingTimeout() async {
        let session = makeStubbedSession()
        let request = URLRequest(url: URL(string: "https://example.com")!)
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("guard-test3.tmp")
        // swiftlint:disable:next force_try
        try! Data([0x00]).write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        do {
            _ = try await session.uploadWithPhaseAwareSTTTimeout(
                for: request, fromFile: fileURL,
                expectedBytes: 100,
                uploadStallTimeoutSeconds: 10,
                processingTimeoutSeconds: 0
            )
            XCTFail("Expected STTError.network")
        } catch let error as STTError {
            if case .network(let msg) = error {
                XCTAssertTrue(msg.contains("processingTimeoutSeconds"), "Expected mention of processingTimeoutSeconds: \(msg)")
            } else {
                XCTFail("Expected .network, got \(error)")
            }
        } catch {
            XCTFail("Expected STTError.network, got \(error)")
        }
    }

    func test_uploadWithPhaseAwareSTTTimeout_throwsOnZeroPollInterval() async {
        let session = makeStubbedSession()
        let request = URLRequest(url: URL(string: "https://example.com")!)
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("guard-test4.tmp")
        // swiftlint:disable:next force_try
        try! Data([0x00]).write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        do {
            _ = try await session.uploadWithPhaseAwareSTTTimeout(
                for: request, fromFile: fileURL,
                expectedBytes: 100,
                uploadStallTimeoutSeconds: 10,
                processingTimeoutSeconds: 30,
                pollIntervalSeconds: 0
            )
            XCTFail("Expected STTError.network")
        } catch let error as STTError {
            if case .network(let msg) = error {
                XCTAssertTrue(msg.contains("pollIntervalSeconds"), "Expected mention of pollIntervalSeconds: \(msg)")
            } else {
                XCTFail("Expected .network, got \(error)")
            }
        } catch {
            XCTFail("Expected STTError.network, got \(error)")
        }
    }

    func test_uploadWithPhaseAwareSTTTimeout_throwsOnInfiniteUploadStallTimeout() async {
        let session = makeStubbedSession()
        let request = URLRequest(url: URL(string: "https://example.com")!)
        let fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("guard-test5.tmp")
        // swiftlint:disable:next force_try
        try! Data([0x00]).write(to: fileURL)
        defer { try? FileManager.default.removeItem(at: fileURL) }

        do {
            _ = try await session.uploadWithPhaseAwareSTTTimeout(
                for: request, fromFile: fileURL,
                expectedBytes: 100,
                uploadStallTimeoutSeconds: .infinity,
                processingTimeoutSeconds: 30
            )
            XCTFail("Expected STTError.network")
        } catch let error as STTError {
            if case .network(let msg) = error {
                XCTAssertTrue(msg.contains("uploadStallTimeout"), "Expected mention of uploadStallTimeout: \(msg)")
            } else {
                XCTFail("Expected .network, got \(error)")
            }
        } catch {
            XCTFail("Expected STTError.network, got \(error)")
        }
    }

    // MARK: - PhaseAwareSTTTimeoutPhase raw values

    func test_phaseRawValues() {
        XCTAssertEqual(PhaseAwareSTTTimeoutPhase.uploadStall.rawValue, "upload_stall")
        XCTAssertEqual(PhaseAwareSTTTimeoutPhase.processingTimeout.rawValue, "processing_timeout")
    }
}
