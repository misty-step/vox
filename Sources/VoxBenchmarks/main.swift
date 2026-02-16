import Darwin
import Foundation
import VoxCore
import VoxProviders

private enum BenchmarkError: Error, CustomStringConvertible {
    case helpRequested
    case missingAPIKey
    case invalidArgument(String)
    case invalidCorpus(String)

    var description: String {
        switch self {
        case .helpRequested:
            return BenchmarkConfig.usage()
        case .missingAPIKey:
            return "Missing OPENROUTER_API_KEY (export it or add it to your shell env)."
        case let .invalidArgument(message):
            return "Invalid argument: \(message)"
        case let .invalidCorpus(message):
            return "Invalid corpus: \(message)"
        }
    }
}

private struct BenchmarkConfig {
    static let defaultModels: [String] = [
        "google/gemini-2.5-flash-lite",
        "google/gemini-2.5-flash",
        "google/gemini-2.0-flash-lite-001",
        "google/gemini-2.0-flash-001",
        "openai/gpt-4o-mini",
        "openai/gpt-4.1-nano",
        "anthropic/claude-haiku-4.5",
        "mistralai/ministral-8b-2512",
        "mistralai/ministral-3b-2512",
        "meta-llama/llama-3.1-8b-instruct",
        "xiaomi/mimo-v2-flash",
        "nvidia/nemotron-nano-9b-v2",
        "inception/mercury",
    ]

    let apiKey: String
    let models: [String]
    let corpusPath: URL
    let outputJSONPath: URL
    let outputMarkdownPath: URL
    let iterations: Int
    let runTimestamp: Date

    static func usage() -> String {
        """
        Usage: swift run VoxBenchmarks [options]

        Options:
          --corpus <path>        Corpus JSON path (default: docs/performance/rewrite-corpus.json)
          --output-json <path>   Raw results JSON path
          --output-md <path>     Markdown report path
          --iterations <N>       Iterations per model+sample (default: 2)
          --models <csv>         Comma-separated model ids
          --help                 Show this message
        """
    }

    init(arguments: [String], environment: [String: String]) throws {
        guard let apiKey = environment["OPENROUTER_API_KEY"], !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw BenchmarkError.missingAPIKey
        }

        let dayStamp = Self.dayStampString(for: Date())
        var corpusPath = Self.resolve("docs/performance/rewrite-corpus.json")
        var outputJSONPath = Self.resolve("docs/performance/rewrite-benchmark-results-\(dayStamp).json")
        var outputMarkdownPath = Self.resolve("docs/performance/rewrite-model-bakeoff-\(dayStamp).md")
        var iterations = 2
        var models = Self.defaultModels

        var index = 0
        while index < arguments.count {
            let argument = arguments[index]
            switch argument {
            case "--help":
                throw BenchmarkError.helpRequested
            case "--corpus":
                index += 1
                guard index < arguments.count else {
                    throw BenchmarkError.invalidArgument("--corpus needs a value")
                }
                corpusPath = Self.resolve(arguments[index])
            case "--output-json":
                index += 1
                guard index < arguments.count else {
                    throw BenchmarkError.invalidArgument("--output-json needs a value")
                }
                outputJSONPath = Self.resolve(arguments[index])
            case "--output-md":
                index += 1
                guard index < arguments.count else {
                    throw BenchmarkError.invalidArgument("--output-md needs a value")
                }
                outputMarkdownPath = Self.resolve(arguments[index])
            case "--iterations":
                index += 1
                guard index < arguments.count, let value = Int(arguments[index]), value > 0 else {
                    throw BenchmarkError.invalidArgument("--iterations needs an integer > 0")
                }
                iterations = value
            case "--models":
                index += 1
                guard index < arguments.count else {
                    throw BenchmarkError.invalidArgument("--models needs a comma-separated value")
                }
                let parsed = arguments[index]
                    .split(separator: ",")
                    .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
                guard !parsed.isEmpty else {
                    throw BenchmarkError.invalidArgument("--models resolved to an empty set")
                }
                models = parsed
            default:
                throw BenchmarkError.invalidArgument("unknown option '\(argument)'")
            }
            index += 1
        }

