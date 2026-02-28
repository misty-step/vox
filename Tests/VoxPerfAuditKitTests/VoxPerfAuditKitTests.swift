import Foundation
import Testing

import VoxPerfAuditKit

@Suite("PerfAuditConfig")
struct PerfAuditConfigTests {
    @Test("Parses required args and defaults")
    func test_init_parsesRequiredArgsAndDefaults() throws {
        let env = ["GITHUB_SHA": "deadbeef"]
        let cfg = try PerfAuditConfig(
            arguments: ["--audio", "fixture.caf", "--output", "out.json"],
            environment: env
        )

        #expect(cfg.audioURLs.map(\.lastPathComponent) == ["fixture.caf"])
        #expect(cfg.outputURL.lastPathComponent == "out.json")
        #expect(cfg.iterations == 3)
        #expect(cfg.warmupIterations == 1)
        #expect(cfg.lane == .provider)
        #expect(cfg.commitSHA == "deadbeef")
        #expect(cfg.pullRequestNumber == nil)
        #expect(cfg.runLabel == nil)
    }

    @Test("Parses iterations, commit, pr, and label")
    func test_init_parsesOptions() throws {
        let cfg = try PerfAuditConfig(
            arguments: [
                "--audio", "a.caf",
                "--audio", "b.caf",
                "--output", "b.json",
                "--iterations", "2",
                "--warmup", "0",
                "--lane", "codepath",
                "--commit", " abc123 ",
                "--pr", "42",
                "--label", " ci ",
            ],
            environment: [:]
        )

        #expect(cfg.audioURLs.map(\.lastPathComponent) == ["a.caf", "b.caf"])
        #expect(cfg.iterations == 2)
        #expect(cfg.warmupIterations == 0)
        #expect(cfg.lane == .codepath)
        #expect(cfg.commitSHA == "abc123")
        #expect(cfg.pullRequestNumber == 42)
        #expect(cfg.runLabel == "ci")
    }

    @Test("Treats empty label as nil")
    func test_init_emptyLabelIsNil() throws {
        let cfg = try PerfAuditConfig(
            arguments: ["--audio", "a.caf", "--output", "b.json", "--label", "   "],
            environment: [:]
        )
        #expect(cfg.runLabel == nil)
    }

    @Test("Help requested throws helpRequested")
    func test_init_helpThrows() {
        #expect(throws: PerfAuditError.helpRequested) {
            _ = try PerfAuditConfig(arguments: ["--help"], environment: [:])
        }
    }

    @Test("Invalid lane yields clear error")
    func test_init_throwsWhenLaneIsInvalid() {
        #expect(throws: PerfAuditError.invalidArgument("--lane must be one of provider|codepath")) {
            _ = try PerfAuditConfig(
                arguments: ["--audio", "a.caf", "--output", "b.json", "--lane", "network"],
                environment: [:]
            )
        }
    }

    @Test("Negative warmup yields clear error")
    func test_init_throwsWhenWarmupIsNegative() {
        #expect(throws: PerfAuditError.invalidArgument("--warmup needs an integer >= 0")) {
            _ = try PerfAuditConfig(
                arguments: ["--audio", "a.caf", "--output", "b.json", "--warmup", "-1"],
                environment: [:]
            )
        }
    }
}

@Suite("StageDistribution")
struct StageDistributionTests {
    @Test("Empty samples")
    func test_init_returnsZerosWhenSamplesAreEmpty() {
        let d = StageDistribution(samples: [])
        #expect(d.min == 0)
        #expect(d.max == 0)
        #expect(d.p50 == 0)
        #expect(d.p95 == 0)
    }

    @Test("Single sample")
    func test_init_returnsSampleValueWhenSingleSampleProvided() {
        let d = StageDistribution(samples: [10.0])
        #expect(d.min == 10)
        #expect(d.max == 10)
        #expect(d.p50 == 10)
        #expect(d.p95 == 10)
    }

    @Test("Interpolates percentiles")
    func test_percentiles_interpolatesBetweenBoundsWhenTwoSamplesProvided() {
        let d = StageDistribution(samples: [0.0, 100.0])
        #expect(d.p50 == 50)
        #expect(d.p95 == 95)
    }
}

