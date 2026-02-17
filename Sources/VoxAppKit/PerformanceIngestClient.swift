import Foundation

/// Best-effort performance telemetry uploader.
///
/// - Disabled by default. Enable with `VOX_PERF_INGEST_URL`.
/// - Never blocks dictation: events are queued and flushed asynchronously.
/// - Sends only allowlisted event names to avoid accidental sensitive payloads.
actor PerformanceIngestClient {
    static let shared = PerformanceIngestClient()

    private struct Envelope: Codable {
        let schemaVersion: Int
        let appVersion: String
        let appBuild: String
        let osVersion: String
        let event: DiagnosticsEvent
    }

    private let ingestURL: URL?
    private let session: URLSession
    private let encoder: JSONEncoder
    private let flushIntervalSeconds: TimeInterval
    private let maxBufferedBytes: Int
    private let allowedEventNames: Set<String> = ["pipeline_timing"]

    private var buffered: [Data] = []
    private var bufferedBytes: Int = 0
    private var flushTask: Task<Void, Never>?

    init(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        session: URLSession = .shared,
        flushIntervalSeconds: TimeInterval = 2.0,
        maxBufferedBytes: Int = 64 * 1024
    ) {
        let rawURL = environment["VOX_PERF_INGEST_URL"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.ingestURL = URL(string: rawURL)
        self.session = session
        self.flushIntervalSeconds = flushIntervalSeconds
        self.maxBufferedBytes = max(1024, maxBufferedBytes)
        self.encoder = JSONEncoder()
        self.encoder.outputFormatting = [.withoutEscapingSlashes]
    }

    nonisolated static func recordAsync(_ event: DiagnosticsEvent) {
        Task {
            await shared.enqueue(event)
        }
    }

    private func enqueue(_ event: DiagnosticsEvent) async {
        guard let ingestURL else { return }
        guard allowedEventNames.contains(event.name) else { return }

        if flushTask == nil {
            flushTask = Task { [weak self] in
                await self?.flushLoop()
            }
        }

        let product = ProductInfo.current()
        let envelope = Envelope(
            schemaVersion: 1,
            appVersion: product.version,
            appBuild: product.build,
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            event: event
        )

        do {
            let line = try encoder.encode(envelope) + Data([0x0A])
            buffered.append(line)
            bufferedBytes += line.count
        } catch {
            #if DEBUG
            print("[Vox] Perf ingest encode failed: \(error)")
            #endif
            return
        }

        if bufferedBytes >= maxBufferedBytes {
            await flush(to: ingestURL)
        }
    }

    private func flushLoop() async {
        guard let ingestURL else { return }
        while !Task.isCancelled {
            try? await Task.sleep(nanoseconds: UInt64(flushIntervalSeconds * 1_000_000_000))
            if Task.isCancelled { return }
            await flush(to: ingestURL)
        }
    }

    private func flush(to ingestURL: URL) async {
        guard !buffered.isEmpty else { return }

        let payload = buffered.reduce(into: Data()) { acc, line in
            acc.append(line)
        }
        buffered.removeAll(keepingCapacity: true)
        bufferedBytes = 0

        var request = URLRequest(url: ingestURL)
        request.httpMethod = "POST"
        request.setValue("application/x-ndjson", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 5

        do {
            let (_, response) = try await session.upload(for: request, from: payload)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                #if DEBUG
                print("[Vox] Perf ingest HTTP \(http.statusCode)")
                #endif
            }
        } catch {
            #if DEBUG
            print("[Vox] Perf ingest upload failed: \(error)")
            #endif
        }
    }
}
