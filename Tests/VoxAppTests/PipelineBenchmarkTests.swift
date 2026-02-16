import Foundation
import Testing
@testable import VoxCore
@testable import VoxAppKit

// MARK: - Benchmark Infrastructure

/// Captures percentile distributions from pipeline timing samples.
private struct StageDistribution: Codable {
    let p50: Double
    let p95: Double
    let min: Double
    let max: Double

    init(samples: [Double]) {
        guard !samples.isEmpty else {
            self.p50 = 0
            self.p95 = 0
            self.min = 0
            self.max = 0
            return
        }
        let sorted = samples.sorted()
        self.min = sorted[0]
        self.max = sorted[sorted.count - 1]
        self.p50 = Self.percentile(sorted, quantile: 0.50)
        self.p95 = Self.percentile(sorted, quantile: 0.95)
    }

    private static func percentile(_ sorted: [Double], quantile: Double) -> Double {
        guard sorted.count > 1 else { return sorted[0] }
        let rank = quantile * Double(sorted.count - 1)
        let lower = Int(rank.rounded(.down))
        let upper = Int(rank.rounded(.up))
        if lower == upper { return sorted[lower] }

        let lowerValue = sorted[lower]
        let upperValue = sorted[upper]
        let fraction = rank - Double(lower)
        return lowerValue + ((upperValue - lowerValue) * fraction)
    }
}

private struct BudgetCheck: Codable {
    let target: Double
    let actual: Double
    let pass: Bool
}

private struct BenchmarkResult: Codable {
    let timestamp: String
    let iterations: Int
    let stages: [String: StageDistribution]
    let budgets: [String: BudgetCheck]
}

private func clampedNanoseconds(for delay: TimeInterval) -> UInt64 {
    let nanoseconds = delay * 1_000_000_000
    guard nanoseconds.isFinite, nanoseconds > 0 else { return 0 }
    if nanoseconds >= Double(UInt64.max) { return UInt64.max }
    return UInt64(nanoseconds)
}

// MARK: - Benchmark Mocks

/// STT mock with configurable latency for benchmark runs.
private final class BenchmarkSTTProvider: STTProvider, Sendable {
    private let delay: TimeInterval

    init(delay: TimeInterval) {
        self.delay = delay
    }

    func transcribe(audioURL: URL) async throws -> String {
        try await Task.sleep(nanoseconds: clampedNanoseconds(for: delay))
        return "benchmark transcript for test"
    }
}

/// Rewrite mock with configurable latency.
private final class BenchmarkRewriteProvider: RewriteProvider, Sendable {
    private let delay: TimeInterval

    init(delay: TimeInterval) {
        self.delay = delay
    }

    func rewrite(transcript: String, systemPrompt: String, model: String) async throws -> String {
        try await Task.sleep(nanoseconds: clampedNanoseconds(for: delay))
        return "Benchmark transcript for test."
    }
}

/// Paster that does nothing — benchmark measures timing, not output.
private final class BenchmarkPaster: TextPaster, Sendable {
    @MainActor func paste(text: String) throws {}
}

// MARK: - Budget Constants

/// Latency SLOs from issue #188.
private enum LatencyBudget {
    static let totalP50: TimeInterval = 1.2
    static let totalP95: TimeInterval = 2.5
    static let pasteP95: TimeInterval = 0.08
    static let rewriteCleanP95: TimeInterval = 0.9
}

// MARK: - Thread-Safe Timing Collector

private final class TimingCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var _timings: [PipelineTiming] = []

    func append(_ timing: PipelineTiming) {
        lock.withLock { _timings.append(timing) }
    }

    var timings: [PipelineTiming] {
        lock.withLock { _timings }
    }
}

// MARK: - Benchmark Suite

@Suite("Pipeline Benchmark")
@MainActor
struct PipelineBenchmarkTests {
    private static let benchmarkEnvFlag = "VOX_RUN_BENCHMARK_TESTS"

    /// Number of iterations per benchmark run.
    /// 20 provides stable percentiles with controlled mock delays while keeping CI fast.
    static let iterations = 20

    private static var benchmarksEnabled: Bool {
        ProcessInfo.processInfo.environment[benchmarkEnvFlag] == "1"
    }

    /// Runs the pipeline N times with given mock delays, returns timing samples.
    private func collectTimings(
        sttDelay: TimeInterval,
        rewriteDelay: TimeInterval,
        processingLevel: ProcessingLevel = .clean,
        enableOpus: Bool = false
    ) async throws -> [PipelineTiming] {
        let stt = BenchmarkSTTProvider(delay: sttDelay)
        let rewriter = BenchmarkRewriteProvider(delay: rewriteDelay)
        let paster = BenchmarkPaster()
        let prefs = MockPreferences()
        prefs.processingLevel = processingLevel

        let collector = TimingCollector()

        let pipeline = DictationPipeline(
            stt: stt,
            rewriter: rewriter,
            paster: paster,
            prefs: prefs,
            rewriteCache: RewriteResultCache(maxEntries: 0, ttlSeconds: 0, maxCharacterCount: 0),
            enableRewriteCache: false,
            enableOpus: enableOpus,
            convertCAFToOpus: { url in url },  // no-op for benchmark
            timingHandler: { timing in
                collector.append(timing)
            }
        )

        // Use .wav extension to bypass CapturedAudioInspector validation (only validates .caf).
        // Mocks ignore file contents, so this URL does not need an actual fixture on disk.
        let audioURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("benchmark-\(UUID().uuidString)")
            .appendingPathExtension("wav")

        for _ in 0..<Self.iterations {
            _ = try await pipeline.process(audioURL: audioURL)
        }

        return collector.timings
    }

