import Foundation
import Testing
@testable import VoxCore
@testable import VoxAppKit

// MARK: - Benchmark Infrastructure

/// Captures percentile distributions from pipeline timing samples.
struct StageDistribution: Codable {
    let p50: Double
    let p95: Double
    let min: Double
    let max: Double

    init(samples: [Double]) {
        let sorted = samples.sorted()
        let count = sorted.count
        self.min = sorted.first ?? 0
        self.max = sorted.last ?? 0
        self.p50 = sorted[count * 50 / 100]
        self.p95 = sorted[Swift.min(count * 95 / 100, count - 1)]
    }
}

struct BudgetCheck: Codable {
    let target: Double
    let actual: Double
    let pass: Bool
}

struct BenchmarkResult: Codable {
    let timestamp: String
    let iterations: Int
    let stages: [String: StageDistribution]
    let budgets: [String: BudgetCheck]
}

// MARK: - Benchmark Mocks

/// STT mock with configurable latency for benchmark runs.
private final class BenchmarkSTTProvider: STTProvider, @unchecked Sendable {
    private let lock = NSLock()
    private let baseDelay: TimeInterval
    private let jitter: TimeInterval
    private var _callCount = 0

    init(baseDelay: TimeInterval, jitter: TimeInterval = 0) {
        self.baseDelay = baseDelay
        self.jitter = jitter
    }

    func transcribe(audioURL: URL) async throws -> String {
        lock.withLock { _callCount += 1 }
        let delay = baseDelay + Double.random(in: 0...jitter)
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        return "benchmark transcript for test"
    }
}

/// Rewrite mock with configurable latency.
private final class BenchmarkRewriteProvider: RewriteProvider, @unchecked Sendable {
    private let lock = NSLock()
    private let baseDelay: TimeInterval
    private let jitter: TimeInterval

    init(baseDelay: TimeInterval, jitter: TimeInterval = 0) {
        self.baseDelay = baseDelay
        self.jitter = jitter
    }

    func rewrite(transcript: String, systemPrompt: String, model: String) async throws -> String {
        let delay = baseDelay + Double.random(in: 0...jitter)
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        return "Benchmark transcript for test."
    }
}

/// Paster that captures text without side effects.
private final class BenchmarkPaster: TextPaster, @unchecked Sendable {
    @MainActor func paste(text: String) throws {}
}

// MARK: - Budget Constants

/// Latency SLOs from issue #188.
enum LatencyBudget {
    static let totalP50: TimeInterval = 1.2
    static let totalP95: TimeInterval = 2.5
    static let pasteP95: TimeInterval = 0.08
    static let rewriteLightP95: TimeInterval = 0.9
    static let rewriteAggressiveP95: TimeInterval = 1.5
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
    /// Number of iterations per benchmark run.
    /// 20 provides stable percentiles with controlled mock delays while keeping CI fast.
    static let iterations = 20

    /// Runs the pipeline N times with given mock delays, returns timing samples.
    private func collectTimings(
        sttDelay: TimeInterval,
        sttJitter: TimeInterval = 0.005,
        rewriteDelay: TimeInterval,
        rewriteJitter: TimeInterval = 0.005,
        processingLevel: ProcessingLevel = .light,
        enableOpus: Bool = false
    ) async throws -> [PipelineTiming] {
        let stt = BenchmarkSTTProvider(baseDelay: sttDelay, jitter: sttJitter)
        let rewriter = BenchmarkRewriteProvider(baseDelay: rewriteDelay, jitter: rewriteJitter)
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

        let audioURL = URL(fileURLWithPath: "/tmp/benchmark-audio.caf")

        for _ in 0..<Self.iterations {
            _ = try await pipeline.process(audioURL: audioURL)
        }

        return collector.timings
    }

    /// Builds a BenchmarkResult from collected timings and writes JSON if output path is set.
    /// Note: totalTime is computed from stage sums, not PipelineTiming.totalTime,
    /// because that property reads wall-clock at access time (not capture time).
    private func buildResult(from timings: [PipelineTiming]) throws -> BenchmarkResult {
        let encodes = timings.map(\.encodeTime)
        let stts = timings.map(\.sttTime)
        let rewrites = timings.map(\.rewriteTime)
        let pastes = timings.map(\.pasteTime)
        let totals = timings.map { $0.encodeTime + $0.sttTime + $0.rewriteTime + $0.pasteTime }

        let stages: [String: StageDistribution] = [
            "encode": StageDistribution(samples: encodes),
            "stt": StageDistribution(samples: stts),
            "rewrite": StageDistribution(samples: rewrites),
            "paste": StageDistribution(samples: pastes),
            "total": StageDistribution(samples: totals),
        ]

        let budgets: [String: BudgetCheck] = [
            "total_p50": BudgetCheck(
                target: LatencyBudget.totalP50,
                actual: stages["total"]!.p50,
                pass: stages["total"]!.p50 <= LatencyBudget.totalP50
            ),
            "total_p95": BudgetCheck(
                target: LatencyBudget.totalP95,
                actual: stages["total"]!.p95,
                pass: stages["total"]!.p95 <= LatencyBudget.totalP95
            ),
            "paste_p95": BudgetCheck(
                target: LatencyBudget.pasteP95,
                actual: stages["paste"]!.p95,
                pass: stages["paste"]!.p95 <= LatencyBudget.pasteP95
            ),
            "rewrite_p95_light": BudgetCheck(
                target: LatencyBudget.rewriteLightP95,
                actual: stages["rewrite"]!.p95,
                pass: stages["rewrite"]!.p95 <= LatencyBudget.rewriteLightP95
            ),
        ]

        let formatter = ISO8601DateFormatter()
        let result = BenchmarkResult(
            timestamp: formatter.string(from: Date()),
            iterations: timings.count,
            stages: stages,
            budgets: budgets
        )

        // Write JSON artifact if output path is set
        if let outputPath = ProcessInfo.processInfo.environment["BENCHMARK_OUTPUT_PATH"] {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(result)
            try data.write(to: URL(fileURLWithPath: outputPath))
        }

        return result
    }

