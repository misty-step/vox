import Foundation
import VoxPerfAuditKit
import VoxAppKit
import VoxCore
import VoxPipeline
import VoxProviders

private struct PerfLevelDistributions: Codable {
    let encodeMs: StageDistribution
    let sttMs: StageDistribution
    let rewriteMs: StageDistribution
    let pasteMs: StageDistribution
    let generationMs: StageDistribution
    let totalStageMs: StageDistribution
}

private struct ProviderDescriptor: Codable {
    let provider: String
    let model: String
}

private struct ProviderUsage: Codable {
    let provider: String
    let model: String
    let count: Int
}

private struct RewriteUsage: Codable {
    let path: String
    let model: String
    let count: Int
}

private struct PerfLevelProviders: Codable {
    let sttMode: String
    let sttObserved: [ProviderUsage]
    let rewriteObserved: [RewriteUsage]?
}

private struct PerfLevelResult: Codable {
    let level: String
    let iterations: Int
    let providers: PerfLevelProviders
    let distributions: PerfLevelDistributions
}

private struct PerfFixtureDescriptor: Codable {
    let id: String
    let audioFile: String
    let audioBytes: Int
}

private struct PerfFixtureResult: Codable {
    let fixtureID: String
    let audioFile: String
    let audioBytes: Int
    let levels: [PerfLevelResult]
}

private struct PerfAuditResult: Codable {
    let schemaVersion: Int
    let generatedAt: String
    let lane: String
    let commitSHA: String?
    let pullRequestNumber: Int?
    let label: String?
    let iterationsPerLevel: Int
    let warmupIterationsPerLevel: Int
    let audioFile: String
    let audioBytes: Int
    let fixtures: [PerfFixtureDescriptor]
    let fixtureResults: [PerfFixtureResult]
    let sttMode: String
    let sttSelectionPolicy: String
    let sttForcedProvider: String?
    let sttChain: [ProviderDescriptor]
    let rewriteRouting: String
    let levels: [PerfLevelResult]
}

private func loadDotEnv(from url: URL) -> [String: String] {
    let fm = FileManager.default
    guard fm.fileExists(atPath: url.path) else { return [:] }
    guard let raw = try? String(contentsOf: url, encoding: .utf8) else { return [:] }

    var out: [String: String] = [:]
    for line in raw.split(separator: "\n", omittingEmptySubsequences: true) {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
        guard let idx = trimmed.firstIndex(of: "=") else { continue }
        let k = trimmed[..<idx].trimmingCharacters(in: .whitespacesAndNewlines)
        let v = trimmed[trimmed.index(after: idx)...].trimmingCharacters(in: .whitespacesAndNewlines)
        if k.isEmpty { continue }

        let unquoted: String
        if (v.hasPrefix("\"") && v.hasSuffix("\"")) || (v.hasPrefix("'") && v.hasSuffix("'")) {
            unquoted = String(v.dropFirst().dropLast())
        } else {
            unquoted = v
        }
        out[String(k)] = unquoted
    }
    return out
}