        self.apiKey = apiKey
        self.models = models
        self.corpusPath = corpusPath
        self.outputJSONPath = outputJSONPath
        self.outputMarkdownPath = outputMarkdownPath
        self.iterations = iterations
        self.runTimestamp = Date()
    }

    private static func dayStampString(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func resolve(_ path: String) -> URL {
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        return URL(fileURLWithPath: path, relativeTo: cwd).standardizedFileURL
    }
}

private struct CorpusFile: Decodable {
    let version: Int
    let entries: [CorpusEntry]
}

private struct CorpusEntry: Decodable, Sendable {
    let id: String
    let level: ProcessingLevel
    let transcript: String
    let notes: String?
}

private struct OpenRouterRequest: Encodable {
    struct Message: Encodable {
        let role: String
        let content: String
    }

    struct Reasoning: Encodable {
        let enabled: Bool
    }

    let model: String
    let messages: [Message]
    let reasoning: Reasoning
}

private struct OpenRouterResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String
        }

        let message: Message
    }

    struct Usage: Decodable {
        let promptTokens: Int?
        let completionTokens: Int?
        let totalTokens: Int?
        let cost: Double?

        enum CodingKeys: String, CodingKey {
            case promptTokens = "prompt_tokens"
            case completionTokens = "completion_tokens"
            case totalTokens = "total_tokens"
            case cost
        }
    }

    struct ErrorPayload: Decodable {
        let message: String?
    }

    let choices: [Choice]
    let usage: Usage?
    let error: ErrorPayload?
}

private struct InvocationResult {
    let text: String
    let usage: OpenRouterResponse.Usage?
}

private final class OpenRouterBenchmarkClient {
    private let apiKey: String
    private let session: URLSession

    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    func rewrite(transcript: String, prompt: String, model: String) async throws -> InvocationResult {
        let requestPayload = OpenRouterRequest(
            model: model,
            messages: [
                .init(role: "system", content: prompt),
                .init(role: "user", content: transcript),
            ],
            reasoning: .init(enabled: false)
        )

        let encoder = JSONEncoder()
        let bodyData = try encoder.encode(requestPayload)

        var request = URLRequest(url: URL(string: "https://openrouter.ai/api/v1/chat/completions")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 60
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("https://github.com/misty-step/vox", forHTTPHeaderField: "HTTP-Referer")
        request.setValue("Vox", forHTTPHeaderField: "X-Title")
        request.httpBody = bodyData

        let (data, response) = try await withTimeout(seconds: 60) {
            try await self.session.data(for: request)
        }

        guard let http = response as? HTTPURLResponse else {
            throw RewriteError.network("OpenRouter invalid response")
        }

        let decoder = JSONDecoder()
        let payload = try decoder.decode(OpenRouterResponse.self, from: data)

        guard http.statusCode == 200 else {
            let detail = payload.error?.message ?? String(data: data, encoding: .utf8) ?? "unknown error"
            switch http.statusCode {
            case 401: throw RewriteError.auth
            case 429: throw RewriteError.throttled
            default: throw RewriteError.unknown("OpenRouter HTTP \(http.statusCode): \(detail)")
            }
        }

        guard let text = payload.choices.first?.message.content else {
            throw RewriteError.unknown("OpenRouter response missing choice text")
        }

        return InvocationResult(text: text, usage: payload.usage)
    }
}

private struct BenchmarkInvocation: Codable {
    let model: String
    let level: ProcessingLevel
    let entryID: String
    let iteration: Int
    let latencySeconds: Double
    let costUSD: Double?
    let promptTokens: Int?
    let completionTokens: Int?
    let qualityPass: Bool
    let qualityRatio: Double
    let responseText: String
    let error: String?
}

private struct Distribution: Codable {
    let count: Int
    let p50: Double
    let p95: Double
    let min: Double
    let max: Double
    let mean: Double

