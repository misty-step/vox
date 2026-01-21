import Foundation
import VoxCore

enum OpenRouterModelPolicy {
    static func ensureSupported(_ modelId: String) throws {
        let trimmed = modelId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw VoxError.internalError("OpenRouter model id is required.")
        }
    }
}
