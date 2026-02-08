import Foundation

/// Runs multiple STT providers in a staggered race and returns the first success.
public struct HedgedSTTProvider: STTProvider {
    public struct Entry: Sendable {
        public let name: String
        public let provider: STTProvider
        public let delay: TimeInterval

        public init(name: String, provider: STTProvider, delay: TimeInterval = 0) {
            self.name = name
            self.provider = provider
            self.delay = delay
        }
    }

    private enum AttemptResult {
        case success(providerName: String, transcript: String)
        case failure(providerName: String, error: Error)
    }

    private let entries: [Entry]
    private let onProviderStart: (@Sendable (_ providerName: String) -> Void)?

    public init(
        entries: [Entry],
        onProviderStart: (@Sendable (_ providerName: String) -> Void)? = nil
    ) {
        precondition(!entries.isEmpty, "HedgedSTTProvider requires at least one entry")

        var normalized: [Entry] = []
        var seenNames = Set<String>()
        normalized.reserveCapacity(entries.count)

        for (index, entry) in entries.enumerated() {
            let name = entry.name.trimmingCharacters(in: .whitespacesAndNewlines)
            precondition(!name.isEmpty, "Entry at index \(index) has an empty name")
            precondition(entry.delay >= 0, "Entry \(name) has a negative delay")
            precondition(!seenNames.contains(name), "Duplicate entry name: \(name)")
            seenNames.insert(name)
            normalized.append(Entry(name: name, provider: entry.provider, delay: entry.delay))
        }

        self.entries = normalized
        self.onProviderStart = onProviderStart
    }

    public func transcribe(audioURL: URL) async throws -> String {
        try await withThrowingTaskGroup(of: AttemptResult.self) { group in
            for entry in entries {
                group.addTask {
                    if entry.delay > 0 {
                        try await Task.sleep(nanoseconds: Self.delayNanoseconds(for: entry.delay))
                    }
                    try Task.checkCancellation()
                    if let onProviderStart {
                        await MainActor.run {
                            onProviderStart(entry.name)
                        }
                    }

                    do {
                        let transcript = try await entry.provider.transcribe(audioURL: audioURL)
                        return .success(providerName: entry.name, transcript: transcript)
                    } catch is CancellationError {
                        throw CancellationError()
                    } catch {
                        return .failure(providerName: entry.name, error: error)
                    }
                }
            }

            var lastFallbackError: Error?
            while let result = try await group.next() {
                switch result {
                case .success(let providerName, let transcript):
                    print("[STT] Hedged race winner: \(providerName)")
                    group.cancelAll()
                    return transcript

                case .failure(let providerName, let error):
                    if let sttError = error as? STTError, !sttError.isFallbackEligible {
                        print("[STT] \(providerName) failed: \(sttError.localizedDescription) — stopping hedge")
                        group.cancelAll()
                        throw sttError
                    }

                    print("[STT] \(providerName) failed: \(error.localizedDescription) — waiting for other hedges")
                    lastFallbackError = error
                }
            }

            throw lastFallbackError ?? STTError.unknown("No STT providers available")
        }
    }

    private static func delayNanoseconds(for delay: TimeInterval) -> UInt64 {
        let nanoseconds = max(0, delay) * 1_000_000_000
        if nanoseconds >= Double(UInt64.max) {
            return UInt64.max
        }
        return UInt64(nanoseconds.rounded())
    }
}