    init(values: [Double]) {
        guard !values.isEmpty else {
            self.count = 0
            self.p50 = 0
            self.p95 = 0
            self.min = 0
            self.max = 0
            self.mean = 0
            return
        }

        self.count = values.count
        let sorted = values.sorted()
        self.p50 = Self.percentile(sorted, quantile: 0.5)
        self.p95 = Self.percentile(sorted, quantile: 0.95)
        self.min = sorted.first ?? 0
        self.max = sorted.last ?? 0
        self.mean = values.reduce(0, +) / Double(values.count)
    }

    private static func percentile(_ sorted: [Double], quantile: Double) -> Double {
        guard sorted.count > 1 else { return sorted[0] }
        let rank = quantile * Double(sorted.count - 1)
        let lower = Int(rank.rounded(.down))
        let upper = Int(rank.rounded(.up))
        if lower == upper { return sorted[lower] }
        let fraction = rank - Double(lower)
        return sorted[lower] + ((sorted[upper] - sorted[lower]) * fraction)
    }
}

private struct ModelLevelSummary: Codable {
    let model: String
    let level: ProcessingLevel
    let samples: Int
    let errorRate: Double
    let qualityPassRate: Double
    let nonEmptyRate: Double
    let latency: Distribution
    let cost: Distribution?
}

private struct CandidateScore: Codable {
    let model: String
    let qualityPassRate: Double
    let latencyP95: Double
    let meanCostUSD: Double?
}

private struct LevelRecommendation: Codable {
    let level: ProcessingLevel
    let qualityTarget: Double
    let selectedModel: String
    let rationale: String
    let candidates: [CandidateScore]
}

private struct ManualSpotCheck: Codable {
    let level: ProcessingLevel
    let entryID: String
    let model: String
    let transcript: String
    let rewritten: String
}

private struct BenchmarkArtifact: Codable {
    let generatedAt: String
    let iterationsPerSample: Int
    let models: [String]
    let corpusPath: String
    let corpusEntries: Int
    let invocations: [BenchmarkInvocation]
    let summaries: [ModelLevelSummary]
    let recommendations: [LevelRecommendation]
    let spotChecks: [ManualSpotCheck]
}

private struct BenchmarkRunner {
    private static let benchmarkLevels: [ProcessingLevel] = [.clean, .polish]
    private static let qualityTargets: [ProcessingLevel: Double] = [
        .clean: 0.95,
        .polish: 0.90,
    ]

    private let config: BenchmarkConfig
    private let corpus: [CorpusEntry]
    private let client: OpenRouterBenchmarkClient

    init(config: BenchmarkConfig, corpus: [CorpusEntry], client: OpenRouterBenchmarkClient) {
        self.config = config
        self.corpus = corpus
        self.client = client
    }

