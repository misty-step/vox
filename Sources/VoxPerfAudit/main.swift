import Foundation
import VoxPerfAuditKit
import VoxAppKit
import VoxCore
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

private struct PerfAuditResult: Codable {
    let schemaVersion: Int
    let generatedAt: String
    let commitSHA: String?
    let pullRequestNumber: Int?
    let label: String?
    let iterationsPerLevel: Int
    let audioFile: String
    let audioBytes: Int
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

private func resolvedProviders(
    environment: [String: String],
    usageRecorder: ProviderUsageRecorder
) throws -> ResolvedProviders {
    func key(_ name: String) -> String {
        environment[name]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    let plan = try PerfProviderPlan.resolve(environment: environment)

    struct STTEntry {
        let name: String
        let model: String
        let provider: STTProvider
    }

    var sttEntries: [STTEntry] = []
    for entry in plan.stt.chain {
        let apiKey = key(entry.apiKeyEnv)
        switch entry.id {
        case "elevenlabs":
            let eleven = ElevenLabsClient(apiKey: apiKey)
            let retried = RetryingSTTProvider(provider: eleven, maxRetries: 3, baseDelay: 0.5, name: entry.displayName)
            sttEntries.append(.init(
                name: entry.displayName,
                model: entry.model,
                provider: InstrumentedSTTProvider(provider: retried, providerName: entry.displayName, model: entry.model, recorder: usageRecorder)
            ))
        case "deepgram":
            let deepgram = DeepgramClient(apiKey: apiKey)
            let retried = RetryingSTTProvider(provider: deepgram, maxRetries: 2, baseDelay: 0.5, name: entry.displayName)
            sttEntries.append(.init(
                name: entry.displayName,
                model: entry.model,
                provider: InstrumentedSTTProvider(provider: retried, providerName: entry.displayName, model: entry.model, recorder: usageRecorder)
            ))
        default:
            throw PerfAuditError.invalidArgument("Unknown STT provider id '\(entry.id)'")
        }
    }

    let sttChain = sttEntries.dropFirst().reduce((name: sttEntries[0].name, provider: sttEntries[0].provider as STTProvider)) { accumulated, next in
        let wrapper = FallbackSTTProvider(
            primary: accumulated.provider,
            fallback: next.provider,
            primaryName: accumulated.name
        )
        return (name: "\(accumulated.name) + \(next.name)", provider: wrapper as STTProvider)
    }

    let maxConcurrent = Int(key("VOX_MAX_CONCURRENT_STT")) ?? 8
    let sttProvider = ConcurrencyLimitedSTTProvider(
        provider: sttChain.provider,
        maxConcurrent: max(1, maxConcurrent)
    )

    let openRouterKey = key("OPENROUTER_API_KEY")
    let geminiKey = key("GEMINI_API_KEY")

    let openRouter = OpenRouterClient(
        apiKey: openRouterKey,
        fallbackModels: [
            "google/gemini-2.5-flash",
            "google/gemini-2.0-flash-001",
        ],
        onModelUsed: { model, _ in
            usageRecorder.recordRewrite(path: "openrouter", model: model)
        }
    )

    let rewriteProvider: RewriteProvider
    let rewriteRouting: String
    if plan.rewrite.hasGeminiDirect {
        let gemini = GeminiClient(apiKey: geminiKey)
        let instrumentedGemini = InstrumentedRewriteProvider(
            provider: gemini,
            path: "gemini_direct",
            recorder: usageRecorder
        )
        rewriteProvider = ModelRoutedRewriteProvider(
            gemini: instrumentedGemini,
            openRouter: openRouter,
            fallbackGeminiModel: ProcessingLevel.defaultCleanRewriteModel
        )
        rewriteRouting = "model-routed (gemini_direct + openrouter)"
    } else {
        rewriteProvider = openRouter
        rewriteRouting = "openrouter"
    }

    return ResolvedProviders(
        sttProvider: sttProvider,
        sttSelectionPolicy: plan.stt.selectionPolicy,
        sttForcedProvider: plan.stt.forcedProvider,
        sttChain: sttEntries.map { ProviderDescriptor(provider: $0.name, model: $0.model) },
        sttMode: plan.stt.mode,
        rewriteProvider: rewriteProvider,
        rewriteRouting: rewriteRouting,
        hasCloudSTT: true
    )
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

            let audioAttrs = try? fm.attributesOfItem(atPath: config.audioURL.path)
            let audioBytes = audioAttrs?[.size] as? Int ?? 0

            let iso = ISO8601DateFormatter()
            let generatedAt = iso.string(from: Date())

            var levelResults: [PerfLevelResult] = []

            for level in ProcessingLevel.allCases {
                let prefs = await MainActor.run { PerfPreferences(level: level, environment: mergedEnv) }

                let paster = NoopPaster()
                let collector = TimingCollector()
                let usageRecorder = ProviderUsageRecorder()

                let providers = try resolvedProviders(environment: mergedEnv, usageRecorder: usageRecorder)

                let pipeline = await MainActor.run {
                    DictationPipeline(
                        stt: providers.sttProvider,
                        rewriter: providers.rewriteProvider,
                        paster: paster,
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
                    _ = try await pipeline.process(audioURL: config.audioURL)
                }

                let timings = collector.timings
                let encodeMs = timings.map { $0.encodeTime * 1000 }
                let sttMs = timings.map { $0.sttTime * 1000 }
                let rewriteMs = timings.map { $0.rewriteTime * 1000 }
                let pasteMs = timings.map { $0.pasteTime * 1000 }
                let generationMs = timings.map { ($0.encodeTime + $0.sttTime + $0.rewriteTime) * 1000 }
                let totalStageMs = timings.map { ($0.encodeTime + $0.sttTime + $0.rewriteTime + $0.pasteTime) * 1000 }

                let distributions = PerfLevelDistributions(
                    encodeMs: StageDistribution(samples: encodeMs),
                    sttMs: StageDistribution(samples: sttMs),
                    rewriteMs: StageDistribution(samples: rewriteMs),
                    pasteMs: StageDistribution(samples: pasteMs),
                    generationMs: StageDistribution(samples: generationMs),
                    totalStageMs: StageDistribution(samples: totalStageMs)
                )

                let rewriteObserved = level == .raw ? nil : usageRecorder.snapshotRewrite()
                levelResults.append(PerfLevelResult(
                    level: level.rawValue,
                    iterations: config.iterations,
                    providers: PerfLevelProviders(
                        sttMode: providers.sttMode,
                        sttObserved: usageRecorder.snapshotSTT(),
                        rewriteObserved: rewriteObserved
                    ),
                    distributions: distributions
                ))
            }

            let usageRecorder = ProviderUsageRecorder()
            let providers = try resolvedProviders(environment: mergedEnv, usageRecorder: usageRecorder)

            let result = PerfAuditResult(
                schemaVersion: 2,
                generatedAt: generatedAt,
                commitSHA: config.commitSHA,
                pullRequestNumber: config.pullRequestNumber,
                label: config.runLabel,
                iterationsPerLevel: config.iterations,
                audioFile: config.audioURL.lastPathComponent,
                audioBytes: audioBytes,
                sttMode: providers.sttMode,
                sttSelectionPolicy: providers.sttSelectionPolicy,
                sttForcedProvider: providers.sttForcedProvider,
                sttChain: providers.sttChain,
                rewriteRouting: providers.rewriteRouting,
                levels: levelResults
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