    private func stageTotal(for timing: PipelineTiming) -> TimeInterval {
        timing.encodeTime + timing.sttTime + timing.rewriteTime + timing.pasteTime
    }

    /// Builds a BenchmarkResult from collected timings.
    /// Uses stage sums (not PipelineTiming.totalTime) because that property
    /// reads wall-clock at access time, not capture time.
    private func buildResult(from timings: [PipelineTiming]) -> BenchmarkResult {
        let encodes = timings.map(\.encodeTime)
        let stts = timings.map(\.sttTime)
        let rewrites = timings.map(\.rewriteTime)
        let pastes = timings.map(\.pasteTime)
        let totals = timings.map { stageTotal(for: $0) }

        let stages: [String: StageDistribution] = [
            "encode": StageDistribution(samples: encodes),
            "stt": StageDistribution(samples: stts),
            "rewrite": StageDistribution(samples: rewrites),
            "paste": StageDistribution(samples: pastes),
            "total": StageDistribution(samples: totals),
        ]

        func check(_ key: String, percentile: KeyPath<StageDistribution, Double>, target: Double) -> BudgetCheck {
            let actual = stages[key]![keyPath: percentile]
            return BudgetCheck(target: target, actual: actual, pass: actual <= target)
        }

        let budgets: [String: BudgetCheck] = [
            "total_p50": check("total", percentile: \.p50, target: LatencyBudget.totalP50),
            "total_p95": check("total", percentile: \.p95, target: LatencyBudget.totalP95),
            "paste_p95": check("paste", percentile: \.p95, target: LatencyBudget.pasteP95),
            "rewrite_p95_clean": check("rewrite", percentile: \.p95, target: LatencyBudget.rewriteCleanP95),
        ]

        return BenchmarkResult(
            timestamp: ISO8601DateFormatter().string(from: Date()),
            iterations: timings.count,
            stages: stages,
            budgets: budgets
        )
    }

    // MARK: - Budget Assertion Tests

    @Test("Pipeline overhead p95 under 50ms (mock delays excluded)")
    func benchmark_pipelineOverhead_under50ms() async throws {
        guard Self.benchmarksEnabled else { return }

        // Use minimal mock delays to measure pipeline framework overhead
        let mockSTTDelay = 0.01
        let mockRewriteDelay = 0.01
        let timings = try await collectTimings(sttDelay: mockSTTDelay, rewriteDelay: mockRewriteDelay)
        #expect(timings.count == Self.iterations, "Expected \(Self.iterations) timing samples")

        // Compute overhead per run, then take p95 of that distribution.
        let overheadSamples = timings.map {
            max(0, stageTotal(for: $0) - mockSTTDelay - mockRewriteDelay)
        }
        let overhead = StageDistribution(samples: overheadSamples).p95
        #expect(
            overhead <= 0.05,
            "Pipeline overhead p95 \(String(format: "%.3f", overhead))s exceeds 50ms"
        )
    }

    @Test("Paste stage p95 within budget")
    func benchmark_pasteP95_withinBudget() async throws {
        guard Self.benchmarksEnabled else { return }

        let timings = try await collectTimings(sttDelay: 0.01, rewriteDelay: 0.01)
        let result = buildResult(from: timings)

        let pasteP95 = result.stages["paste"]!.p95
        #expect(
            pasteP95 <= LatencyBudget.pasteP95,
            "Paste p95 \(String(format: "%.3f", pasteP95))s exceeds budget \(LatencyBudget.pasteP95)s"
        )
    }

    @Test("Stage timings sum correctly across iterations")
    func benchmark_stageSums_matchTotal() async throws {
        guard Self.benchmarksEnabled else { return }

        let timings = try await collectTimings(sttDelay: 0.05, rewriteDelay: 0.05)
        #expect(timings.count == Self.iterations, "Expected \(Self.iterations) timing samples")

        for timing in timings {
            let stageSum = stageTotal(for: timing)
            #expect(stageSum >= 0.1, "Stage sum should include configured provider delays")
            #expect(timing.sttTime >= 0.05, "STT time should reflect mock delay")
            #expect(timing.rewriteTime >= 0.05, "Rewrite time should reflect mock delay")
        }
    }

    // MARK: - Full Benchmark Run (JSON Output)

    @Test("Full benchmark produces valid JSON artifact")
    func benchmark_fullRun_producesJSON() async throws {
        guard Self.benchmarksEnabled else { return }

        let timings = try await collectTimings(sttDelay: 0.05, rewriteDelay: 0.05)
        let result = buildResult(from: timings)

        // Round-trip through JSON to verify Codable conformance
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(result)
        let decoded = try JSONDecoder().decode(BenchmarkResult.self, from: data)

        #expect(decoded.iterations == Self.iterations)
        let expectedStages: Set<String> = ["encode", "stt", "rewrite", "paste", "total"]
        #expect(Set(decoded.stages.keys) == expectedStages)

        // Assert all budget checks pass
        for (name, budget) in decoded.budgets {
            #expect(budget.pass, "Budget '\(name)' failed: \(budget.actual * 1000)ms > \(budget.target * 1000)ms")
        }
    }

}