    func run() async throws -> BenchmarkArtifact {
        var invocations: [BenchmarkInvocation] = []
        invocations.reserveCapacity(config.models.count * corpus.count * config.iterations)

        for model in config.models {
            for entry in corpus {
                for iteration in 1...config.iterations {
                    let prompt = RewritePrompts.prompt(for: entry.level)
                    let startedAt = DispatchTime.now().uptimeNanoseconds

                    let record: BenchmarkInvocation
                    do {
                        let success = try await retrying(maxAttempts: 3, baseDelaySeconds: 0.5) {
                            try await client.rewrite(transcript: entry.transcript, prompt: prompt, model: model)
                        }

                        let endedAt = DispatchTime.now().uptimeNanoseconds
                        let latencySeconds = Double(endedAt - startedAt) / 1_000_000_000

                        let decision = RewriteQualityGate.evaluate(
                            raw: entry.transcript,
                            candidate: success.text,
                            level: entry.level
                        )

                        record = BenchmarkInvocation(
                            model: model,
                            level: entry.level,
                            entryID: entry.id,
                            iteration: iteration,
                            latencySeconds: latencySeconds,
                            costUSD: success.usage?.cost,
                            promptTokens: success.usage?.promptTokens,
                            completionTokens: success.usage?.completionTokens,
                            qualityPass: decision.isAcceptable,
                            qualityRatio: decision.ratio,
                            responseText: success.text,
                            error: nil
                        )
                    } catch {
                        let endedAt = DispatchTime.now().uptimeNanoseconds
                        let latencySeconds = Double(endedAt - startedAt) / 1_000_000_000

                        let decision = RewriteQualityGate.evaluate(
                            raw: entry.transcript,
                            candidate: "",
                            level: entry.level
                        )

                        record = BenchmarkInvocation(
                            model: model,
                            level: entry.level,
                            entryID: entry.id,
                            iteration: iteration,
                            latencySeconds: latencySeconds,
                            costUSD: nil,
                            promptTokens: nil,
                            completionTokens: nil,
                            qualityPass: decision.isAcceptable,
                            qualityRatio: decision.ratio,
                            responseText: "",
                            error: error.localizedDescription
                        )
                    }

                    invocations.append(record)

                    let costText = record.costUSD.map { String(format: "$%.6f", $0) } ?? "n/a"
                    let errorText = record.error.map { " error=\($0)" } ?? ""
                    print(
                        String(
                            format: "[Benchmark] level=%@ model=%@ sample=%@ iter=%d latency=%.3fs quality=%@ ratio=%.2f cost=%@%@",
                            entry.level.rawValue,
                            model,
                            entry.id,
                            iteration,
                            record.latencySeconds,
                            record.qualityPass ? "pass" : "fail",
                            record.qualityRatio,
                            costText,
                            errorText
                        )
                    )
                }
            }
        }

        let summaries = buildSummaries(from: invocations)
        let recommendations = buildRecommendations(from: summaries)
        let spotChecks = buildSpotChecks(invocations: invocations, recommendations: recommendations)

        let formatter = ISO8601DateFormatter()
        let artifact = BenchmarkArtifact(
            generatedAt: formatter.string(from: config.runTimestamp),
            iterationsPerSample: config.iterations,
            models: config.models,
            corpusPath: config.corpusPath.path,
            corpusEntries: corpus.count,
            invocations: invocations,
            summaries: summaries,
            recommendations: recommendations,
            spotChecks: spotChecks
        )
        return artifact
    }

