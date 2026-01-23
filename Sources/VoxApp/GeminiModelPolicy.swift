import Foundation
import VoxCore

enum GeminiModelPolicy {
    private static let maxOutputTokens = 65_536
    private static let allowedPrefixes = [
        "gemini-3-pro",
        "gemini-3-flash"
    ]

    static func ensureSupported(_ modelId: String) throws {
        guard isSupported(modelId) else {
            throw VoxError.internalError("Unsupported Gemini model '\(modelId)'. Use gemini-3-pro or gemini-3-flash.")
        }
    }

    static func isSupported(_ modelId: String) -> Bool {
        let id = modelId.lowercased()
        guard !id.contains("image") else { return false }
        return allowedPrefixes.contains { id.hasPrefix($0) }
    }

    static func maxOutputTokens(for modelId: String) -> Int {
        _ = modelId
        return maxOutputTokens
    }

    static func effectiveMaxOutputTokens(requested: Int?, modelId: String) -> Int {
        let maxTokens = maxOutputTokens(for: modelId)
        guard let requested, requested > 0 else {
            return maxTokens
        }
        return min(requested, maxTokens)
    }

    static func normalizedModelId(_ modelId: String) -> String {
        let trimmed = modelId.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = trimmed.lowercased()
        switch normalized {
        case "gemini-3-flash":
            return "gemini-3-flash-preview"
        case "gemini-3-pro":
            return "gemini-3-pro-preview"
        default:
            return trimmed
        }
    }
}
