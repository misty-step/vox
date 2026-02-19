import Foundation
import Testing
@testable import VoxAppKit

@Suite("DiagnosticsStore")
struct DiagnosticsStoreTests {
    @Test("Record writes JSONL to diagnostics-current.jsonl")
    func record_writesJSONL() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = DiagnosticsStore(directoryURL: dir, maxFileBytes: 1024 * 1024, maxRotatedFiles: 2)

        await store.record(
            name: "test_event",
            sessionID: "abc",
            fields: [
                "n": .int(1),
                "ok": .bool(true),
                "label": .string("safe"),
            ]
        )

        let fileURL = dir.appendingPathComponent("diagnostics-current.jsonl")
        let raw = try String(contentsOf: fileURL, encoding: .utf8)
        let lines = raw.split(separator: "\n", omittingEmptySubsequences: true)
        #expect(lines.count == 1)

        let json = try #require(lines.first.map { Data($0.utf8) })
        let obj = try JSONSerialization.jsonObject(with: json) as? [String: Any]
        let fields = obj?["fields"] as? [String: Any]

        #expect(obj?["name"] as? String == "test_event")
        #expect(obj?["sessionID"] as? String == "abc")
        #expect(fields?["n"] as? Int == 1)
        #expect(fields?["ok"] as? Bool == true)
        #expect(fields?["label"] as? String == "safe")
        #expect(obj?["timestamp"] as? String != nil)
    }

    @Test("Rotation keeps at most maxRotatedFiles")
    func record_rotatesAndPrunes() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = DiagnosticsStore(directoryURL: dir, maxFileBytes: 1, maxRotatedFiles: 1)

        await store.record(name: "one")
        await store.record(name: "two")
        await store.record(name: "three")

        let urls = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        let rotated = urls.filter { $0.lastPathComponent.hasPrefix("diagnostics-") && $0.lastPathComponent != "diagnostics-current.jsonl" }
        #expect(rotated.count <= 1)
        #expect(urls.contains { $0.lastPathComponent == "diagnostics-current.jsonl" })
    }

    @Test("Rotation deletes all rotated files when maxRotatedFiles is 0")
    func record_rotatesAndDeletesAllRotatedFiles() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = DiagnosticsStore(directoryURL: dir, maxFileBytes: 1, maxRotatedFiles: 0)

        await store.record(name: "one")
        await store.record(name: "two")
        await store.record(name: "three")

        let urls = try FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)
        let rotated = urls.filter { $0.lastPathComponent.hasPrefix("diagnostics-") && $0.lastPathComponent != "diagnostics-current.jsonl" }
        #expect(rotated.isEmpty)
        #expect(urls.contains { $0.lastPathComponent == "diagnostics-current.jsonl" })
    }

    @Test("Export writes zip containing context.json and logs")
    func exportZip_createsBundle() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = DiagnosticsStore(directoryURL: dir, maxFileBytes: 1024 * 1024, maxRotatedFiles: 2)
        await store.record(name: "event", fields: ["x": .int(1)])

        let zipURL = dir.appendingPathComponent("out.zip")
        let context = sampleContext()

        try await store.exportZip(to: zipURL, context: context)
        #expect(FileManager.default.fileExists(atPath: zipURL.path))

        let extractDir = dir.appendingPathComponent("extract", isDirectory: true)
        try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)
        try await runDittoExtract(zipURL: zipURL, to: extractDir)

        let (contextURL, logURL) = try #require(findExportedFiles(in: extractDir))
        #expect(contextURL.lastPathComponent == "context.json")
        #expect(logURL.lastPathComponent == "diagnostics-current.jsonl")

        let decoded = try JSONSerialization.jsonObject(with: Data(contentsOf: contextURL)) as? [String: Any]
        #expect(decoded?["appVersion"] as? String == "1.2.3")
        #expect(decoded?["appBuild"] as? String == "456")
    }

    @Test("Export succeeds even if the diagnostics directory doesn't exist yet")
    func exportZip_succeedsWithoutLogs() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let diagnosticsDir = root.appendingPathComponent("Diagnostics", isDirectory: true)
        let store = DiagnosticsStore(directoryURL: diagnosticsDir, maxFileBytes: 1024 * 1024, maxRotatedFiles: 2)

        let zipURL = root.appendingPathComponent("out.zip")
        try await store.exportZip(to: zipURL, context: sampleContext())
        #expect(FileManager.default.fileExists(atPath: zipURL.path))

        let extractDir = root.appendingPathComponent("extract", isDirectory: true)
        try FileManager.default.createDirectory(at: extractDir, withIntermediateDirectories: true)
        try await runDittoExtract(zipURL: zipURL, to: extractDir)

        let names = exportedFileNames(in: extractDir)
        #expect(names.contains("context.json"))
        #expect(!names.contains("diagnostics-current.jsonl"))
    }
}

private func sampleContext() -> DiagnosticsContext {
    DiagnosticsContext(
        exportedAt: "2026-01-01T00:00:00Z",
        appVersion: "1.2.3",
        appBuild: "456",
        osVersion: "macOS",
        processingLevel: "raw",
        selectedInputDeviceConfigured: false,
        sttRouting: "sequential",
        streamingAllowed: true,
        audioBackend: "engine",
        maxConcurrentSTT: 8,
        keysPresent: .init(
            elevenLabs: false,
            deepgram: false,
            gemini: false,
            openRouter: false
        )
    )
}

private func exportedFileNames(in root: URL) -> Set<String> {
    let fm = FileManager.default
    guard let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: nil) else {
        return []
    }
    var names: Set<String> = []
    for case let file as URL in enumerator {
        names.insert(file.lastPathComponent)
    }
    return names
}

private func findExportedFiles(in root: URL) -> (context: URL, log: URL)? {
    let fm = FileManager.default
    guard let enumerator = fm.enumerator(at: root, includingPropertiesForKeys: nil) else {
        return nil
    }
    var contextURL: URL?
    var logURL: URL?
    for case let file as URL in enumerator {
        if file.lastPathComponent == "context.json" {
            contextURL = file
        }
        if file.lastPathComponent == "diagnostics-current.jsonl" {
            logURL = file
        }
    }
    guard let contextURL, let logURL else { return nil }
    return (contextURL, logURL)
}

private func runDittoExtract(zipURL: URL, to extractDir: URL) async throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
    process.arguments = ["-x", "-k", zipURL.path, extractDir.path]
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice

    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
        process.terminationHandler = { proc in
            if proc.terminationStatus == 0 {
                continuation.resume()
            } else {
                continuation.resume(throwing: NSError(domain: "ditto", code: Int(proc.terminationStatus)))
            }
        }
        do {
            try process.run()
        } catch {
            continuation.resume(throwing: error)
        }
    }
}
