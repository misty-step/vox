import Foundation

enum DiagnosticsEventNames {
    static let pipelineTiming = "pipeline_timing"
    static let shareTrigger = "share_triggered"
    static let rewriteOpenRouterAttempt = "rewrite_openrouter_attempt"
    static let rewriteModelUsed = "rewrite_model_used"
    static let rewriteStageOutcome = "rewrite_stage_outcome"
}

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
    private let allowedEventNames: Set<String> = [DiagnosticsEventNames.pipelineTiming, DiagnosticsEventNames.shareTrigger]
    private let appVersion: String
    private let appBuild: String
    private let osVersion: String

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

        let product = ProductInfo.current()
        self.appVersion = product.version
        self.appBuild = product.build
        self.osVersion = ProcessInfo.processInfo.operatingSystemVersionString
    }

    nonisolated static func recordAsync(_ event: DiagnosticsEvent) {
        Task {
            await shared.enqueue(event)
        }
    }

    private func enqueue(_ event: DiagnosticsEvent) async {
        guard let ingestURL else { return }
        guard allowedEventNames.contains(event.name) else { return }

        let envelope = Envelope(
            schemaVersion: 1,
            appVersion: appVersion,
            appBuild: appBuild,
            osVersion: osVersion,
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
            flushTask?.cancel()
            flushTask = nil
            await flush(to: ingestURL)
            return
        }

        scheduleFlush(to: ingestURL)
    }

    private func scheduleFlush(to ingestURL: URL) {
        guard flushTask == nil else { return }
        let intervalNanoseconds = UInt64(max(0.1, flushIntervalSeconds) * 1_000_000_000)
        flushTask = Task { [intervalNanoseconds] in
            try? await Task.sleep(nanoseconds: intervalNanoseconds)
            guard !Task.isCancelled else { return }
            await self.flush(to: ingestURL)
            flushCompleted(to: ingestURL)
        }
    }

    private func flushCompleted(to ingestURL: URL) {
        flushTask = nil
        if !buffered.isEmpty {
            scheduleFlush(to: ingestURL)
        }
    }

    private func flush(to ingestURL: URL) async {
        guard !buffered.isEmpty else { return }

        let payload = buffered.reduce(into: Data()) { acc, line in
            acc.append(line)
        }
        // Best-effort. We drop on upload failure to avoid backpressure in dictation hot paths.
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
