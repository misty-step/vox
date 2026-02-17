import Foundation
import VoxAppKit
import VoxCore
import VoxProviders

private enum PerfAuditError: Error, CustomStringConvertible {
    case helpRequested
    case missingAudioPath
    case missingOutputPath
    case invalidArgument(String)
    case missingRequiredKey(String)

    var description: String {
        switch self {
        case .helpRequested:
            return PerfAuditConfig.usage()
        case .missingAudioPath:
            return "Missing --audio <path>."
        case .missingOutputPath:
            return "Missing --output <path>."
        case let .invalidArgument(message):
            return "Invalid argument: \(message)"
        case let .missingRequiredKey(name):
            return "Missing required API key: \(name)"
        }
    }
}

private struct PerfAuditConfig {
    let audioURL: URL
    let outputURL: URL
    let iterations: Int
    let commitSHA: String?
    let pullRequestNumber: Int?
    let runLabel: String?
    let environment: [String: String]

    static func usage() -> String {
        """
        Usage: swift run VoxPerfAudit --audio <path> --output <path> [options]

        Options:
          --audio <path>         Input audio file (CAF recommended).
          --output <path>        Output JSON path.
          --iterations <N>       Iterations per level (default: 3)
          --commit <sha>         Commit SHA (default: GITHUB_SHA if set)
          --pr <number>          Pull request number (optional)
          --label <string>       Run label (optional, e.g. "ci", "local")
          --help                 Show this message
        """
    }

    init(arguments: [String], environment: [String: String]) throws {
        var audioPath: String?
        var outputPath: String?
        var iterations = 3
        var commitSHA: String? = environment["GITHUB_SHA"]
        var pullRequestNumber: Int?
        var runLabel: String?

        var index = 0
        while index < arguments.count {
            let arg = arguments[index]
            switch arg {
            case "--help":
                throw PerfAuditError.helpRequested
            case "--audio":
                index += 1
                guard index < arguments.count else { throw PerfAuditError.invalidArgument("--audio needs a value") }
                audioPath = arguments[index]
            case "--output":
                index += 1
                guard index < arguments.count else { throw PerfAuditError.invalidArgument("--output needs a value") }
                outputPath = arguments[index]
            case "--iterations":
                index += 1
                guard index < arguments.count, let value = Int(arguments[index]), value > 0 else {
                    throw PerfAuditError.invalidArgument("--iterations needs an integer > 0")
                }
                iterations = value
            case "--commit":
                index += 1
                guard index < arguments.count else { throw PerfAuditError.invalidArgument("--commit needs a value") }
                commitSHA = arguments[index].trimmingCharacters(in: .whitespacesAndNewlines)
            case "--pr":
                index += 1
                guard index < arguments.count, let value = Int(arguments[index]), value > 0 else {
                    throw PerfAuditError.invalidArgument("--pr needs an integer > 0")
                }
                pullRequestNumber = value
            case "--label":
                index += 1
                guard index < arguments.count else { throw PerfAuditError.invalidArgument("--label needs a value") }
                let trimmed = arguments[index].trimmingCharacters(in: .whitespacesAndNewlines)
                runLabel = trimmed.isEmpty ? nil : trimmed
            default:
                throw PerfAuditError.invalidArgument("unknown option '\(arg)'")
            }
            index += 1
        }

        guard let audioPath else { throw PerfAuditError.missingAudioPath }
        guard let outputPath else { throw PerfAuditError.missingOutputPath }

        self.audioURL = Self.resolve(audioPath)
        self.outputURL = Self.resolve(outputPath)
        self.iterations = iterations
        self.commitSHA = commitSHA?.isEmpty == true ? nil : commitSHA
        self.pullRequestNumber = pullRequestNumber
        self.runLabel = runLabel
        self.environment = environment
    }

    private static func resolve(_ path: String) -> URL {
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        return URL(fileURLWithPath: path, relativeTo: cwd).standardizedFileURL
    }
}

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

private struct PerfLevelDistributions: Codable {
    let encodeMs: StageDistribution
    let sttMs: StageDistribution
    let rewriteMs: StageDistribution
    let pasteMs: StageDistribution
    let generationMs: StageDistribution
    let totalStageMs: StageDistribution
}

private struct PerfLevelResult: Codable {
    let level: String
    let iterations: Int
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
    let sttProvider: String
    let rewriteProvider: String
    let levels: [PerfLevelResult]
}

@MainActor
private final class PerfPreferences: PreferencesReading, @unchecked Sendable {
    var processingLevel: ProcessingLevel
    var selectedInputDeviceUID: String? = nil
    var elevenLabsAPIKey: String = ""
    var openRouterAPIKey: String = ""
    var deepgramAPIKey: String = ""
    var openAIAPIKey: String = ""
    var geminiAPIKey: String = ""

    init(level: ProcessingLevel) {
        self.processingLevel = level
    }
}

private final class NoopPaster: TextPaster, @unchecked Sendable {
    @MainActor
    func paste(text: String) async throws {}
}

private struct ResolvedProviders {
    let sttProvider: STTProvider
    let sttName: String
    let rewriteProvider: RewriteProvider
    let rewriteName: String
    let hasCloudSTT: Bool
}