private func mergedEnvironment(_ environment: [String: String], dotenv: [String: String]) -> [String: String] {
    func configured(_ value: String?) -> Bool {
        guard let value else { return false }
        return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var merged = environment
    for (k, v) in dotenv {
        if !configured(merged[k]) && configured(v) {
            merged[k] = v
        }
    }
    return merged
}

@MainActor
// @unchecked Sendable: constrained to MainActor, but must satisfy PreferencesReading: Sendable.
private final class PerfPreferences: PreferencesReading, @unchecked Sendable {
    let processingLevel: ProcessingLevel
    let selectedInputDeviceUID: String? = nil
    let elevenLabsAPIKey: String
    let openRouterAPIKey: String
    let deepgramAPIKey: String
    let geminiAPIKey: String

    init(level: ProcessingLevel, environment: [String: String]) {
        self.processingLevel = level

        func key(_ name: String) -> String {
            environment[name]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }
        self.elevenLabsAPIKey = key("ELEVENLABS_API_KEY")
        self.openRouterAPIKey = key("OPENROUTER_API_KEY")
        self.deepgramAPIKey = key("DEEPGRAM_API_KEY")
        self.geminiAPIKey = key("GEMINI_API_KEY")
    }
}

// @unchecked Sendable: no state; paste is @MainActor and a no-op in perf audit.
private final class NoopPaster: TextPaster, @unchecked Sendable {
    @MainActor
    func paste(text: String) async throws {}
}

private func clampedNanoseconds(for delaySeconds: TimeInterval) -> UInt64 {
    let nanoseconds = delaySeconds * 1_000_000_000
    guard nanoseconds.isFinite, nanoseconds > 0 else { return 0 }
    if nanoseconds >= Double(UInt64.max) { return UInt64.max }
    return UInt64(nanoseconds)
}

private final class FixedDelaySTTProvider: STTProvider, @unchecked Sendable {
    private let delaySeconds: TimeInterval

    init(delaySeconds: TimeInterval) {
        self.delaySeconds = delaySeconds
    }

    func transcribe(audioURL: URL) async throws -> String {
        try await Task.sleep(nanoseconds: clampedNanoseconds(for: delaySeconds))
        return "Deterministic benchmark transcript."
    }
}

private final class FixedDelayRewriteProvider: RewriteProvider, @unchecked Sendable {
    private let delaySeconds: TimeInterval

    init(delaySeconds: TimeInterval) {
        self.delaySeconds = delaySeconds
    }

    func rewrite(transcript: String, systemPrompt: String, model: String) async throws -> String {
        try await Task.sleep(nanoseconds: clampedNanoseconds(for: delaySeconds))
        return "Deterministic benchmark transcript."
    }
}

private struct ResolvedProviders {
    let sttProvider: STTProvider
    let sttSelectionPolicy: String
    let sttForcedProvider: String?
    let sttChain: [ProviderDescriptor]
    let sttMode: String
    let rewriteProvider: RewriteProvider
    let rewriteRouting: String
    let hasCloudSTT: Bool
}

private func resolvedProviderLane(
    environment: [String: String],
    usageRecorder: ProviderUsageRecorder
) throws -> ResolvedProviders {
    func key(_ name: String) -> String {
        environment[name]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    let plan = try PerfProviderPlan.resolve(environment: environment)

    let assemblyConfig = ProviderAssemblyConfig(
        elevenLabsAPIKey: key("ELEVENLABS_API_KEY"),
        deepgramAPIKey: key("DEEPGRAM_API_KEY"),
        geminiAPIKey: key("GEMINI_API_KEY"),
        openRouterAPIKey: key("OPENROUTER_API_KEY"),
        sttInstrument: { name, model, provider in
            InstrumentedSTTProvider(provider: provider, providerName: name, model: model, recorder: usageRecorder)
        },
        rewriteInstrument: { path, provider in
            InstrumentedRewriteProvider(provider: provider, path: path, recorder: usageRecorder)
        },
        openRouterOnModelUsed: { model, _ in
            usageRecorder.recordRewrite(path: "openrouter", model: model)
        }
    )

    let cloudResult = ProviderAssembly.makeCloudSTTProvider(config: assemblyConfig)

    // Apply forced-provider reordering from plan (perf-audit specific).
    // PerfProviderPlan validates that the forced provider key exists; entries are pre-built here.
    var entries = cloudResult.entries
    if let forced = plan.stt.forcedProvider,
       let idx = entries.firstIndex(where: { $0.name.lowercased() == forced }) {
        let first = entries.remove(at: idx)
        entries.insert(first, at: 0)
    }

    // PerfProviderPlan.resolve() guarantees at least one key exists, but guard defensively.
    guard !entries.isEmpty else {
        throw PerfAuditError.missingRequiredKey("ELEVENLABS_API_KEY (or DEEPGRAM_API_KEY)")
    }

    // Rebuild sequential fallback chain from (potentially reordered) entries.
    let chainProvider = ProviderAssembly.buildFallbackChain(from: entries)!

    let maxConcurrent = max(1, Int(key("VOX_MAX_CONCURRENT_STT")) ?? 8)
    let sttProvider = ConcurrencyLimitedSTTProvider(provider: chainProvider, maxConcurrent: maxConcurrent)

    let rewriteProvider = ProviderAssembly.makeRewriteProvider(config: assemblyConfig)
    let rewriteRouting = plan.rewrite.hasGeminiDirect
        ? "model-routed (gemini_direct + openrouter)"
        : "openrouter"

    return ResolvedProviders(
        sttProvider: sttProvider,
        sttSelectionPolicy: plan.stt.selectionPolicy,
        sttForcedProvider: plan.stt.forcedProvider,
        sttChain: entries.map { ProviderDescriptor(provider: $0.name, model: $0.model) },
        sttMode: plan.stt.mode,
        rewriteProvider: rewriteProvider,
        rewriteRouting: rewriteRouting,
        hasCloudSTT: true
    )
}

private func resolvedCodepathLane(
    level: ProcessingLevel,
    usageRecorder: ProviderUsageRecorder
) -> ResolvedProviders {
    let sttDelay: TimeInterval = 0.06
    let rewriteDelay: TimeInterval
    switch level {
    case .raw:
        rewriteDelay = 0
    case .clean:
        rewriteDelay = 0.10
    case .polish:
        rewriteDelay = 0.16
    }

    let sttProvider = InstrumentedSTTProvider(
        provider: FixedDelaySTTProvider(delaySeconds: sttDelay),
        providerName: "DeterministicSTT",
        model: "fixed-delay-v1",
        recorder: usageRecorder
    )
    let rewriteProvider = InstrumentedRewriteProvider(
        provider: FixedDelayRewriteProvider(delaySeconds: rewriteDelay),
        path: "deterministic",
        recorder: usageRecorder
    )

    return ResolvedProviders(
        sttProvider: sttProvider,
        sttSelectionPolicy: "fixed",
        sttForcedProvider: "deterministic",
        sttChain: [ProviderDescriptor(provider: "DeterministicSTT", model: "fixed-delay-v1")],
        sttMode: "mock",
        rewriteProvider: rewriteProvider,
        rewriteRouting: "deterministic",
        hasCloudSTT: false
    )
}

private func resolvedProviders(
    lane: PerfAuditLane,
    level: ProcessingLevel,
    environment: [String: String],
    usageRecorder: ProviderUsageRecorder
) throws -> ResolvedProviders {
    switch lane {
    case .provider:
        return try resolvedProviderLane(environment: environment, usageRecorder: usageRecorder)
    case .codepath:
        return resolvedCodepathLane(level: level, usageRecorder: usageRecorder)
    }
}

private final class ProviderUsageRecorder: @unchecked Sendable {
    // NSLock-protected counters to avoid any actor hops on hot paths.
    private let lock = NSLock()
    private var sttCounts: [String: Int] = [:]
    private var rewriteCounts: [String: Int] = [:]

    func recordSTT(provider: String, model: String) {
        let key = "\(provider)\u{001F}\(model)"
        lock.withLock { sttCounts[key, default: 0] += 1 }
    }

    func recordRewrite(path: String, model: String) {
        let key = "\(path)\u{001F}\(model)"
        lock.withLock { rewriteCounts[key, default: 0] += 1 }
    }

    func snapshotSTT() -> [ProviderUsage] {
        lock.withLock {
            sttCounts
                .map { key, count in
                    let parts = key.split(separator: "\u{001F}", maxSplits: 1).map(String.init)
                    return ProviderUsage(provider: parts[0], model: parts.count > 1 ? parts[1] : "", count: count)
                }
                .sorted { ($0.count, $0.provider, $0.model) > ($1.count, $1.provider, $1.model) }
        }
    }

    func snapshotRewrite() -> [RewriteUsage] {
        lock.withLock {
            rewriteCounts
                .map { key, count in
                    let parts = key.split(separator: "\u{001F}", maxSplits: 1).map(String.init)
                    return RewriteUsage(path: parts[0], model: parts.count > 1 ? parts[1] : "", count: count)
                }
                .sorted { ($0.count, $0.path, $0.model) > ($1.count, $1.path, $1.model) }
        }
    }
}

private struct InstrumentedSTTProvider: STTProvider {
    let provider: STTProvider
    let providerName: String
    let model: String
    let recorder: ProviderUsageRecorder

    func transcribe(audioURL: URL) async throws -> String {
        let result = try await provider.transcribe(audioURL: audioURL)
        recorder.recordSTT(provider: providerName, model: model)
        return result
    }
}

private struct InstrumentedRewriteProvider: RewriteProvider {
    let provider: RewriteProvider
    let path: String
    let recorder: ProviderUsageRecorder

    func rewrite(transcript: String, systemPrompt: String, model: String) async throws -> String {
        let result = try await provider.rewrite(transcript: transcript, systemPrompt: systemPrompt, model: model)
        recorder.recordRewrite(path: path, model: model)
        return result
    }
}

// @unchecked Sendable: NSLock protects cross-task writes from the timing handler.
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

private struct TimingSamples {
    var encodeMs: [Double] = []
    var sttMs: [Double] = []
    var rewriteMs: [Double] = []
    var pasteMs: [Double] = []
    var generationMs: [Double] = []
    var totalStageMs: [Double] = []

    mutating func append(_ timings: [PipelineTiming]) {
        encodeMs.append(contentsOf: timings.map { $0.encodeTime * 1000 })
        sttMs.append(contentsOf: timings.map { $0.sttTime * 1000 })
        rewriteMs.append(contentsOf: timings.map { $0.rewriteTime * 1000 })
        pasteMs.append(contentsOf: timings.map { $0.pasteTime * 1000 })
        generationMs.append(contentsOf: timings.map { ($0.encodeTime + $0.sttTime + $0.rewriteTime) * 1000 })
        totalStageMs.append(contentsOf: timings.map { ($0.encodeTime + $0.sttTime + $0.rewriteTime + $0.pasteTime) * 1000 })
    }
}

private struct FixtureInput {
    let id: String
    let audioURL: URL
    let audioBytes: Int
}

private func distributions(from samples: TimingSamples) -> PerfLevelDistributions {
    PerfLevelDistributions(
        encodeMs: StageDistribution(samples: samples.encodeMs),
        sttMs: StageDistribution(samples: samples.sttMs),
        rewriteMs: StageDistribution(samples: samples.rewriteMs),
        pasteMs: StageDistribution(samples: samples.pasteMs),
        generationMs: StageDistribution(samples: samples.generationMs),
        totalStageMs: StageDistribution(samples: samples.totalStageMs)
    )
}

private func mergeSTTUsage(_ entries: [ProviderUsage]) -> [ProviderUsage] {
    var counts: [String: Int] = [:]
    for entry in entries {
        let key = "\(entry.provider)\u{001F}\(entry.model)"
        counts[key, default: 0] += entry.count
    }
    return counts
        .map { key, count in
            let parts = key.split(separator: "\u{001F}", maxSplits: 1).map(String.init)
            return ProviderUsage(provider: parts[0], model: parts.count > 1 ? parts[1] : "", count: count)
        }
        .sorted { ($0.count, $0.provider, $0.model) > ($1.count, $1.provider, $1.model) }
}

private func mergeRewriteUsage(_ entries: [RewriteUsage]) -> [RewriteUsage] {
    var counts: [String: Int] = [:]
    for entry in entries {
        let key = "\(entry.path)\u{001F}\(entry.model)"
        counts[key, default: 0] += entry.count
    }
    return counts
        .map { key, count in
            let parts = key.split(separator: "\u{001F}", maxSplits: 1).map(String.init)
            return RewriteUsage(path: parts[0], model: parts.count > 1 ? parts[1] : "", count: count)
        }
        .sorted { ($0.count, $0.path, $0.model) > ($1.count, $1.path, $1.model) }
}

@main
struct VoxPerfAudit {
    static func main() async {
        do {
            let env = ProcessInfo.processInfo.environment
            let config = try PerfAuditConfig(arguments: Array(CommandLine.arguments.dropFirst()), environment: env)

            let fm = FileManager.default
            let cwd = URL(fileURLWithPath: fm.currentDirectoryPath, isDirectory: true)
            let dotenv = loadDotEnv(from: cwd.appendingPathComponent(".env.local"))
            let mergedEnv = mergedEnvironment(config.environment, dotenv: dotenv)

            var seenFixtureIDs: Set<String> = []
            var fixtures: [FixtureInput] = []
            for (index, audioURL) in config.audioURLs.enumerated() {
                let attrs = try? fm.attributesOfItem(atPath: audioURL.path)
                let audioBytes = attrs?[.size] as? Int ?? 0
                let baseFixtureID = {
                    let raw = audioURL.deletingPathExtension().lastPathComponent
                    return raw.isEmpty ? "fixture-\(index + 1)" : raw
                }()

                var fixtureID = baseFixtureID
                var suffix = 2
                while seenFixtureIDs.contains(fixtureID) {
                    fixtureID = "\(baseFixtureID)-\(suffix)"
                    suffix += 1
                }
                seenFixtureIDs.insert(fixtureID)
                fixtures.append(FixtureInput(id: fixtureID, audioURL: audioURL, audioBytes: audioBytes))
            }

            let iso = ISO8601DateFormatter()
            let generatedAt = iso.string(from: Date())

            var fixtureLevelResults = Array(repeating: [PerfLevelResult](), count: fixtures.count)
            var aggregatedLevelResults: [PerfLevelResult] = []
            var reportProviders: ResolvedProviders?

            for level in ProcessingLevel.allCases {
                var aggregateSamples = TimingSamples()
                var aggregateSTTUsage: [ProviderUsage] = []
                var aggregateRewriteUsage: [RewriteUsage] = []

                for (fixtureIndex, fixture) in fixtures.enumerated() {
                    let prefs = await MainActor.run { PerfPreferences(level: level, environment: mergedEnv) }

                    if config.warmupIterations > 0 {
                        let warmupCollector = TimingCollector()
                        let warmupUsageRecorder = ProviderUsageRecorder()
                        let warmupProviders = try resolvedProviders(
                            lane: config.lane,
                            level: level,
                            environment: mergedEnv,
                            usageRecorder: warmupUsageRecorder
                        )

                        let warmupPipeline = await MainActor.run {
                            DictationPipeline(
                                stt: warmupProviders.sttProvider,
                                rewriter: warmupProviders.rewriteProvider,
                                paster: NoopPaster(),
                                prefs: prefs,
                                enableRewriteCache: false,
                                enableOpus: warmupProviders.hasCloudSTT,
                                pipelineTimeout: 180,
                                timingHandler: { timing in
                                    warmupCollector.append(timing)
                                }
                            )
                        }

                        for _ in 0..<config.warmupIterations {
                            _ = try await warmupPipeline.process(audioURL: fixture.audioURL)
                        }
                    }

                    let collector = TimingCollector()
                    let usageRecorder = ProviderUsageRecorder()
                    let providers = try resolvedProviders(
                        lane: config.lane,
                        level: level,
                        environment: mergedEnv,
                        usageRecorder: usageRecorder
                    )
                    reportProviders = reportProviders ?? providers

                    let pipeline = await MainActor.run {
                        DictationPipeline(
                            stt: providers.sttProvider,
                            rewriter: providers.rewriteProvider,
                            paster: NoopPaster(),
                            prefs: prefs,
                            enableRewriteCache: false,
                            enableOpus: providers.hasCloudSTT,
                            pipelineTimeout: 180,
                            timingHandler: { timing in
                                collector.append(timing)
                            }
                        )
                    }

                    for _ in 0..<config.iterations {
                        _ = try await pipeline.process(audioURL: fixture.audioURL)
                    }

                    let timings = collector.timings
                    var fixtureSamples = TimingSamples()
                    fixtureSamples.append(timings)
                    aggregateSamples.append(timings)

                    let fixtureSTTUsage = usageRecorder.snapshotSTT()
                    aggregateSTTUsage.append(contentsOf: fixtureSTTUsage)

                    let fixtureRewriteUsage = usageRecorder.snapshotRewrite()
                    if level != .raw {
                        aggregateRewriteUsage.append(contentsOf: fixtureRewriteUsage)
                    }

                    fixtureLevelResults[fixtureIndex].append(
                        PerfLevelResult(
                            level: level.rawValue,
                            iterations: timings.count,
                            providers: PerfLevelProviders(
                                sttMode: providers.sttMode,
                                sttObserved: fixtureSTTUsage,
                                rewriteObserved: level == .raw ? nil : fixtureRewriteUsage
                            ),
                            distributions: distributions(from: fixtureSamples)
                        )
                    )
                }

                let providerMetadata = reportProviders
                let aggregatedRewriteObserved = level == .raw ? nil : mergeRewriteUsage(aggregateRewriteUsage)
                aggregatedLevelResults.append(
                    PerfLevelResult(
                        level: level.rawValue,
                        iterations: aggregateSamples.generationMs.count,
                        providers: PerfLevelProviders(
                            sttMode: providerMetadata?.sttMode ?? "—",
                            sttObserved: mergeSTTUsage(aggregateSTTUsage),
                            rewriteObserved: aggregatedRewriteObserved
                        ),
                        distributions: distributions(from: aggregateSamples)
                    )
                )
            }

            let providers: ResolvedProviders
            if let reportProviders {
                providers = reportProviders
            } else {
                providers = try resolvedProviders(
                    lane: config.lane,
                    level: .clean,
                    environment: mergedEnv,
                    usageRecorder: ProviderUsageRecorder()
                )
            }

            let fixtureDescriptors = fixtures.map {
                PerfFixtureDescriptor(id: $0.id, audioFile: $0.audioURL.lastPathComponent, audioBytes: $0.audioBytes)
            }
            let renderedFixtureResults = fixtures.enumerated().map { index, fixture in
                PerfFixtureResult(
                    fixtureID: fixture.id,
                    audioFile: fixture.audioURL.lastPathComponent,
                    audioBytes: fixture.audioBytes,
                    levels: fixtureLevelResults[index]
                )
            }

            let totalAudioBytes = fixtures.reduce(into: 0) { partialResult, fixture in
                partialResult += fixture.audioBytes
            }
            let audioFileSummary = fixtures.count == 1 ? fixtures[0].audioURL.lastPathComponent : "\(fixtures.count) fixtures"

            let result = PerfAuditResult(
                schemaVersion: 3,
                generatedAt: generatedAt,
                lane: config.lane.rawValue,
                commitSHA: config.commitSHA,
                pullRequestNumber: config.pullRequestNumber,
                label: config.runLabel,
                iterationsPerLevel: config.iterations,
                warmupIterationsPerLevel: config.warmupIterations,
                audioFile: audioFileSummary,
                audioBytes: totalAudioBytes,
                fixtures: fixtureDescriptors,
                fixtureResults: renderedFixtureResults,
                sttMode: providers.sttMode,
                sttSelectionPolicy: providers.sttSelectionPolicy,
                sttForcedProvider: providers.sttForcedProvider,
                sttChain: providers.sttChain,
                rewriteRouting: providers.rewriteRouting,
                levels: aggregatedLevelResults
            )

            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            let data = try encoder.encode(result)
            try fm.createDirectory(
                at: config.outputURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: config.outputURL, options: [.atomic])
        } catch {
            if let err = error as? PerfAuditError {
                switch err {
                case .helpRequested:
                    print(err.description)
                    exit(0)
                default:
                    fputs("\(err.description)\n", stderr)
                    exit(2)
                }
            } else {
                fputs("\(error)\n", stderr)
                exit(1)
            }
        }
    }
}