@Suite("PerfProviderPlan")
struct PerfProviderPlanTests {
    @Test("Auto selects providers by preference order")
    func test_resolve_autoOrder() throws {
        let plan = try PerfProviderPlan.resolve(environment: [
            "OPENROUTER_API_KEY": "or",
            "ELEVENLABS_API_KEY": "el",
            "DEEPGRAM_API_KEY": "dg",
        ])

        #expect(plan.stt.mode == "batch")
        #expect(plan.stt.selectionPolicy == "auto")
        #expect(plan.stt.forcedProvider == nil)
        #expect(plan.stt.chain.map { $0.id } == ["elevenlabs", "deepgram"])
        #expect(plan.rewrite.routing == "openrouter")
        #expect(plan.rewrite.hasGeminiDirect == false)
        #expect(plan.rewrite.hasInceptionDirect == false)
    }

    @Test("Forced provider reorders chain")
    func test_resolve_forcedOrder() throws {
        let plan = try PerfProviderPlan.resolve(environment: [
            "OPENROUTER_API_KEY": "or",
            "ELEVENLABS_API_KEY": "el",
            "DEEPGRAM_API_KEY": "dg",
            "VOX_PERF_STT_PROVIDER": "deepgram",
        ])

        #expect(plan.stt.selectionPolicy == "forced")
        #expect(plan.stt.forcedProvider == "deepgram")
        #expect(plan.stt.chain.map { $0.id } == ["deepgram", "elevenlabs"])
    }

    @Test("Missing OPENROUTER_API_KEY fails fast")
    func test_resolve_missingOpenRouterKey() {
        #expect(throws: PerfAuditError.missingRequiredKey("OPENROUTER_API_KEY")) {
            _ = try PerfProviderPlan.resolve(environment: ["ELEVENLABS_API_KEY": "el"])
        }
    }

    @Test("Missing STT key fails fast")
    func test_resolve_missingSTTKeys() {
        #expect(throws: PerfAuditError.missingRequiredKey("ELEVENLABS_API_KEY (or DEEPGRAM_API_KEY)")) {
            _ = try PerfProviderPlan.resolve(environment: ["OPENROUTER_API_KEY": "or"])
        }
    }

    @Test("Forced provider with missing key yields precise error")
    func test_resolve_forcedProviderMissingKey() {
        #expect(throws: PerfAuditError.missingRequiredKey("ELEVENLABS_API_KEY")) {
            _ = try PerfProviderPlan.resolve(environment: [
                "OPENROUTER_API_KEY": "or",
                "DEEPGRAM_API_KEY": "dg",
                "VOX_PERF_STT_PROVIDER": "elevenlabs",
            ])
        }
    }

    @Test("Unknown forced provider fails with allowed-values hint")
    func test_resolve_unknownForcedProvider() {
        #expect(throws: PerfAuditError.invalidArgument("Unknown VOX_PERF_STT_PROVIDER 'whisper'; use auto|elevenlabs|deepgram")) {
            _ = try PerfProviderPlan.resolve(environment: [
                "OPENROUTER_API_KEY": "or",
                "ELEVENLABS_API_KEY": "el",
                "VOX_PERF_STT_PROVIDER": "whisper",
            ])
        }
    }

    @Test("Forced provider matching is case-insensitive")
    func test_resolve_forcedProviderCaseInsensitive() throws {
        let plan = try PerfProviderPlan.resolve(environment: [
            "OPENROUTER_API_KEY": "or",
            "ELEVENLABS_API_KEY": "el",
            "DEEPGRAM_API_KEY": "dg",
            "VOX_PERF_STT_PROVIDER": "DeepGram",
        ])

        #expect(plan.stt.selectionPolicy == "forced")
        #expect(plan.stt.forcedProvider == "deepgram")
        #expect(plan.stt.chain.map { $0.id } == ["deepgram", "elevenlabs"])
    }

    @Test("Gemini key enables model-routed rewrite")
    func test_resolve_geminiEnablesModelRouted() throws {
        let plan = try PerfProviderPlan.resolve(environment: [
            "OPENROUTER_API_KEY": "or",
            "ELEVENLABS_API_KEY": "el",
            "GEMINI_API_KEY": "g",
        ])

        #expect(plan.rewrite.routing == "model-routed")
        #expect(plan.rewrite.hasGeminiDirect == true)
        #expect(plan.rewrite.hasInceptionDirect == false)
    }
}