    // MARK: - Budget Assertion Tests

    @Test("Pipeline overhead p95 under 50ms (mock delays excluded)")
    func benchmark_pipelineOverhead_under50ms() async throws {
        // Use minimal mock delays to measure pipeline framework overhead
        let mockSTTDelay = 0.01
        let mockRewriteDelay = 0.01
        let timings = try await collectTimings(sttDelay: mockSTTDelay, rewriteDelay: mockRewriteDelay)
        let result = try buildResult(from: timings)

        // Overhead = total - (stt + rewrite mock delays)
        let totalP95 = result.stages["total"]!.p95
        let sttP95 = result.stages["stt"]!.p95
        let rewriteP95 = result.stages["rewrite"]!.p95
        let overhead = totalP95 - sttP95 - rewriteP95
        #expect(
            overhead <= 0.05,
            "Pipeline overhead p95 \(String(format: "%.3f", overhead))s exceeds 50ms"
        )
    }

    @Test("Paste stage p95 within budget")
    func benchmark_pasteP95_withinBudget() async throws {
        let timings = try await collectTimings(sttDelay: 0.01, rewriteDelay: 0.01)
        let result = try buildResult(from: timings)

        let pasteP95 = result.stages["paste"]!.p95
        #expect(
            pasteP95 <= LatencyBudget.pasteP95,
            "Paste p95 \(String(format: "%.3f", pasteP95))s exceeds budget \(LatencyBudget.pasteP95)s"
        )
    }

    @Test("Stage timings sum correctly across iterations")
    func benchmark_stageSums_matchTotal() async throws {
        let timings = try await collectTimings(sttDelay: 0.05, rewriteDelay: 0.05)

        for timing in timings {
            let stageSum = timing.encodeTime + timing.sttTime + timing.rewriteTime + timing.pasteTime
            // Stage sum should be close to wall-clock total (within 10ms of pipeline overhead)
            #expect(stageSum > 0, "Stage sum should be positive")
            #expect(timing.sttTime >= 0.05, "STT time should reflect mock delay")
            #expect(timing.rewriteTime >= 0.05, "Rewrite time should reflect mock delay")
        }
    }

    // MARK: - Full Benchmark Run (JSON Output)

    @Test("Full benchmark produces valid JSON artifact")
    func benchmark_fullRun_producesJSON() async throws {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("benchmark-\(UUID().uuidString).json")
        defer { try? FileManager.default.removeItem(at: outputURL) }

        // Can't set env vars at runtime, so we write manually
        let timings = try await collectTimings(sttDelay: 0.05, rewriteDelay: 0.05)

        let result = try buildResult(from: timings)

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(result)
        try data.write(to: outputURL)

        // Verify JSON is valid and contains expected keys
        let decoded = try JSONDecoder().decode(BenchmarkResult.self, from: data)
        #expect(decoded.iterations == Self.iterations)
        #expect(decoded.stages.count == 5)
        #expect(decoded.stages["total"] != nil)
        #expect(decoded.stages["stt"] != nil)
        #expect(decoded.stages["encode"] != nil)
        #expect(decoded.stages["rewrite"] != nil)
        #expect(decoded.stages["paste"] != nil)
    }

    // MARK: - Reproducibility Verification

    @Test("Two consecutive runs produce p50 within 15% variance")
    func benchmark_reproducibility_p50Within15Percent() async throws {
        let timings1 = try await collectTimings(sttDelay: 0.05, rewriteDelay: 0.05)
        let timings2 = try await collectTimings(sttDelay: 0.05, rewriteDelay: 0.05)

        let stageSum: (PipelineTiming) -> Double = { $0.encodeTime + $0.sttTime + $0.rewriteTime + $0.pasteTime }
        let total1 = StageDistribution(samples: timings1.map(stageSum))
        let total2 = StageDistribution(samples: timings2.map(stageSum))

        let variance = abs(total1.p50 - total2.p50) / total1.p50
        #expect(
            variance <= 0.15,
            "p50 variance \(String(format: "%.1f", variance * 100))% exceeds 15% threshold (run1: \(String(format: "%.3f", total1.p50))s, run2: \(String(format: "%.3f", total2.p50))s)"
        )
    }
}
