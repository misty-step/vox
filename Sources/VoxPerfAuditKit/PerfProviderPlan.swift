import Foundation

package struct PerfSTTProviderPlan: Sendable, Codable, Equatable {
    package let id: String
    package let displayName: String
    package let model: String
    package let apiKeyEnv: String
}

package struct PerfSTTPlan: Sendable, Codable, Equatable {
    package let mode: String
    package let selectionPolicy: String
    package let forcedProvider: String?
    package let chain: [PerfSTTProviderPlan]
}

package struct PerfRewritePlan: Sendable, Codable, Equatable {
    package let routing: String
    package let hasGeminiDirect: Bool
}

package struct PerfProviderPlan: Sendable, Codable, Equatable {
    package let stt: PerfSTTPlan
    package let rewrite: PerfRewritePlan

    package static func resolve(environment: [String: String]) throws -> PerfProviderPlan {
        func configured(_ value: String) -> Bool {
            !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        func key(_ name: String) -> String {
            environment[name]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        }

        let forcedSTT = key("VOX_PERF_STT_PROVIDER").lowercased()
        let sttSelectionPolicy = forcedSTT.isEmpty || forcedSTT == "auto" ? "auto" : "forced"
        let sttForcedProvider: String? = sttSelectionPolicy == "forced" ? forcedSTT : nil

        let elevenKey = key("ELEVENLABS_API_KEY")
        let deepgramKey = key("DEEPGRAM_API_KEY")

        var sttChain: [PerfSTTProviderPlan] = []
        if configured(elevenKey) {
            sttChain.append(.init(id: "elevenlabs", displayName: "ElevenLabs", model: "scribe_v2", apiKeyEnv: "ELEVENLABS_API_KEY"))
        }
        if configured(deepgramKey) {
            sttChain.append(.init(id: "deepgram", displayName: "Deepgram", model: "nova-3", apiKeyEnv: "DEEPGRAM_API_KEY"))
        }

        if sttSelectionPolicy == "forced" {
            guard let forced = sttForcedProvider else {
                throw PerfAuditError.invalidArgument("Invalid VOX_PERF_STT_PROVIDER")
            }
            guard let forcedEntry = sttChain.first(where: { $0.id == forced }) else {
                switch forced {
                case "elevenlabs":
                    throw PerfAuditError.missingRequiredKey("ELEVENLABS_API_KEY")
                case "deepgram":
                    throw PerfAuditError.missingRequiredKey("DEEPGRAM_API_KEY")
                default:
                    throw PerfAuditError.invalidArgument("Unknown VOX_PERF_STT_PROVIDER '\(forced)'; use auto|elevenlabs|deepgram")
                }
            }
            sttChain = [forcedEntry] + sttChain.filter { $0.id != forcedEntry.id }
        }

        guard !sttChain.isEmpty else {
            throw PerfAuditError.missingRequiredKey("ELEVENLABS_API_KEY (or DEEPGRAM_API_KEY)")
        }

        let openRouterKey = key("OPENROUTER_API_KEY")
        guard configured(openRouterKey) else {
            throw PerfAuditError.missingRequiredKey("OPENROUTER_API_KEY")
        }

        let geminiKey = key("GEMINI_API_KEY")
        let hasGeminiDirect = configured(geminiKey)
        let rewriteRouting = hasGeminiDirect ? "model-routed" : "openrouter"

        return PerfProviderPlan(
            stt: PerfSTTPlan(
                mode: "batch",
                selectionPolicy: sttSelectionPolicy,
                forcedProvider: sttForcedProvider,
                chain: sttChain
            ),
            rewrite: PerfRewritePlan(
                routing: rewriteRouting,
                hasGeminiDirect: hasGeminiDirect
            )
        )
    }
}