private func resolvedProviders(
    environment: [String: String]
) throws -> ResolvedProviders {
    func configured(_ value: String) -> Bool {
        !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func key(_ name: String) -> String {
        environment[name]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    let elevenKey = key("ELEVENLABS_API_KEY")
    let deepgramKey = key("DEEPGRAM_API_KEY")
    let openAIKey = key("OPENAI_API_KEY")

    // STT: prefer ElevenLabs → Deepgram → Whisper. (AppleSpeech isn't viable in `swift run` without a bundle.)
    var sttEntries: [(name: String, provider: STTProvider)] = []

    if configured(elevenKey) {
        let eleven = ElevenLabsClient(apiKey: elevenKey)
        sttEntries.append((name: "ElevenLabs", provider: RetryingSTTProvider(provider: eleven, maxRetries: 3, baseDelay: 0.5, name: "ElevenLabs")))
    }
    if configured(deepgramKey) {
        let deepgram = DeepgramClient(apiKey: deepgramKey)
        sttEntries.append((name: "Deepgram", provider: RetryingSTTProvider(provider: deepgram, maxRetries: 2, baseDelay: 0.5, name: "Deepgram")))
    }
    if configured(openAIKey) {
        let whisper = WhisperClient(apiKey: openAIKey)
        sttEntries.append((name: "Whisper", provider: RetryingSTTProvider(provider: whisper, maxRetries: 2, baseDelay: 0.5, name: "Whisper")))
    }

    guard !sttEntries.isEmpty else {
        throw PerfAuditError.missingRequiredKey("ELEVENLABS_API_KEY (or DEEPGRAM_API_KEY / OPENAI_API_KEY)")
    }

    let sttChain = sttEntries.dropFirst().reduce(sttEntries[0]) { accumulated, next in
        let wrapper = FallbackSTTProvider(
            primary: accumulated.provider,
            fallback: next.provider,
            primaryName: accumulated.name
        )
        return (name: "\(accumulated.name) + \(next.name)", provider: wrapper as STTProvider)
    }

    let sttProvider = ConcurrencyLimitedSTTProvider(
        provider: sttChain.provider,
        maxConcurrent: 1  // perf audit is single-threaded; keep it deterministic.
    )

    // Rewrite: prefer OpenRouter (needed for polish default), optionally route Gemini direct when configured.
    let openRouterKey = key("OPENROUTER_API_KEY")
    let geminiKey = key("GEMINI_API_KEY")

    let openRouter: OpenRouterClient? = openRouterKey.isEmpty ? nil : OpenRouterClient(
        apiKey: openRouterKey,
        fallbackModels: [
            "google/gemini-2.5-flash",
            "google/gemini-2.0-flash-001",
        ]
    )
    let gemini: GeminiClient? = geminiKey.isEmpty ? nil : GeminiClient(apiKey: geminiKey)

    guard let openRouter else {
        throw PerfAuditError.missingRequiredKey("OPENROUTER_API_KEY")
    }

    let rewriteProvider: RewriteProvider
    let rewriteName: String
    if let gemini {
        rewriteProvider = ModelRoutedRewriteProvider(
            gemini: gemini,
            openRouter: openRouter,
            fallbackGeminiModel: ProcessingLevel.defaultCleanRewriteModel
        )
        rewriteName = "Gemini+OpenRouter"
    } else {
        rewriteProvider = openRouter
        rewriteName = "OpenRouter"
    }

    let hasCloudSTT = sttEntries.contains { $0.name != "Apple Speech" }
    return ResolvedProviders(
        sttProvider: sttProvider,
        sttName: sttChain.name,
        rewriteProvider: rewriteProvider,
        rewriteName: rewriteName,
        hasCloudSTT: hasCloudSTT
    )
}

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
            let audioAttrs = try? fm.attributesOfItem(atPath: config.audioURL.path)
            let audioBytes = audioAttrs?[.size] as? Int ?? 0

            let providers = try resolvedProviders(environment: config.environment)

            let iso = ISO8601DateFormatter()
            let generatedAt = iso.string(from: Date())

            var levelResults: [PerfLevelResult] = []

            for level in ProcessingLevel.allCases {
                let prefs = await MainActor.run { PerfPreferences(level: level) }

                let paster = NoopPaster()
                let collector = TimingCollector()

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

                levelResults.append(PerfLevelResult(
                    level: level.rawValue,
                    iterations: config.iterations,
                    distributions: distributions
                ))
            }

            let result = PerfAuditResult(
                schemaVersion: 1,
                generatedAt: generatedAt,
                commitSHA: config.commitSHA,
                pullRequestNumber: config.pullRequestNumber,
                label: config.runLabel,
                iterationsPerLevel: config.iterations,
                audioFile: config.audioURL.lastPathComponent,
                audioBytes: audioBytes,
                sttProvider: providers.sttName,
                rewriteProvider: providers.rewriteName,
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
                fputs("\(err.description)\n", stderr)
            } else {
                fputs("\(error)\n", stderr)
            }
            exit(1)
        }
    }
}
