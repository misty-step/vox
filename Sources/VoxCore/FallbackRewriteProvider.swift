import Foundation

/// Sequential fallback across rewrite providers.
/// Tries each entry in order; only actual errors trigger the next attempt.
/// CancellationError always propagates immediately.
public final class FallbackRewriteProvider: RewriteProvider, @unchecked Sendable {
    public struct Entry: Sendable {
        public let provider: any RewriteProvider
        public let model: String
        public let label: String

        public init(provider: any RewriteProvider, model: String, label: String) {
            self.provider = provider
            self.model = model
            self.label = label
        }
    }

    private let entries: [Entry]

    public init(entries: [Entry]) {
        precondition(!entries.isEmpty, "FallbackRewriteProvider requires at least one entry")
        self.entries = entries
    }

    public func rewrite(transcript: String, systemPrompt: String, model: String) async throws -> String {
        var lastError: Error?

        for (index, entry) in entries.enumerated() {
            try Task.checkCancellation()
            do {
                return try await entry.provider.rewrite(
                    transcript: transcript,
                    systemPrompt: systemPrompt,
                    model: entry.model
                )
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                lastError = error
                if index < entries.count - 1 {
                    print("[Rewrite] \(entry.label) failed: \(errorSummary(error)), trying next provider")
                }
            }
        }

        throw lastError ?? RewriteError.unknown("All rewrite providers failed")
    }

    private func errorSummary(_ error: Error) -> String {
        if let r = error as? RewriteError {
            return r.localizedDescription
        }
        return String(describing: type(of: error))
    }
}