    private func buildSummaries(from invocations: [BenchmarkInvocation]) -> [ModelLevelSummary] {
        struct SummaryKey: Hashable {
            let model: String
            let level: ProcessingLevel
        }

        let grouped = Dictionary(grouping: invocations) { SummaryKey(model: $0.model, level: $0.level) }
        let sortedKeys = grouped.keys.sorted {
            if $0.level.rawValue == $1.level.rawValue {
                return $0.model < $1.model
            }
            return $0.level.rawValue < $1.level.rawValue
        }

        return sortedKeys.compactMap { key in
            guard let rows = grouped[key], !rows.isEmpty else { return nil }
            let errorCount = rows.filter { $0.error != nil }.count
            let passCount = rows.filter(\.qualityPass).count
            let nonEmptyCount = rows.filter { !$0.responseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
            let latencyValues = rows.map(\.latencySeconds)
            let costValues = rows.compactMap(\.costUSD)
            return ModelLevelSummary(
                model: key.model,
                level: key.level,
                samples: rows.count,
                errorRate: Double(errorCount) / Double(rows.count),
                qualityPassRate: Double(passCount) / Double(rows.count),
                nonEmptyRate: Double(nonEmptyCount) / Double(rows.count),
                latency: Distribution(values: latencyValues),
                cost: costValues.isEmpty ? nil : Distribution(values: costValues)
            )
        }
    }

    private func buildRecommendations(from summaries: [ModelLevelSummary]) -> [LevelRecommendation] {
        Self.benchmarkLevels.map { level in
            let perLevel = summaries
                .filter { $0.level == level }
                .sorted { lhs, rhs in
                    if lhs.qualityPassRate == rhs.qualityPassRate {
                        if lhs.latency.p95 == rhs.latency.p95 {
                            return costMean(lhs) < costMean(rhs)
                        }
                        return lhs.latency.p95 < rhs.latency.p95
                    }
                    return lhs.qualityPassRate > rhs.qualityPassRate
                }

            let qualityTarget = Self.qualityTargets[level] ?? 0.0
            let eligible = perLevel.filter { $0.qualityPassRate >= qualityTarget }
            let winner: ModelLevelSummary? = {
                if eligible.isEmpty {
                    return perLevel.first
                }
                return eligible.min(by: { lhs, rhs in
                    if lhs.latency.p95 == rhs.latency.p95 {
                        return costMean(lhs) < costMean(rhs)
                    }
                    return lhs.latency.p95 < rhs.latency.p95
                })
            }()

            let candidateScores = perLevel.map {
                CandidateScore(
                    model: $0.model,
                    qualityPassRate: $0.qualityPassRate,
                    latencyP95: $0.latency.p95,
                    meanCostUSD: $0.cost?.mean
                )
            }

            let selectedModel = winner?.model ?? ""
            let rationale: String = {
                guard let winner else { return "no candidates" }

                let costText = winner.cost.map { String(format: "$%.6f", $0.mean) } ?? "n/a"
                if eligible.isEmpty {
                    return String(
                        format: "no model met quality target %.0f%%; picked best available (pass %.1f%%, p95 %.3fs, mean cost %@)",
                        qualityTarget * 100.0,
                        winner.qualityPassRate * 100.0,
                        winner.latency.p95,
                        costText
                    )
                }

                return String(
                    format: "passed quality target %.0f%%; best p95 latency %.3fs; mean cost %@",
                    qualityTarget * 100.0,
                    winner.latency.p95,
                    costText
                )
            }()

            return LevelRecommendation(
                level: level,
                qualityTarget: qualityTarget,
                selectedModel: selectedModel,
                rationale: rationale,
                candidates: candidateScores
            )
        }
    }

    private func buildSpotChecks(
        invocations: [BenchmarkInvocation],
        recommendations: [LevelRecommendation]
    ) -> [ManualSpotCheck] {
        recommendations.compactMap { recommendation in
            guard
                let row = invocations.first(where: {
                    $0.level == recommendation.level && $0.model == recommendation.selectedModel && $0.qualityPass
                }) ?? invocations.first(where: {
                    $0.level == recommendation.level && $0.model == recommendation.selectedModel
                }),
                let corpusEntry = corpus.first(where: { $0.id == row.entryID })
            else {
                return nil
            }

            return ManualSpotCheck(
                level: recommendation.level,
                entryID: row.entryID,
                model: recommendation.selectedModel,
                transcript: corpusEntry.transcript,
                rewritten: row.responseText
            )
        }
    }
}

private func retrying<T>(
    maxAttempts: Int,
    baseDelaySeconds: TimeInterval,
    operation: () async throws -> T
) async throws -> T {
    precondition(maxAttempts > 0)
    var attempt = 0
    while true {
        attempt += 1
        do {
            return try await operation()
        } catch {
            if attempt >= maxAttempts || !isRetryable(error) {
                throw error
            }
            let delay = baseDelaySeconds * pow(2.0, Double(attempt - 1))
            try await Task.sleep(nanoseconds: clampedNanoseconds(for: delay))
        }
    }
}

private func withTimeout<T>(
    seconds: TimeInterval,
    operation: @escaping () async throws -> T
) async throws -> T {
    try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask { try await operation() }
        group.addTask {
            try await Task.sleep(nanoseconds: clampedNanoseconds(for: seconds))
            throw RewriteError.timeout
        }

        let result = try await group.next()
        group.cancelAll()

        guard let result else {
            throw RewriteError.unknown("withTimeout: no result")
        }

        return result
    }
}

private func clampedNanoseconds(for seconds: TimeInterval) -> UInt64 {
    let value = seconds * 1_000_000_000
    guard value.isFinite, value > 0 else { return 0 }
    if value >= Double(UInt64.max) { return UInt64.max }
    return UInt64(value)
}

private func isRetryable(_ error: Error) -> Bool {
    if let rewriteError = error as? RewriteError {
        switch rewriteError {
        case .throttled, .timeout, .network:
            return true
        case .auth, .quotaExceeded, .invalidRequest, .unknown:
            return false
        }
    }

    if error is URLError { return true }
    return false
}

private func costMean(_ summary: ModelLevelSummary) -> Double {
    summary.cost?.mean ?? Double.greatestFiniteMagnitude
}

private func loadCorpus(from path: URL) throws -> [CorpusEntry] {
    let data = try Data(contentsOf: path)
    let decoded = try JSONDecoder().decode(CorpusFile.self, from: data)
    guard decoded.version == 1 else {
        throw BenchmarkError.invalidCorpus("unsupported version \(decoded.version); expected 1")
    }

    let filtered = decoded.entries.filter { [.clean, .polish].contains($0.level) }
    guard !filtered.isEmpty else {
        throw BenchmarkError.invalidCorpus("no benchmark entries for clean/polish")
    }

    for level in [ProcessingLevel.clean, .polish] {
        guard filtered.contains(where: { $0.level == level }) else {
            throw BenchmarkError.invalidCorpus("missing entries for level '\(level.rawValue)'")
        }
    }

    return filtered
}

private func writeJSON(_ artifact: BenchmarkArtifact, to path: URL) throws {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    let data = try encoder.encode(artifact)
    try ensureDirectoryExists(for: path)
    try data.write(to: path)
}

private func writeMarkdown(_ artifact: BenchmarkArtifact, to path: URL) throws {
    let body = BenchmarkReportMarkdown.render(artifact: artifact)
    try ensureDirectoryExists(for: path)
    try body.data(using: .utf8)?.write(to: path)
}

private func ensureDirectoryExists(for filePath: URL) throws {
    let directory = filePath.deletingLastPathComponent()
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
}

private enum BenchmarkReportMarkdown {
    static func render(artifact: BenchmarkArtifact) -> String {
        let recommendationsByLevel = Dictionary(uniqueKeysWithValues: artifact.recommendations.map { ($0.level, $0) })
        let summariesByLevel = Dictionary(grouping: artifact.summaries, by: \.level)

        var lines: [String] = []
        lines.append("# Rewrite Model Bakeoff")
        lines.append("")
        lines.append("- Generated: \(artifact.generatedAt)")
        lines.append("- Iterations per sample: \(artifact.iterationsPerSample)")
        lines.append("- Corpus entries: \(artifact.corpusEntries)")
        lines.append("- Candidate models: \(artifact.models.joined(separator: ", "))")
        lines.append("")
        lines.append("## Methodology")
        lines.append("- Uses production rewrite prompts from `RewritePrompts` per processing level.")
        lines.append("- Evaluates quality with `RewriteQualityGate` pass/fail and ratio checks.")
        lines.append("- Measures wall-clock request latency and OpenRouter-reported request cost.")
        lines.append("- Decision rule: filter by quality target, pick lowest p95 latency, tie-break by mean cost.")
        lines.append("")

        for level in [ProcessingLevel.clean, .polish] {
            lines.append("## \(level.rawValue.capitalized) Results")
            lines.append("")
            lines.append("| Model | Quality pass | Errors | Non-empty | Latency p50 | Latency p95 | Mean cost | Cost p95 |")
            lines.append("| --- | --- | --- | --- | --- | --- | --- | --- |")

            let sorted = (summariesByLevel[level] ?? []).sorted {
                if $0.qualityPassRate == $1.qualityPassRate {
                    return $0.latency.p95 < $1.latency.p95
                }
                return $0.qualityPassRate > $1.qualityPassRate
            }

            for row in sorted {
                let meanCostText = row.cost.map { String(format: "$%.6f", $0.mean) } ?? "n/a"
                let p95CostText = row.cost.map { String(format: "$%.6f", $0.p95) } ?? "n/a"
                lines.append(
                    String(
                        format: "| `%@` | %.1f%% | %.1f%% | %.1f%% | %.3fs | %.3fs | %@ | %@ |",
                        row.model,
                        row.qualityPassRate * 100.0,
                        row.errorRate * 100.0,
                        row.nonEmptyRate * 100.0,
                        row.latency.p50,
                        row.latency.p95,
                        meanCostText,
                        p95CostText
                    )
                )
            }

            if let recommendation = recommendationsByLevel[level] {
                lines.append("")
                lines.append("- Recommendation: `\(recommendation.selectedModel)`")
                lines.append("- Rationale: \(recommendation.rationale)")
                lines.append("- Quality target: \(Int(recommendation.qualityTarget * 100))%")
            }

            lines.append("")
        }

        lines.append("## Manual Spot Checks")
        lines.append("")
        for check in artifact.spotChecks {
            lines.append("### \(check.level.rawValue.capitalized) (`\(check.model)` / sample `\(check.entryID)`)")
            lines.append("")
            lines.append("- Transcript:")
            lines.append("")
            lines.append("```")
            lines.append(check.transcript)
            lines.append("```")
            lines.append("")
            lines.append("- Rewritten:")
            lines.append("")
            lines.append("```")
            lines.append(check.rewritten)
            lines.append("```")
            lines.append("")
        }

        lines.append("## Rollback Plan")
        lines.append("")
        lines.append("- Trigger: rewrite quality complaints increase or quality-gate fallback rate regresses after rollout.")
        lines.append("- Immediate rollback: restore prior defaults in `Sources/VoxCore/ProcessingLevel.swift`.")
        lines.append("- Validation after rollback: run strict build/tests and compare rewrite latency logs against baseline.")
        lines.append("")
        lines.append("## Raw Artifact")
        lines.append("")
        lines.append("- `\(artifact.corpusPath)`")
        lines.append("- JSON results committed separately in `docs/performance/` for reproducibility.")

        return lines.joined(separator: "\n")
    }
}

@main
enum VoxBenchmarksMain {
    static func main() async {
        do {
            let config = try BenchmarkConfig(
                arguments: Array(CommandLine.arguments.dropFirst()),
                environment: ProcessInfo.processInfo.environment
            )

            let corpus = try loadCorpus(from: config.corpusPath)
            let runner = BenchmarkRunner(
                config: config,
                corpus: corpus,
                client: OpenRouterBenchmarkClient(apiKey: config.apiKey)
            )
            let artifact = try await runner.run()

            try writeJSON(artifact, to: config.outputJSONPath)
            try writeMarkdown(artifact, to: config.outputMarkdownPath)

            print("")
            print("[Benchmark] JSON artifact: \(config.outputJSONPath.path)")
            print("[Benchmark] Markdown report: \(config.outputMarkdownPath.path)")
            print("[Benchmark] Recommendations:")
            for recommendation in artifact.recommendations {
                print("- \(recommendation.level.rawValue): \(recommendation.selectedModel)")
            }
        } catch BenchmarkError.helpRequested {
            print(BenchmarkConfig.usage())
            Darwin.exit(0)
        } catch let error as BenchmarkError {
            let message = error.description
            fputs("[Benchmark] \(message)\n", stderr)
            if case .invalidArgument = error {
                fputs("\(BenchmarkConfig.usage())\n", stderr)
            }
            Darwin.exit(1)
        } catch {
            fputs("[Benchmark] \(error)\n", stderr)
            Darwin.exit(1)
        }
    }
}
